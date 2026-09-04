local disable_ci_background_checks = vim.env.NVIM_DISABLE_AUTO_INSTALLS == "1"
local has_r = vim.fn.executable("Rscript") == 1

-- The `linting.eslint` extra reads this at spec-import time, so it has to be
-- set before `require("lazy").setup()` runs. false keeps prettier (configured
-- in plugins/lang.lua) as the JS/TS formatter instead of eslint's fix-on-save.
vim.g.lazyvim_eslint_auto_format = false

-- All LazyVim extras are imported here, in the order LazyVim's startup check
-- expects: `lazyvim.plugins` first, then every `lazyvim.plugins.extras.*`,
-- then our own `plugins` directory. Importing extras from inside `plugins/`
-- trips LazyVim's "import order is incorrect" warning on interactive start.
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- Editor / workflow extras
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    { import = "lazyvim.plugins.extras.util.octo" },
    { import = "lazyvim.plugins.extras.dap.core" },

    -- Language extras (lang.python and lang.typescript also pull in
    -- nvim-dap-python and the JS/TS dap adapters once dap.core is present).
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.sql" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.tex" },
    { import = "lazyvim.plugins.extras.lang.tailwind" },
    { import = "lazyvim.plugins.extras.lang.clangd" },
    { import = "lazyvim.plugins.extras.lang.cmake" },
    -- Spacemacs layer parity: rust, ocaml, terraform, docker, ansible, helm.
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.ocaml" },
    { import = "lazyvim.plugins.extras.lang.terraform" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.ansible" },
    { import = "lazyvim.plugins.extras.lang.helm" },
    -- R support only makes sense with an R interpreter on PATH; the extra
    -- would otherwise have mason install r-languageserver on a machine that
    -- cannot run it.
    { import = "lazyvim.plugins.extras.lang.r", enabled = has_r },

    { import = "lazyvim.plugins.extras.linting.eslint" },

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
