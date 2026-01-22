return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format", "ruff_organize_imports" },
        lua = { "stylua" },
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
      formatters = {
        ruff_organize_imports = {
          command = "ruff",
          args = { "check", "--select", "I", "--fix-only", "--stdin-filename", "$FILENAME", "-" },
          stdin = true,
        },
      },
    },
  },
}
