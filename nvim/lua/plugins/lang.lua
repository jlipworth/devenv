-- Language tooling on top of the LazyVim language extras, which are imported
-- from lua/config/lazy.lua (LazyVim requires every extras import to sit before
-- the `plugins` import, otherwise it warns about the import order).
local has_powershell = vim.fn.executable("pwsh") == 1 or vim.fn.executable("powershell") == 1
local has_sourcekit = vim.fn.executable("sourcekit-lsp") == 1
local disable_auto_installs = vim.env.NVIM_DISABLE_AUTO_INSTALLS == "1"

return {
  -- markdown-preview.nvim (transitive via the lang.markdown extra) is
  -- unmaintained (last commit 2023-10-17, 30+ mo). render-markdown.nvim from
  -- the same extra covers in-buffer rendering and is actively maintained;
  -- live-preview.nvim (below) covers browser preview.
  { "iamcco/markdown-preview.nvim", enabled = false },

  -- Shell + HTML/CSS + PowerShell support
  {
    "nvim-treesitter/nvim-treesitter",
    -- Parsers are compiled with the tree-sitter CLI, which mason provides;
    -- depending on mason keeps it on PATH before any parser install runs.
    dependencies = { "mason-org/mason.nvim" },
    opts = function(_, opts)
      if disable_auto_installs then
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
      -- Spacemacs vimscript / nginx / sql layer parity.
      opts.servers.vimls = {}
      opts.servers.nginx_language_server = {}
      opts.servers.sqls = {}

      -- PowerShell / Windows scripts support (.ps1). Only enable when a
      -- PowerShell executable is available, otherwise Mason/PSES install will fail.
      if has_powershell then
        opts.servers.powershell_es = {}
      end

      -- Swift: sourcekit-lsp ships with the Xcode/Swift toolchain and is not
      -- a mason package, so only wire it up when it is already on PATH.
      if has_sourcekit then
        opts.servers.sourcekit = { mason = false }
      end

      -- C++20 modules. Extend LazyVim's clangd cmd instead of replacing it so
      -- the extra's --background-index/--clang-tidy/... flags survive.
      local clangd = opts.servers.clangd
      if type(clangd) == "table" and type(clangd.cmd) == "table" then
        if not vim.tbl_contains(clangd.cmd, "--experimental-modules-support") then
          table.insert(clangd.cmd, "--experimental-modules-support")
        end
      end

      -- CI / provisioning runs must not trigger mason installs. LazyVim
      -- derives mason-lspconfig's ensure_installed from this `servers` table,
      -- so opting every server out of mason is what actually neutralises it.
      if disable_auto_installs then
        for name, server in pairs(opts.servers) do
          opts.servers[name] = type(server) == "table" and server or {}
          opts.servers[name].mason = false
        end
      end
    end,
  },
  {
    -- The pinned mason-lspconfig (v2) supports `ensure_installed` and
    -- `automatic_enable` only; `automatic_installation` was removed upstream.
    -- LazyVim passes `automatic_enable = { exclude = ... }` itself.
    --
    -- NOTE: this `ensure_installed = {}` override is a no-op safety net, not
    -- the thing that disables installs. LazyVim builds its own list and does
    -- `vim.list_extend(install, LazyVim.opts("mason-lspconfig.nvim").ensure_installed or {})`
    -- (lazyvim/plugins/lsp/init.lua), which always *appends* this spec's
    -- value onto its derived list rather than replacing it, so setting it to
    -- `{}` here can never clear anything. The `mason = false` loop in the
    -- nvim-lspconfig opts above (which flips every entry in `servers`) is
    -- what actually prevents mason-lspconfig from installing anything: do
    -- not remove that loop believing this block covers it.
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      if disable_auto_installs then
        opts.ensure_installed = {}
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonUpdate",
      "MasonLog",
    },
    -- Use function form (not table) to merge ensure_installed with entries from
    -- LazyVim language extras, which also contribute to this list. Only non-LSP
    -- tools belong here: LSP servers listed under `servers` above are installed
    -- by LazyVim through mason-lspconfig, and listing them twice double-books
    -- the install.
    opts = function(_, opts)
      if disable_auto_installs then
        opts.ensure_installed = {}
        return
      end
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "shellcheck",
        "ruff",
        "prettier",
      })
    end,
  },

  -- Format-on-save: ruff for Python (with import sorting), prettier for JS/TS
  -- Matches Spacemacs python-format-on-save + python-sort-imports-on-save
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      local wanted = {
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
      }
      -- Merge instead of replace: LazyVim's lang.markdown extra already sets
      -- markdown = { "prettier", "markdownlint-cli2", "markdown-toc" }, and a
      -- plain table override would drop the last two.
      for ft, formatters in pairs(wanted) do
        local current = opts.formatters_by_ft[ft]
        if current == nil then
          opts.formatters_by_ft[ft] = formatters
        else
          for _, formatter in ipairs(formatters) do
            if not vim.tbl_contains(current, formatter) then
              table.insert(current, formatter)
            end
          end
        end
      end
    end,
  },

  -- LaTeX preview: Skim on macOS, zathura elsewhere.
  {
    "lervag/vimtex",
    optional = true,
    init = function()
      vim.g.vimtex_view_method = vim.fn.has("mac") == 1 and "skim" or "zathura"
    end,
  },

  -- Browser-based markdown preview (replaces the unmaintained
  -- markdown-preview.nvim disabled above).
  {
    "brianhuster/live-preview.nvim",
    ft = { "markdown" },
    cmd = { "LivePreview" },
    keys = {
      { "<leader>cp", "<cmd>LivePreview start<cr>", ft = "markdown", desc = "Markdown preview" },
    },
    opts = {},
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
