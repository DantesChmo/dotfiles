-- init.lua: Полная конфигурация Neovim

-- Менеджер пакетов lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Сохраняем оригинальную функцию уведомлений
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if type(msg) == "string" then
    -- Игнорируем только варнинг про deprecated framework nvim-lspconfig
    if msg:match("require%(\'lspconfig\'%) \"framework\" is deprecated") then
      return
    end
  end
  -- Все остальные уведомления показываем
  orig_notify(msg, level, opts)
end

require("lazy").setup({
  -- Xcodebuild для Neovim
    {
      "wojciech-kulik/xcodebuild.nvim",
      dependencies = {
        "nvim-telescope/telescope.nvim",
        "MunifTanjim/nui.nvim",
      },
      config = function()
        require("xcodebuild").setup()
      end,
    },

    -- DONE
  -- Mason для управления LSP, DAP, Linters и Formatters
    {
      "williamboman/mason.nvim",
      lazy = false,
      config = function()
        require("mason").setup()
      end,
    },

    -- DONE
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

  -- DONE
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    lazy = false,
    config = function()
      local ok, mason_lspconfig = pcall(require, "mason-lspconfig")
      if not ok or not mason_lspconfig then
        vim.notify("❌ Mason LSPconfig не найден", vim.log.levels.ERROR)
        return
      end

      mason_lspconfig.setup({
        ensure_installed = {
          "pyright",
          "ts_ls",
          "gopls",
          "cssls",
          "html",
          "tailwindcss",
          "dockerls",
          "kotlin_language_server",
          "jdtls",
        },
        automatic_installation = true,
      })

      local lspconfig = require("lspconfig")

      -- Swift / sourcekit-lsp
      lspconfig.sourcekit.setup({
        cmd = { "xcrun", "sourcekit-lsp" },
        filetypes = { "swift", "objective-c" },
        root_dir = lspconfig.util.root_pattern("Package.swift", ".git"),
      })

      -- Pyright с поддержкой Poetry
      lspconfig.pyright.setup({
        before_init = function(_, config)
          local handle = io.popen("poetry env info -p 2>/dev/null")
          if handle then
            local path = handle:read("*a"):gsub("%s+$", "")
            handle:close()
            if path ~= "" and vim.fn.executable(path .. "/bin/python") == 1 then
              config.settings = config.settings or {}
              config.settings.python = config.settings.python or {}
              config.settings.python.pythonPath = path .. "/bin/python"
            end
          end
        end,
      })

      -- Другие LSP
      lspconfig.ts_ls.setup({})
      lspconfig.gopls.setup({})
      lspconfig.html.setup({})
      lspconfig.cssls.setup({ settings = { css={validate=true}, scss={validate=true}, less={validate=true} } })
      lspconfig.tailwindcss.setup({ filetypes={"html","javascriptreact","typescriptreact"} })
      lspconfig.dockerls.setup({})
      lspconfig.kotlin_language_server.setup({})
      lspconfig.jdtls.setup({})
    end
  },

  -- DONE
  {
    "neovim/nvim-lspconfig",
    lazy = false,
  },

  	-- DONE
    -- Автодополнение nvim-cmp
    { "hrsh7th/nvim-cmp", dependencies = { "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip" } },

    -- DONE
   -- основной плагин для работы с базами данных  
    {
      "tpope/vim-dadbod",
      lazy = true,
    },

    -- DONE
    -- :DBUIToggle
    {
      "kristijanhusak/vim-dadbod-ui",
      dependencies = { "tpope/vim-dadbod" },
      cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    },

    -- DONE
    -- Комментарии
    { "numToStr/Comment.nvim" },

    -- DONE
    -- LSP Signature: Подсказки параметров функций
    {
      "ray-x/lsp_signature.nvim",
      config = function()
        require("lsp_signature").setup()
      end
    },

    -- DONE
    -- Diffview: Просмотр изменений Git
    {
      "sindrets/diffview.nvim",
      dependencies = "nvim-lua/plenary.nvim"
    },

    -- DONE
    -- Gitsigns: Индикация изменений Git в гуттере
    {
      "lewis6991/gitsigns.nvim",
      config = function() require("gitsigns").setup() end
    },

    -- DONE
    -- Bufferline: Улучшенное управление буферами
    {
      "akinsho/bufferline.nvim",
      dependencies = "nvim-tree/nvim-web-devicons"
    },

    -- DONE
    -- Markdown Preview
    {
      "iamcco/markdown-preview.nvim",
      build = "cd app && npm install",
      ft = "markdown",  -- плагин активируется только для Markdown
    },

    -- DONE
    -- автодополнение для dadbod
    {
      "kristijanhusak/vim-dadbod-completion",
      ft = { "sql", "mysql", "plsql" },
      lazy = true,
    },

    -- DONE
    -- Fzf-lua: Быстрый поиск и навигация
    {
      "ibhagwan/fzf-lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("fzf-lua").setup({
          "fzf-native",
          winopts = {
            height = 0.85,
            width = 0.80,
            preview = {
              layout = "vertical",
            },
          },
        })
      end,
    },

    -- DONE
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

    -- DONE
    -- Copilot и интеграция с nvim-cmp
    {
      "zbirenbaum/copilot-cmp",
      dependencies = { "github/copilot.vim", "hrsh7th/nvim-cmp" },
      config = function()
        require("copilot_cmp").setup()
      end
    },

    -- DONE
    -- Git интеграция с copilot
    {
      "github/copilot.vim",
      config = function()
        -- Включить автодополнение Copilot
        vim.g.copilot_no_tab_map = true       -- отключаем стандартное Tab поведение
        vim.api.nvim_set_keymap("i", "<C-J>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
        vim.api.nvim_set_keymap("i", "<C-K>", 'copilot#Next()', { silent = true, expr = true })
        vim.api.nvim_set_keymap("i", "<C-L>", 'copilot#Previous()', { silent = true, expr = true })
      end
    },

    -- DONE
    -- Copilot Chat: чат с AI внутри Neovim
    {
      "CopilotC-Nvim/CopilotChat.nvim",
      dependencies = {
        "github/copilot.vim",
        "nvim-lua/plenary.nvim",
      },
      opts = {
        model = "gpt-4o",
      },
    },

    -- DONE
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

    -- DONE
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

    -- DONE
    -- Nvim-tree: файловый проводник
    { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" }, config = true },

    -- Fugitive: Git интеграция
    { "tpope/vim-fugitive" },

    -- DONE
    -- Vim-dispatch: асинхронное выполнение команд
    {
      "tpope/vim-dispatch",
      config = function() 
      end
    },

    -- DONE
    -- Lualine: статусбар
    { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" }, config = true },

    -- CANCEL
    -- Telescope: мощный поиск и навигация
    { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" }, config = true },

    -- DONE
    -- Symbols-outline: боковая панель с символами файла
    { "simrat39/symbols-outline.nvim" },

    -- DONE
    -- Gruvbox тема
    {
      "ellisonleao/gruvbox.nvim",
      priority = 1000,
      config = function()
        require("gruvbox").setup({
          contrast = "soft", -- hard, medium, soft
        })
        vim.o.background = "dark" -- или "light"
        vim.cmd("colorscheme gruvbox")
      end,
    },

    -- DONE
    -- Nvim-treesitter: улучшенная подсветка синтаксиса и парсинг кода
    {
      "nvim-treesitter/nvim-treesitter",
      run = ":TSUpdate",
      event = { "BufReadPost", "BufNewFile" },
      config = function()
        require("nvim-treesitter.configs").setup({
          ensure_installed = { "lua", "typescript", "javascript", "go", "python", "java", "html", "lua", "css", "json", "tsx" }, -- языки
          highlight = {
            enable = true,            -- включаем подсветку
            additional_vim_regex_highlighting = false,
          },
          indent = { enable = true }, -- умные отступы
          rainbow = {
            enable = true,             -- разноцветные скобки
            extended_mode = true,
            max_file_lines = nil,
          },
        })
      end
    },

    -- CANCEL
    -- Cinnamon: плавные движения курсора
    {
      "declancm/cinnamon.nvim",
      config = function()
        require("cinnamon").setup({
          scroll = { enable = false },  -- scroll будет через Luxmotion / Neoscroll
          keymaps = {
            basic = true,
            extra = true,
            extended = true,
          },
          options = {
            mode = "cursor",
            max_delta = {
              time = 500,
              line = 150,
            },
            delay = 3,
            step = 1,
          },
        })
      end
    },

    -- CANCEL
    -- Luxmotion: анимация scroll motion-команд
    {
      "LuxVim/nvim-luxmotion",
      config = function()
        require("luxmotion").setup({
          scroll = {
            enable = true,
            duration = 150,
            easing = "ease-in-out",
          },
          cursor = {
            enable = false, -- курсор анимирует Cinnamon
          },
        })
      end
    },

    -- DONE
    -- Nvim-html-css: Подсветка CSS в HTML и JSX файлах
    {
      "Jezda1337/nvim-html-css",
      dependencies = {"nvim-treesitter/nvim-treesitter", "hrsh7th/nvim-cmp"},
      opts = {
        enable_on = { "html", "javascriptreact", "typescriptreact", "vue", "php", "svelte" },
        documentation = { auto_show = true },
      },
    },
    {
      {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = {
          "nvim-neotest/nvim-nio"
        },
      },
      "theHamsta/nvim-dap-virtual-text",
      "nvim-telescope/telescope-dap.nvim",
      {
        "mxsdev/nvim-dap-vscode-js",
        dependencies = {"mfussenegger/nvim-dap"},
        config = function()
          require("dap-vscode-js").setup({
            node_path = "node",
            debugger_path = vim.fn.stdpath("data") .. "/dapinstall/jsnode",
            adapters = {"pwa-node", "pwa-chrome"},
          })
        end
      }
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      require("nvim-dap-virtual-text").setup()
      dapui.setup()

      local opts = { noremap=true, silent=true }

      -- Шорткаты
      vim.api.nvim_set_keymap('n', '<F5>', ':lua require"dap".continue()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<F10>', ':lua require"dap".step_over()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<F11>', ':lua require"dap".step_into()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<F12>', ':lua require"dap".step_out()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<leader>b', ':lua require"dap".toggle_breakpoint()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<leader>B', ':lua require"dap".set_breakpoint(vim.fn.input("Условие точки останова: "))<CR>', opts)
      vim.api.nvim_set_keymap('n', '<leader>dr', ':lua require"dap".repl.open()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<leader>du', ':lua require"dapui".toggle()<CR>', opts)

      -- Авто UI
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- ==================================
      -- Конфигурации по языкам
      -- ==================================
      local lang_configs = {}

      -- Python
      lang_configs.python = function()
        dap.adapters.python = { type='executable', command='python', args={'-m','debugpy.adapter'} }
        dap.configurations.python = {{
          type='python', request='launch', name='Запуск текущего файла', program='${file}',
          pythonPath=function() return '/usr/bin/python' end
        }}
      end

      -- Go
      lang_configs.go = function()
        dap.adapters.go = {
          type='server', host='127.0.0.1', port=38697,
          executable={command='dlv', args={'dap','-l','127.0.0.1:38697'}}
        }
        dap.configurations.go = {{ type='go', request='launch', name='Запуск файла', program='${file}' }}
      end

      -- Kotlin
      lang_configs.kotlin = function()
        dap.adapters.java = { type='server', host='127.0.0.1', port=5005 }
        dap.configurations.kotlin = {{ type='java', request='attach', name='Attach к JVM', hostName='127.0.0.1', port=5005 }}
      end

      -- Swift
      lang_configs.swift = function()
        dap.adapters.lldb = { type='executable', command='/usr/bin/lldb-vscode', name='lldb' }
        dap.configurations.swift = {{
          type='lldb', request='launch', name='Запуск Swift файла',
          program=function() return vim.fn.input('Путь к файлу: ', vim.fn.getcwd()..'/', 'file') end,
          cwd='${workspaceFolder}', stopOnEntry=false, args={}
        }}
      end

      -- ==================================
      -- Функция для определения фронтенд-проекта
      -- ==================================
      local function is_frontend_project()
        local cwd = vim.fn.getcwd()
        local files = vim.fn.readdir(cwd)

        local frontend_configs = {
          "vite.config.js", "vite.config.ts",
          "webpack.config.js",
          "nuxt.config.js",
          "next.config.js"
        }

        for _, cfg in ipairs(frontend_configs) do
          if vim.fn.filereadable(cwd.."/"..cfg) == 1 then
            return true
          end
        end

        local package_json_path = cwd.."/package.json"
        if vim.fn.filereadable(package_json_path) == 1 then
          local package_json = vim.fn.readfile(package_json_path)
          local content = table.concat(package_json, "\n")
          local frontend_deps = {"react", "vue", "svelte", "next", "nuxt"}
          for _, dep in ipairs(frontend_deps) do
            if content:match(dep) then
              return true
            end
          end
        end

        return false
      end

      -- ==================================
      -- Функция для определения фронтенд-URL
      -- ==================================
      local function detect_frontend_url()
        local cwd = vim.fn.getcwd()
        local url = "http://localhost:3000" -- дефолт

        local package_json_path = cwd.."/package.json"
        if vim.fn.filereadable(package_json_path) == 1 then
          local content = table.concat(vim.fn.readfile(package_json_path), "\n")
          if content:match("vite") then
            url = "http://localhost:5173"
          elseif content:match("next") or content:match("react") or content:match("nuxt") then
            url = "http://localhost:3000"
          elseif content:match("webpack") then
            url = "http://localhost:8080"
          end
        end

        return url
      end

      -- ==================================
      -- Авто-загрузка DAP для JS/TS
      -- ==================================
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"javascript","typescript"},
        callback = function(args)
          local ft = args.match
          if is_frontend_project() then
            local url = detect_frontend_url()
            require("dap-vscode-js").setup({ adapters = {"pwa-chrome"} })
            dap.configurations.javascript = {{
              type = "pwa-chrome",
              request = "launch",
              name = "Фронтенд JS",
              url = url,
              webRoot = "${workspaceFolder}",
              sourceMaps = true,
            }}
            dap.configurations.typescript = dap.configurations.javascript
            print("DAP фронтенд (Chrome) загружен для: " .. ft .. " URL: " .. url)
          else
            require("dap-vscode-js").setup({ adapters = {"pwa-node"} })
            dap.configurations.javascript = {{
              type = "pwa-node",
              request = "launch",
              name = "Node.js",
              program = "${file}",
              cwd = vim.fn.getcwd(),
              sourceMaps = true,
            }}
            dap.configurations.typescript = dap.configurations.javascript
            print("DAP Node.js загружен для: " .. ft)
          end
        end
      })

      -- Остальные языки
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"python","go","kotlin","swift"},
        callback = function(args)
          local ft = args.match
          if lang_configs[ft] then
            lang_configs[ft]()
            print("DAP конфигурация загружена для: " .. ft)
          end
        end
      })
    end
  }
    },
  {
    "rcarriga/nvim-notify",
    config = function()
      local notify = require("notify")
      notify.setup({
        timeout = 3000,
        stages = "fade",
        render = "minimal",
      })
      vim.notify = notify
    end,
  },
  {
    "j-hui/fidget.nvim",
    opts = {},
  },
  {
    "linrongbin16/lsp-progress.nvim",
    config = function()
      require("lsp-progress").setup()
    end,
  },
})

--------------------------------------------------
-- Helpers: find Xcode project & scheme
--------------------------------------------------

local notify = vim.notify
local uv = vim.loop

local function find_xcode_project()
  local project_root = vim.fs.root(0, function(name)
    return name:match("%.xcodeproj$") or name:match("%.xcworkspace$")
  end)

  if not project_root then
    return nil
  end

  local entries = vim.fn.readdir(project_root)
  for _, name in ipairs(entries) do
    if name:match("%.xcworkspace$") or name:match("%.xcodeproj$") then
      return project_root .. "/" .. name
    end
  end

  return nil
end

local function detect_scheme(project_file)
  if not project_file then
    return nil
  end

  -- выбираем правильный флаг: workspace или project
  local arg = ""
  if project_file:match("%.xcworkspace$") then
    arg = "-workspace " .. project_file
  else
    arg = "-project " .. project_file
  end

  -- получаем список схем
  local ok, output = pcall(vim.fn.system, "xcodebuild " .. arg .. " -list 2>/dev/null | sed -n '/Schemes:/,$p' | sed '1d' | sed '/^$/q'")
  if not ok or not output or output == "" then
    return nil
  end

  -- возвращаем первую строку как схему
  local scheme = vim.split(output, "\n")[1]
  if scheme and scheme ~= "" then
    return scheme
  end

  return nil
end

--------------------------------------------------
-- Async index generation (non-blocking)
--------------------------------------------------

local function async_gen_index(cmd, on_exit)
  notify("📦 Swift: генерация индекса…", vim.log.levels.INFO, { title = "Swift" })

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle
  handle = uv.spawn("sh", {
    args = { "-c", cmd },
    stdio = { nil, stdout, stderr },
  }, function(code)
    stdout:close()
    stderr:close()
    handle:close()

    if code == 0 then
      notify("✅ Swift индекс обновлён", vim.log.levels.INFO, { title = "Swift" })
    else
      notify("❌ Ошибка генерации Swift индекса", vim.log.levels.ERROR, { title = "Swift" })
    end

    if on_exit then
      on_exit(code)
    end
  end)

  stdout:read_start(function(_, data)
    -- можно логировать stdout при необходимости
  end)

  stderr:read_start(function(_, data)
    if data then
      notify(data, vim.log.levels.ERROR, { title = "Swift stderr" })
    end
  end)
end

--------------------------------------------------
-- User command: SwiftGenIndexAsync
--------------------------------------------------

vim.api.nvim_create_user_command("SwiftGenIndexAsync", function()
  local project = find_xcode_project()
  local scheme = detect_scheme(project)
  notify("project", project)
  notify("scheme", scheme)

  if not project or not scheme then
    notify("❌ Не удалось определить xcodeproj или scheme", vim.log.levels.ERROR)
    return
  end

  -- без xcpretty
  local cmd = string.format(
    "xcodebuild -project %s -scheme %s build | xcode-build-server parse -a -",
    project,
    scheme
  )

  async_gen_index(cmd, function(code)
    if code == 0 then
      vim.schedule(function()
        vim.cmd("LspRestart")
      end)
    end
  end)
end, {})

--------------------------------------------------
-- Auto triggers: open session / add / delete files
--------------------------------------------------

local group = vim.api.nvim_create_augroup("SwiftAutoReindex", { clear = true })
local ran_initial = false

-- First Swift file opened in session
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  group = group,
  pattern = "*.swift",
  callback = function()
    if not ran_initial then
      ran_initial = true
      vim.defer_fn(function()
        vim.cmd("SwiftGenIndexAsync")
      end, 500)
    end
  end,
})

-- New or deleted Swift files
vim.api.nvim_create_autocmd({ "BufNewFile", "BufDelete" }, {
  group = group,
  pattern = "*.swift",
  callback = function()
    vim.defer_fn(function()
      vim.cmd("SwiftGenIndexAsync")
    end, 500)
  end,
})

--------------------------------------------------
-- END
--------------------------------------------------

-- Основные настройки
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.updatetime = 200
vim.opt.timeoutlen = 400
vim.opt.completeopt = { "menuone", "noselect" }

-- Горячие клавиши для диагностики LSP
vim.keymap.set('n', '<leader>de', vim.diagnostic.open_float, { noremap = true, silent = true, desc = "Показать ошибки/предупреждения в строке" })
vim.keymap.set('n', '<leader>dq', vim.diagnostic.setloclist, { noremap = true, silent = true, desc = "Список ошибок буфера" })
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { noremap = true, silent = true, desc = "Предыдущая ошибка" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { noremap = true, silent = true, desc = "Следующая ошибка" })

-- колесо мыши → Luxmotion + Neoscroll
vim.keymap.set({"n","v"}, "<ScrollWheelDown>", "3<C-d>", { noremap = true, silent = true })
vim.keymap.set({"n","v"}, "<ScrollWheelUp>", "3<C-u>", { noremap = true, silent = true })

-- PgUp / PgDn
vim.keymap.set("n", "<PageDown>", "<C-f>", { noremap = true, silent = true })
vim.keymap.set("n", "<PageUp>", "<C-b>", { noremap = true, silent = true })

-- Shift+колесо → прокрутка на страницу
vim.keymap.set({"n","v"}, "<S-ScrollWheelDown>", "<C-f>", { noremap = true, silent = true })
vim.keymap.set({"n","v"}, "<S-ScrollWheelUp>", "<C-b>", { noremap = true, silent = true })
 
-- PgUp / PgDown → тоже плавные
vim.keymap.set("n", "<PageDown>", "<C-f>", { noremap = true, silent = true })
vim.keymap.set("n", "<PageUp>", "<C-b>", { noremap = true, silent = true })

-- Плавный переход к предыдущему блоку
vim.keymap.set("n", "<S-[>", "{", { noremap = true, silent = true })

-- Плавный переход к следующему блоку
vim.keymap.set("n", "<S-]>", "}", { noremap = true, silent = true })

-- Переход между функциями
vim.keymap.set("n", "]]", "]]", { noremap = true, silent = true })
vim.keymap.set("n", "[[", "[[", { noremap = true, silent = true })

-- LSP прыжки → превращаем в motions, чтобы cinnamon их анимировал
vim.keymap.set("n", "gd", function()
  vim.lsp.buf.definition()
end, { silent = true })

-- LSP прыжки к реализации
vim.keymap.set("n", "gi", function()
  vim.lsp.buf.implementation()
end, { silent = true })

-- LSP поиск ссылок на символ
vim.keymap.set("n", "gr", function()
  vim.lsp.buf.references()
end, { silent = true })

-- Плавная навигация по поиску
vim.keymap.set("n", "n", "nzzzv", { noremap = true, silent = true })
vim.keymap.set("n", "N", "Nzzzv", { noremap = true, silent = true })

-- Плавная навигация по marks (маркеры)
vim.keymap.set("n", "'A", "'A", { noremap = true, silent = true })
vim.keymap.set("n", "`A", "`A", { noremap = true, silent = true })   -- если используешь ` (backtick)

-- DONE
-- Дерево файлов
-- Функция для кастомных клавиш в дереве
local function on_attach(bufnr)
  local api = require('nvim-tree.api')

  local function opts(desc)
    return { desc = desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

-- Основные действия
  vim.keymap.set('n', '<CR>', api.node.open.edit, opts('Open')) -- открыть файл/папку
  vim.keymap.set('n', 'o', api.node.open.edit, opts('Open')) -- открыть файл/папку
  vim.keymap.set('n', 'v', api.node.open.vertical, opts('Open: Vertical Split')) -- открыть в вертикальном сплите
  vim.keymap.set('n', 's', api.node.open.horizontal, opts('Open: Horizontal Split')) -- открыть в горизонтальном сплите
  vim.keymap.set('n', 't', api.node.open.tab, opts('Open: New Tab')) -- открыть в новой вкладке
  vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close Directory')) -- закрыть папку
  vim.keymap.set('n', 'l', api.node.open.edit, opts('Open')) -- открыть файл/папку

  -- Работа с файлами
  vim.keymap.set('n', 'a', api.fs.create, opts('Create File')) -- добавить файл
  vim.keymap.set('n', 'd', api.fs.remove, opts('Delete File')) -- удалить файл
  vim.keymap.set('n', 'r', api.fs.rename, opts('Rename File')) -- переименовать файл
  vim.keymap.set('n', 'x', api.fs.cut, opts('Cut File')) -- вырезать файл
  vim.keymap.set('n', 'p', api.fs.paste, opts('Paste File')) -- вставить файл
end

-- DONE
-- Настройка дерева
require('nvim-tree').setup({
  sort_by = 'case_sensitive',
  renderer = { group_empty = true },
  actions = {
    open_file = { quit_on_open = false, resize_window = true },
  },
  view = {
    width = 30,
    side = 'left',
  },
  on_attach = on_attach, -- вот ключевой момент
})

-- DONE
-- Statusbar
require("lualine").setup({
  options = {
    theme = "auto",
    section_separators = "",
    component_separators = ""
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = {
      "filename",
      function()
        return require("lsp-progress").progress()
      end,
    },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

-- DONE
-- Автодополнение
local cmp = require("cmp")
local luasnip = require("luasnip")
cmp.setup({
  snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
  mapping = cmp.mapping.preset.insert({
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "buffer" },
    { name = "vim-dadbod-completion" },
  }),
})

-- CANCEL
-- Telescope
local telescope = require("telescope.builtin")
-- vim.keymap.set('n', '<leader>ff', telescope.find_files, { noremap = true, silent = true })
-- vim.keymap.set('n', '<leader>fg', telescope.live_grep, { noremap = true, silent = true })
-- vim.keymap.set('n', '<leader>fb', telescope.buffers, { noremap = true, silent = true })
-- vim.keymap.set('n', '<leader>fh', telescope.help_tags, { noremap = true, silent = true })

-- DONE
-- FZF Lua
local fzf = require("fzf-lua")

-- DONE
-- Горячие клавиши для FZF
vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Files" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Grep" })
vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Help" })
vim.keymap.set("n", "<leader>fc", fzf.commands, { desc = "Commands" })

-- DONE
-- FZF для просмотра Docker контейнеров и логов
vim.keymap.set("n", "<leader>dps", function()
  fzf.fzf_exec("docker ps --format '{{.Names}}'", {
    prompt = "Containers> ",
    actions = {
      ["default"] = function(selected)
        vim.cmd("ToggleTerm cmd='docker logs -f " .. selected[1] .. "'")
      end,
    },
  })
end)

-- DONE
-- FZF для просмотра Docker Compose сервисов
local function compose_services()
  return "docker compose ps --services"
end

-- DONE
-- FZF для запуска Docker Compose сервисов
vim.keymap.set("n", "<leader>dcu", function()
  fzf.fzf_exec(compose_services(), {
    prompt = "Compose UP> ",
    actions = {
      ["default"] = function(sel)
        vim.cmd("ToggleTerm cmd='docker compose up -d " .. sel[1] .. "'")
      end,
    },
  })
end)

-- DONE
-- FZF для остановки Docker Compose сервисов
vim.keymap.set("n", "<leader>cl", function()
  fzf.fzf_exec(compose_services(), {
    prompt = "Compose LOGS> ",
    actions = {
      ["default"] = function(sel)
        vim.cmd("ToggleTerm cmd='docker compose logs -f " .. sel[1] .. "'")
      end,
    },
  })
end)

-- DONE
-- FZF для остановки всех Docker Compose сервисов
vim.keymap.set("n", "<leader>cd", function()
  vim.cmd("ToggleTerm cmd='docker compose down'")
end)

-- DONE
-- FZF для просмотра k9s в терминале
vim.keymap.set("n", "<leader>kk", function()
  require("toggleterm.terminal").Terminal
    :new({ cmd = "k9s", hidden = true })
    :toggle()
end)

-- DONE
-- Очистка подсветки поиска
vim.keymap.set('n', '<leader><space>', ':nohlsearch<CR>', { noremap = true, silent = true })

-- Markdown Preview
vim.cmd([[let g:mkdp_auto_start = 1]])

-- DONE
-- Copilot Chat
vim.keymap.set("n", "<leader>ai", function()
  vim.cmd("CopilotChat")
end)

-- DONE
-- Объяснение кода с помощью Copilot Chat
vim.keymap.set("v", "<leader>ad", function()
  vim.cmd("CopilotChatExplain")
end)

-- В терминальном буфере Ctrl-n сразу переводит в Normal mode
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    -- Вставляем mapping только для терминала
    vim.api.nvim_buf_set_keymap(0, "t", "<C-n>", "<C-\\><C-n>", { noremap = true, silent = true })
  end
})

-- DONE START
-- Горячие клавиши
local opts = { noremap = true, silent = true }

-- Горизонтальный терминал
vim.keymap.set('n', '<leader>th', ':split | terminal<CR>', opts)

-- Вертикальный терминал
vim.keymap.set('n', '<leader>tv', ':vsplit | terminal<CR>', opts)

-- Навигация между окнами
vim.keymap.set('n', '<C-h>', '<C-w>h', opts) -- влево
vim.keymap.set('n', '<C-j>', '<C-w>j', opts) -- вниз
vim.keymap.set('n', '<C-k>', '<C-w>k', opts) -- вверх
vim.keymap.set('n', '<C-l>', '<C-w>l', opts) -- вправо

vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<CR>', opts) -- переключение терминала
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', opts) -- файловый проводник

vim.keymap.set('n', '<leader>gs', ':Git<CR>', opts) -- git статус
vim.keymap.set('n', '<leader>gc', ':Git commit<CR>', opts) -- git коммит
vim.keymap.set('n', '<leader>gp', ':Git push<CR>', opts) -- git пуш
vim.keymap.set('n', '<leader>gl', ':Git pull<CR>', opts) -- git пулл

vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts) -- переход к определению
vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts) -- поиск ссылок на символ
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts) -- переход к реализации
vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts) -- показать документацию

vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts) -- переименование символа
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts) -- действия кода
vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts) -- форматирование
vim.keymap.set('n', '<S-l>', ':bnext<CR>', opts) -- следующий буфер
vim.keymap.set('n', '<S-h>', ':bprevious<CR>', opts) -- предыдущий буфер
vim.keymap.set('n', '<leader>q', ':qa!<CR>', opts) -- выйти из Neovim
vim.keymap.set('n', '<leader>w', ':w<CR>', opts) -- сохранить файл
-- DONE END

-- DONE
-- Горячие клавиши для FZF диагностики
vim.keymap.set("n", "<leader>dd", require("fzf-lua").diagnostics_document)
vim.keymap.set("n", "<leader>dw", require("fzf-lua").diagnostics_workspace)

-- DONE
-- Горячие клавиши для Dadbod UI
vim.keymap.set("n", "<leader>db", ":DBUIToggle<CR>", opts)

