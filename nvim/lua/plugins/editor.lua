return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = {
            exclude = { "node_modules", "__pycache__" },
          },
          grep = {
            exclude = { "**/node_modules/**", "**/__pycache__/**" },
          },
        },
      },
    },
  },
}
