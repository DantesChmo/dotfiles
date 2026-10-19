return {
  -- Diffview: Просмотр изменений Git
  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim"
  },

  -- Gitsigns: Индикация изменений Git в гуттере
  {
    "lewis6991/gitsigns.nvim",
    config = function() require("gitsigns").setup() end
  },

  -- Fugitive: Git интеграция
  { "tpope/vim-fugitive" },

  -- ToggleTerm: Встроенный терминал
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<c-\>]],
        direction = "horizontal",
        shade_terminals = true,
      })
    end,
  },
}
