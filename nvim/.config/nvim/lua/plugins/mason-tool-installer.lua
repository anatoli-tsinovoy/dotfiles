return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "stylua",
        "shfmt",
      },
      auto_update = false,
      run_on_start = true,
    },
  },
}
