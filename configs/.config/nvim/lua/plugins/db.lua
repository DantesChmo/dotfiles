return {
 -- основной плагин для работы с базами данных
  {
    "tpope/vim-dadbod",
    lazy = true,
  },

  -- :DBUIToggle
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = { "tpope/vim-dadbod" },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    config = function ()
      -- Горячие клавиши для Dadbod UI
      vim.keymap.set("n", "<leader>db", ":DBUIToggle<CR>", { noremap = true, silent = true })
    end
  },

    -- автодополнение для dadbod
  {
    "kristijanhusak/vim-dadbod-completion",
    ft = { "sql", "mysql", "plsql" },
    lazy = true,
  },

}
