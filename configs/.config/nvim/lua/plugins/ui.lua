return {
      -- Nvim-tree: файловый проводник
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function ()
      require('nvim-tree').setup({
        sort_by = 'case_sensitive',
        git = { enable = true },
        -- Показываем игнорируемые файлы, но визуально отделяем их
        filters = { git_ignored = false },
        renderer = {
          group_empty = true,
          highlight_git = 'name', -- подсветка имени для git-ignored (и arc через декоратор)
          decorators = {
            'Git', 'Open', 'Hidden', 'Modified', 'Bookmark', 'Diagnostics', 'Copied',
            require('config.arcignore'), -- .arcignore: тот же вид, что git-ignored
            'Cut',
          },
        },
        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = true,
            -- Когда окон несколько — при открытии файла показываем на них буквы,
            -- жмёшь букву и файл открывается именно в это окно.
            window_picker = {
              enable = true,
              picker = 'default',
              chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
              exclude = {
                filetype = { 'notify', 'packer', 'qf', 'diff', 'fugitive', 'fugitiveblame' },
                buftype = { 'nofile', 'terminal', 'help' },
              },
            },
          },
        },
        view = {
          width = 30,
          side = 'left',
        },
        on_attach = function (bufnr)
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

          -- Path-aware поиск: печатаешь путь через "/", папки раскрываются на лету
          local tree_search = require('config.tree_path_search')
          vim.keymap.set('n', '/', tree_search.start, opts('Path Search'))
          -- Прыжки по совпадениям и сброс подсветки — как n/N и <leader><space> в тексте
          vim.keymap.set('n', 'n', tree_search.next, opts('Path Search: Next'))
          vim.keymap.set('n', 'N', tree_search.prev, opts('Path Search: Prev'))
          vim.keymap.set('n', '<leader><space>', tree_search.clear, opts('Path Search: Clear'))

          -- Работа с файлами
          vim.keymap.set('n', 'a', api.fs.create, opts('Create File')) -- добавить файл
          vim.keymap.set('n', 'd', api.fs.remove, opts('Delete File')) -- удалить файл
          vim.keymap.set('n', 'r', api.fs.rename, opts('Rename File')) -- переименовать файл
          vim.keymap.set('n', 'x', api.fs.cut, opts('Cut File')) -- вырезать файл
          vim.keymap.set('n', 'p', api.fs.paste, opts('Paste File')) -- вставить файл
        end
      })
    end
  },

  -- Symbols-outline: боковая панель с символами файла
  { "simrat39/symbols-outline.nvim" },

  -- Lualine: статусбар
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      { "linrongbin16/lsp-progress.nvim", opts = {} },
    },
    config = function ()
      -- Компонент имени файла с относительным путём — переиспользуем в winbar
      local filename_with_path = {
        "filename",
        path = 1,             -- относительный путь от рабочей директории (0=имя, 2=абсолютный, 3=абс. с ~, 4=имя+родитель)
        shorting_target = 40, -- ужимать путь (foo/bar/baz → f/b/baz), если места не хватает
        symbols = {
          modified = "[+]",      -- файл изменён и не сохранён
          readonly = "[RO]",     -- файл только для чтения
          unnamed = "[No Name]", -- буфер без имени
          newfile = "[New]",     -- новый, ещё не записанный на диск файл
        },
      }

      require("lualine").setup({
        options = {
          theme = "auto",
          section_separators = "",
          component_separators = "",
          globalstatus = true, -- один статуслайн на весь редактор (совпадает с laststatus=3)
          disabled_filetypes = {
            winbar = { "NvimTree", "toggleterm", "help" }, -- не рисуем winbar на дереве, терминале, справке
          },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            filename_with_path, -- в глобальном статуслайне снизу — полный путь (места достаточно)
            function()
              return require("lsp-progress").progress()
            end,
          },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        -- Winbar — отдельная строка сверху каждого окна, только имя файла
        winbar = {
          lualine_c = { "filename" }, -- активное окно: имя файла
        },
        inactive_winbar = {
          lualine_c = { "filename" }, -- неактивные окна: имя файла, приглушённо
        },
      })
    end
  },
}
