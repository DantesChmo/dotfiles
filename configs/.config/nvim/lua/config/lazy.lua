-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Cannot install lazy.nvim: " .. output)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Загрузка плагинов
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
if vim.env.DOTFILES_BOOTSTRAP == "1" then
  -- Lazy writes its lockfile even during install/restore. Use a disposable copy
  -- so bootstrapping a second device cannot dirty or erase the tracked pins.
  local temporary_lock = vim.fn.tempname()
  vim.fn.writefile(vim.fn.readfile(lockfile), temporary_lock)
  lockfile = temporary_lock
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    callback = function() vim.fn.delete(temporary_lock) end,
  })
end
require("lazy").setup({
  lockfile = lockfile,
  concurrency = 8,
  git = { timeout = 300 },
  defaults = { lazy = vim.env.DOTFILES_BOOTSTRAP == "1" },
  install = { missing = vim.env.DOTFILES_BOOTSTRAP ~= "1" },
  spec = {
    { import = "plugins" },
  },
  change_detection = {
    notify = false
  },
})

