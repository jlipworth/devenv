return {
  -- Use tokyonight as the default colorscheme (LazyVim default, good terminal support)
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
    },
  },

  -- Set it as the LazyVim colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },

  { "catppuccin/nvim", enabled = false },
}
