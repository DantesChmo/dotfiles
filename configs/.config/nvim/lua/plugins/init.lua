return {
  -- Gruvbox тема
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "soft",      -- hard, medium, soft
        transparent_mode = true
      })
      vim.o.background = "dark" -- или "light"
      vim.cmd("colorscheme gruvbox")
    end,
  },
}
