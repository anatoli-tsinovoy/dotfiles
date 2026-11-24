local SOURCE_GLYPHS = {
    ["com.apple.keylayout.ABC"] = "A",
    ["com.apple.keylayout.Hebrew"] = "א",
}

local look
look = require("../lib/skin")({
    capsules = true,
    workspaceMetrics = function(_, style, metrics)
        local item = style.height - 10
        if item >= 16 then
            return { item = math.min(metrics.item, item) }
        end
    end,
    volumeBar = function(ctx, state)
        local level = state.volume
        local symbol = if state.muted or level == 0 then "speaker.slash.fill"
            elseif not level or level < 10 then "speaker.fill"
            elseif level < 30 then "speaker.wave.1.fill"
            elseif level < 60 then "speaker.wave.2.fill"
            else "speaker.wave.3.fill"
        return look.bar(ctx, { look.glyph{ name = symbol, size = 14 * look.scale(ctx) } })
    end,
    inputSourceBar = function(ctx, state)
        local source = ctx.select("vars", "dotfilesInputSourceID") or state.id
        local scale = look.scale(ctx)
        return look.bar(ctx, {
            pad = 2 * scale,
            ui.stack{
                w = 18 * scale, h = 18 * scale, radius = 3 * scale, fill = "foreground",
                look.text{
                    text = SOURCE_GLYPHS[source] or "?", size = 12 * scale, weight = "medium", color = "background",
                },
            },
        })
    end,
})
return look
