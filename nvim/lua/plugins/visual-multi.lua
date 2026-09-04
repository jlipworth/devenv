-- Multi-cursor editing. See docs/archive/2026-04-12-nvim-debug-polish-design.md
-- Plugin delta: +1 (vim-visual-multi).
-- Default <C-n> trigger: no conflict with LazyVim defaults (normal-mode
-- <C-n> is unbound; insert-mode <C-n> is cmp's "next item" and VM does
-- not claim insert-mode). The default "Add Cursor Up/Down" trigger
-- (<C-Up>/<C-Down>) DOES conflict with LazyVim's window-resize keymaps, so
-- those are remapped to <M-Up>/<M-Down> below.

return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    keys = {
      { "<C-n>", mode = { "n", "v" }, desc = "Multi-cursor: select next match" },
      { "<M-Up>", mode = { "n" }, desc = "Multi-cursor: add cursor above" },
      { "<M-Down>", mode = { "n" }, desc = "Multi-cursor: add cursor below" },
    },
    init = function()
      -- Leave the rest of g:VM_maps at upstream defaults; only move the
      -- cursor-add keys off <C-Up>/<C-Down> to avoid the LazyVim conflict.
      -- vim.g.<name> returns a copy on read, so indexing straight into it
      -- (vim.g.VM_maps["x"] = y) silently no-ops; build the table locally
      -- and assign it back wholesale.
      local vm_maps = vim.g.VM_maps or {}
      vm_maps["Add Cursor Up"] = "<M-Up>"
      vm_maps["Add Cursor Down"] = "<M-Down>"
      vim.g.VM_maps = vm_maps
    end,
  },
}
