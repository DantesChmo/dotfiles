# SketchyBar config

Конфиг строки состояния [SketchyBar](https://github.com/FelixKratz/SketchyBar)
для macOS с интеграцией тайлингового менеджера
[AeroSpace](https://github.com/nikitabobko/AeroSpace).

**Что показывает:**

- воркспейсы AeroSpace с индикатором раскладки (h_tiles / v_tiles / accordion)
  и маркером fullscreen на активном;
- индикатор режима resize;
- часы, дату, CPU, RAM, батарею;
- текущий язык ввода (EN/RU/…), обновляется мгновенно при смене раскладки.

Все метрики обновляет **один нативный процесс** через mach-порт, без форков и
без запуска `top`/`date` каждую секунду. Язык ввода — событийно: сам бар ловит
системное уведомление о смене раскладки. Подробности в
[CONTRIBUTING.md](CONTRIBUTING.md).

## Требования

| Зависимость | Зачем |
|---|---|
| `sketchybar` | сама строка состояния |
| `aerospace` | тайлинг + события воркспейсов |
| `borders` | подсветка рамки активного окна |
| Hack Nerd Font | иконки в баре |
| Xcode Command Line Tools | `clang` + `make` для сборки провайдера метрик |

> Провайдер метрик — небольшая C-программа, которую нужно **собрать локально**
> (`make`). Поэтому «просто `brew install sketchybar` + `brew services start`»
> уже недостаточно — см. шаг 3.

## Установка

Команды выполняются из корня репозитория dotfiles:

```sh
make install-sketchybar
make install-aerospace
make start-sketchybar
make start-aerospace
```

Установка подтягивает SketchyBar, AeroSpace, JankyBorders, Hack Nerd Font,
собирает провайдер метрик локальным `clang` и подключает конфиги через Stow.
На Arch Linux этот пакет автоматически пропускается: используются macOS API.

Для сборки нужны Xcode Command Line Tools (Homebrew обычно уже устанавливает
их). Установка проверяет компилятор и подсказывает дальнейшее действие, если
его нет. Бинарник пересобирается на текущем Mac, поэтому архитектура старого
устройства не переносится.

Установка и запуск разделены: `start-sketchybar` включает login-сервис,
`start-aerospace` открывает приложение. AeroSpace запускает `borders` со своими
параметрами — отдельный сервис borders для этого конфига не нужен.
В macOS должны быть включены «Displays have separate Spaces»; Accessibility
для AeroSpace разрешается в системном диалоге при первом запуске.

### Интеграция AeroSpace ↔ SketchyBar

Индикаторы воркспейсов и режимов обновляются по событиям от AeroSpace, поэтому
в `~/.config/aerospace/aerospace.toml` должны быть настроены:

- **событие смены воркспейса** — иначе бар не узнает о переключении:

  ```toml
  exec-on-workspace-change = [
    '/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
  ]
  ```

- **триггеры смены раскладки/режима** — чтобы иконка раскладки, fullscreen и
  плашка `RESIZE` обновлялись мгновенно. К биндингам layout/fullscreen добавлен
  `sketchybar --trigger …`, а вход/выход resize шлёт
  `sketchybar --set aerospace_mode drawing=on/off`.

> `aerospace.toml` поставляется соседним Stow-пакетом `aerospace`.

## Применение изменений

```sh
make install-sketchybar        # повторно собрать helper и применить ссылки
make start-sketchybar          # включить сервис, если он ещё не запущен
```

## Разработка

Устройство провайдера, добавление новых метрик и работа с Nerd Font иконками —
в [CONTRIBUTING.md](CONTRIBUTING.md).
