-- Git parity: Magit-style Neogit + Diffview + Octo (GitHub issues/PRs).
-- See docs/superpowers/specs/2026-04-12-nvim-git-parity-design.md.
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
      integrations = { diffview = true, telescope = true },
      disable_commit_confirmation = false,
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
