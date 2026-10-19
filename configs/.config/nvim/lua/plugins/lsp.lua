-- ~/.config/nvim/lua/plugins/lsp.lua
return {
  -- Swift плагин для Neovim
  {
    "devswiftzone/swift.nvim",
    ft = "swift",  -- загружается только при открытии .swift
    config = function()
      require("swift").setup({
        -- здесь можно указать дополнительные опции
        -- например: auto_open_scheme_picker = true
      })
    end,
  },

  -- Mason Tool Installer: ставит инструменты, которые НЕ настраиваются через mason-lspconfig
  -- (jdtls запускается через nvim-jdtls, java-debug-adapter и java-test — DAP-бандлы,
  -- google-java-format — форматтер для conform.nvim)
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    event = "VeryLazy",
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = require("config.tools").java_tools,
        auto_update = false,
        run_on_start = vim.env.DOTFILES_BOOTSTRAP ~= "1",
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
      { "folke/neodev.nvim", opts = {} },
    },
    config = function()
      -- Mason setup
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = vim.env.DOTFILES_BOOTSTRAP == "1" and {} or require("config.tools").servers,
        -- jdtls belongs to ftplugin/java.lua; do not auto-enable a second client.
        automatic_enable = false,
      })

      -- Общие capabilities и on_attach для всех LSP-клиентов (включая jdtls)
      local lsp_shared = require("config.lsp_shared")
      local capabilities = lsp_shared.capabilities()
      local on_attach = lsp_shared.on_attach

      -- Используем vim.lsp.config для новых версий Neovim
      local lsp_config = vim.lsp.config

      -- Аркадия: универсальный резолв импортов для pyright без venv.
      -- Корень Аркадии ищется по маркеру .arcadia.root вверх от файла,
      -- в extraPaths кладём корень (для passport.* и любых аркадийных
      -- абсолютных импортов) + все contrib/python/*/py3 (для сторонних
      -- питон-библиотек: flask, requests, numpy и т.п.).
      local function arcadia_root(start)
        -- rootPath/uri могут прийти как vim.NIL (userdata) — берём только строки
        if type(start) ~= "string" or start == "" then
          return nil
        end
        local hit = vim.fs.find({ ".arcadia.root" }, { upward = true, path = start, type = "file" })[1]
        return hit and vim.fs.dirname(hit) or nil
      end

      local arcadia_paths_cache = {}
      local function arcadia_extra_paths(root)
        if arcadia_paths_cache[root] then
          return arcadia_paths_cache[root]
        end
        local paths = { root }
        for _, p in ipairs(vim.fn.glob(root .. "/contrib/python/*/py3", true, true)) do
          paths[#paths + 1] = p
        end
        arcadia_paths_cache[root] = paths
        return paths
      end

      -- Go
      -- Аркадия: GOPATH-режим, префикс импортов a.yandex-team.ru, без go.mod.
      -- Обёртка ~/.config/nvim/bin/gopls включает GO111MODULE=off + GOPATH только
      -- когда сервер стартует внутри Аркадии (находит .arcadia.root по cwd), поэтому
      -- обычные go.mod-проекты вне Аркадии продолжают работать в module-режиме.
      -- Требуется симлинк ~/go/src/a.yandex-team.ru -> корень Аркадии.
      lsp_config.gopls = {
        cmd = { vim.fn.stdpath("config") .. "/bin/gopls" },
        cmd_env = { DOTFILES_MASON_GOPLS = vim.fn.stdpath("data") .. "/mason/bin/gopls" },
        filetypes = { "go", "gomod", "gowork", "gotmpl" },
        -- В Аркадии скоупим gopls на каталог пакета, чтобы он не пытался
        -- проиндексировать весь монорепозиторий (иначе go-to-definition падает
        -- по таймауту). Cross-package переходы всё равно работают через GOPATH.
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          if arcadia_root(fname) then
            on_dir(vim.fs.dirname(fname))
          else
            on_dir(vim.fs.root(bufnr, { "go.work", "go.mod", ".git" }))
          end
        end,
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
            },
            staticcheck = true,
          },
        },
      }

      -- TypeScript/JavaScript
      lsp_config.ts_ls = {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Python
      lsp_config.pyright = {
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", ".git" },
        capabilities = capabilities,
        on_attach = on_attach,
        before_init = function(params, config)
          local wf = params.workspaceFolders
          local wf_path
          if type(wf) == "table" and wf[1] and type(wf[1].uri) == "string" then
            wf_path = vim.uri_to_fname(wf[1].uri)
          end
          -- ищем корень Аркадии из самых надёжных источников по очереди:
          -- путь открытого буфера → rootPath → workspaceFolder → cwd
          local root = arcadia_root(vim.api.nvim_buf_get_name(0))
            or arcadia_root(params.rootPath)
            or arcadia_root(wf_path)
            or arcadia_root(vim.fn.getcwd())
          if root then
            config.settings = config.settings or {}
            config.settings.python = config.settings.python or {}
            config.settings.python.analysis = config.settings.python.analysis or {}
            config.settings.python.analysis.extraPaths = arcadia_extra_paths(root)
          end
        end,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
            },
          },
        },
      }

      -- Swift
      local sourcekit_cmd = require("config.tools").sourcekit_command()
      lsp_config.sourcekit = {
        cmd = sourcekit_cmd or { "sourcekit-lsp" },
        filetypes = { "swift", "objective-c", "objective-cpp" },
        root_markers = { "Package.swift", ".git" },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Kotlin
      lsp_config.kotlin_language_server = {
        cmd = { "kotlin-language-server" },
        filetypes = { "kotlin" },
        root_markers = { "settings.gradle", "settings.gradle.kts", ".git" },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Lua
      lsp_config.lua_ls = {
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml", ".git" },
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
            },
            telemetry = { enable = false },
          },
        },
      }

      -- Включаем серверы
      vim.lsp.enable("gopls")
      vim.lsp.enable("ts_ls")
      vim.lsp.enable("pyright")
      if sourcekit_cmd then
        vim.lsp.enable("sourcekit")
      end
      vim.lsp.enable("kotlin_language_server")
      vim.lsp.enable("lua_ls")

      -- Диагностика
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        update_in_insert = false,
        underline = true,
        severity_sort = true,
      })

      -- Иконки диагностики
      local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end
    end,
  },

  -- Nvim-html-css: Подсветка CSS в HTML и JSX файлах
  {
    "Jezda1337/nvim-html-css",
    dependencies = {"nvim-treesitter/nvim-treesitter", "hrsh7th/nvim-cmp"},
    opts = {
      enable_on = { "html", "javascriptreact", "typescriptreact", "vue", "php", "svelte" },
      documentation = { auto_show = true },
    },
  },
}

