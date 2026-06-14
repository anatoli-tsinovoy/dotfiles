-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

if vim.g.vscode then
  -- Keep undo/redo lists in sync with VSCode
  vim.keymap.set("n", "u", function()
    vim.fn.VSCodeNotify("undo")
  end, { silent = true })

  vim.keymap.set("n", "<C-r>", function()
    vim.fn.VSCodeNotify("redo")
  end, { silent = true })
end
