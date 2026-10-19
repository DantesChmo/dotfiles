-- ~/.config/nvim/lua/plugins/dap.lua
-- DAP-инфраструктура: запуск отладочных сессий, UI и инлайн-значения переменных.
-- Java-конкретные конфиги создаются в ftplugin/java.lua через jdtls.dap.setup_dap_main_class_configs.

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",          -- зависимость dap-ui
      "theHamsta/nvim-dap-virtual-text", -- инлайн-показ значений переменных при отладке
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup({})

      -- Авто-открытие/закрытие dap-ui при старте/остановке сессии
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close() end

      -- Иконки брейкпоинтов и текущей строки выполнения
      vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn",  numhl = "" })
      vim.fn.sign_define("DapStopped",             { text = "▶", texthl = "DiagnosticInfo",  numhl = "" })

      -- Управление отладкой через F-клавиши
      vim.keymap.set("n", "<F5>",  dap.continue,  { desc = "DAP: продолжить / запустить" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "DAP: шаг через" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "DAP: шаг внутрь" })
      vim.keymap.set("n", "<F12>", dap.step_out,  { desc = "DAP: шаг наружу" })

      -- Брейкпоинты: <leader>b и <leader>B (короткие, частые)
      vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "DAP: брейкпоинт" })
      vim.keymap.set("n", "<leader>B", function()
        vim.ui.input({ prompt = "Условие брейкпоинта: " }, function(cond)
          if cond and cond ~= "" then dap.set_breakpoint(cond) end
        end)
      end, { desc = "DAP: условный брейкпоинт" })

      -- DAP UI и REPL под префиксом <leader>x (eXecute) — <leader>d занят диагностикой/Docker/Dadbod
      vim.keymap.set("n", "<leader>xu", dapui.toggle,         { desc = "DAP: показать/скрыть UI" })
      vim.keymap.set("n", "<leader>xr", dap.repl.toggle,      { desc = "DAP: REPL" })
      vim.keymap.set("n", "<leader>xc", dap.clear_breakpoints, { desc = "DAP: очистить все брейкпоинты" })
      vim.keymap.set("n", "<leader>xl", dap.run_last,         { desc = "DAP: повторить последнюю сессию" })
    end,
  },
}
