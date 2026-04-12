-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local function insert_current_date()
  local date = os.date("%b %d, %Y")
  vim.api.nvim_put({ date }, "c", true, true)
end

-- Match the current Spacemacs major-mode date insertion habit (`<localleader>oc`)
-- for the filetypes where it is configured today.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "plaintex", "org" },
  callback = function(event)
    vim.keymap.set("n", "<localleader>oc", insert_current_date, {
      buffer = event.buf,
      desc = "Insert current date",
    })
  end,
})

-- === Jupyter cell workflow ===================================================
-- See docs/superpowers/specs/2026-04-12-nvim-jupyter-workflow-design.md.
-- BufReadCmd/BufWriteCmd for *.ipynb and buffer-local keymaps for python files.

require("jupyter.autocmds").setup()

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("JupyterFiletype", { clear = true }),
  pattern = "python",  -- BufReadCmd normalizes .ipynb -> python; no "ipynb" branch needed
  callback = function(args)
    require("jupyter.keymaps").setup(args.buf)
  end,
})
