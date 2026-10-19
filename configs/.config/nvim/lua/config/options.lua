local opt = vim.opt

-- Основные настройки
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.swapfile = false

-- Отступы
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

-- Поиск
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Внешний вид
opt.termguicolors = true
opt.laststatus = 3 -- один глобальный статуслайн на весь редактор (а не по окну) — больше места под путь
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false

-- Разделение окон
opt.splitbelow = true
opt.splitright = true

-- Производительность
opt.updatetime = 250
opt.timeoutlen = 300

-- Дополнительно
opt.completeopt = "menu,menuone,noselect"
opt.pumheight = 10

-- Команды работают и на русской раскладке (ЙЦУКЕН -> QWERTY).
-- langmap транслирует буквы только для normal/visual/operator-режимов,
-- ввод текста в insert не затрагивается. Пример из :help langmap.
opt.langmap =
  "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ," ..
  "фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz"

