-- Path-aware поиск внутри буфера nvim-tree (замена нативного `/`).
--
-- Идея: печатаешь как путь, сегменты разделены `/`.
--   pages          -> подсветить детей текущего уровня, чьё имя содержит "pages"
--   pages/         -> раскрыть папку pages, подсветить её саму
--   pages/auth     -> внутри раскрытой pages подсветить детей, чьё имя содержит "auth"
--   (стёр до pages) -> pages свернуть обратно, вернуться к первому шагу
--
-- Механика ввода повторяет nvim-tree/explorer/live-filter.lua: однострочный
-- оверлей-буфер у курсора + хук on_lines, реагирующий на каждый символ.
--
-- Разбор: последний сегмент — active (что ищем сейчас), всё до него — committed
-- (уже пройденный путь). Committed-сегменты резолвим от корня, раскрывая по
-- одной директории за шаг; active-сегмент подсвечивает детей текущего контекста.
-- Сегменты матчатся по подстроке в любом месте имени — как стандартный `/` в
-- Vim; регистр по 'ignorecase' + 'smartcase' (см. name_matches).

local M = {}

local core = require("nvim-tree.core")
local view = require("nvim-tree.view")

local NS = vim.api.nvim_create_namespace("nvim_tree_path_search")

-- Подсветка совпадений. link=default, чтобы не перебивать пользовательскую тему.
vim.api.nvim_set_hl(0, "NvimTreePathSearchMatch", { link = "Search", default = true })
vim.api.nvim_set_hl(0, "NvimTreePathSearchCurrent", { link = "CurSearch", default = true })

---@type table? активная сессия поиска; nil когда поиск не идёт
local state = nil

---@type table? последний зафиксированный поиск для навигации n/N;
--- { explorer, bufnr, matches = {node}, index }. nil — прыгать не по чему.
local nav = nil

-- Директория ли узел (у файлов нет .nodes).
local function is_dir(node)
  return node ~= nil and type(node.nodes) == "table"
end

-- Совпадение имени с запросом как в стандартном поиске Vim: подстрока в ЛЮБОМ
-- месте имени (не только префикс). Регистр — по 'ignorecase' + 'smartcase':
-- нечувствительно по умолчанию, но чувствительно, если в запросе есть заглавная.
local function name_matches(name, query)
  if query == "" then
    return true
  end
  local case_sensitive
  if not vim.o.ignorecase then
    case_sensitive = true
  elseif vim.o.smartcase and query:find("%u") then
    case_sensitive = true
  else
    case_sensitive = false
  end
  local hay, needle = name, query
  if not case_sensitive then
    hay, needle = name:lower(), query:lower()
  end
  return hay:find(needle, 1, true) ~= nil -- plain=true: query как обычный текст, не паттерн
end

-- Прямые дети узла с учётом группировки (group_empty): реальные дети лежат на
-- последнем узле группы. Для корня (explorer) — просто explorer.nodes.
local function children_of(node)
  if node == state.explorer then
    return node.nodes or {}
  end
  local head = node.last_group_node and node:last_group_node() or node
  return head.nodes or {}
end

-- Раскрыта ли директория (флаг лежит на последнем узле группы).
local function is_open(node)
  local head = node.last_group_node and node:last_group_node() or node
  return head.open == true
end

-- Резолв сегмента пути в директорию: тем же глубоким обходом (прямые дети ctx +
-- рекурсия в раскрытые поддиректории, как в collect_matches) ищем подходящие
-- директории. Если по пути встретился pin (узел, выбранный пользователем через
-- Ctrl+N до коммита слэшем) — возвращаем именно его; иначе — первую по порядку
-- дерева. Так pin побеждает сортировку (напр. `.config` раньше `config`), а без
-- пина поведение прежнее.
local function resolve_segment(ctx, query, pin)
  local first
  local function walk(node)
    for _, n in ipairs(children_of(node)) do
      if is_dir(n) then
        if name_matches(n.name, query) then
          if pin and n == pin then
            return n
          end
          first = first or n
        end
        if is_open(n) then
          local hit = walk(n)
          if hit then
            return hit
          end
        end
      end
    end
    return nil
  end
  return walk(ctx) or first
end

local function contains(list, item)
  for _, v in ipairs(list) do
    if v == item then
      return true
    end
  end
  return false
end

-- Собрать узлы, чьё имя совпадает с query (см. name_matches): прямые дети ctx и,
-- рекурсивно, содержимое уже раскрытых поддиректорий. За счёт этого контент
-- открытых папок ищется сразу, без явного проговаривания пути `/папка/...`.
-- Порядок обхода — как в дереве.
local function collect_matches(ctx, query, acc)
  for _, n in ipairs(children_of(ctx)) do
    if name_matches(n.name, query) then
      table.insert(acc, n)
    end
    if is_dir(n) and is_open(n) then
      collect_matches(n, query, acc)
    end
  end
end

-- Раскрыть ровно один уровень директории (с учётом группировки), вернуть её head.
local function open_one(node)
  local head = node:last_group_node()
  if not head.open then
    head.open = true
    if #head.nodes == 0 then
      state.explorer:expand_dir_node(head)
    end
  end
  return head
end

local function clear_highlights(bufnr)
  bufnr = bufnr or (state and state.tree_bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  end
end

-- Подсветить строки узлов; узел под индексом current — «текущий» (CurSearch),
-- на него ставим курсор. Не зависит от state: используется и при живом вводе,
-- и при навигации n/N уже после коммита поиска.
local function draw_matches(explorer, bufnr, nodes, current)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  local cursor_line
  for i, node in ipairs(nodes) do
    local line = explorer:find_node_line(node)
    if line > 0 then
      local group = (i == current) and "NvimTreePathSearchCurrent" or "NvimTreePathSearchMatch"
      vim.api.nvim_buf_set_extmark(bufnr, NS, line - 1, 0, {
        line_hl_group = group,
        priority = 200,
      })
      if i == current then
        cursor_line = line
      end
    end
  end
  local win = view.get_winnr()
  if cursor_line and win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { cursor_line, 0 })
  end
end

-- Ядро: пересобрать состояние дерева под текущий запрос.
local function update(query)
  if not state then
    return
  end
  state.query = query -- запоминаем текущую строку, чтобы восстановить при повторном входе

  local segments = vim.split(query, "/", { plain = true })
  local active = segments[#segments]
  local committed = {}
  for i = 1, #segments - 1 do
    committed[i] = segments[i]
  end
  local committed_n = #committed

  -- Пины выбранного через Ctrl+N узла: когда активный сегмент коммитится слэшем
  -- (committed стало длиннее), закрепляем текущий выбор за новой позицией сегмента,
  -- чтобы резолвился именно он, а не первый по порядку дерева.
  if committed_n > state.prev_committed_n then
    local node = state.active_sel_node
    if node and is_dir(node) and name_matches(node.name, committed[committed_n]) then
      state.pins[committed_n] = node
    end
  elseif committed_n < state.prev_committed_n then
    -- Стёрли `/` — снимаем пины за пределами текущего пути.
    for i = committed_n + 1, state.prev_committed_n do
      state.pins[i] = nil
    end
  end

  -- Резолвим committed-путь от корня, раскрывая по одной директории.
  local ctx = state.explorer
  local new_opened = {}
  local resolved = true
  for i, seg in ipairs(committed) do
    local child = resolve_segment(ctx, seg, state.pins[i])
    if not child then
      resolved = false
      break
    end
    local head = child:last_group_node()
    if not head.open then
      open_one(child)
      table.insert(new_opened, head) -- раскрыли мы
    elseif contains(state.opened, head) then
      table.insert(new_opened, head) -- раскрывали мы раньше — сохраняем владение
    end
    ctx = child
  end

  -- Свернуть то, что раскрывали мы и что больше не на пути (шаг «стёр — папка закрылась»).
  -- Папки, открытые пользователем до поиска, не в state.opened — их не трогаем.
  for _, node in ipairs(state.opened) do
    if not contains(new_opened, node) then
      node.open = false
    end
  end
  state.opened = new_opened

  state.explorer.renderer:draw()

  -- Подсветка: active пустой (ввёл слэш) — подсвечиваем саму папку-контекст;
  -- иначе — детей контекста с префиксом active.
  local matches = {}
  if resolved then
    if active == "" then
      if ctx ~= state.explorer then
        matches = { ctx }
      end
    else
      collect_matches(ctx, active, matches)
    end
  end

  -- Сменился активный сегмент — сбрасываем выбор на первый; иначе держим прежний
  -- (его двигает Ctrl+N/Ctrl+P), клампя в границы нового набора совпадений.
  if active ~= state.prev_active then
    state.sel = 1
  end
  if #matches == 0 then
    state.sel = 1
  elseif state.sel > #matches then
    state.sel = #matches
  end
  -- Первый пересчёт после восстановления сессии: вернуть выбор на узел, что был
  -- активен при выходе (а не на первый по порядку в дереве).
  if state.restore_sel_node then
    for i, node in ipairs(matches) do
      if node == state.restore_sel_node then
        state.sel = i
        break
      end
    end
    state.restore_sel_node = nil
  end
  state.active_sel_node = matches[state.sel]

  state.last_matches = matches
  draw_matches(state.explorer, state.tree_bufnr, matches, state.sel)

  state.prev_committed_n = committed_n
  state.prev_active = active
end

-- Выход из поиска (и по <CR>, и по <Esc> — оба сохраняют результат). Раскрытые
-- поиском папки остаются, подсветка и совпадения запоминаются в nav — чтобы
-- прыгать n/N и восстановить строку при повторном входе. Стирает только M.clear
-- (<leader><space>).
local function finish()
  if not state then
    return
  end
  local s = state
  state = nil

  if vim.api.nvim_win_is_valid(s.overlay_winnr) then
    vim.api.nvim_win_close(s.overlay_winnr, true)
  end
  if vim.api.nvim_buf_is_valid(s.overlay_bufnr) then
    vim.api.nvim_buf_delete(s.overlay_bufnr, { force = true })
  end

  if s.last_matches and #s.last_matches > 0 then
    nav = {
      explorer = s.explorer,
      bufnr = s.tree_bufnr,
      matches = s.last_matches,
      index = 1,
      query = s.query, -- строка запроса для восстановления при повторном входе
      pins = s.pins, -- выбор (Ctrl+N) по committed-сегментам — чтобы `conf/` снова открыл config, а не .config
      sel_node = s.active_sel_node, -- активный выбранный узел — чтобы вернуть подсветку на него
    }
    draw_matches(nav.explorer, nav.bufnr, nav.matches, nav.index)
  else
    clear_highlights(s.tree_bufnr)
    nav = nil
  end

  -- вернуть фокус в дерево
  if view.get_winnr() and vim.api.nvim_win_is_valid(view.get_winnr()) then
    vim.api.nvim_set_current_win(view.get_winnr())
  end
end

-- Навигация по совпадениям последнего зафиксированного поиска, как n/N в Vim.
-- Индекс циклический; строки узлов пересчитываем каждый раз — устойчиво к
-- сворачиванию/разворачиванию дерева между прыжками.
local function jump(delta)
  if not nav or #nav.matches == 0 then
    return
  end
  if not (nav.bufnr and vim.api.nvim_buf_is_valid(nav.bufnr)) then
    nav = nil
    return
  end
  nav.index = ((nav.index - 1 + delta) % #nav.matches) + 1
  draw_matches(nav.explorer, nav.bufnr, nav.matches, nav.index)
end

function M.next()
  jump(1)
end

function M.prev()
  jump(-1)
end

-- Во время ВВОДА (поиск идёт) циклически двигать активное вхождение по совпадениям
-- текущего сегмента. Текст запроса не меняется — меняется только выбор: подсветка
-- «текущего» и курсор в дереве едут на него, фокус остаётся в поле ввода. Выбранный
-- узел запоминаем, чтобы по `/` открылся именно он (см. пины в update).
local function reselect(delta)
  if not state then
    return
  end
  local m = state.last_matches
  if not m or #m == 0 then
    return
  end
  state.sel = ((state.sel - 1 + delta) % #m) + 1
  state.active_sel_node = m[state.sel]
  draw_matches(state.explorer, state.tree_bufnr, m, state.sel)
end

function M.select_next()
  reselect(1)
end

function M.select_prev()
  reselect(-1)
end

-- Сброс подсветки и навигации (вешается на <leader><space> в дереве).
function M.clear()
  if nav then
    clear_highlights(nav.bufnr)
    nav = nil
  end
end

local function create_overlay()
  local bufnr = vim.api.nvim_create_buf(false, true)
  state.overlay_bufnr = bufnr

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      vim.schedule(function()
        if state and vim.api.nvim_buf_is_valid(bufnr) then
          local line = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1] or ""
          update(line)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = bufnr,
    once = true,
    callback = finish,
  })

  -- <CR> и <Esc> — оба просто выходят из поиска, сохраняя результат (см. finish).
  vim.keymap.set("i", "<CR>", "<cmd>stopinsert<CR>", { buffer = bufnr })
  vim.keymap.set("i", "<Esc>", "<cmd>stopinsert<CR>", { buffer = bufnr })
  -- Ctrl+N/Ctrl+P — выбрать активное вхождение среди совпадений текущего сегмента.
  vim.keymap.set("i", "<C-n>", M.select_next, { buffer = bufnr })
  vim.keymap.set("i", "<C-p>", M.select_prev, { buffer = bufnr })

  -- Прибиваем ввод к нижней строке окна дерева — как привычный `/` внизу.
  local tree_winnr = view.get_winnr()
  local win_height = vim.api.nvim_win_get_height(tree_winnr)
  local win_width = vim.api.nvim_win_get_width(tree_winnr)
  state.overlay_winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "win",
    win = tree_winnr,
    row = win_height - 1,
    col = 0,
    width = math.max(win_width, 1),
    height = 1,
    border = "none",
    style = "minimal",
  })
  vim.api.nvim_set_option_value("filetype", "NvimTreePathSearch", { buf = bufnr })

  -- Выключаем nvim-cmp в поле ввода: иначе он по InsertEnter перехватывает
  -- <C-n>/<C-p> под свой автокомплит (перебивая наши бинды) и показывает попап,
  -- который тут не нужен. Окно оверлея уже в фокусе, так что setup.buffer бьёт
  -- по нужному буферу.
  local ok_cmp, cmp = pcall(require, "cmp")
  if ok_cmp then
    cmp.setup.buffer({ enabled = false })
  end

  vim.cmd("startinsert")

  -- Восстановить последнюю сессию, если результаты не стёрли (nav жив): строку,
  -- пины (выбор по committed-сегментам) и активный выбранный узел. Изменение
  -- буфера дёрнет on_lines → update, который по пинам заново раскроет тот же путь
  -- и вернёт подсветку на выбранный узел, а не на первый по порядку.
  if nav and nav.query and nav.query ~= "" then
    if nav.pins then
      for i, node in pairs(nav.pins) do
        state.pins[i] = node
      end
    end
    state.restore_sel_node = nav.sel_node
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { nav.query })
    vim.api.nvim_win_set_cursor(state.overlay_winnr, { 1, #nav.query })
  end
end

-- Точка входа: маппится на `/` в буфере дерева (см. on_attach в plugins/ui.lua).
function M.start()
  local explorer = core.get_explorer()
  if not explorer then
    return
  end
  if state then
    finish()
  end

  state = {
    explorer = explorer,
    tree_bufnr = vim.api.nvim_get_current_buf(),
    opened = {}, -- директории, раскрытые нами в этой сессии
    sel = 1, -- индекс активного вхождения среди совпадений (двигается Ctrl+N/P)
    active_sel_node = nil, -- конкретный выбранный узел активного сегмента
    pins = {}, -- pins[i] = выбранный узел для committed-сегмента i
    prev_committed_n = 0,
    prev_active = nil,
  }

  create_overlay()
end

return M
