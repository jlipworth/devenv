-- Multi-cursor editing. See docs/superpowers/specs/2026-04-12-nvim-debug-polish-design.md
-- Plugin delta: +1 (vim-visual-multi).
-- Default <C-n> trigger: no conflict with LazyVim defaults (normal-mode
-- <C-n> is unbound; insert-mode <C-n> is cmp's "next item" and VM does
-- not claim insert-mode).

return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    keys = {
      { "<C-n>", mode = { "n", "v" }, desc = "Multi-cursor: select next match" },
      { "<C-Up>", mode = { "n" }, desc = "Multi-cursor: add cursor above" },
      { "<C-Down>", mode = { "n" }, desc = "Multi-cursor: add cursor below" },
    },
    init = function()
      -- Leave g:VM_maps at upstream defaults. If a future conflict
      -- surfaces, set a custom "Find Under" here.
    end,
  },
}
