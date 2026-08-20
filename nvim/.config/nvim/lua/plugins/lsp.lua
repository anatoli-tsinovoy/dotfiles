-- Enable ty LSP (not yet in mason-lspconfig, so we enable manually)
vim.lsp.enable("ty")

return {
  { import = "lazyvim.plugins.extras.lang.dart" },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Python linter (ruff LSP provides diagnostics)
        ruff = {},
        -- Lua (comes with LazyVim defaults, but explicit for clarity)
        lua_ls = {},
      },
    },
  },
}
