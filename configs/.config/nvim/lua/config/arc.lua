-- Тонкая обёртка вокруг Arc VCS (Аркадия) — «fugitive-lite» для arc.
--
-- git-плагины (fugitive, gitsigns, diffview) хардкодят бинарь `git` и лезут в
-- git-специфичный пламбинг (--git-dir, rev-parse --absolute-git-dir,
-- show :0:file), которого у arc нет. Поэтому под arc заведён отдельный лёгкий
-- модуль. Порцелайн arc близок к git — status/diff/log/blame/commit/add — их и
-- оборачиваем: команды :Arc* + keymaps <leader>a* по аналогии с git <leader>g*.

local M = {}

local uv = vim.uv or vim.loop

-- Каталог, из которого запускать arc: папка текущего файла (чтобы arc сам нашёл
-- корень репозитория, как git из любого подкаталога), иначе — cwd.
local function buf_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and uv.fs_stat(name) then
    return vim.fs.dirname(name)
  end
  return uv.cwd()
end

-- Абсолютный путь текущего файла или nil, если буфер не привязан к файлу.
local function buf_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and uv.fs_stat(name) then
    return name
  end
  return nil
end

-- Реестр scratch-буферов по заголовку, чтобы переиспользовать окно/буфер
-- (arc://status и т.д.), а не плодить новые на каждый вызов.
local bufs = {}

-- Показывает строки в выделенном scratch-буфере arc://<title>. Переиспользует
-- существующий буфер и окно; создаёт горизонтальный сплит, если окна ещё нет.
local function show(title, lines, filetype)
  local buf = bufs[title]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
    bufs[title] = buf
    pcall(vim.api.nvim_buf_set_name, buf, "arc://" .. title)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true, desc = "Закрыть окно arc" })
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = filetype or ""

  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd("botright split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_height(win, math.min(math.max(#lines + 1, 5), 20))
  end
  vim.api.nvim_set_current_win(win)
  return buf, win
end

-- Асинхронно запускает `arc <args>` и отдаёт результат в колбэк (в main loop).
local function run(args, opts, on_done)
  opts = opts or {}
  local cmd = { "arc" }
  vim.list_extend(cmd, args)
  vim.system(cmd, { cwd = opts.cwd or buf_dir(), text = true }, vim.schedule_wrap(on_done))
end

-- Запускает arc и выводит stdout (+ stderr при ошибке) в scratch-буфер.
local function run_show(args, title, filetype, opts)
  opts = opts or {}
  run(args, opts, function(res)
    local out = res.stdout or ""
    if res.code ~= 0 and (res.stderr or "") ~= "" then
      out = out .. "\n-- stderr --\n" .. res.stderr
    end
    local lines = vim.split(out, "\n", { plain = true })
    while #lines > 1 and lines[#lines] == "" do
      table.remove(lines)
    end
    if #lines == 0 or (#lines == 1 and lines[1] == "") then
      lines = { "(нет изменений)" }
    end
    local _, win = show(title, lines, filetype)
    if opts.cursor_line and vim.api.nvim_win_is_valid(win) then
      local target = math.min(opts.cursor_line, #lines)
      pcall(vim.api.nvim_win_set_cursor, win, { target, 0 })
    else
      pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
    end
  end)
end

-- :ArcStatus — состояние рабочей копии.
function M.status()
  run_show({ "status" }, "status", "")
end

-- :ArcDiff [args] — изменения рабочей копии (или с индексом при --cached).
function M.diff(args)
  local a = { "diff" }
  vim.list_extend(a, args or {})
  run_show(a, "diff", "diff")
end

-- :ArcLog [args] — история одной строкой, последние 50 коммитов по умолчанию.
function M.log(args)
  args = args or {}
  local a = { "log", "--oneline" }
  if #args == 0 then
    vim.list_extend(a, { "-n", "50" })
  else
    vim.list_extend(a, args)
  end
  run_show(a, "log", "git")
end

-- :ArcBlame — авторы построчно для текущего файла, курсор на исходной строке.
function M.blame()
  local file = buf_file()
  if not file then
    vim.notify("Arc: текущий буфер не привязан к файлу", vim.log.levels.WARN)
    return
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  run_show({ "blame", "-r", vim.fs.basename(file) }, "blame", "", {
    cwd = vim.fs.dirname(file),
    cursor_line = line,
  })
end

-- :ArcCommit [msg] — коммит с сообщением; без аргумента спрашивает его.
function M.commit(msg)
  local function do_commit(m)
    if not m or m == "" then
      return
    end
    run({ "commit", "-m", m }, {}, function(res)
      if res.code == 0 then
        vim.notify("Arc: закоммичено", vim.log.levels.INFO)
        M.status()
      else
        vim.notify("Arc commit: " .. (res.stderr or res.stdout or "ошибка"), vim.log.levels.ERROR)
      end
    end)
  end

  if msg and msg ~= "" then
    do_commit(msg)
  else
    vim.ui.input({ prompt = "Arc commit: " }, do_commit)
  end
end

-- :ArcAdd [path...] — добавить в индекс (по умолчанию текущий файл).
function M.add(args)
  local a = { "add" }
  if args and #args > 0 then
    vim.list_extend(a, args)
  else
    local file = buf_file()
    if not file then
      vim.notify("Arc: нет файла для добавления", vim.log.levels.WARN)
      return
    end
    table.insert(a, vim.fs.basename(file))
  end
  run(a, { cwd = buf_dir() }, function(res)
    if res.code == 0 then
      vim.notify("Arc: добавлено в индекс", vim.log.levels.INFO)
    else
      vim.notify("Arc add: " .. (res.stderr or "ошибка"), vim.log.levels.ERROR)
    end
  end)
end

-- Регистрирует пользовательские команды :Arc* один раз при загрузке модуля.
function M.setup()
  -- arc (VCS Аркадии/X5) есть не на всякой машине. Нет бинарника → команды :Arc*
  -- бессмысленны, тихо выходим (на такой машине работает штатный git/fugitive).
  if vim.fn.executable("arc") == 0 then
    return
  end

  local cmd = vim.api.nvim_create_user_command

  -- Универсальная :Arc <args> — вывод любой неинтерактивной команды в сплит.
  cmd("Arc", function(o)
    if #o.fargs == 0 then
      M.status()
    else
      run_show(o.fargs, "arc", "")
    end
  end, { nargs = "*", desc = "Запустить произвольную команду arc" })

  cmd("ArcStatus", function() M.status() end, { desc = "Arc: статус рабочей копии" })
  cmd("ArcDiff", function(o) M.diff(o.fargs) end, { nargs = "*", desc = "Arc: изменения" })
  cmd("ArcLog", function(o) M.log(o.fargs) end, { nargs = "*", desc = "Arc: история коммитов" })
  cmd("ArcBlame", function() M.blame() end, { desc = "Arc: авторы построчно" })
  cmd("ArcCommit", function(o) M.commit(o.args) end, { nargs = "?", desc = "Arc: коммит" })
  cmd("ArcAdd", function(o) M.add(o.fargs) end, { nargs = "*", desc = "Arc: добавить в индекс" })
end

return M
