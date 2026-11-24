return require("../lib/skin")({
    capsules = true,
    workspaceMetrics = function(_, style, metrics)
        local item = style.height - 10
        if item >= 16 then
            return { item = math.min(metrics.item, item) }
        end
    end,
})
