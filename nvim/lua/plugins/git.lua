-- Git parity: Magit-style Neogit + Diffview + Octo (GitHub issues/PRs).
-- See docs/archive/2026-04-12-nvim-git-parity-design.md.
-- Plugin delta: +3 (neogit, diffview, octo via extra). gitsigns stays on
-- LazyVim defaults with no customization here.

return {
  -- Magit-style git UI
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim", -- inline diff popups inside Neogit
    },
    cmd = { "Neogit" },
    keys = {
      { "<leader>gg", function() require("neogit").open() end, desc = "Neogit" },
      { "<leader>gc", function() require("neogit").open({ "commit" }) end, desc = "Neogit commit" },
      { "<leader>gl", function() require("neogit").open({ "log" }) end, desc = "Neogit log" },
      { "<leader>gr", function() require("neogit").open({ "pull" }) end, desc = "Neogit pull" },
      -- gP (push) is registered in the octo override spec below, because we
      -- must `false` octo's <leader>gP before binding our own.
    },
    opts = {
      -- telescope is not installed (LazyVim 16 uses snacks.picker); snacks is
      -- the picker Neogit should delegate to. `disable_commit_confirmation`
      -- was removed upstream and is rejected by the pinned config validator.
      integrations = { diffview = true, snacks = true },
      graph_style = "unicode",
    },
  },

  -- Side-by-side and merge-conflict diff viewer
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewRefresh",
      "DiffviewToggleFiles",
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview (working tree)" },
      { "<leader>gD", "<cmd>DiffviewOpen origin/HEAD...HEAD<cr>", desc = "Diffview (vs origin/HEAD)" },
      { "<leader>gF", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview file history" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>", desc = "Diffview close" },
    },
  },

  -- Snacks picker keymap fixups: <leader>gd/<leader>gD/<leader>gS are bound by
  -- the LazyVim snacks_picker extra and collide with the diffview bindings
  -- above (lazy.nvim keymap resolution between two plugins is order-dependent,
  -- so drop the snacks side explicitly). Snacks' git stash picker is re-homed
  -- on <leader>gz, which nothing else claims.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gd", false },
      { "<leader>gD", false },
      { "<leader>gS", false },
      { "<leader>gz", function() Snacks.picker.git_stash() end, desc = "Git stash (Snacks)" },
    },
  },

  -- Octo keymap fixups: relocate collisions with Neogit's pull/push bindings.
  {
    "pwntester/octo.nvim",
    keys = {
      { "<leader>gr", false }, -- was "List Repos (Octo)" in octo extra
      { "<leader>gP", false }, -- was "Search PRs (Octo)" in octo extra
      { "<leader>gR", "<cmd>Octo repo list<CR>", desc = "List Repos (Octo)" },
      -- Re-register Neogit's push on <leader>gP:
      { "<leader>gP", function() require("neogit").open({ "push" }) end, desc = "Neogit push" },
    },
  },
}
