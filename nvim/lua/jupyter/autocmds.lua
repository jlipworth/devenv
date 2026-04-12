-- BufReadCmd / BufWriteCmd for *.ipynb: transparently round-trip via the
-- jupytext CLI. Keeps the buffer as filetype=python with `# %%` markers.

local M = {}

local function notify_err(msg)
  vim.notify("jupyter: " .. msg, vim.log.levels.ERROR)
end

-- Read .ipynb via `jupytext --to py:percent --output - <path>`.
-- Uses nvim_buf_get_name to get the real path (args.match may be a pattern
-- expansion that drops the directory component on some platforms).
local function on_read(args)
  local path = vim.api.nvim_buf_get_name(args.buf)
  if path == "" then path = args.match end
  local result = vim.fn.systemlist({ "jupytext", "--to", "py:percent", "--output", "-", path })
  if vim.v.shell_error ~= 0 then
    notify_err("jupytext read failed for " .. path)
    return
  end
  vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, result)
  vim.bo[args.buf].filetype = "python"
  vim.bo[args.buf].modified = false
end

-- Write .ipynb by piping current buffer lines to jupytext.
-- Fires BufWritePost on success so format-on-save, gitsigns, LSP sync keep working.
local function on_write(args)
  local path = vim.api.nvim_buf_get_name(args.buf)
  if path == "" then path = args.match end
  local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
  local tmp = vim.fn.tempname() .. ".py"
  if vim.fn.writefile(lines, tmp) ~= 0 then
    notify_err("failed to write temp buffer for " .. path)
    return
  end
  vim.fn.system({ "jupytext", "--from", "py:percent", "--to", "ipynb",
                  "--output", path, tmp })
  local rc = vim.v.shell_error
  vim.fn.delete(tmp)
  if rc ~= 0 then
    notify_err("jupytext write failed for " .. path)
    return
  end
  vim.bo[args.buf].modified = false
  vim.api.nvim_exec_autocmds("BufWritePost", {
    buffer = args.buf,
    modeline = false,
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("JupyterIpynb", { clear = true })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = on_read,
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = on_write,
  })
end

return M
