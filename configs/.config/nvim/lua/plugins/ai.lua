-- Официальный GitHub Copilot (github/copilot.vim).
-- Только inline-подсказки (ghost-text), без чата и без сторонних провайдеров.
-- Первый раз нужно авторизоваться: :Copilot setup (откроет device-flow в браузере).
-- Требует node в PATH (есть nvm). Если node слишком свежий/старый — можно указать
-- конкретный бинарь через vim.g.copilot_node_command.

return {
  {
    "github/copilot.vim",
    event = "InsertEnter",
    cmd = "Copilot",
    init = function()
      -- Tab отдаём nvim-cmp (он им листает меню). Подсказку Copilot принимаем явно.
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      -- <C-J> — принять всю подсказку целиком.
      vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        silent = true,
        desc = "Copilot: принять подсказку",
      })
      -- Навигация по вариантам и отмена.
      vim.keymap.set("i", "<C-L>", "<Plug>(copilot-accept-word)", { desc = "Copilot: принять слово" })
      vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", { desc = "Copilot: следующий вариант" })
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", { desc = "Copilot: предыдущий вариант" })
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)", { desc = "Copilot: скрыть подсказку" })
    end,
  },
}
