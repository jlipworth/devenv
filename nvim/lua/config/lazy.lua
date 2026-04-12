local disable_ci_background_checks = vim.env.NVIM_DISABLE_AUTO_INSTALLS == "1"

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "lazyvim.plugins.extras.util.octo" },
    { import = "lazyvim.plugins.extras.dap.core" },
    -- lang.python and lang.typescript already imported in plugins/lang.lua;
    -- they pull in nvim-dap-python and JS/TS dap adapters respectively
    -- whenever dap.core is loaded. Keeping them out of here avoids a
    -- duplicate-import lint on the lazy spec.
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
