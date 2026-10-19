-- Run against an installed test HOME through make test-nvim.
-- This checks real plugin configuration, installed tools and loadable parsers.
local errors = {}
local notify = vim.notify
vim.notify = function(message, level, opts)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = tostring(message) end
  notify(message, level, opts)
end

local ok, err = xpcall(function()
  local plugins = vim.tbl_keys(require("lazy.core.config").plugins)
  require("lazy").load({ plugins = plugins })
  vim.wait(1500, function() return #errors > 0 end, 100)
  assert(#errors == 0, "Plugin configuration failed: " .. table.concat(errors, "\n"))
  local pins = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if pins[name] then
      local info = require("lazy.manage.git").info(plugin.dir)
      assert(info and info.commit == pins[name].commit, "Plugin version differs from lockfile: " .. name)
    end
  end
  for _, command in ipairs({ "NvimTreeToggle", "DBUI", "DiffviewOpen", "ToggleTerm" }) do
    assert(vim.fn.exists(":" .. command) == 2, "Missing plugin command: " .. command)
  end
  local kotlin = vim.lsp.config.kotlin_language_server
  assert(type(kotlin.init_options.storagePath) == "string", "Kotlin initializationOptions must be a nonempty JSON object")
  local tools = require("config.tools")
  local registry = require("mason-registry")
  for _, name in ipairs(tools.mason_packages) do
    assert(registry.get_package(name):is_installed(), "Missing Mason package: " .. name)
  end
  for _, name in ipairs(tools.parsers) do
    assert(vim.treesitter.language.add(name), "Cannot load parser: " .. name)
  end
  print("All plugin configs, " .. #tools.mason_packages .. " Mason tools and " .. #tools.parsers .. " parsers verified")
end, debug.traceback)
if ok then
  vim.cmd("qa!")
else
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
