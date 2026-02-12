-- Semantic variable highlighting: each variable gets a deterministic color
-- based on its name hash. Local module vendored from goldos24/rainbow-variables-nvim.

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("RainbowVariablesInit", { clear = true }),
  once = true,
  callback = function()
    require("lib.rainbow-variables").setup({
      palette = {
        "#B5544E", -- Red
        "#33BCA7", -- Teal
        "#B8953E", -- Gold
        "#6D50B5", -- Purple
        "#E69AB3", -- Pink
      },
      reduce_color_collisions = true,
      semantic_background_colors = false,
    })
  end,
})

return {}
