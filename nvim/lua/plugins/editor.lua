return {
  -- Telescope: use ripgrep if available (matches .vimrc FZF_DEFAULT_COMMAND)
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        file_ignore_patterns = { ".git/", "node_modules/", "__pycache__/" },
      },
    },
  },
}
