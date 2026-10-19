-- ~/.config/nvim/lua/plugins/test.lua
-- Универсальный тестовый раннер neotest.
-- Адаптер neotest-java сам выбирает mvn(w) или gradle(w) по корневым файлам проекта,
-- так что одной настройкой покрываются и Maven, и Gradle.

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "mfussenegger/nvim-dap",   -- для запуска тестов под отладчиком (<leader>td)
      "rcasia/neotest-java",     -- адаптер для JUnit / TestNG
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local neotest = require("neotest")

      neotest.setup({
        adapters = {
          require("neotest-java")({
            ignore_wrapper = false,  -- использовать mvnw/gradlew, если они есть в проекте
          }),
        },
      })

      -- Кеймапы тестов (префикс <leader>t).
      -- ВАЖНО: <leader>tt, <leader>th, <leader>tv заняты терминалом в config/keymaps.lua —
      -- их не трогаем; для тестов берём другие буквы.
      vim.keymap.set("n", "<leader>tr", function() neotest.run.run() end,
        { desc = "Тест: запустить ближайший" })
      vim.keymap.set("n", "<leader>tf", function() neotest.run.run(vim.fn.expand("%")) end,
        { desc = "Тест: запустить файл" })
      vim.keymap.set("n", "<leader>tl", function() neotest.run.run_last() end,
        { desc = "Тест: повторить последний" })
      vim.keymap.set("n", "<leader>td", function() neotest.run.run({ strategy = "dap" }) end,
        { desc = "Тест: отладить ближайший" })
      vim.keymap.set("n", "<leader>ts", function() neotest.summary.toggle() end,
        { desc = "Тест: дерево результатов" })
      vim.keymap.set("n", "<leader>to", function() neotest.output.open({ enter = true }) end,
        { desc = "Тест: показать вывод" })
    end,
  },
}
