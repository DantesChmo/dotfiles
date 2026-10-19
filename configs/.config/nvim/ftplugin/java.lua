-- ~/.config/nvim/ftplugin/java.lua
-- Запускается при открытии любого Java-файла.
-- Поднимает jdtls с правильными bundles (java-debug-adapter и java-test, поставлены mason'ом)
-- и отдельной workspace на каждый проект (без неё jdtls путает индексы между проектами).

local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
  vim.notify("nvim-jdtls ещё не установлен — открой :Lazy и подожди установку", vim.log.levels.WARN)
  return
end

local lsp_shared = require("config.lsp_shared")

-- Корень проекта: Maven, Gradle или git
local root_markers = {
  "pom.xml",
  "build.gradle", "build.gradle.kts",
  "settings.gradle", "settings.gradle.kts",
  "mvnw", "gradlew",
  ".git",
}
local root_dir = require("jdtls.setup").find_root(root_markers)
if not root_dir then
  -- Не нашли корень — стартовать jdtls бессмысленно, выходим тихо
  return
end

-- Имя проекта по корневой папке (для отдельной workspace)
local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls/workspace/" .. project_name

-- Bundles для DAP: java-debug-adapter (отладка) и java-test (запуск JUnit/TestNG из dap)
local mason_path = vim.fn.stdpath("data") .. "/mason"
local bundles = vim.fn.glob(mason_path .. "/share/java-debug-adapter/com.microsoft.java.debug.plugin-*.jar", true, true)
for _, jar in ipairs(vim.fn.glob(mason_path .. "/share/java-test/*.jar", true, true)) do
  local name = vim.fs.basename(jar)
  if name ~= "com.microsoft.java.test.runner-jar-with-dependencies.jar" and name ~= "jacocoagent.jar" then
    bundles[#bundles + 1] = jar
  end
end

-- Bundles для spring-boot.nvim, если плагин уже загружен (на ft=java он догружается рядом)
local sb_ok, spring_boot = pcall(require, "spring_boot")
if sb_ok and spring_boot.java_extensions then
  vim.list_extend(bundles, spring_boot.java_extensions())
end

-- on_attach: общие LSP keymap'ы + Java-специфичные + DAP setup
local function on_attach(client, bufnr)
  -- Общие keymap'ы (gd, gr, K, <leader>rn, <leader>ca, <leader>f и т.д.)
  lsp_shared.on_attach(client, bufnr)

  -- Регистрируем DAP-конфиги для main-классов и тест-методов
  jdtls.setup_dap({ hotcodereplace = "auto" })
  require("jdtls.dap").setup_dap_main_class_configs()

  local opts = { buffer = bufnr, silent = true }

  -- Java-специфичные действия (префикс <leader>j)
  vim.keymap.set("n", "<leader>jo", jdtls.organize_imports, opts)                            -- упорядочить импорты
  vim.keymap.set("n", "<leader>jv", function() jdtls.extract_variable() end, opts)           -- вынести в переменную
  vim.keymap.set("v", "<leader>jv", function() jdtls.extract_variable(true) end, opts)       -- то же из visual-режима
  vim.keymap.set("n", "<leader>jc", function() jdtls.extract_constant() end, opts)           -- вынести в константу
  vim.keymap.set("v", "<leader>jm", function() jdtls.extract_method(true) end, opts)         -- вынести в метод (visual)

  -- Запуск/отладка тестов через jdtls.dap (использует bundle java-test)
  vim.keymap.set("n", "<leader>jr", function() require("jdtls.dap").test_class() end, opts)         -- запустить весь тест-класс
  vim.keymap.set("n", "<leader>jR", function() require("jdtls.dap").test_nearest_method() end, opts) -- запустить ближайший @Test

  -- Spring Boot: bean navigation и список endpoint'ов (даёт spring-boot.nvim)
  vim.keymap.set("n", "<leader>jb", function()
    require("fzf-lua").lsp_live_workspace_symbols({ query = "@+" })
  end, opts)
  vim.keymap.set("n", "<leader>jp", function()
    require("fzf-lua").lsp_live_workspace_symbols({ query = "@/" })
  end, opts)
end

-- Конфигурация jdtls
local config = {
  -- mason кладёт shim-обёртку jdtls в PATH, она сама подхватывает $JAVA_HOME
  cmd = { "jdtls", "-data", workspace_dir },
  root_dir = root_dir,
  capabilities = lsp_shared.capabilities(),
  on_attach = on_attach,

  init_options = {
    bundles = bundles,
  },

  settings = {
    java = {
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
      configuration = {
        updateBuildConfiguration = "interactive",  -- jdtls будет спрашивать перед обновлением classpath
      },
      signatureHelp = { enabled = true },
      contentProvider = { preferred = "fernflower" },  -- декомпилятор для просмотра .class
      completion = {
        favoriteStaticMembers = {
          -- Чаще всего нужны статические импорты для тестов и Spring MVC
          "org.junit.jupiter.api.Assertions.*",
          "org.junit.jupiter.api.Assumptions.*",
          "org.mockito.Mockito.*",
          "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
          "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
        },
      },
      sources = {
        organizeImports = {
          starThreshold = 9999,        -- никогда не сворачивать в `import a.b.*`
          staticStarThreshold = 9999,  -- то же для static-импортов
        },
      },
    },
  },
}

-- Поднимаем jdtls для текущего буфера
jdtls.start_or_attach(config)
