-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Ghostty forwards Command-1..9 to Neovim (rather than using them for tabs).
-- Match Spacemacs/AeroSpace by selecting the corresponding visible window.
for number = 1, 9 do
  map("n", "<D-" .. number .. ">", number .. "<C-w>w", {
    desc = "Go to window " .. number,
  })
end

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
