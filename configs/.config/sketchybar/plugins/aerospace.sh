#!/usr/bin/env bash

# Shell запускается только для кликов и одного общего обновления по событию.
# Hover отключён: у зон нет подписок на события мыши.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

focused_ws() { aerospace list-workspaces --focused 2>/dev/null; }

if [[ "${2:-}" == click:* ]]; then
  SID="$1"
  ZONE="${2#click:}"
  FOCUSED=$(focused_ws)
  [[ -n "$FOCUSED" ]] || exit 0
  if [[ "$SID" != "$FOCUSED" ]]; then
    aerospace workspace "$SID"
    exit
  fi
  case "$ZONE" in
    fs) aerospace fullscreen off 2>/dev/null ;;
    mode)
      CUR=$(aerospace list-workspaces --focused --format '%{workspace-root-container-layout}' 2>/dev/null)
      case "$CUR" in
        h_tiles)     aerospace layout v_tiles ;;
        v_tiles)     aerospace layout h_accordion ;;
        *)           aerospace layout h_tiles ;;
      esac
      ;;
    *) exit 0 ;;
  esac
  sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$FOCUSED"
  exit
fi

[[ "$1" == render ]] || exit 0
# display_change/system_woke не несут FOCUSED_WORKSPACE. При --update на старте
# фокус тоже нужно получить явно, иначе все кнопки останутся неактивными.
FOCUSED="${FOCUSED_WORKSPACE:-$(focused_ws)}"
[[ -n "$FOCUSED" ]] || exit 0
LAYOUT=$(aerospace list-workspaces --focused --format '%{workspace-root-container-layout}' 2>/dev/null)
FULLSCREEN=$(aerospace list-windows --focused --format '%{window-is-fullscreen}' 2>/dev/null)

case "$LAYOUT" in
  *accordion*) printf -v LAYOUT_ICON '\xef\x89\x8d' ;;
  v_tiles)     printf -v LAYOUT_ICON '\xef\x83\x89' ;;
  h_tiles)     printf -v LAYOUT_ICON '\xef\x83\x9b' ;;
  *)           LAYOUT_ICON="$LAYOUT" ;;
esac
FS_ICON=""
[[ "$FULLSCREEN" == true ]] && printf -v FS_ICON '\xef\x81\xa5'

# Одним IPC обновляем фон и labels всех кнопок, без анимаций.
sketchybar \
  --set '/ws\..*/' background.color=0x22ffffff \
  --set "ws.$FOCUSED" background.color=0xffffffff \
  --set '/space\..*/' label.color=0x99ffffff \
  --set '/space\..*\.mode/' label="" \
  --set '/space\..*\.fs/' label="" \
  --set "space.$FOCUSED" label.color=0xff000000 \
  --set "space.$FOCUSED.mode" label="$LAYOUT_ICON" label.color=0xff000000 \
  --set "space.$FOCUSED.fs" label="$FS_ICON" label.color=0xff000000
