-- Called only by make's post-Stow hook; never by normal editor startup.
local M = {}

function M.clear_stale_mason_lock(name)
  local path = require("mason-core.installer.InstallLocation").global():lockfile(name)
  if vim.fn.filereadable(path) == 0 then return end
  local pid = tonumber(table.concat(vim.fn.readfile(path), ""))
  assert(pid and pid > 0, "Mason lock has no valid owner: " .. path)
  local alive, err = vim.uv.kill(pid, 0)
  -- Never bypass a live owner or a permissions error. A crashed installer,
  -- however, must not permanently block the next make install.
  if alive == nil and tostring(err):find("ESRCH", 1, true) then
    assert(vim.fn.delete(path) == 0, "Cannot remove abandoned Mason lock: " .. name)
    return
  end
  error("Mason package " .. name .. " is locked by process " .. pid .. "; wait for that installer to finish")
end

function M.run()
  local ok, err = xpcall(function()
    assert(vim.fn.has("nvim-0.12") == 1, "This lockfile requires Neovim >= 0.12")
    local lazy = require("lazy")
    local pins = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
    local lock = require("lazy.manage.lock")
    local failed = {}
    for attempt = 1, 3 do
      -- install() rewrites Lazy's in-memory lock with existing checkouts too.
      -- Keep restoring the tracked pins, including for an older installed tree.
      lock.lock = vim.deepcopy(pins)
      lazy.install({ wait = true, show = false, lockfile = true })
      local restore = {}
      for name, plugin in pairs(require("lazy.core.config").plugins) do
        local pin = pins[name]
        if plugin._.installed and pin then
          local info = require("lazy.manage.git").info(plugin.dir)
          if not info or info.commit ~= pin.commit then restore[#restore + 1] = name end
        end
      end
      -- Already installed and correctly pinned plugins need no network fetch.
      if #restore > 0 then
        lock.lock = vim.deepcopy(pins)
        lazy.restore({ plugins = restore, wait = true, show = false })
      end
      failed = {}
      -- Manager tasks report errors without throwing; make must fail explicitly.
      for name, plugin in pairs(require("lazy.core.config").plugins) do
        local broken = not plugin._.installed
        if plugin._.installed and pins[name] then
          local info = require("lazy.manage.git").info(plugin.dir)
          if not info or info.commit ~= pins[name].commit then broken = true end
        end
        for _, task in ipairs(plugin._.tasks or {}) do
          if task:has_errors() then broken = true end
        end
        if broken then failed[#failed + 1] = name end
      end
      if #failed == 0 then break end
      if attempt < 3 then print("Retrying plugin installation: " .. table.concat(failed, ", ")) end
    end
    assert(#failed == 0, "Plugin installation failed: " .. table.concat(failed, ", ") .. " (see :Lazy)")

    lazy.load({ plugins = { "mason.nvim", "nvim-treesitter" } })
    require("mason").setup()
    local registry = require("mason-registry")
    local needs_registry = false
    for _, name in ipairs(require("config.tools").mason_packages) do
      if not registry.has_package(name) or not registry.is_installed(name) then needs_registry = true end
    end
    if needs_registry then
      local refreshed, refresh_ok = false, false
      registry.refresh(function(success)
        refresh_ok = success
        refreshed = true
      end)
      assert(vim.wait(120000, function() return refreshed end, 100), "Mason registry refresh timed out")
      assert(refresh_ok, "Mason registry refresh failed")
    end
    for attempt = 1, 3 do
      failed = {}
      local pending = 0
      for _, name in ipairs(require("config.tools").mason_packages) do
        local pkg = registry.get_package(name)
        if not pkg:is_installed() then
          M.clear_stale_mason_lock(name)
          pending = pending + 1
          pkg:install({}, vim.schedule_wrap(function(success)
            if not success or not pkg:is_installed() then failed[#failed + 1] = name end
            pending = pending - 1
          end))
        end
      end
      assert(vim.wait(1200000, function() return pending == 0 end, 100), "Mason tools installation timed out")
      if #failed == 0 then break end
      if attempt < 3 then print("Retrying Mason installation: " .. table.concat(failed, ", ")) end
    end
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
