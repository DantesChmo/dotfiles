# Зависимости всех конфигов

Проверены восемь конфигов и все их исходные файлы, включая shell/Lua-модули,
lockfile, нативный helper, документацию и неактивные backup. Секреты не читались.
Ниже обязательные инструменты, которые устанавливаются через `make install`;
подробная привязка к файлам и условные интеграции — по ссылкам.
Единственный источник списков и шагов установки — `dependencies.yaml` (Ansible).

| Конфиг | Устанавливаемые зависимости |
|---|---|
| [Zsh](#zsh) | Zsh, Git, curl/xz, fzf, eza, vivid; Powerlevel10k, zsh-async, autosuggestions, syntax-highlighting, history-substring-search, fzf-tab; выбранные плагины Oh My Zsh; nvm + Node LTS, Go/goenv, Python/pip, JDK17, Docker/Compose, kubectl/kubectx, Terraform, psql, Yazi и preview helpers, Meslo Nerd Font |
| [Neovim](configs/.config/nvim/README.md) | Neovim >=0.12, Git, compiler/CLT/base-devel, Node/npm, Go, Python, JDK21, Maven/Gradle, SQLite, curl/unzip, tree-sitter CLI, fzf/fd/ripgrep, Docker/Compose/k9s/kubectl; Lazy-плагины из lockfile, Mason LSP/formatters/debuggers и Treesitter parsers |
| [btop](#btop) | btop со штатной темой gruvbox_material_dark |
| [OpenCode](#opencode) | OpenCode; в Arch также clipboard backends X11/Wayland. Provider SDK устанавливает само приложение |
| [AeroSpace](#aerospace) | AeroSpace, iTerm2, связанный конфиг SketchyBar |
| [AeroSpace Swipe](#aerospace-swipe) | AeroSpace, compiler/CLT, сборка upstream bundle с vendored yyjson, LaunchAgent |
| [Hammerspoon](#hammerspoon) | Hammerspoon, Zen Browser для его хоткеев; используются встроенные hs-модули |
| [SketchyBar](#sketchybar) | SketchyBar, AeroSpace, JankyBorders, Hack Nerd Font; helper собирается системным clang и macOS frameworks |

macOS-приложения не имеют пакетов для Arch и там пропускаются автоматически.
В Arch общие конфиги получают wl-clipboard и xclip для Wayland/X11.
Homebrew и pacman сами устанавливают транзитивные зависимости своих пакетов.

## Что нельзя восстановить только из dotfiles

Секреты, корпоративная сеть/доступы, авторизация AI-провайдеров и Copilot,
Docker daemon и Kubernetes contexts, конкретные БД и проектные SDK.
Включение Accessibility требует действий пользователя в macOS.

Необязательные интеграции в конфигурациях условны: Android SDK, Swift toolchain
на Arch, Ollama, Claude CLI, Yandex ya/arc и Arc-индикатор Powerlevel10k.
Штатные P10k status modules не являются требованием установить все
перечисляемые ими языки, облачные CLI и менеджеры окружений.

[Подробный аудит Zsh](#zsh) перечисляет команды, плагины и способы установки;
[аудит Neovim](configs/.config/nvim/README.md) содержит точный список
Mason-инструментов и parser languages;
[аудит desktop](#аудит-desktop-конфигов-и-зависимостей) покрывает каждый файл оставшихся шести
пакетов, источники зависимостей и запуск сервисов.

## Проверка установки

`make test` выполняет определённые в Makefile проверки с настоящим GNU Stow:
повторная и выборочная линковка, снятие ссылок, сохранение файлов при конфликтах,
автообнаружение конфигов и динамических Make targets, штатный `--simulate`,
выбор ОС и исключение служебных файлов/секретов. Линковку и обработку конфликтов
выполняет сам Stow; собственного backup-механизма нет.

Zsh также проверен с настоящими загруженными плагинами в отдельном HOME под PTY;
SketchyBar helper собран настоящим macOS clang. Планы установки macOS и Arch
проверены без переустановки системных пакетов. Полная установка на чистую Arch
машину в этой среде не выполнялась.

---

# Zsh

Установка из корня dotfiles:

```sh
make install-zsh  # зависимости и Stow: ~/.zshrc, ~/.p10k.zsh
make deps-zsh     # только зависимости
```

Плагины лежат в `${XDG_DATA_HOME:-~/.local/share}/dotfiles/zsh` и устанавливаются
bootstrap-скриптом. Конфиг подключает их напрямую: Zinit больше не нужен,
открытие нового shell не скачивает плагины. Уже установленные репозитории
не сбрасываются и не обновляются автоматически.

## Зависимости

- Shell: zsh, Git, curl, xz, fzf, eza, vivid, Meslo Nerd Font.
- Плагины: Powerlevel10k, zsh-async, zsh-autosuggestions,
  zsh-syntax-highlighting, zsh-history-substring-search, fzf-tab.
- Выборочные плагины Oh My Zsh: git, docker, docker-compose, kubectl,
  python, pip, nvm, golang, terraform. Полный framework/его updater не запускается.
- Инструменты интеграций: Go и goenv, Python/pip, upstream nvm и Node LTS,
  OpenJDK 17, kubectl/kubectx/kubens, Docker CLI/Compose, Terraform, psql.
- Arch: xclip и wl-clipboard для функций буфера обмена Git/OMZ.
- Yazi и помощники preview/search: ffmpeg, 7-Zip, jq, poppler, fd, ripgrep,
  zoxide, resvg, ImageMagick; file — системный в macOS, отдельный пакет в Arch.
- nvim устанавливается соответствующим пакетом dotfiles.

На macOS используются Homebrew formulae/casks; на Arch — официальные пакеты
pacman. goenv/nvm и shell-плагины клонируются из upstream GitHub. nvm получает
Node LTS только при отсутствии действующего default; существующая версия
и выбранный default сохраняются. Не устанавливается системный Python через pip.

Установленный Nerd Font надо выбрать в настройках своего терминала.
Docker CLI не запускает Docker daemon: на macOS нужен Docker Desktop/Colima,
на Arch — запущенный docker.service и доступ пользователя к Docker.

## Необязательные интеграции

Android SDK, Ollama, Claude CLI, внутренние `ya`/`arc` и расширение
`powerlevel10k-prompt-arc` требуют отдельной установки/доступа. Их упоминания в
конфиге — переменные окружения, алиас или условное подключение существующего файла.
Отсутствие этих программ не мешает shell запускаться. Для `ya` можно задать
`YANDEX_YA` (абсолютный путь): это избегает коллизии с CLI `ya` из Yazi.
Старый вручную установленный `/usr/local/bin/ya` сохраняет приоритет, если это
не бинарник Yazi из Homebrew; в остальных случаях используется PATH.

`p10k.zsh` содержит штатные индикаторы множества окружений (asdf, pyenv, AWS,
Azure, gcloud, Ruby, Nix, taskwarrior и других). Они показываются при наличии
соответствующей среды и **не требуют устанавливать все эти приложения**.
Файл проверен целиком: он настраивает prompt, пользовательские функции работают
с данными Git/P10k, внешних обязательных команд помимо Git/P10k нет.

## Секреты

Предпочтительный отдельный файл: `${XDG_CONFIG_HOME:-~/.config}/zsh/secrets.zsh`.
Он не управляется Stow и переносится на новый компьютер отдельно.

Подключается первый существующий файл:

1. `${XDG_CONFIG_HOME:-~/.config}/zsh/secrets.zsh`;
2. `${ZDOTDIR:-~}/.zsh.secrets`;
3. `configs/.zsh.secrets` рядом с исходным `configs/.zshrc` в репозитории.

Существующий файл сохранён в последнем расположении с режимом 600.
Он исключён из Git и Stow; его содержимое не анализировалось.

## Исправления при миграции

Порядок загрузки: completion paths → compinit → OMZ → fzf-tab →
autosuggestions/history → syntax highlighting в самом конце. NVM загружается
один раз. JAVA_HOME на macOS указывает на JDK Home внутри bundle. PATH не
накапливает дубликаты; mktemp работает и на macOS, и на Arch.

Источники: [fzf-tab](https://github.com/Aloxaf/fzf-tab),
[Powerlevel10k](https://github.com/romkatv/powerlevel10k),
[nvm](https://github.com/nvm-sh/nvm), [goenv](https://github.com/go-nv/goenv),
[Terraform](https://developer.hashicorp.com/terraform/install),
[Arch postgresql-libs](https://archlinux.org/packages/extra/x86_64/postgresql-libs/files/).

## Проверка

Конфиг проверен не только синтаксически: все семь публичных репозиториев
плагинов скачаны в изолированный временный HOME, установлен gitstatus для P10k.
Интерактивный zsh под PTY успешно загрузил настоящие OMZ/P10k/внешние плагины,
completion, widgets и первый prompt. Проверены функции, alias и precmd hooks;
ошибок не было. Docker/kubectl в этом тесте заменены безопасными заглушками,
чтобы проверить ветки OMZ без daemon/кластера. Пользовательские секреты не
подключались. Зависимости теперь перенесены в единый Ansible playbook
`dependencies.yaml`; прежние отдельные shell-установщики удалены.

На свежем Arch выбери zsh как login shell через `chsh -s /usr/bin/zsh`
(смена login shell автоматически не выполняется).

---

# Аудит desktop-конфигов и зависимостей

Проверены все исходные файлы пакетов `aerospace`, `aerospace-swipe`, `btop`,
`hammerspoon`, `opencode`, `sketchybar`, включая скрытые служебные файлы,
backup и сгенерированное состояние. Ниже пути внутри конфига каждого пакета;
Stow размещает их в `~/.config/<package>/`.

## Что устанавливается

| Пакет | macOS | Arch Linux | Дополнительное действие |
|---|---|---|---|
| `aerospace` | AeroSpace, iTerm2; пакет `sketchybar` по зависимости | Пропускается | `make start-aerospace`, разрешить Accessibility |
| `aerospace-swipe` | AeroSpace; сборка upstream-приложения `AerospaceSwipe.app`, создание LaunchAgent | Пропускается | `make start-aerospace-swipe`, разрешить Accessibility; отключить конфликтующие жесты macOS |
| `btop` | `btop` | `btop` | Нет; тема поставляется вместе с btop |
| `hammerspoon` | Hammerspoon, Zen Browser | Пропускается | `make start-hammerspoon`, разрешить Accessibility |
| `opencode` | `opencode` | `opencode`, `wl-clipboard`, `xclip` | Предоставить `ELIZA_TOKEN` и доступ к настроенным внутренним провайдерам |
| `sketchybar` | SketchyBar, JankyBorders, AeroSpace, Hack Nerd Font; локальная сборка helper | Пропускается | `make start-sketchybar`; включить «Displays have separate Spaces» |

На macOS предполагается установленный Homebrew. Для нативных сборок нужны
Xcode Command Line Tools: bootstrap проверяет доступность `clang` и SDK.
Системный Bash 3.2 достаточен для shell-кода этих пакетов. Ни Python,
ни отдельный Lua/LuaRocks, ни Rust не требуются этим шести конфигам.

Установка не запускает UI-приложения или сервисы. `make start-*` делает это
явно. Уже включённый в AeroSpace `start-at-login = true` сохраняется;
JankyBorders запускается из его `after-startup-command`, поэтому отдельный
сервис borders не нужен. Устанавливаемые шрифты нужно отдельно выбрать в
настройках терминала; SketchyBar выбирает Hack Nerd Font своим конфигом.

## Покрытие каждого файла

### AeroSpace

- `aerospace.toml`: активный конфиг. Использует CLI `sketchybar`, `borders`,
  `aerospace`, системные `/bin/bash` и `osascript`; хоткей открытия терминала
  явно обращается к iTerm, поэтому устанавливается cask `iterm2`.
  PATH задаёт оба стандартных Homebrew-префикса для Intel и Apple Silicon.
- `.claude/settings.local.json`: локальная история разрешений редактора;
  для работы AeroSpace не нужна, в подключаемый конфиг не входит.

Удалён активный callback Übersicht/simple-bar: самого виджета в репозитории
нет, а актуальная строка состояния — SketchyBar. Иначе чистый Mac получал бы
вызов отсутствующего приложения при каждой смене фокуса.

### AeroSpace Swipe

- `config.json`: активный конфиг жестов, включая haptic и пороги скорости и
  расстояния. Читается upstream из `~/.config/aerospace-swipe/config.json`.

Официального Homebrew-рецепта upstream не предоставляет. Bootstrap клонирует
`acsandmann/aerospace-swipe` в пользовательский data-каталог и запускает
`make bundle`: C/Objective-C код, vendored yyjson, системные macOS frameworks
и ad-hoc codesign. Homebrew-пакеты yyjson или Swift для этой сборки не нужны.
Готовое приложение остаётся в checkout, LaunchAgent указывает на
`AerospaceSwipe.app/Contents/MacOS/AerospaceSwipe` именно в этом каталоге.
Каталог нельзя удалять после установки.

Upstream `make install` сразу загружает сервис, поэтому bootstrap его не
использует. Plist создаётся системным `plutil`, чтобы корректно обработать
пути с пробелами и XML-символами. `make start-aerospace-swipe` регистрирует
LaunchAgent в GUI-сессии пользователя; `RunAtLoad`/`KeepAlive` обеспечивают
последующий автоматический запуск. Обновление checkout намеренно не делается
повторной установкой: существующий клон и локальные изменения сохраняются.

### btop

- `btop.conf`: единственный активный файл. Внешние команды или плагины не
  вызываются. `gruvbox_material_dark` выбирается по имени вместо жёсткого пути
  в конкретную Homebrew Cellar-версию; тема входит в btop на обеих ОС.
- `themes/`: исходная пустая директория; пользовательских тем не было.

Температуры, GPU и CPU power зависят от оборудования и доступов конкретной
ОС. Наличие соответствующих опций не требует автоматически устанавливать
драйверы, менять права бинарника или запускать монитор от root.

### Hammerspoon

- `init.lua`: загружает два локальных модуля и удерживает их в глобальных
  переменных, чтобы watcher/eventtap не собирались GC.
- `zen_keys.lua`: использует встроенные `hs.application`, `hs.hotkey`,
  `hs.eventtap`, `hs.timer`; горячие клавиши активны только для Zen Browser.
  Zen нужен этому модулю, но отсутствие открытого Zen не мешает скроллу.
- `key_scroll.lua`: использует встроенные `hs.eventtap`, `hs.window`,
  `hs.screen`, `hs.timer`; внешние Spoons и Lua-модули не нужны.

Hammerspoon по умолчанию ищет `~/.hammerspoon/init.lua`, тогда как исходный
манифест подключал `~/.config/hammerspoon`. Bootstrap сохраняет этот путь и
задаёт `org.hammerspoon.Hammerspoon MJConfigFile` на установленный `init.lua`.

### OpenCode

- `opencode.jsonc`: активный конфиг четырёх внутренних провайдеров. Для
  провайдеров используется `@ai-sdk/openai-compatible`; OpenCode загружает
  provider SDK самостоятельно. Настроенных сторонних `plugin` и локальной
  директории плагинов в исходниках нет.
- `tui.json`: активный выбор темы `gruvbox-material`.
- `themes/gruvbox-material.json`: активная локальная тема; внешних зависимостей
  нет.
- `opencode.jsonc.tui-migration.bak`: неактивный backup до переноса темы в
  `tui.json`; сохраняется как исходный архив, не подключается Stow.
- `package.json`, `package-lock.json`: сгенерированное OpenCode npm-состояние
  с `@opencode-ai/plugin` и транзитивными зависимостями. Не объявляет
  подключённый пользовательский плагин, отдельно через npm не устанавливается
  и не переносится между устройствами.
- `.gitignore`: исходные правила для сгенерированных package-файлов,
  `node_modules`, `bun.lock`; не является runtime-конфигом приложения.

Установка не читает и не записывает токены. `ELIZA_TOKEN`, корпоративная сеть,
права на модели и доступность внутренних endpoint обеспечиваются отдельно.
Живые запросы к моделям при проверке не выполнялись. На Arch устанавливаются
оба clipboard backend, чтобы конфиг работал в Wayland и X11; выбор делает
окружение OpenCode.

### SketchyBar

- `sketchybarrc`: активная точка входа; системный Bash, CLI SketchyBar и
  AeroSpace, Hack Nerd Font, `pkill`; запускает собственный helper при
  старте/reload уже запущенного бара.
- `plugins/aerospace.sh`: активный обработчик workspace/hover/click событий;
  Bash, SketchyBar/AeroSpace, системные `awk`, `tr`, `cat`, `printf` и helper
  `--mouse`. Оба shell-файла имеют executable bit.
- `helper/provider.c`: метрики CPU/RAM/батареи/часов/даты и одноразовые
  `--lang`/`--mouse`; системные CoreFoundation, CoreGraphics, IOKit, Carbon,
  Mach. Внешних библиотек и периодических вызовов `top`/`date` нет.
- `helper/mach.c`, `helper/mach.h`: локальный Mach IPC-код; дополнительных
  загрузок при сборке нет.
- `helper/Makefile`: собирает helper системными `make` и `clang`.
- `helper/sketchybar_metrics`: исходный сгенерированный arm64 Mach-O, который
  нельзя переносить на Intel Mac. Исключён из Git и пересобирается локально
  с `make -B` при установке пакета.
- `.gitignore`: исключает бинарник helper и объектные файлы.
- `README.md`, `CONTRIBUTING.md`: документация; не зависимости runtime.
- `.claude/settings.local.json`: локальная история разрешений со старыми
  абсолютными путями; не зависимость и не переносимый конфиг.

## Проверка

- Все новые install/activation hooks и активные SketchyBar shell-скрипты
  прошли `bash -n` системным Bash 3.2.
- Нативный helper успешно собран `clang` в `/private/tmp` с теми же C99
  параметрами и frameworks. Бинарник не запускался и сервисы не трогались.
- JSON/JSONC файлы и backup разобраны парсером; в текущих JSONC комментариев
  нет, поэтому для этой проверки достаточно JSON-парсера.
- Hooks выполнены с подменёнными package/build/activation функциями: проверены
  macOS/Arch ветки и сохранение аргументов с пробелами. Plist проверен нативным
  `plutil`, включая путь с пробелами и `&`, повторное создание проходит.
- Полная установка Homebrew/pacman, живой запуск macOS desktop и сборка
  aerospace-swipe не выполнялись: текущий компьютер не переустанавливался.

## Источники

- [AeroSpace: установка, поиск конфига, PATH GUI-приложения](https://nikitabobko.github.io/AeroSpace/guide).
- [SketchyBar: установка, шрифты, требование Displays have separate Spaces](https://felixkratz.github.io/SketchyBar/setup).
- [JankyBorders: установка и запуск из AeroSpace](https://github.com/FelixKratz/JankyBorders).
- [AeroSpace Swipe: upstream README](https://github.com/acsandmann/aerospace-swipe),
  [makefile и реальные targets сборки/сервиса](https://github.com/acsandmann/aerospace-swipe/blob/main/makefile),
  [параметры конфига](https://github.com/acsandmann/aerospace-swipe/blob/main/config.md).
- [btop: поставляемые темы и поиск путей](https://github.com/aristocratos/btop),
  [gruvbox_material_dark](https://github.com/aristocratos/btop/blob/main/themes/gruvbox_material_dark.theme).
- [Hammerspoon: стандартный каталог](https://www.hammerspoon.org/docs/hs),
  [реализация MJConfigFile](https://github.com/Hammerspoon/hammerspoon/blob/master/Hammerspoon/MJConfigUtils.m),
  [cask Hammerspoon](https://formulae.brew.sh/cask/hammerspoon),
  [cask Zen](https://formulae.brew.sh/cask/zen).
- [OpenCode: Homebrew formula](https://formulae.brew.sh/formula/opencode),
  [Arch Extra package и clipboard backends](https://archlinux.org/packages/extra/x86_64/opencode/).
