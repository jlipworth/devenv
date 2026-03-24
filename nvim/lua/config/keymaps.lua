-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Match current Spacemacs `evil-escape` usage.
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Approximate `evil-respect-visual-line-mode`: only move by screen lines when
-- wrapping is actually enabled for the current buffer and no count was given.
map({ "n", "x" }, "j", "v:count == 0 && &wrap ? 'gj' : 'j'", {
  expr = true,
  silent = true,
  desc = "Down (respect wrapped lines)",
})
map({ "n", "x" }, "k", "v:count == 0 && &wrap ? 'gk' : 'k'", {
  expr = true,
  silent = true,
  desc = "Up (respect wrapped lines)",
})
