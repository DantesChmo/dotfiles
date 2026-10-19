-- Кастомный декоратор для nvim-tree: подсвечивает файлы из .arcignore
-- (Arc / Аркадия), по аналогии с тем, как nvim-tree подсвечивает git-ignored.
-- Публичный API декораторов: см. :help nvim-tree-decorators

local uv = vim.uv or vim.loop

-- Кэш распарсенных правил по корню репозитория, чтобы не читать .arcignore
-- на каждый рендер дерева. Инвалидируется по mtime файла.
local cache = {} -- root -> { mtime = number, rules = table }

-- Превращает glob-паттерн (gitignore-синтаксис) в Lua-паттерн.
local function glob_to_lua(glob)
  local pat = glob:gsub("[%%%^%$%(%)%.%[%]%+%-]", "%%%0") -- экранируем магию Lua
  pat = pat:gsub("%*%*", "\0") -- ** -> плейсхолдер
  pat = pat:gsub("%*", "[^/]*") -- * -> любой сегмент без /
  pat = pat:gsub("%z", ".*") -- ** -> что угодно, включая /
  pat = pat:gsub("%?", "[^/]") -- ? -> один символ, не /
  return pat
end

-- Парсит .arcignore в список правил.
local function parse(path)
  local rules = {}
  local fd = io.open(path, "r")
  if not fd then
    return rules
  end
  for line in fd:lines() do
    local raw = line:gsub("%s+$", "") -- обрезаем хвостовые пробелы
    if raw ~= "" and raw:sub(1, 1) ~= "#" then
      local neg = false
      if raw:sub(1, 1) == "!" then
        neg = true
        raw = raw:sub(2)
      end
      local dironly = false
      if raw:sub(-1) == "/" then
        dironly = true
        raw = raw:sub(1, -2)
      end
      -- Паттерн без внутреннего "/" матчится по любому сегменту пути.
      -- Паттерн со "/" — привязан к корню репозитория.
      local anchored = raw:find("/") ~= nil
      if raw:sub(1, 1) == "/" then
        raw = raw:sub(2)
      end
      table.insert(rules, {
        neg = neg,
        dironly = dironly,
        anchored = anchored,
        pat = "^" .. glob_to_lua(raw) .. "$",
      })
    end
  end
  fd:close()
  return rules
end

-- Возвращает правила для корня, читая/обновляя кэш по mtime.
local function rules_for(root)
  local path = root .. "/.arcignore"
  local stat = uv.fs_stat(path)
  if not stat then
    cache[root] = nil
    return nil
  end
  local mtime = stat.mtime.sec
  local c = cache[root]
  if not c or c.mtime ~= mtime then
    c = { mtime = mtime, rules = parse(path) }
    cache[root] = c
  end
  return c.rules
end

-- Проверяет, игнорируется ли относительный путь rel правилами arcignore.
local function is_ignored(rules, rel)
  local ignored = false
  for _, r in ipairs(rules) do
    local hit = false
    if r.anchored then
      -- привязка к корню: либо точное совпадение, либо префикс-каталог
      if rel:match(r.pat) or rel:match(r.pat:sub(1, -2) .. "/") then
        hit = true
      end
    else
      -- матч по любому сегменту пути
      for seg in (rel .. "/"):gmatch("([^/]+)/") do
        if seg:match(r.pat) then
          hit = true
          break
        end
      end
    end
    if hit then
      ignored = not r.neg
    end
  end
  return ignored
end

-- Arc-игнор должен выглядеть ИДЕНТИЧНО git-игнору, поэтому переиспользуем
-- ту же highlight-группу, что nvim-tree применяет к git-ignored файлам.
local IGNORE_HL = "NvimTreeGitFileIgnoredHL"

---@class ArcIgnoreDecorator: nvim_tree.api.Decorator
local ArcIgnore = require("nvim-tree.api").Decorator:extend()

function ArcIgnore:new()
  self.enabled = true
  self.highlight_range = "all"
  self.icon_placement = "none"
end

function ArcIgnore:highlight_group(node)
  if not node or not node.absolute_path then
    return nil
  end
  local root = uv.cwd()
  local rules = rules_for(root)
  if not rules or #rules == 0 then
    return nil
  end
  local abs = node.absolute_path
  if abs:sub(1, #root + 1) ~= root .. "/" then
    return nil -- узел вне текущего корня — не наш случай
  end
  local rel = abs:sub(#root + 2)
  if is_ignored(rules, rel) then
    return IGNORE_HL
  end
  return nil
end

return ArcIgnore
