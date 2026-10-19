-- init.lua: Полная конфигурация Neovim
-- Загрузка настроек
require("config.tools").setup_environment()
require("config.options")
require("config.keymaps")
require("config.arc").setup() -- команды :Arc* (обёртка над Arc VCS Аркадии)
require("config.arcsigns").setup() -- значки изменений arc в гуттере (аналог gitsigns)
require("config.lazy")
-- require("config.autocmds")
