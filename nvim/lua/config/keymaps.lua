-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- jk to escape (matches Spacemacs evil-escape)
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Visual line navigation (don't skip wrapped lines)
map("n", "j", "gj", { desc = "Down (visual line)" })
map("n", "k", "gk", { desc = "Up (visual line)" })

-- Insert date (matches Spacemacs ,oc and .vimrc <leader>dat)
map("n", "<leader>id", function()
  local date = os.date("%b %d, %Y")
  vim.api.nvim_put({ date }, "c", true, true)
end, { desc = "Insert date" })
