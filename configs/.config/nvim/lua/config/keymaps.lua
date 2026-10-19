local keymapSet = vim.keymap.set
local opts = { noremap = true, silent = true } 

-- Горизонтальный терминал
keymapSet('n', '<leader>th', ':split | terminal<CR>', opts)

-- Вертикальный терминал
keymapSet('n', '<leader>tv', ':vsplit | terminal<CR>', opts)

-- Навигация между окнами
keymapSet('n', '<C-h>', '<C-w>h', opts) -- влево
keymapSet('n', '<C-j>', '<C-w>j', opts) -- вниз
keymapSet('n', '<C-k>', '<C-w>k', opts) -- вверх
keymapSet('n', '<C-l>', '<C-w>l', opts) -- вправо

-- Перемещение окна на ОДНУ позицию (обмен с соседом), как тайлы в aerospace.
-- Ctrl+Shift + h/j/k/l. Один аккорд: можно держать Ctrl+Shift и тапать hjkl —
-- окно шагает по одному, курсор едет вместе с ним.
local function swap_win(dir)
  local cur = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur)
  vim.cmd('wincmd ' .. dir)            -- перейти к соседу в направлении
  local target = vim.api.nvim_get_current_win()
  if target == cur then return end     -- соседа в эту сторону нет
  local target_buf = vim.api.nvim_win_get_buf(target)
  vim.api.nvim_win_set_buf(target, cur_buf)  -- меняем буферы местами
  vim.api.nvim_win_set_buf(cur, target_buf)
  -- фокус остаётся в target, где теперь наш буфер — курсор «переехал» с окном
end

keymapSet('n', '<C-S-h>', function() swap_win('h') end, opts) -- влево
keymapSet('n', '<C-S-j>', function() swap_win('j') end, opts) -- вниз
keymapSet('n', '<C-S-k>', function() swap_win('k') end, opts) -- вверх
keymapSet('n', '<C-S-l>', function() swap_win('l') end, opts) -- вправо

-- Схлопнуть смешанную раскладку в одну линию, выровнять размеры и вернуть фокус.
local function relayout(dir)
  local cur = vim.api.nvim_get_current_win()  -- запоминаем текущее окно
  vim.cmd('windo wincmd ' .. dir)             -- выстраиваем все окна в линию
  vim.cmd('wincmd =')                         -- выравниваем размеры
  if vim.api.nvim_win_is_valid(cur) then
    vim.api.nvim_set_current_win(cur)         -- возвращаем фокус на исходное окно
  end
end

keymapSet('n', '<C-S-s>', function() relayout('L') end, opts) -- все окна в ряд (колонки бок о бок)
keymapSet('n', '<C-S-v>', function() relayout('J') end, opts) -- все окна стопкой (одна колонка)

keymapSet('n', '<leader>tt', '<cmd>ToggleTerm<CR>', opts) -- переключение терминала
keymapSet('n', '<leader>e', ':NvimTreeToggle<CR>', opts) -- файловый проводник

keymapSet('n', '<leader>gs', ':Git<CR>', opts) -- git статус
keymapSet('n', '<leader>gc', ':Git commit<CR>', opts) -- git коммит
keymapSet('n', '<leader>gp', ':Git push<CR>', opts) -- git пуш
keymapSet('n', '<leader>gl', ':Git pull<CR>', opts) -- git пулл

-- Arc VCS (Аркадия): обёртка config/arc.lua, по аналогии с git <leader>g*
keymapSet('n', '<leader>as', ':ArcStatus<CR>', opts) -- arc статус
keymapSet('n', '<leader>ad', ':ArcDiff<CR>', opts) -- arc дифф
keymapSet('n', '<leader>al', ':ArcLog<CR>', opts) -- arc лог
keymapSet('n', '<leader>ab', ':ArcBlame<CR>', opts) -- arc blame текущего файла
keymapSet('n', '<leader>ac', ':ArcCommit<CR>', opts) -- arc коммит (спросит сообщение)

-- LSP-навигация (gd/gr/gi/gt/K, rename, code action, format) настраивается
-- в config/lsp_shared.lua → on_attach, буфер-локально и через fzf с превью.
keymapSet('n', 'gb', '<C-o>', opts) -- go back: вернуться к позиции до прыжка (jumplist), напр. после gd
keymapSet('n', '<S-l>', ':bnext<CR>', opts) -- следующий буфер
keymapSet('n', '<S-h>', ':bprevious<CR>', opts) -- предыдущий буфер
keymapSet('n', '<leader>q', ':qa!<CR>', opts) -- выйти из Neovim
keymapSet('n', '<leader>w', ':w<CR>', opts) -- сохранить файл

keymapSet('n', '<leader><space>', ':nohlsearch<CR>', opts) -- очистка подстветки поиска

-- Горячие клавиши для диагностики LSP
keymapSet('n', '<leader>de', vim.diagnostic.open_float, { noremap = true, silent = true, desc = "Показать ошибки/предупреждения в строке" })
keymapSet('n', '<leader>dq', vim.diagnostic.setloclist, { noremap = true, silent = true, desc = "Список ошибок буфера" })
keymapSet('n', '[d', vim.diagnostic.goto_prev, { noremap = true, silent = true, desc = "Предыдущая ошибка" })
keymapSet('n', ']d', vim.diagnostic.goto_next, { noremap = true, silent = true, desc = "Следующая ошибка" })

-- gi/gr перенесены в config/lsp_shared.lua → on_attach (fzf с превью).

keymapSet('t', '<Esc>', [[<C-\><C-n>]], { noremap = true }) -- выход из терминала в normal-режим
