-- Jupyter / .ipynb editing. See docs/superpowers/specs/2026-04-12-nvim-jupyter-workflow-design.md
-- Plugin delta: +2 (iron.nvim for REPL, mini.hipatterns for # %% marker highlight).
-- mini.ai contribution and which-key group are added in Task 7.
-- The setup calls and FileType autocmd live in config/autocmds.lua (Task 6)
-- — NOT here, because lazy.nvim does not run user `config` blocks for its
-- own spec entry, and every other plugin-piggyback is brittle.

return {
  -- REPL sender: current buffer/visual/line -> external IPython via :terminal.
  {
    "Vigemus/iron.nvim",
    cmd = { "IronRepl", "IronAttach", "IronSend", "IronFocus" },
    config = function()
      local iron = require("iron.core")
      local view = require("iron.view")
      iron.setup({
        config = {
          scratch_repl = true,
          repl_definition = {
            python = {
              command = { "ipython", "--no-autoindent" },
              format = require("iron.fts.common").bracketed_paste_python,
            },
          },
          repl_open_cmd = view.split.vertical.botright("40%"),
        },
        -- Disable iron's default keymaps entirely; ours are installed per-buffer
        -- by jupyter.keymaps (Task 6) and must not collide with iron defaults.
        keymaps = false,
        highlight = { italic = true },
        ignore_blank_lines = true,
      })
    end,
  },

  -- Visual highlight for # %% cell markers.
  -- Lua pattern: %%%% matches literal %% (each %% = one literal %).
  {
    "echasnovski/mini.hipatterns",
    event = { "BufReadPost *.py", "BufReadPost *.ipynb", "BufNewFile *.py" },
    opts = function(_, opts)
      opts.highlighters = opts.highlighters or {}
      opts.highlighters.jupyter_cell = {
        pattern = "^# %%%%.*$",
        group = "Title",
      }
      return opts
    end,
  },
}
