local SOURCE_GLYPHS = {
    ["com.apple.keylayout.ABC"] = "A",
    ["com.apple.keylayout.Hebrew"] = "א",
}

local look
local appFontMapAvailable, APP_FONT_MAP = pcall(function()
    return require("./app-font-map")
end)
if not appFontMapAvailable then
    APP_FONT_MAP = nil
end

local function appGlyph(name, size, color, opacity)
    if APP_FONT_MAP == nil or type(name) ~= "string" or name == "" then
        return nil
    end
    local glyph
    for _, pattern in ipairs(APP_FONT_MAP.patterns or {}) do
        if string.match(name, pattern[1]) then
            glyph = pattern[2]
            break
        end
    end
    glyph = glyph or APP_FONT_MAP.default
    if type(glyph) ~= "string" or glyph == "" then
        return nil
    end
    return ui.text{
        text = glyph, font = APP_FONT_MAP.font, size = size * 0.8, color = color, opacity = opacity,
    }
end

local function appGlyphColor(item, showHidden)
    if showHidden and item.count > 0 and item.hidden == item.count then
        return "error/0.32"
    end
    return item.focused and "accent" or "purple"
end

local function appGlyphOpacity(item, style)
    if item.count > 0 and item.hidden == item.count then
        return 0.9
    end
    if item.focused then
        return 1
    end
    return if style.inactive >= 0 then style.inactive else 0.5
end

local function renderWorkspaceGlyph(parent, native, item, size, opacity, showHidden)
    local custom = appGlyph(item.name, size, appGlyphColor(item, showHidden), opacity)
    if custom then
        native.w = 0
        native.h = 0
        parent[#parent + 1] = custom
    end
end

local function windowIcon(icon, glyph, item, style, metrics)
    renderWorkspaceGlyph(icon, glyph, item, metrics.icon, appGlyphOpacity(item, style), true)
end

local function scratchpadIcon(slot, glyph, member, _scratchpad, _style, metrics)
    renderWorkspaceGlyph(slot, glyph, member, metrics.icon, glyph.opacity, false)
end

local function activeWindowBar(ctx, model)
    local scale = look.scale(ctx)
    local props = { help = model.help }
    if model.showIcon then
        local glyph = appGlyph(model.app, 18 * scale, "foreground")
        if not glyph then
            return nil
        end
        props[#props + 1] = glyph
    end
    if model.showText then
        props[#props + 1] = look.text{
            text = model.title, size = 13 * scale, weight = "medium", maxWidth = model.maxWidth,
        }
    end
    return look.bar(ctx, props)
end

local SPEAKER = "M2 6 H5 L10 2 Q11 1 11 3 V15 Q11 17 10 16 L5 12 H2 Q1 12 1 11 V7 Q1 6 2 6 Z"
local VOLUME_WAVES = {
    "M14 6 Q16 9 14 12",
    "M17 4 Q20 9 17 14",
    "M20 2 Q24 9 20 16",
}

look = require("../lib/skin")({
    capsules = true,
    workspaceMetrics = function(_, style, metrics)
        local item = style.height - 10
        if item >= 16 then
            return { item = math.min(metrics.item, item) }
        end
    end,
    windowIcon = windowIcon,
    scratchpadIcon = scratchpadIcon,
    activeWindowBar = activeWindowBar,
    appGlyph = appGlyph,
    volumeBar = function(ctx, state)
        local level = state.volume or 0
        local waveCount = if level >= 60 then 3 elseif level >= 30 then 2 elseif level >= 10 then 1 else 0
        local signal = if state.muted or state.volume == 0 then "M14 6 L20 12 M20 6 L14 12"
            else table.concat(VOLUME_WAVES, " ", 1, waveCount)
        local scale = look.scale(ctx)
        local width, height = 22 * scale, 16.5 * scale
        local viewBox = { 0, 0, 24, 18 }
        local icon = ui.stack{ w = width, h = height,
            ui.path{ w = width, h = height, viewBox = viewBox, d = SPEAKER, fill = "foreground" },
            if signal ~= "" then ui.path{
                w = width, h = height, viewBox = viewBox, d = signal,
                border = "foreground", borderWidth = 1.5 * scale,
            } else nil,
        }
        return look.bar(ctx, { icon })
    end,
    inputSourceBar = function(ctx, state)
        local source = ctx.select("vars", "dotfilesInputSourceID") or state.id
        local scale = look.scale(ctx)
        return look.bar(ctx, {
            pad = 2 * scale,
            ui.stack{
                w = 15 * scale, h = 14 * scale, radius = 2.5 * scale, fill = "foreground",
                look.text{
                    text = SOURCE_GLYPHS[source] or "?", size = 11 * scale, weight = "medium", color = "background",
                },
            },
        })
    end,
})
return look
