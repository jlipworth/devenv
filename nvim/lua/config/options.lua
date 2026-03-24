-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Keep this file limited to settings grounded in the current `.spacemacs`.

local opt = vim.opt

-- Match the current `.spacemacs` line-number preference.
opt.number = true
opt.relativenumber = true

-- Match Spacemacs `evil-escape-delay`.
opt.timeoutlen = 200
