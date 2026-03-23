return {
  -- LazyVim language extras
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.sql" },
  { import = "lazyvim.plugins.extras.lang.toml" },

  -- Shell LSP (no built-in LazyVim extra — manual config)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    -- Use function form (not table) to merge ensure_installed with entries from
    -- LazyVim language extras, which also contribute to this list.
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "bash-language-server", "shellcheck" })
    end,
  },
}
