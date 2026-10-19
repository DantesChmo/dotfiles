-- Переопределение клавиш для браузера Zen.
-- Cmd+Shift+J / Cmd+Shift+K → переключение вкладок (Cmd+Alt+Down / Up),
-- активно только когда фронт — Zen.
local M = {}

M.BUNDLE_ID = "app.zen-browser.zen"

-- Единый источник правды: хоткеи включены ровно тогда, когда фронт — Zen.
-- Идемпотентно, можно звать сколько угодно раз.
local function syncState()
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() == M.BUNDLE_ID then
    M.nextTab:enable()
    M.prevTab:enable()
  else
    M.nextTab:disable()
    M.prevTab:disable()
  end
end

function M.start()
  if M.nextTab then return M end  -- уже запущен

  M.nextTab = hs.hotkey.new({"cmd", "shift"}, "J", function()
    hs.eventtap.keyStroke({"cmd", "alt"}, "down", 0)
  end)

  M.prevTab = hs.hotkey.new({"cmd", "shift"}, "K", function()
    hs.eventtap.keyStroke({"cmd", "alt"}, "up", 0)
  end)

  -- Слушаем и activated, и deactivated — меньше шансов застрять в
  -- рассинхроне, если одно из событий потеряется.
  M.appWatcher = hs.application.watcher.new(function(_, eventType, _)
    if eventType == hs.application.watcher.activated
       or eventType == hs.application.watcher.deactivated then
      syncState()
    end
  end)
  M.appWatcher:start()

  -- Watchdog: страховка на случай, если watcher пропустил событие.
  -- Досинхронивает состояние раз в секунду, поэтому ручной reload не нужен.
  M.watchdog = hs.timer.doEvery(1, syncState)

  syncState()
  return M
end

function M.stop()
  if M.watchdog then M.watchdog:stop(); M.watchdog = nil end
  if M.appWatcher then M.appWatcher:stop(); M.appWatcher = nil end
  if M.nextTab then M.nextTab:delete(); M.nextTab = nil end
  if M.prevTab then M.prevTab:delete(); M.prevTab = nil end
end

return M
