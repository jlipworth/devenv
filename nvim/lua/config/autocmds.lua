-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Filetype-specific indentation (matches .vimrc settings)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "typescript", "typescriptreact", "javascriptreact", "json", "yaml", "html", "css" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})

-- Spell checking for text-oriented filetypes (matches .vimrc)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "text", "markdown", "gitcommit" },
  callback = function()
    vim.opt_local.spell = true
  end,
})
