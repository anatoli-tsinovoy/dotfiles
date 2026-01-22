return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "ty",
        "ruff",
        "stylua",
        "shfmt",
      },
      auto_update = false,
      run_on_start = true,
    },
  },
}
