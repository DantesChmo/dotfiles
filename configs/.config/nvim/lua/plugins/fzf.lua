return {
  -- Fzf-lua: Быстрый поиск и навигация
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local fzf = require('fzf-lua')

      fzf.setup({
        -- Отключаем профиль "hide" (в этой версии fzf-lua он активен по умолчанию):
        -- он вешает <Esc> на стороне Neovim на fzf.hide() и перезаписывает наш
        -- fzf-бинд esc, из-за чего Esc всегда закрывал окно — даже из INSERT.
        -- С no_hide наш esc:transform ниже становится единственным обработчиком Esc.
        defaults = { no_hide = true },
        winopts = {
          height = 0.85,
          width = 0.80,
          -- Глобальный `tnoremap <Esc> <C-\><C-n>` (config/keymaps.lua) крадёт Esc
          -- у fzf: роняет нас в Neovim Normal-mode поверх терминала, где j/k не
          -- скроллят результаты. Буфер fzf держит <Esc> у себя и пробрасывает его
          -- в fzf — тогда наш esc-transform (hide-input/abort) снова работает.
          on_create = function()
            vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = true, nowait = true })
          end,
          preview = {
            default = "builtin", -- встроенный превьювер: рендерит код в Neovim с treesitter-подсветкой (без внешнего bat)
            layout = "vertical", -- превью кода снизу под списком результатов
            vertical = "down:60%", -- отдать под код 60% высоты, чтобы сразу видеть контекст
          },
        },
        -- Модальность как в Vim: любое окно fzf открывается в NORMAL-режиме.
        -- Ввод скрыт (hide-input) → печать не идёт в запрос, клавиши свободны под навигацию.
        --   j/k — двигаться по списку, g — в начало (в конец — alt-G из дефолтов)
        --   i или / — перейти в INSERT (показать поле ввода, печатать запрос)
        --   Esc — из INSERT вернуться в NORMAL; из NORMAL — закрыть; q — тоже закрыть
        -- Работает и для live_grep: start:+hide-input дописывается к внутреннему
        -- start:+reload fzf-lua (append-синтаксис `+`), ничего не затирая.
        keymap = {
          fzf = {
            true, -- [1]=true: наследовать дефолтные бинды fzf-lua (ctrl-u, ctrl-f, alt-g/G и др.)
            ["start"] = "+hide-input",                       -- стартуем в NORMAL (поле ввода скрыто)
            ["j"]     = "down",
            ["k"]     = "up",
            ["g"]     = "first",
            ["q"]     = "abort",
            ["i"]     = "show-input+unbind(i,/,j,k,g,q)",     -- INSERT: показать ввод, вернуть клавишам печать
            ["/"]     = "show-input+unbind(i,/,j,k,g,q)",
            -- Esc: в NORMAL (ввод скрыт) — закрыть; в INSERT — скрыть ввод и вернуть навигацию.
            -- transform исполняется через $SHELL -c, поэтому POSIX-тест `[ ]`, не `[[ ]]`.
            ["esc"]   = [[transform:[ "$FZF_INPUT_STATE" = hidden ] && echo abort || echo "hide-input+rebind(i,/,j,k,g,q)"]],
          },
        },
        -- Инлайн-фильтрация каталогов/файлов прямо в момент поиска.
        -- В окне live_grep пишем: `запрос -- !dist !build` — всё после ` -- `
        -- уходит в ripgrep как --iglob (!dist исключить, *.lua сузить).
        grep = {
          rg_glob = true,            -- парсить glob'ы из запроса
          glob_flag = "--iglob",     -- нечувствительно к регистру
          glob_separator = "%s%-%-", -- разделитель " -- "
        },
      })

      -- Горячие клавиши для FZF
      vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Files" })       -- поиск файла по имени
      vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Grep" })    -- поиск текста по всему проекту
      vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })   -- переключение между открытыми буферами
      vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Help" })    -- поиск по справке Neovim
      vim.keymap.set("n", "<leader>fc", fzf.commands, { desc = "Commands" }) -- список всех команд (в т.ч. пикеров fzf)

      -- Текстовый поиск: слово под курсором, выделение, повтор последнего grep
      vim.keymap.set("n", "<leader>fw", fzf.grep_cword, { desc = "Grep word" })        -- grep слова под курсором (без ввода)
      vim.keymap.set("v", "<leader>fw", fzf.grep_visual, { desc = "Grep selection" })  -- grep выделенного текста в visual-режиме
      vim.keymap.set("n", "<leader>fr", fzf.live_grep_resume, { desc = "Grep resume" }) -- продолжить последний grep с тем же запросом
      vim.keymap.set("n", "<leader>fl", fzf.blines, { desc = "Buffer lines" })         -- fuzzy-поиск по строкам текущего файла

      -- Поиск символов (функции/классы/методы) через LSP
      vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "Symbols (file)" })            -- символы текущего файла
      vim.keymap.set("n", "<leader>fS", fzf.lsp_live_workspace_symbols, { desc = "Symbols (project)" })   -- символы по всему проекту, live-фильтр

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

      -- FZF для просмотра Docker Compose сервисов
      local function compose_services()
        return "docker compose ps --services"
      end

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

      -- FZF для остановки всех Docker Compose сервисов
      vim.keymap.set("n", "<leader>cd", function()
        vim.cmd("ToggleTerm cmd='docker compose down'")
      end)

      -- FZF для просмотра k9s в терминале
      vim.keymap.set("n", "<leader>kk", function()
        require("toggleterm.terminal").Terminal
          :new({ cmd = "k9s", hidden = true })
          :toggle()
      end)

      -- Горячие клавиши для FZF диагностики
      vim.keymap.set("n", "<leader>dd", require("fzf-lua").diagnostics_document)
      vim.keymap.set("n", "<leader>dw", require("fzf-lua").diagnostics_workspace)
    end,
  },
}
