local has_powershell = vim.fn.executable("pwsh") == 1 or vim.fn.executable("powershell") == 1

return {
  -- LazyVim language extras
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.sql" },
  { import = "lazyvim.plugins.extras.lang.toml" },
  { import = "lazyvim.plugins.extras.lang.r" },
  { import = "lazyvim.plugins.extras.lang.tex" },
  { import = "lazyvim.plugins.extras.lang.tailwind" },

  -- Shell + HTML/CSS + PowerShell support
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "powershell" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.bashls = {}
      -- HTML/CSS/SCSS LSP (matches Spacemacs html layer with css/scss/html lsp)
      opts.servers.html = {}
      opts.servers.cssls = {}
      opts.servers.emmet_ls = {}

      -- PowerShell / Windows scripts support (.ps1). Only enable when a
      -- PowerShell executable is available, otherwise Mason/PSES install will fail.
      if has_powershell then
        opts.servers.powershell_es = {}
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    -- Use function form (not table) to merge ensure_installed with entries from
    -- LazyVim language extras, which also contribute to this list.
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "bash-language-server",
        "shellcheck",
        "ruff",
        "prettier",
        "html-lsp",
        "css-lsp",
        "emmet-ls",
        "texlab",
        "r-languageserver",
      })
      if has_powershell then
        table.insert(opts.ensure_installed, "powershell-editor-services")
      end
    end,
  },

  -- Format-on-save: ruff for Python (with import sorting), prettier for JS/TS
  -- Matches Spacemacs python-format-on-save + python-sort-imports-on-save
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_format" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascriptreact = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        less = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
      },
    },
  },
}
