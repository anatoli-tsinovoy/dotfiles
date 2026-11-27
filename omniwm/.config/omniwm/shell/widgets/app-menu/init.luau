-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local button = require("../lib/menu-button")
local look = require("../lib/look")

function render(ctx: Context)
    local app = ctx.data.menuApp
    if app == nil or not ctx.data.bar.style.hidesMenuBar then
        return ui.box{ w = 0, h = 0 }
    end
    local node = button.render(ctx, { app = if app.bundle ~= "" then app.bundle else nil,
        pid = if app.bundle == "" then app.pid else nil, action = "menu app", help = app.name })
    local image = node[1]
    local glyph = look.appGlyph(app.name, image.w * 0.86, ctx.data.bar.style.solidBlack and "#FFFFFF" or "foreground")
    if glyph then
        node[1] = glyph
    end
    return node
end
