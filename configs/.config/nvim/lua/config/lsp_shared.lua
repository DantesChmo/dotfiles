-- ~/.config/nvim/lua/config/lsp_shared.lua
-- Общие настройки для всех LSP-клиентов: capabilities и стандартные keymap'ы.
-- Используются и в plugins/lsp.lua (через vim.lsp.config), и в ftplugin/java.lua (через nvim-jdtls).

local M = {}

-- Capabilities с поддержкой completion от nvim-cmp
function M.capabilities()
  return require("cmp_nvim_lsp").default_capabilities()
end

-- Базовые keymap'ы LSP, навешиваются при подключении сервера к буферу
function M.on_attach(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  local fzf = require("fzf-lua")                                              -- пикеры fzf с превью вместо quickfix

  -- Показать окно fzf с превью кода (даже для единственного результата), не уходя из текущего окна.
  -- Внутри окна: Enter — открыть в текущем окне, Ctrl-v — верт. сплит, Ctrl-x — гор. сплит, Ctrl-t — вкладка.
  local function in_float(picker)
    return function()
      picker({ jump1 = false })
    end
  end

  vim.keymap.set("n", "gd", fzf.lsp_definitions, opts)           -- определения символа (прыжок в текущем окне)
  vim.keymap.set("n", "gr", fzf.lsp_references, opts)            -- все использования символа (прыжок в текущем окне)
  vim.keymap.set("n", "gi", fzf.lsp_implementations, opts)       -- реализации интерфейса (прыжок в текущем окне)
  vim.keymap.set("n", "gt", fzf.lsp_typedefs, opts)             -- определения типа (прыжок в текущем окне)
  vim.keymap.set("n", "<leader>gd", in_float(fzf.lsp_definitions), opts)     -- определение в окне fzf с превью
  vim.keymap.set("n", "<leader>gr", in_float(fzf.lsp_references), opts)      -- использования в окне fzf с превью
  vim.keymap.set("n", "<leader>gi", in_float(fzf.lsp_implementations), opts) -- реализации в окне fzf с превью
  vim.keymap.set("n", "<leader>gt", in_float(fzf.lsp_typedefs), opts)        -- определения типа в окне fzf с превью
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)       -- переход к декларации (обычно единственная — прыжок сразу)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)              -- показать документацию во всплывашке
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)    -- переименование символа во всём проекте
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts) -- code actions (импорты, фиксы, рефакторинг)
  vim.keymap.set("n", "<leader>cf", function()
    vim.lsp.buf.format({ async = true })                        -- форматирование текущего буфера (не на <leader>f — конфликт с fzf-поиском)
  end, opts)
end

return M
