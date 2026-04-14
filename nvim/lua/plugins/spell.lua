-- Spell-check UI: Spacemacs `SPC S *` parity using Neovim's native spell.
-- No external dependency (aspell/hunspell not used); Neovim downloads
-- language .spl files on demand to ~/.local/share/nvim/site/spell/.

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>S", group = "spell" },
      },
    },
  },

  {
    "LazyVim/LazyVim",
    keys = {
      { "<leader>Sb", function()
          vim.opt_local.spell = true
          vim.opt_local.spelllang = "en_us"
          vim.notify("spell: on (en_us)")
        end,
        desc = "Enable spell (buffer)" },
      { "<leader>St", function()
          vim.opt_local.spell = not vim.opt_local.spell:get()
          vim.notify("spell: " .. (vim.opt_local.spell:get() and "on" or "off"))
        end,
        desc = "Toggle spell" },
      { "<leader>Sn", "]s", desc = "Next misspelling" },
      { "<leader>SN", "[s", desc = "Previous misspelling" },
      { "<leader>Ss", "z=", desc = "Suggest corrections" },
      { "<leader>Sa", "zg", desc = "Add word to dictionary" },
      { "<leader>Sw", "zw", desc = "Mark word as wrong" },
      { "<leader>Su", "zug", desc = "Undo add/mark word" },
    },
  },
}
