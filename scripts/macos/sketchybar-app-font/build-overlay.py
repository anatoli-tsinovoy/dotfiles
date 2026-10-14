#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["fonttools==4.58.5", "lxml==5.4.0"]
# ///

"""Append local SVG glyphs to an installed sketchybar-app-font derivative."""

import argparse
import json
import os
import re
import shlex
import tempfile
from pathlib import Path

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import SVGPath
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

PUA_START, PUA_END = 0xF0000, 0xFFFFD
DEFAULT_ICON = ":default:"
FAMILY = "sketchybar-app-font-local"


def add_unicode_cmap(font, mappings):
    cmap = font["cmap"]
    stock_mappings = font.getBestCmap().copy()
    subtables = [s for s in cmap.tables if s.format == 12 and s.isUnicode()]
    for platform, encoding in ((0, 4), (3, 10)):
        subtable = next(
            (
                s
                for s in subtables
                if s.platformID == platform and s.platEncID == encoding
            ),
            None,
        )
        if subtable is None:
            subtable = CmapSubtable.newSubtable(12)
            subtable.platformID, subtable.platEncID = platform, encoding
            subtable.language, subtable.cmap = 0, stock_mappings.copy()
            cmap.tables.append(subtable)
            subtables.append(subtable)
    for subtable in subtables:
        subtable.cmap.update(mappings)


def atomic_write(font, font_path, map_path, map_text):
    staged = []
    try:
        for output in (font_path, map_path):
            output.parent.mkdir(parents=True, exist_ok=True)
            fd, name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
            os.close(fd)
            staged.append(Path(name))
        font.save(str(staged[0]))
        staged[1].write_text(map_text, encoding="utf-8")
        for path in staged:
            os.chmod(path, 0o644)
        os.replace(staged[0], font_path)
        os.replace(staged[1], map_path)
    finally:
        for path in staged:
            path.unlink(missing_ok=True)


def build(stock_path, overrides_path, svg_dir, font_path, map_path):
    if stock_path.resolve() in {font_path.resolve(), map_path.resolve()}:
        raise ValueError("overlay outputs must not replace the stock Homebrew font")
    if not svg_dir.is_dir():
        raise ValueError(f"local SVG directory does not exist: {svg_dir}")

    overrides = json.loads(overrides_path.read_text(encoding="utf-8"))
    font = TTFont(str(stock_path), recalcTimestamp=False)
    try:
        metadata = font["meta"].data
        raw_appm = metadata.get(b"APPM", metadata.get("APPM"))
        appm = json.loads(
            raw_appm.decode("utf-8") if isinstance(raw_appm, bytes) else raw_appm
        )
        if appm["version"] != 1:
            raise ValueError("stock font APPM metadata must use version 1")
        icons_list = appm["icons"]
        icons = {name: (codepoint, apps) for name, codepoint, apps in icons_list}
        cmap = font.getBestCmap()
        default_cp = icons[DEFAULT_ICON][0]
        upem = font["head"].unitsPerEm
        paths = sorted(
            svg_dir.glob("*.svg"), key=lambda p: (p.name != ":tern:.svg", p.name)
        )
        used_cps = {
            cp for sub in font["cmap"].tables if sub.isUnicode() for cp in sub.cmap
        }
        local, glyph_order, new_glyphs = {}, list(font.getGlyphOrder()), {}
        glyf, hmtx = font["glyf"], font["hmtx"].metrics

        for index, path in enumerate(paths):
            ligature, codepoint = path.name[:-4], PUA_START + index
            if codepoint > PUA_END or codepoint in used_cps:
                raise ValueError(
                    f"local SVG {path.name} cannot use reserved U+{codepoint:06X}"
                )
            svg = SVGPath(str(path))
            x_min, y_min, width, height = map(
                float, re.split(r"[\s,]+", svg.root.get("viewBox").strip())
            )
            if width != height:
                raise ValueError(f"local SVG {path} must have a square viewBox")
            scale = upem / width
            glyph_pen = TTGlyphPen(None)
            pen = Cu2QuPen(glyph_pen, max_err=upem / 1000)
            transform = (scale, 0, 0, -scale, -x_min * scale, (y_min + height) * scale)
            svg.draw(TransformPen(pen, transform))
            glyph = glyph_pen.glyph()

            stock_icon = icons.get(ligature)
            metric_cp = stock_icon[0] if stock_icon else default_cp
            metric_name = cmap[metric_cp]
            glyph_name = f"localOverlay{codepoint:06X}"
            local[ligature] = codepoint
            glyf[glyph_name] = glyph
            hmtx[glyph_name] = hmtx[metric_name]
            glyph_order.append(glyph_name)
            new_glyphs[codepoint] = glyph_name

        font.setGlyphOrder(glyph_order)
        font["maxp"].numGlyphs = len(glyph_order)
        if new_glyphs:
            add_unicode_cmap(font, new_glyphs)

        def icon_codepoint(ligature, app_pattern):
            if ligature in local:
                return local[ligature]
            if ligature not in icons:
                raise ValueError(
                    f"override for {app_pattern!r} targets missing {ligature!r}; "
                    f"add {ligature}.svg or use a ligature in stock APPM"
                )
            codepoint = icons[ligature][0]
            if codepoint not in cmap:
                raise ValueError(
                    f"stock ligature {ligature!r} has no Unicode cmap entry"
                )
            return codepoint

        cases, seen = [], set()
        for pattern, ligature in overrides.items():
            cases.append((pattern, icon_codepoint(ligature, pattern)))
            seen.add(pattern)
        for _, codepoint, apps in icons_list:
            for pattern in apps or []:
                if pattern not in seen:
                    cases.append((pattern, codepoint))
                    seen.add(pattern)

        lines = ["__icon_map() {", '  case "$1" in']
        for pattern, codepoint in cases:
            shell_pattern = "*".join(shlex.quote(part) for part in pattern.split("*"))
            lines.extend(
                [
                    f"    {shell_pattern})",
                    f"      icon_result={shlex.quote(chr(codepoint))}",
                    "      ;;",
                ]
            )
        lines.extend(
            [
                "    *)",
                f"      icon_result={shlex.quote(chr(default_cp))}",
                "      ;;",
                "  esac",
                "}",
                "",
            ]
        )

        names = {
            1: FAMILY,
            3: f"{FAMILY} Regular (local overlay)",
            4: f"{FAMILY} Regular",
            6: f"{FAMILY}-Regular",
            16: FAMILY,
            17: "Regular",
        }
        table = font["name"]
        for name_id, value in names.items():
            records = [r for r in table.names if r.nameID == name_id]
            if not records:
                table.setName(value, name_id, 3, 1, 0x409)
            for record in records:
                table.setName(
                    value, name_id, record.platformID, record.platEncID, record.langID
                )
        atomic_write(font, font_path, map_path, "\n".join(lines))
    finally:
        font.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("stock-font", "overrides", "svg-dir", "font-output", "map-output"):
        parser.add_argument(
            f"--{name}", required=True, type=Path, dest=name.replace("-", "_")
        )
    args = parser.parse_args()
    try:
        build(
            args.stock_font,
            args.overrides,
            args.svg_dir,
            args.font_output,
            args.map_output,
        )
    except (OSError, KeyError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
