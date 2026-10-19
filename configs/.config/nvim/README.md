# Neovim Configuration

A personal Neovim setup focused on polyglot development (Java/Spring Boot, Go, TypeScript, Python, Swift, Kotlin, Lua) with LSP, DAP, GitHub Copilot completion, Git/Arc integration, and Docker/Kubernetes helpers.

## Requirements

- Neovim ≥ 0.12 (the locked Treesitter main branch requires the new API)
- `git`, `curl`, a C compiler (for tree-sitter parsers)
- `ripgrep` and `fd` (recommended, used by `fzf-lua`)
- A Nerd Font (for `nvim-web-devicons`)
- `tree-sitter-cli` ≥ 0.26.1 (system package, not npm)
- Node.js/npm (TypeScript/Pyright/Copilot), Go (gopls), Python 3 (jdtls launcher)
- JDK 21+ for jdtls and the Java toolchain; Maven and Gradle for projects without wrappers

## Installation

```sh
cd ~/projects/dotfiles
make install-nvim
```

The Make target installs OS packages, links this config with GNU Stow, then waits for lazy.nvim plugins, Mason tools and Treesitter parsers. Plugin pins come from `lazy-lock.json`; the bootstrap uses a disposable lockfile copy so installing another device cannot rewrite the tracked file. Normal launches can still install missing tools. The shared tool inventory is `lua/config/tools.lua`.

## Structure

```
.
├── init.lua                  # entry point — loads config.* modules
├── lazy-lock.json            # locked plugin versions
├── ftplugin/
│   └── java.lua              # per-buffer jdtls bootstrap for Java files
└── lua/
    ├── config/
    │   ├── options.lua       # vim options (numbers, tabs, search, UI, etc.)
    │   ├── keymaps.lua       # global keymaps
    │   ├── lazy.lua          # lazy.nvim bootstrap and plugin spec import
    │   └── lsp_shared.lua    # shared LSP capabilities + on_attach
    └── plugins/
        ├── init.lua          # colorscheme (gruvbox)
        ├── lsp.lua           # mason, mason-lspconfig, lspconfig
        ├── cmp.lua           # nvim-cmp completion + luasnip
        ├── treesitter.lua    # nvim-treesitter
        ├── fzf.lua           # fzf-lua + Docker/k9s pickers
        ├── git.lua           # gitsigns, fugitive, diffview, toggleterm
        ├── ui.lua            # nvim-tree, lualine, symbols-outline
        ├── helpers.lua       # autopairs, autotag, comment, bufferline, etc.
        ├── format.lua        # conform.nvim (google-java-format)
        ├── dap.lua           # nvim-dap + dap-ui + virtual text
        ├── test.lua          # neotest + neotest-java
        ├── db.lua            # vim-dadbod + dadbod-ui
        ├── java.lua          # nvim-jdtls and spring-boot.nvim specs
        └── ai.lua            # official GitHub Copilot (manual login)
```

## Plugin manager

[`folke/lazy.nvim`](https://github.com/folke/lazy.nvim) — bootstrapped automatically by `lua/config/lazy.lua`. Plugin specs are split per-domain under `lua/plugins/` and imported as a whole directory.

## Language support

LSP servers managed by `mason-lspconfig` and configured via `vim.lsp.config` in `lua/plugins/lsp.lua`:

| Language       | Server                    |
| -------------- | ------------------------- |
| Go             | `gopls`                   |
| TypeScript/JS  | `ts_ls`                   |
| Python         | `pyright`                 |
| Swift          | `sourcekit-lsp`           |
| Kotlin         | `kotlin_language_server`  |
| Lua            | `lua_ls`                  |
| Java           | `jdtls` (via `nvim-jdtls`)|

Java is special: `jdtls` is started per-buffer from `ftplugin/java.lua` (not via `mason-lspconfig`) because it needs its own workspace per project, DAP bundles, and Spring Boot extensions. `mason-tool-installer` ensures the following tools are present:

- `jdtls` — Java LSP
- `java-debug-adapter` — DAP adapter for Java
- `java-test` — JUnit/TestNG runner bundle
- `google-java-format` — Java formatter (used by `conform.nvim`, AOSP style)
- `vscode-spring-boot-tools` — Spring Boot language server and jdtls extension jars

Treesitter parsers (`nvim-treesitter`) cover Bash, CSS, Go, HTML, Java, JS, JSON, Kotlin, Lua, Markdown, Python, Swift, TSX/TS, Vim, XML, YAML, and more.

## Completion

`nvim-cmp` with sources: `nvim_lsp`, `luasnip`, `buffer`, `path`, plus `cmp-cmdline` for `:` and `/`. Snippets come from `friendly-snippets` via `LuaSnip`.

## AI

`github/copilot.vim` supplies inline suggestions. Node.js is installed by Make. Authenticate once per device with `:Copilot setup`; bootstrap never starts a login flow. There is no active X5/CodeCompanion endpoint or `X5_API_KEY` dependency.

## Debugging

`nvim-dap` + `nvim-dap-ui` + `nvim-dap-virtual-text`. The UI opens/closes automatically on session start/stop. Java DAP configurations are registered by `jdtls` for `main` classes and `@Test` methods.

## Tests

`neotest` with the `neotest-java` adapter — Maven and Gradle are detected automatically by the adapter.

## Database

`vim-dadbod` + `vim-dadbod-ui` + `vim-dadbod-completion`. Open the UI with `<leader>db`.

## Theme & UI

- Colorscheme: `gruvbox` (soft contrast, transparent background)
- Statusline: `lualine` with LSP progress
- File explorer: `nvim-tree`
- Buffer tabs: `bufferline.nvim`
- Symbols panel: `symbols-outline.nvim`
- Markdown rendering: `render-markdown.nvim`

## Keymaps

Leader is the default `\`. Highlights:

### Files / search (`fzf-lua`)

| Keys           | Action                |
| -------------- | --------------------- |
| `<leader>ff`   | Find files            |
| `<leader>fg`   | Live grep             |
| `<leader>fb`   | Buffers               |
| `<leader>fh`   | Help tags             |
| `<leader>fc`   | Commands              |
| `<leader>e`    | Toggle `nvim-tree`    |

### Buffers / windows

| Keys           | Action                |
| -------------- | --------------------- |
| `<S-l>` / `<S-h>` | Next / previous buffer |
| `<C-h/j/k/l>`  | Move between splits   |
| `<leader>w`    | Save                  |
| `<leader>q`    | Quit all (force)      |
| `<leader><space>` | Clear search highlight |

### Terminal

| Keys           | Action                       |
| -------------- | ---------------------------- |
| `<leader>th`   | Horizontal terminal split    |
| `<leader>tv`   | Vertical terminal split      |
| `<leader>tt`   | `ToggleTerm`                 |
| `<C-\>`        | `ToggleTerm` (default mapping) |
| `<Esc>` (term) | Exit terminal-insert mode    |

### LSP

| Keys           | Action                  |
| -------------- | ----------------------- |
| `gd`           | Go to definition        |
| `gD`           | Go to declaration       |
| `gr`           | References              |
| `gi`           | Implementation          |
| `gt`           | Type definition         |
| `K`            | Hover documentation     |
| `<leader>rn`   | Rename symbol           |
| `<leader>ca`   | Code action             |
| `<leader>cf`   | Format buffer (LSP, or `google-java-format` in Java) |

### Diagnostics

| Keys           | Action                          |
| -------------- | ------------------------------- |
| `<leader>de`   | Show diagnostic on current line |
| `<leader>dq`   | Loclist of buffer diagnostics   |
| `<leader>dd`   | Document diagnostics (fzf)      |
| `<leader>dw`   | Workspace diagnostics (fzf)     |
| `[d` / `]d`    | Previous / next diagnostic      |

### Git

| Keys           | Action            |
| -------------- | ----------------- |
| `<leader>gs`   | `:Git` (fugitive) |
| `<leader>gc`   | `:Git commit`     |
| `<leader>gp`   | `:Git push`       |
| `<leader>gl`   | `:Git pull`       |

### Debugging (DAP)

| Keys           | Action                          |
| -------------- | ------------------------------- |
| `<F5>`         | Continue / start                |
| `<F10>`        | Step over                       |
| `<F11>`        | Step into                       |
| `<F12>`        | Step out                        |
| `<leader>b`    | Toggle breakpoint               |
| `<leader>B`    | Conditional breakpoint          |
| `<leader>xu`   | Toggle DAP UI                   |
| `<leader>xr`   | Toggle DAP REPL                 |
| `<leader>xc`   | Clear all breakpoints           |
| `<leader>xl`   | Re-run last session             |

### Tests (`neotest`)

| Keys           | Action                          |
| -------------- | ------------------------------- |
| `<leader>tr`   | Run nearest test                |
| `<leader>tf`   | Run current file                |
| `<leader>tl`   | Repeat last test                |
| `<leader>td`   | Debug nearest test              |
| `<leader>ts`   | Toggle summary tree             |
| `<leader>to`   | Show output                     |

### Java (`<leader>j`)

| Keys           | Action                          |
| -------------- | ------------------------------- |
| `<leader>jo`   | Organize imports                |
| `<leader>jv`   | Extract variable (normal/visual)|
| `<leader>jc`   | Extract constant                |
| `<leader>jm`   | Extract method (visual)         |
| `<leader>jr`   | Run test class                  |
| `<leader>jR`   | Run nearest test method         |
| `<leader>jb`   | Spring Boot — list beans        |
| `<leader>jp`   | Spring Boot — list endpoints    |

### Docker / Kubernetes (via `fzf-lua` + `toggleterm`)

| Keys           | Action                                  |
| -------------- | --------------------------------------- |
| `<leader>dps`  | Pick a container and tail its logs      |
| `<leader>dcu`  | Pick a Compose service and `up -d` it   |
| `<leader>cl`   | Pick a Compose service and tail logs    |
| `<leader>cd`   | `docker compose down`                   |
| `<leader>kk`   | Open `k9s` in a floating terminal       |

### AI

| Keys | Action |
| ---- | ------ |
| `<C-J>` | Accept Copilot suggestion |
| `<C-L>` | Accept next word |
| `<M-]>` / `<M-[>` | Next / previous suggestion |
| `<C-]>` | Dismiss suggestion |

### Database

| Keys           | Action                |
| -------------- | --------------------- |
| `<leader>db`   | Toggle `DBUI`         |

## Options worth knowing

Set in `lua/config/options.lua`:

- Relative line numbers, system clipboard, persistent undo, no swap files
- 2-space indents, smart indent, smart case search
- True color, sign column always on, cursor line, 8-line scroll padding
- New splits go below / to the right
- 250 ms `updatetime`, 300 ms `timeoutlen`

## Notes

- `init_bak.lua` is a backup of an older single-file configuration kept around for reference. It is not loaded.
- `lazy-lock.json` is committed so plugin versions are reproducible — run `:Lazy update` to bump.

## Dependency audit and platform notes

Every file in this configuration was checked, including the inactive backup and local development metadata.

| Files | External/runtime dependencies |
| --- | --- |
| `init.lua`, `config/lazy.lua`, `lazy-lock.json` | Neovim 0.12+, Git, network access to public plugin repositories. Lazy manages all Lua plugins. |
| `plugins/lsp.lua`, `config/tools.lua`, `bin/gopls` | Node/npm, Go, Python 3, JDK 21; Mason installs gopls, typescript-language-server, pyright, kotlin-language-server and lua-language-server. The gopls wrapper respects XDG paths and `NVIM_APPNAME`. |
| `plugins/java.lua`, `ftplugin/java.lua`, `plugins/format.lua`, `plugins/dap.lua`, `plugins/test.lua` | JDK 21, Python 3, Maven/Gradle (project `mvnw`/`gradlew` preferred); Mason supplies jdtls, java-debug-adapter, java-test, google-java-format and vscode-spring-boot-tools. |
| `plugins/treesitter.lua` | C compiler, curl, tar and system tree-sitter-cli >= 0.26.1; Make compiles all 20 configured parsers. No Rust toolchain is required. |
| `plugins/fzf.lua` | fzf, ripgrep, fd; Docker CLI + Compose for container shortcuts, k9s + kubectl for Kubernetes. Builtin previews do not require bat. |
| `plugins/ai.lua` | Node.js and a user-provided GitHub Copilot account; `:Copilot setup` once per device. |
| `plugins/db.lua` | SQLite CLI installed; other Dadbod database clients depend on your own connection URLs (none are configured here). For PostgreSQL use `libpq` (brew) / `postgresql-libs` (Arch); for MySQL use `mysql-client` (brew) / `mariadb-clients` (Arch). No database servers or credentials are provisioned. |
| `config/options.lua` | macOS clipboard works with pbcopy/pbpaste; Arch installs both wl-clipboard (Wayland) and xclip (X11). Configure a Nerd Font in the terminal for icons. |
| `plugins/ui.lua`, `config/tree_path_search.lua` | Lua plugins only; the formerly missing `lsp-progress.nvim` is now declared and locked. |
| `plugins/cmp.lua`, `plugins/helpers.lua`, `plugins/git.lua`, `plugins/init.lua`, `config/lsp_shared.lua`, `config/keymaps.lua` | Lua plugins, Git, and the configured interactive shell; no further OS packages. |
| `config/arc.lua`, `config/arcsigns.lua`, `config/arcignore.lua` | Optional internal Arc CLI and an existing Arcadia checkout. Without Arc the first two modules quietly disable themselves; the ignore decorator reads local files only. |
| `config/bootstrap.lua` | Installs and verifies missing plugins/tools/parsers; used only by the Make hook. |
| `init_bak.lua` | Historical, never loaded by `init.lua`. Its old Xcode build server, Poetry, debugpy, delve, JS DAP and Markdown-preview dependencies are deliberately not installed. |
| `README.md`, archived `local/legacy/nvim/.claude/settings.local.json` | Documentation/development metadata; no editor runtime dependencies. |

The installed JDK 21 is selected inside Neovim even if the login shell selects Java 17. Set `NVIM_JAVA_HOME` to explicitly choose the editor runtime; shell/system JDK settings are unchanged. A project can declare its own JDK/toolchain independently from the jdtls runtime.

Swift support uses `sourcekit-lsp` from the Swift toolchain. On macOS it is found directly or through `xcrun`; Xcode projects/simulators require Xcode installed and selected separately. On Arch, Swift is optional and is not in the official pacman repositories: install a toolchain using the [official Swiftly instructions](https://www.swift.org/install/linux/swiftly/) and expose `swift`/`sourcekit-lsp` in PATH. The editor stays usable without Swift and does not start an unavailable SourceKit server. Swift formatting/linting commands additionally support `swift-format`, `swiftformat` and `swiftlint`; these are optional plugin features, not required for the configured LSP setup.

Docker shortcuts require a running Docker daemon (e.g. Colima/Docker Desktop on macOS, Docker service on Arch). Kubernetes requires your kubeconfig/cluster credentials. Bootstrap installs client tools but does not start services, select contexts or copy credentials.

For Arcadia Go imports the existing `~/go/src/a.yandex-team.ru` symlink must point at your own checkout; its location and internal access cannot be inferred on a new device. Public dotfiles bootstrap never installs internal tools or starts corporate authentication.

Primary references: [Treesitter main requirements and API](https://github.com/nvim-treesitter/nvim-treesitter/tree/main), [nvim-jdtls Java/Python requirements](https://github.com/mfussenegger/nvim-jdtls), [Mason Spring tools package](https://github.com/mason-org/mason-registry/blob/main/packages/vscode-spring-boot-tools/package.yaml), [Swift plugin dependencies](https://github.com/devswiftzone/swift.nvim).

## Bootstrap verification

Verified in an isolated HOME/XDG environment with real upstream downloads:
Lazy installation/restore at the locked revisions, the main plugin configurations,
all 20 Treesitter parsers (compiled and loaded), highlighting/indent callbacks and
incremental selection. The repository lockfile remained byte-for-byte unchanged.
The gopls wrapper was tested with custom XDG paths, ordinary modules and nested
Arcadia directories.

Mason installed gopls, typescript-language-server, pyright, lua-language-server,
java-debug-adapter and java-test. Completion of the four larger downloads
(jdtls, kotlin-language-server, google-java-format and vscode-spring-boot-tools)
was not verified because of the test network's download speed; the isolated run
was stopped. A resume check confirmed successful packages were retained and the
interrupted packages were retryable, with no stale installation handles.
Their registry entries and bootstrap installation calls were validated.
