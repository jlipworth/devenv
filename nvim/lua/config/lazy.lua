local disable_ci_background_checks = vim.env.NVIM_DISABLE_AUTO_INSTALLS == "1"

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "lazyvim.plugins.extras.util.octo" },
    { import = "plugins" },
  },
  defaults = { lazy = false },
  checker = { enabled = not disable_ci_background_checks },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
