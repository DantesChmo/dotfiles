-- ~/.config/nvim/lua/plugins/format.lua
-- Форматирование через conform.nvim.
-- Для Java используется google-java-format (бинарь поставлен mason-tool-installer'ом).
-- Базовый <leader>cf в lsp_shared зовёт vim.lsp.buf.format; для Java переопределяем его на conform,
-- чтобы вместо Eclipse-форматтера jdtls применять google-java-format.

return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "ConformInfo" },
    config = function()
      local conform = require("conform")

      conform.setup({
        formatters_by_ft = {
          java = { "google-java-format" },
        },
        formatters = {
          ["google-java-format"] = {
            -- AOSP-стиль: 4 пробела (привычнее для Spring проектов).
            -- Убери prepend_args, если хочешь классический 2-пробельный Google-стиль.
            prepend_args = { "--aosp" },
          },
        },
      })

      -- Для Java перебиваем <leader>cf на conform (переопределяем буферно после открытия Java-файла)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function(args)
          vim.keymap.set("n", "<leader>cf", function()
            conform.format({ bufnr = args.buf, async = true, lsp_format = "fallback" })
          end, { buffer = args.buf, silent = true, desc = "Format: google-java-format" })
        end,
      })
    end,
  },
}
