local SOURCE_GLYPHS = {
    ["com.apple.keylayout.ABC"] = "A",
    ["com.apple.keylayout.Hebrew"] = "א",
}

local SPEAKER = "M2 6 H5 L10 2 Q11 1 11 3 V15 Q11 17 10 16 L5 12 H2 Q1 12 1 11 V7 Q1 6 2 6 Z"
local VOLUME_WAVES = {
    "M14 6 Q16 9 14 12",
    "M17 4 Q20 9 17 14",
    "M20 2 Q24 9 20 16",
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
