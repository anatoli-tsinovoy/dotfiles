local SOURCE_BADGE = "M2.5 0 H12.5 Q15 0 15 2.5 V11.5 Q15 14 12.5 14 H2.5 Q0 14 0 11.5 V2.5 Q0 0 2.5 0 Z "
local SOURCE_CUTOUTS = {
    ["com.apple.keylayout.ABC"] = "M6.7 3 H8.3 L11.5 11 H9.9 L9.2 9.1 H5.8 L5.1 11 H3.5 Z M7.5 4.7 L6.3 7.8 H8.7 Z",
    ["com.apple.keylayout.Hebrew"] = "M3.8 3.5 H5.6 L8.8 7.2 Q9.5 6.1 9.5 3.5 H11 Q11 6.6 9.7 8.3 L11.5 10.5 H9.7 L6.4 6.6 Q5.5 7.8 5.5 10.5 H4 Q4 7.2 5.5 5.5 Z",
}
local UNKNOWN_SOURCE_CUTOUT = "M4.8 5.6 C4.8 2.1 10.2 2.1 10.2 5.2 C10.2 7.1 8.2 7.1 8.2 8.5 H6.8 C6.8 6.5 8.8 6.4 8.8 5.2 C8.8 3.9 6.2 3.9 6.2 5.6 Z M6.8 9.5 H8.2 V11 H6.8 Z"

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

local function appGlyphOpacity(item, style, metrics)
    if item.count > 0 and item.hidden == item.count then
        return 0.9
    end
    if item.focused or metrics.indicator == "pills" then
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
    renderWorkspaceGlyph(icon, glyph, item, metrics.icon, appGlyphOpacity(item, style, metrics), true)
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

-- SketchyBar used these bands on battery, with a yellow bolt whenever on AC.
local BATTERY_BANDS = {
    { 80, "battery.100percent", "accent", "accent" },
    { 60, "battery.75percent", "warning", "warning" },
    { 30, "battery.50percent", "#E6B334", "#FFE680" },
    { 10, "battery.25percent", "error", "#FF6767" },
    { 0, "battery.0percent", "error", "error" },
}

local function batteryIcon(ctx, state)
    local power = ctx.data.power
    if state.charging or (power and power.source == "ac") then
        return "battery.100percent.bolt", "warning"
    end
    for _, band in ipairs(BATTERY_BANDS) do
        if state.level >= band[1] then
            return band[2], ctx.data.appearance == "light" and band[3] or band[4]
        end
    end
end

look = require("../lib/skin")({
    capsules = true,
    workspaceMetrics = function(_, style, metrics)
        local item = style.height - 10
        return {
            item = item >= 16 and math.min(metrics.item, item) or metrics.item,
        }
    end,
    workspacePill = function(pill, workspace, _, metrics)
        if metrics.indicator == "pills" then
            pill.fill = "background"
            pill.border = workspace.focused and "accent" or "border/0.38"
            pill.borderWidth = 1.5
        end
    end,
    workspaceMarker = function(ctx, workspace, _, metrics)
        if metrics.indicator ~= "pills" or workspace.focused then
            return nil
        end
        local length = utf8.len(workspace.name)
        local width = metrics.vertical and metrics.item - 4 or (length == 1 and 16 or 28) * metrics.scale
        local label = look.text{
            text = workspace.name, size = 13 * metrics.scale, weight = "medium",
            color = ctx.data.appearance == "light" and "#C47891" or "#FFC9D7",
            maxWidth = metrics.vertical and width or nil,
        }
        return length <= 2 and ui.stack{ w = width, h = metrics.icon, label } or label
    end,
    windowIcon = windowIcon,
    scratchpadIcon = scratchpadIcon,
    activeWindowBar = activeWindowBar,
    appGlyph = appGlyph,
    batteryDetailsBar = function(ctx, state)
        local symbol, color = batteryIcon(ctx, state)
        local scale = look.scale(ctx)
        local icon = look.glyph{ name = symbol, size = 18 * scale, color = color }
        if ctx.data.bar.style.vertical then
            return look.bar(ctx, { gap = scale, pad = 2 * scale, icon,
                look.text{ text = state.text, size = 10 * scale } })
        end
        if state.mode == "inside" then
            icon = ui.stack{ w = 30 * scale, h = 15 * scale, radius = 4 * scale,
                border = color, borderWidth = scale,
                look.text{ text = state.text, size = 10 * scale, color = color } }
        end
        return look.bar(ctx, { icon,
            if state.mode == "beside" then look.text{ text = state.percent, size = 13 * scale, reserve = state.reserve }
            else nil })
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
            ui.path{
                w = 15 * scale, h = 14 * scale, viewBox = { 0, 0, 15, 14 },
                d = SOURCE_BADGE .. (SOURCE_CUTOUTS[source] or UNKNOWN_SOURCE_CUTOUT),
                fill = "foreground", evenOdd = true,
            },
        })
    end,
})
return look
