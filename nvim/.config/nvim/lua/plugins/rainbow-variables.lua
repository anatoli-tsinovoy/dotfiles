-- Semantic variable highlighting: each variable name gets a unique color
-- based on its name hash, similar to the VSCode Semantic Highlighting extension.
return {
  {
    "goldos24/rainbow-variables-nvim",
    event = "LspAttach",
    config = function()
      -- 9-color palette: first 5 from Cursor semantic-highlighting config,
      -- last 4 derived from tokyonight theme for visual coherence.
      -- All tested for readability on both dark (#110034) and light (#F3F0DF).
      require("rainbow-variables-nvim").start_with_config({
        palette = {
          "#B5544E", -- Red
          "#33BCA7", -- Teal
          "#B8953E", -- Gold
          "#6D50B5", -- Purple
          "#E69AB3", -- Pink
          "#4A8EC2", -- Steel Blue
          "#CC7832", -- Orange
          "#5EA868", -- Forest Green
          "#9A67FF", -- Lavender
        },
        reduce_color_collisions = true,
        semantic_background_colors = false,
      })

      -- To re-enable semantic_background_colors, flip to true above and
      -- uncomment below to override the plugin's hardcoded dark-only backgrounds:
      --
      -- local function apply_semantic_backgrounds()
      --   local is_light = (vim.o.background == "light")
      --   if is_light then
      --     vim.api.nvim_set_hl(0, "@lsp.type.parameter", { bg = "#E3DCC6" })
      --     vim.api.nvim_set_hl(0, "@lsp.type.property", { bg = "#DDD5B8" })
      --     vim.api.nvim_set_hl(0, "@lsp.type.variable", { bg = "#E8E2CE" })
      --   else
      --     vim.api.nvim_set_hl(0, "@lsp.type.parameter", { bg = "#1A0845" })
      --     vim.api.nvim_set_hl(0, "@lsp.type.property", { bg = "#0E0028" })
      --     vim.api.nvim_set_hl(0, "@lsp.type.variable", { bg = "#150540" })
      --   end
      -- end
      -- apply_semantic_backgrounds()
      -- vim.api.nvim_create_autocmd("ColorScheme", {
      --   group = vim.api.nvim_create_augroup("RainbowVarsBg", { clear = true }),
      --   callback = apply_semantic_backgrounds,
      -- })
    end,
  },
}
