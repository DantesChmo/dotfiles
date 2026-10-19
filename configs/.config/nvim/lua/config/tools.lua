-- One inventory for interactive Mason/Treesitter setup and the Make bootstrap.
local M = {}

M.servers = { "gopls", "ts_ls", "pyright", "kotlin_language_server", "lua_ls" }
M.java_tools = {
  "jdtls", "java-debug-adapter", "java-test", "google-java-format",
  "vscode-spring-boot-tools",
}
M.mason_packages = {
  "gopls", "typescript-language-server", "pyright", "kotlin-language-server", "lua-language-server",
}
vim.list_extend(M.mason_packages, M.java_tools)
M.parsers = {
  "bash", "css", "go", "html", "java", "javascript", "json", "kotlin", "lua",
  "markdown", "markdown_inline", "properties", "python", "swift", "tsx", "typescript",
  "vim", "vimdoc", "xml", "yaml",
}

function M.setup_environment()
  -- The installer probes every installed SDK. Reuse its verified choice for
  -- Treesitter's compiler, including when the newest SDK needs a newer linker.
  if vim.fn.has("macunix") == 1 then
    local data_home = vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")
    local path = data_home .. "/dotfiles/native-toolchain.json"
    if vim.fn.filereadable(path) == 1 then
      local ok, native = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
      if ok and type(native) == "table" and type(native.cc) == "string"
        and type(native.sdk) == "string" and vim.fn.executable(native.cc) == 1
        and vim.fn.isdirectory(native.sdk) == 1 then
        vim.env.CC = native.cc
        if vim.fn.executable(native.cc .. "++") == 1 then vim.env.CXX = native.cc .. "++" end
        vim.env.SDKROOT = native.sdk
        vim.env.TOOLCHAINS = "default"
      end
    end
  end
  -- jdtls needs 21 even when the interactive shell selects a project JDK 17.
  -- This changes only the editor process, never the login shell or system JDK.
  local homes = {
    vim.env.NVIM_JAVA_HOME or "",
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home",
    "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home",
    "/usr/lib/jvm/java-21-openjdk",
  }
  for _, home in ipairs(homes) do
    if home ~= "" and vim.fn.executable(home .. "/bin/java") == 1 then
      vim.env.JAVA_HOME = home
      vim.env.PATH = home .. "/bin:" .. vim.env.PATH
      break
    end
  end
end

function M.sourcekit_command()
  if vim.fn.executable("sourcekit-lsp") == 1 then
    return { "sourcekit-lsp" }
  end
  if vim.fn.has("macunix") == 1 and vim.fn.executable("xcrun") == 1 then
    local result = vim.system({ "xcrun", "--find", "sourcekit-lsp" }, { text = true }):wait()
    if result.code == 0 then
      return { "xcrun", "sourcekit-lsp" }
    end
  end
end

return M
