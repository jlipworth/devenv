-- Spell-check UI under `<leader>S`, inspired by the Spacemacs spell-checking
-- layer's `SPC S` prefix but NOT a key-for-key port of it. Uses Neovim's
-- native spell support; no external dependency (aspell/hunspell not used).
-- Neovim downloads language .spl files on demand to
-- ~/.local/share/nvim/site/spell/.
--
-- Deviations from the Spacemacs `SPC S` letters:
--   * `Ss` suggests corrections (`z=`); Spacemacs uses `SPC S c` for
--     flyspell-correct-word and `SPC S s` for correct-at-point.
--   * `Sb` enables spell for the buffer; Spacemacs `SPC S b` runs
--     flyspell-buffer over an already-enabled buffer.
--   * `St` toggles spell here; Spacemacs toggles flyspell under `SPC t S`.
--   * `Sn` / `SN` are next/previous misspelling; Spacemacs binds only
--     `SPC S n` (next) and has no `SPC S N`.
--   * `Sa` / `Sw` / `Su` (zg / zw / zug) have no Spacemacs `SPC S`
--     equivalent -- flyspell handles the personal dictionary differently.
--   * `Sd` sets 'spelllang' and is the analogue of Spacemacs `SPC S d`
--     (change dictionary).
--   * Spacemacs `SPC S r` (flyspell-region) has no counterpart here.

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

  -- LazyVim binds <leader>S to Snacks.scratch.select(). Drop it so <leader>S
  -- can act as the `+spell` prefix instead of firing the scratch picker.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>S", false },
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
      { "<leader>Sd", function()
          vim.ui.input({
            prompt = "spelllang: ",
            default = table.concat(vim.opt_local.spelllang:get(), ","),
          }, function(input)
            if not input or input == "" then
              return
            end
            vim.opt_local.spelllang = input
            vim.notify("spelllang: " .. input)
          end)
        end,
        desc = "Set dictionary" },
      { "<leader>Sn", "]s", desc = "Next misspelling" },
      { "<leader>SN", "[s", desc = "Previous misspelling" },
      { "<leader>Ss", "z=", desc = "Suggest corrections" },
      { "<leader>Sa", "zg", desc = "Add word to dictionary" },
      { "<leader>Sw", "zw", desc = "Mark word as wrong" },
      { "<leader>Su", "zug", desc = "Undo add/mark word" },
    },
  },
}
