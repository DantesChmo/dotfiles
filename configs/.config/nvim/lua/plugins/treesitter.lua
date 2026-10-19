return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = vim.env.DOTFILES_BOOTSTRAP == "1",
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      -- The locked main branch uses the rewritten API (Neovim >= 0.12).
      local ts = require("nvim-treesitter")
      ts.setup({})
      if vim.env.DOTFILES_BOOTSTRAP ~= "1" then
        ts.install(require("config.tools").parsers)
      end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true }),
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if lang and pcall(vim.treesitter.start, args.buf, lang) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- main no longer ships incremental_selection; preserve the existing keys
      -- with Neovim's public TSNode API.
      local selections = {}
      local function select(node)
        local sr, sc, er, ec = node:range()
        if ec == 0 and er > sr then
          er = er - 1
          ec = #vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1]
        end
        vim.cmd("normal! \27")
        vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(0, { er + 1, math.max(ec - 1, 0) })
      end
      vim.keymap.set("n", "<C-space>", function()
        local ok, node = pcall(vim.treesitter.get_node)
        if ok and node then
          selections[vim.api.nvim_get_current_buf()] = { node }
          select(node)
        end
      end, { desc = "Select syntax node" })
      vim.keymap.set("x", "<C-space>", function()
        local stack = selections[vim.api.nvim_get_current_buf()]
        if stack and stack[#stack]:parent() then
          stack[#stack + 1] = stack[#stack]:parent()
          select(stack[#stack])
        end
      end, { desc = "Expand syntax selection" })
      vim.keymap.set("x", "<BS>", function()
        local stack = selections[vim.api.nvim_get_current_buf()]
        if stack and #stack > 1 then
          table.remove(stack)
          select(stack[#stack])
        end
      end, { desc = "Shrink syntax selection" })
      vim.api.nvim_create_autocmd({ "BufDelete", "TextChanged", "TextChangedI" }, {
        callback = function(args) selections[args.buf] = nil end,
      })
    end,
  },
}
