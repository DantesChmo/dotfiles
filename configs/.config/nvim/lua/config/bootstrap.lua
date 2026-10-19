-- Called only by make's post-Stow hook; never by normal editor startup.
local M = {}

function M.run()
  local ok, err = xpcall(function()
    assert(vim.fn.has("nvim-0.12") == 1, "This lockfile requires Neovim >= 0.12")
    local lazy = require("lazy")
    lazy.install({ wait = true, show = false, lockfile = true })
    lazy.restore({ wait = true, show = false })
    -- Manager tasks report errors without throwing; make must fail explicitly.
    for name, plugin in pairs(require("lazy.core.config").plugins) do
      assert(plugin._.installed, "Plugin installation failed: " .. name)
      for _, task in ipairs(plugin._.tasks or {}) do
        assert(not task:has_errors(), "Plugin task failed: " .. name .. " (see :Lazy)")
      end
    end

    lazy.load({ plugins = { "mason.nvim", "nvim-treesitter" } })
    require("mason").setup()
    local registry = require("mason-registry")
    local refreshed, refresh_ok = false, false
    registry.refresh(function(success)
      refresh_ok = success
      refreshed = true
    end)
    assert(vim.wait(120000, function() return refreshed end, 100), "Mason registry refresh timed out")
    assert(refresh_ok, "Mason registry refresh failed")
    local failed = {}
    local pending = 0
    for _, name in ipairs(require("config.tools").mason_packages) do
      local pkg = registry.get_package(name)
      if not pkg:is_installed() then
        pending = pending + 1
        pkg:install({}, vim.schedule_wrap(function(success)
          if not success or not pkg:is_installed() then failed[#failed + 1] = name end
          pending = pending - 1
        end))
      end
    end
    assert(vim.wait(1200000, function() return pending == 0 end, 100), "Mason tools installation timed out")
    assert(#failed == 0, "Mason installation failed: " .. table.concat(failed, ", "))

    local parsers = require("config.tools").parsers
    require("nvim-treesitter").install(parsers, { max_jobs = 4 }):wait(600000)
    for _, language in ipairs(parsers) do
      local installed, reason = pcall(vim.treesitter.language.add, language)
      assert(installed, "Parser installation failed: " .. language .. ": " .. tostring(reason))
    end
    print("Neovim plugins, Mason tools and Treesitter parsers are ready")
  end, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
  else
    vim.cmd("qa!")
  end
end

return M
