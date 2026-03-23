-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

-- Line wrapping and formatting
opt.textwidth = 100
opt.linebreak = true
opt.breakindent = true

-- Indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true

-- Search
opt.ignorecase = true
opt.smartcase = true

-- Clipboard
opt.clipboard = "unnamedplus"

-- UI
opt.number = true
opt.relativenumber = true
opt.scrolloff = 8
opt.termguicolors = true

-- Timeout for key sequences (matches Spacemacs evil-escape-delay)
opt.timeoutlen = 200
