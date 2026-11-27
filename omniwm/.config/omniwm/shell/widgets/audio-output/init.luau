-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

local function outputSymbol(output)
    if string.find(string.lower(output.name), "blackhole", 1, true) then
        return "laser.burst"
    elseif output.transport == "builtin" then
        return "hifispeaker.2.fill"
    end
    return "headphones.over.ear"
end

function render(ctx)
    local output
    for _, device in ctx.data.outputs or {} do
        if device.default then
            output = device
            break
        end
    end
    if not output then
        return ui.box{ w = 0, h = 0 }
    end

    local scale = look.scale(ctx)
    return look.bar(ctx, {
        help = output.name,
        [1] = look.glyph{ name = outputSymbol(output), size = 16 * scale },
    })
end
