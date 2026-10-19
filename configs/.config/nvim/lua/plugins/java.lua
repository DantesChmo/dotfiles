-- ~/.config/nvim/lua/plugins/java.lua
-- Поддержка Java и Spring Boot.
-- Сам jdtls стартует не отсюда, а из ftplugin/java.lua (так делает большинство примеров nvim-jdtls,
-- потому что start_or_attach должен вызываться при открытии каждого Java-буфера).
-- Здесь только spec для lazy.nvim — какие плагины подгружать.

return {
  -- nvim-jdtls: лаунчер Eclipse JDT.LS, понимает workspace folders, bundles и DAP
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "mfussenegger/nvim-dap",   -- jdtls.dap использует dap для запуска тестов и main-классов
    },
    -- config не нужен: вся настройка в ftplugin/java.lua
  },

  -- spring-boot.nvim: расширение jdtls для Spring Boot.
  -- Даёт навигацию по бинам, список endpoint'ов, autocomplete для application.properties/yml.
  {
    "JavaHello/spring-boot.nvim",
    ft = { "java", "yaml", "properties" },
    dependencies = {
      "mfussenegger/nvim-jdtls",
    },
    config = function()
      require("spring_boot").setup({})
    end,
  },
}
