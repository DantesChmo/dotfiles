local M = {}

-- ===== Настройки по умолчанию =====
M.PAGE_FRACTION = 0.5
M.SMOOTHING     = 0.2
M.FPS           = 120
M.SIGN          = 1
-- ===================================

local props     = hs.eventtap.event.properties
local newScroll = hs.eventtap.event.newScrollEvent

local PHASE_BEGAN, PHASE_CHANGED, PHASE_ENDED = 1, 2, 4
local KC_PGUP, KC_PGDOWN = 116, 121

local function round(x) return math.floor(x + 0.5) end

local function viewportHeight()
  local w = hs.window.focusedWindow()
  return (w and w:frame().h) or hs.screen.mainScreen():frame().h
end

local function postScroll(dy, phase)
  local e = newScroll({0, dy}, {}, "pixel")
  e:setProperty(props.scrollWheelEventIsContinuous, 1)
  e:setProperty(props.scrollWheelEventScrollPhase, phase)
  e:post()
end

local remaining = 0
local started   = false
local timer     = nil

local function endGesture()
  postScroll(0, PHASE_ENDED)
  started = false
  if timer then timer:stop(); timer = nil end
end

local function tick()
  if math.abs(remaining) < 1 then
    remaining = 0
    endGesture()
    return
  end
  local step = remaining * M.SMOOTHING
  if math.abs(step) < 1 then step = (step > 0) and 1 or -1 end
  local istep = round(step)
  if started then
    postScroll(istep, PHASE_CHANGED)
  else
    postScroll(istep, PHASE_BEGAN)
    started = true
  end
  remaining = remaining - istep
end

local function scrollBy(distance)
  remaining = remaining + distance
  if not timer then timer = hs.timer.doEvery(1 / M.FPS, tick) end
end

local function page(dir)
  scrollBy(dir * M.PAGE_FRACTION * viewportHeight())
end

function M.start()
  if M.tap then return M end  -- уже запущен
  M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
    local code = ev:getKeyCode()
    if code ~= KC_PGUP and code ~= KC_PGDOWN then return false end

    local f = ev:getFlags()
    if f.cmd or f.alt or f.ctrl or f.shift then return false end

    if code == KC_PGUP then page(M.SIGN) else page(-M.SIGN) end
    return true
  end)
  M.tap:start()

  -- Watchdog: macOS может прибить eventtap по таймауту. Раз в секунду
  -- поднимаем tap обратно, если он оказался выключен — ручной reload не нужен.
  M.watchdog = hs.timer.doEvery(1, function()
    if M.tap and not M.tap:isEnabled() then M.tap:start() end
  end)

  return M
end

function M.stop()
  if M.watchdog then M.watchdog:stop(); M.watchdog = nil end
  if M.tap then M.tap:stop(); M.tap = nil end
  if timer then timer:stop(); timer = nil end
end

return M
