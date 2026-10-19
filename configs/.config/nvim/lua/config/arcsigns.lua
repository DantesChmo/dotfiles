-- Значки изменений в гуттере (signcolumn) для Arc VCS — аналог gitsigns.
--
-- gitsigns умеет только git, поэтому в чекауте Аркадии колонка пустая. Здесь
-- повторяем его подход: берём версию файла из индекса arc (`arc show :PATH`),
-- сравниваем с текущим содержимым буфера через vim.diff и рисуем значки
-- добавления/изменения/удаления. Значки живые — обновляются по мере правки
-- (индекс кэшируется, на каждый TextChanged дёргается только быстрый vim.diff,
-- без вызова arc).
--
-- В git-репозитории `arc show` падает (не arc) → модуль молча выключается, и
-- работает штатный gitsigns. Репозитории не пересекаются: .git vs .arc.

local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("arcsigns")

-- Состояние по буферу: закэшированная база (содержимое из индекса) и метаданные.
-- base == false → файл не под arc/не отслеживается, значков нет.
local state = {} -- bufnr -> { base = string|false, relpath = string }

-- Путь каталога от корня репозитория (`arc rev-parse --show-prefix`), с кэшем.
-- Используем его вместо арифметики префиксов, чтобы не спотыкаться о симлинки:
-- arc сам считает путь относительно корня. false → каталог не под arc.
local prefix_cache = {} -- dir -> string|false ("" в корне, "sub/dir/" глубже)
local function prefix_for(dir, cb)
  local cached = prefix_cache[dir]
  if cached ~= nil then
    return cb(cached)
  end
  vim.system({ "arc", "rev-parse", "--show-prefix" }, { cwd = dir, text = true }, vim.schedule_wrap(function(res)
    local prefix = (res.code == 0) and (vim.trim(res.stdout or "")) or false
    prefix_cache[dir] = prefix
    cb(prefix)
  end))
end

-- Значки и хайлайты. Цвета переиспользуем от gitsigns (он загружен), с
-- запасными вариантами на стандартные diff-группы.
local SIGNS = {
  add = { text = "▎", hl = "ArcSignsAdd" },
  change = { text = "▎", hl = "ArcSignsChange" },
  delete = { text = "▁", hl = "ArcSignsDelete" },
}

local function link(from, candidates)
  for _, to in ipairs(candidates) do
    if vim.fn.hlexists(to) == 1 then
      vim.api.nvim_set_hl(0, from, { link = to, default = true })
      return
    end
  end
end

local function setup_highlights()
  link("ArcSignsAdd", { "GitSignsAdd", "Added", "diffAdded", "DiffAdd" })
  link("ArcSignsChange", { "GitSignsChange", "Changed", "diffChanged", "DiffChange" })
  link("ArcSignsDelete", { "GitSignsDelete", "Removed", "diffRemoved", "DiffDelete" })
end

-- Рисует значки в буфере по хункам vim.diff (индексы 1-based на стороне буфера).
local function place(bufnr, hunks)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local total = vim.api.nvim_buf_line_count(bufnr)

  local function sign(line1, kind)
    local row = line1 - 1
    if row < 0 or row >= total then
      return
    end
    local s = SIGNS[kind]
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      sign_text = s.text,
      sign_hl_group = s.hl,
      priority = 6,
    })
  end

  for _, h in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = h[1], h[2], h[3], h[4]
    if count_a == 0 then
      -- чистое добавление: строки start_b..start_b+count_b-1
      for l = start_b, start_b + count_b - 1 do
        sign(l, "add")
      end
    elseif count_b == 0 then
      -- чистое удаление: якорь на строке, после которой вырезан кусок
      sign(math.max(start_b, 1), "delete")
    else
      -- изменение диапазона строк буфера
      for l = start_b, start_b + count_b - 1 do
        sign(l, "change")
      end
    end
  end
end

-- Обычный файловый буфер? Спецбуферы (NvimTree, терминал, help, quickfix и
-- т.п.) игнорируем полностью, иначе наши автокоманды дёргают чужие буферы.
-- Проверок две, и обе обязательны:
--   1) buftype == "" — отсекает terminal/help/quickfix/nofile;
--   2) имя буфера — существующий РЕГУЛЯРНЫЙ файл (stat.type == "file").
-- Пункт 2 критичен: буфер nvim-tree назван именем каталога, а на старте, пока
-- дерево не проставило buftype=nofile, проверки (1) недостаточно из-за гонки —
-- каталог принимался за файл, `arc show :<каталог>` отдаёт листинг дерева
-- (exit 0!), и значки садились прямо на буфер дерева.
local function is_file_buf(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return false
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end
  local st = uv.fs_stat(name)
  return st ~= nil and st.type == "file"
end

-- Пересчитывает значки по кэшированной базе (без вызова arc) — быстрый путь.
local function redraw(bufnr)
  local st = state[bufnr]
  if not st or not st.base or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local cur = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") .. "\n"
  local hunks = vim.diff(st.base, cur, { result_type = "indices" })
  place(bufnr, hunks or {})
end

-- Тянет версию файла из индекса arc и кладёт в кэш, затем перерисовывает.
local function fetch_base(bufnr, cb)
  if not is_file_buf(bufnr) then
    state[bufnr] = { base = false }
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end
    return cb and cb()
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = vim.fs.dirname(name)
  prefix_for(dir, function(prefix)
    if not prefix then
      state[bufnr] = { base = false }
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      return cb and cb()
    end
    -- путь от корня репозитория (индекс arc адресуется от корня).
    -- ВАЖНО: arc rev-parse --show-prefix, в отличие от git, НЕ добавляет
    -- завершающий "/" (и отдаёт "" в корне) — склеиваем через слэш сами.
    local base_name = vim.fs.basename(name)
    local rel = (prefix == "" and base_name) or (prefix .. "/" .. base_name)
    vim.system({ "arc", "show", ":" .. rel }, { cwd = dir, text = true }, vim.schedule_wrap(function(res)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return cb and cb()
      end
      if res.code ~= 0 then
        -- файл не отслеживается (новый) — можно было бы красить всё как add,
        -- но для v1 просто без значков
        state[bufnr] = { base = false, relpath = rel }
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      else
        state[bufnr] = { base = res.stdout or "", relpath = rel }
        redraw(bufnr)
      end
      if cb then cb() end
    end))
  end)
end

-- Дебаунс перерисовки на частых событиях (набор текста). Раньше здесь были
-- сырые uv-таймеры (uv.new_timer + :start/:stop), но их :stop()/:start() в
-- колбэке автокоманды могли синхронно кидать ошибку по жизненному циклу хэндла
-- («Error in InsertLeave Autocommands»). vim.defer_fn сам управляет таймером и
-- вызывает колбэк в main loop — ручной lifecycle не нужен. Гасим устаревшие
-- срабатывания через счётчик поколений на буфер.
local gen = {} -- bufnr -> number
local function debounce_redraw(bufnr)
  local g = (gen[bufnr] or 0) + 1
  gen[bufnr] = g
  vim.defer_fn(function()
    if gen[bufnr] == g then
      redraw(bufnr)
    end
  end, 150)
end

function M.refresh(bufnr)
  fetch_base(bufnr or vim.api.nvim_get_current_buf())
end

function M.setup()
  -- Без бинарника arc (VCS Аркадии/X5) каждый vim.system({"arc",...}) бросает
  -- ENOENT на автокомандах и заваливает буферы ошибками. Нет arc → модуль не
  -- поднимается, значки рисует штатный gitsigns.
  if vim.fn.executable("arc") == 0 then
    return
  end

  setup_highlights()

  local group = vim.api.nvim_create_augroup("ArcSigns", { clear = true })

  -- Загрузка/сохранение/добавление в индекс → перечитать базу из arc.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    callback = function(a)
      if is_file_buf(a.buf) then
        fetch_base(a.buf)
      end
    end,
  })

  -- Фокус на буфер: если базу ещё не тянули (открыт до загрузки модуля) —
  -- тянем; иначе ничего не делаем (значки уже стоят). Без повторных вызовов
  -- arc на каждый BufEnter — иначе это спам и лишние перерисовки.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(a)
      if is_file_buf(a.buf) and state[a.buf] == nil then
        fetch_base(a.buf)
      end
    end,
  })

  -- Правка буфера → быстрый пересчёт по кэшу, без вызова arc.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    callback = function(a)
      if is_file_buf(a.buf) then
        debounce_redraw(a.buf)
      end
    end,
  })

  -- Пересветить хайлайты после смены цветовой схемы.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = setup_highlights,
  })

  -- Очистка состояния закрытого буфера.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(a)
      state[a.buf] = nil
      gen[a.buf] = nil
    end,
  })

  vim.api.nvim_create_user_command("ArcSignsRefresh", function()
    M.refresh()
  end, { desc = "Arc: пересчитать значки в гуттере" })

  -- Проставить значки в уже открытом буфере (например, при :luafile на лету).
  local cur = vim.api.nvim_get_current_buf()
  if is_file_buf(cur) then
    fetch_base(cur)
  end
end

return M
