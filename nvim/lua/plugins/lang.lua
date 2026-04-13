local has_powershell = vim.fn.executable("pwsh") == 1 or vim.fn.executable("powershell") == 1
local has_r = vim.fn.executable("Rscript") == 1
local disable_auto_installs = vim.env.NVIM_DISABLE_AUTO_INSTALLS == "1"

return {
  -- LazyVim language extras
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  -- markdown-preview.nvim (transitive via lang.markdown) is unmaintained
  -- (last commit 2023-10-17, 30+ mo). render-markdown.nvim from the same
  -- extra covers in-buffer rendering and is actively maintained.
  { "iamcco/markdown-preview.nvim", enabled = false },
  { import = "lazyvim.plugins.extras.lang.sql" },
  { import = "lazyvim.plugins.extras.lang.toml" },
  { import = "lazyvim.plugins.extras.lang.r" },
  { import = "lazyvim.plugins.extras.lang.tex" },
  { import = "lazyvim.plugins.extras.lang.tailwind" },
  { import = "lazyvim.plugins.extras.lang.clangd" },
  { import = "lazyvim.plugins.extras.lang.cmake" },

  -- Shell + HTML/CSS + PowerShell support
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if disable_auto_installs then
        opts.auto_install = false
        opts.ensure_installed = {}
        return
      end
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "powershell" })
    end,
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
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonInstallAll",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonUpdate",
      "MasonLog",
    },
    -- Use function form (not table) to merge ensure_installed with entries from
    -- LazyVim language extras, which also contribute to this list.
    opts = function(_, opts)
      if disable_auto_installs then
        opts.ensure_installed = {}
        return
      end
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
      })
      if has_r then
        table.insert(opts.ensure_installed, "r-languageserver")
      end
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

  -- CSV/TSV: rainbow column highlighting + field navigation
  {
    "hat0uma/csvview.nvim",
    ft = { "csv", "tsv" },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
    opts = {
      view = {
        display_mode = "highlight",
      },
    },
  },
}
