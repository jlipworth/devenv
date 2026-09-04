-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Match Spacemacs/AeroSpace by selecting a numbered visible window. <D-n>
-- covers direct GUI/CSI-u input; Ghostty encodes Cmd-n as <M-n> so it also
-- survives tmux, whose extended-key protocol cannot represent Super. Bound
-- in every mode (Spacemacs' equivalent works everywhere), leaving insert
-- and terminal via <Esc>/<C-\><C-n> before switching windows.
local window_mode_prefixes = { n = "", x = "<Esc>", i = "<Esc>", t = "<C-\\><C-n>" }
for number = 1, 9 do
  for _, modifier in ipairs({ "D", "M" }) do
    for mode, prefix in pairs(window_mode_prefixes) do
      map(mode, "<" .. modifier .. "-" .. number .. ">", prefix .. number .. "<C-w>w", {
        desc = "Go to window " .. number,
      })
    end
  end
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
