-- LuaSnip: load repo-managed VSCode-style snippets from nvim/snippets/.
-- See docs/superpowers/specs/2026-04-12-nvim-debug-polish-design.md §5.
-- Plugin delta: 0 (LuaSnip is already in LazyVim base).

return {
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      if opts then
        require("luasnip").setup(opts)
      end
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/snippets" },
      })
    end,
  },
}
