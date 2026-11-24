-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

local TRANSPORT = {
    builtin = "laptopcomputer",
    usb = "cable.connector",
    bluetooth = "headphones",
    hdmi = "display",
    displayport = "display",
    airplay = "airplayaudio",
    thunderbolt = "bolt.horizontal",
}

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
    local props = { help = output.name }
    props[1] = look.glyph{ name = TRANSPORT[output.transport] or "hifispeaker.fill", size = 14 * scale }
    if not ctx.data.bar.style.vertical then
        props[2] = look.text{ text = output.name, size = 13 * scale, maxWidth = 160 * scale }
    end
    return look.bar(ctx, props)
end
