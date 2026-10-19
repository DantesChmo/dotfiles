-- Фичи держим в глобальных таблицах, а не в local главного чанка.
-- Иначе Lua GC соберёт watcher/hotkey/eventtap, и они молча перестанут
-- работать (классический баг Hammerspoon → раньше лечилось ручным reload).

-- Фича 1: переопределение клавиш для браузера Zen.
zen_keys = require("zen_keys").start()

-- Фича 2: плавный скролл при PgUp/PgDown.
key_scroll = require("key_scroll").start()
