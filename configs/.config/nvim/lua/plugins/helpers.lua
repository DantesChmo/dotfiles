return {
  -- Bufferline: Улучшенное управление буферами
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons"
  },

    -- Nvim-autopairs: автоматическое закрытие скобок, кавычек и т.д.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        check_ts = true,        -- treesitter aware
        disable_filetype = { "TelescopePrompt", "vim" },
        ts_config = {
          typecript = { "string", "template_string" },
          javascript = { "string", "template_string" },
          tsx = { "string", "template_string" },
        },
        fast_wrap = {},
      })
    end,
  },

  -- Nvim-ts-autotag: автоматическое закрытие и переименование HTML-тегов
  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      filetypes = {
        "html",
        "javascriptreact",
        "typescriptreact",
      },
    },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },

    -- Комментарии
  { "numToStr/Comment.nvim" },

  -- LSP Signature: Подсказки параметров функций
  {
    "ray-x/lsp_signature.nvim",
    config = function()
      require("lsp_signature").setup()
    end
  },

    -- Vim-dispatch: асинхронное выполнение команд
  {
    "tpope/vim-dispatch",
    config = function()
    end
  },

  -- render-markdown: Улучшенное отображение Markdown
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-mini/mini.nvim',
      'nvim-tree/nvim-web-devicons'
    },
    opts = {},
  },
}
