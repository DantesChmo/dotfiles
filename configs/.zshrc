# Powerlevel10k instant prompt must precede interactive initialization.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Plugins are installed by `make deps-zsh`; shell startup never clones them.
typeset -g ZSH_CONFIG_DIR="${${(%):-%x}:A:h}"
typeset -g DOTFILES_ZSH_PLUGINS="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/zsh"
export ZSH="$DOTFILES_ZSH_PLUGINS/ohmyzsh"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zsh"
mkdir -p "$ZSH_CACHE_DIR/completions"
typeset -U path fpath
path=("$HOME/.local/bin" $path /usr/local/bin)
export VIRTUAL_ENV_DISABLE_PROMPT=1

case "$OSTYPE" in
  darwin*) OS_TYPE=macos ;;
  linux*)  OS_TYPE=linux ;;
  *)       OS_TYPE=unknown ;;
esac

for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$_brew" ]]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew
path=("$HOME/.local/bin" $path)

(( $+commands[vivid] )) && export LS_COLORS="$(vivid generate gruvbox-dark)"
export GOPATH="${GOPATH:-$HOME/go}"
export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"
path=("$GOENV_ROOT/bin" "$GOPATH/bin" $path)
(( $+commands[goenv] )) && eval "$(goenv init -)"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -n ${HOMEBREW_PREFIX:-} && -d "$HOMEBREW_PREFIX/opt/openjdk@17" ]]; then
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
elif [[ -d /usr/lib/jvm/java-17-openjdk ]]; then
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
fi
[[ -z ${JAVA_HOME:-} ]] || path=("$JAVA_HOME/bin" $path)

# Optional Android SDK: exported when installed separately via Android Studio/sdkmanager.
if [[ "$OS_TYPE" == macos ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
else
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
fi
export ANDROID_SDK_ROOT="$ANDROID_HOME"
[[ ! -d "$ANDROID_HOME" ]] || path+=("$ANDROID_HOME/emulator" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin")
[[ -z ${HOMEBREW_PREFIX:-} || ! -d "$HOMEBREW_PREFIX/opt/libpq/bin" ]] || path=("$HOMEBREW_PREFIX/opt/libpq/bin" $path)

# Declare completion directories before compinit; widgets are loaded afterwards.
fpath=("$ZSH_CACHE_DIR/completions" $fpath)
for _plugin in git docker docker-compose kubectl python pip nvm golang terraform; do
  [[ ! -d "$ZSH/plugins/$_plugin" ]] || fpath+=("$ZSH/plugins/$_plugin")
done
autoload -Uz compinit add-zsh-hook is-at-least
compinit -d "$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"

# Use selected Oh My Zsh libraries/snippets, without its updater or full framework.
# P10k owns the prompt; the OMZ git library only supplies alias helper functions.
zstyle ':omz:alpha:lib:git' async-prompt no
for _library in functions git clipboard; do
  [[ ! -r "$ZSH/lib/$_library.zsh" ]] || source "$ZSH/lib/$_library.zsh"
done
for _plugin in git docker docker-compose kubectl python pip nvm golang terraform; do
  [[ ! -r "$ZSH/plugins/$_plugin/$_plugin.plugin.zsh" ]] || source "$ZSH/plugins/$_plugin/$_plugin.plugin.zsh"
done
# Compatibility with pre-existing Homebrew/Arch nvm installations.
if ! (( $+functions[nvm] )); then
  if [[ -n ${HOMEBREW_PREFIX:-} && -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
    source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
  elif [[ -s /usr/share/nvm/init-nvm.sh ]]; then
    source /usr/share/nvm/init-nvm.sh
  fi
fi

for _plugin in zsh-async/async.zsh powerlevel10k/powerlevel10k.zsh-theme fzf-tab/fzf-tab.plugin.zsh zsh-autosuggestions/zsh-autosuggestions.zsh zsh-history-substring-search/zsh-history-substring-search.zsh; do
  [[ ! -r "$DOTFILES_ZSH_PLUGINS/$_plugin" ]] || source "$DOTFILES_ZSH_PLUGINS/$_plugin"
done
unset _plugin _library

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
setopt AUTO_CD CORRECT HIST_IGNORE_DUPS SHARE_HISTORY
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"

function y() {
  local tmp cwd result
  tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
  yazi "$@" --cwd-file="$tmp"
  result=$?
  if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
  return "$result"
}

alias vim=nvim
alias yy=y
alias nvimconfig='nvim ~/.config/nvim'
alias lst='eza --tree -la --sort=type'
alias lsg='eza --grid --all --icons --color=auto --sort=type'
alias ls=lsg
alias g=git
alias gst='git status'
alias glg='git log --oneline --graph --decorate'
alias сдфгву=claude
alias тмшь=nvim

[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
# Internal Arc prompt extension is optional and can retain its legacy location.
for _arc_prompt in "$HOME/.oh-my-zsh/themes/powerlevel10k-prompt-arc/arc.zsh" "$ZSH/themes/powerlevel10k-prompt-arc/arc.zsh"; do
  if [[ -r "$_arc_prompt" ]]; then
    source "$_arc_prompt"
    break
  fi
done
unset _arc_prompt
export EDITOR=nvim
export VISUAL=nvim
export OLLAMA_NUM_CTX=32768

# Keep machine-specific secrets outside the Stow tree. First existing file wins.
for _secrets in "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh" "${ZDOTDIR:-$HOME}/.zsh.secrets" "$ZSH_CONFIG_DIR/.zsh.secrets"; do
  if [[ -r "$_secrets" ]]; then
    source "$_secrets"
    break
  fi
done
unset _secrets

# Prefer an explicitly selected internal ya executable over Yazi's companion CLI.
if [[ -n ${YANDEX_YA:-} && -x "$YANDEX_YA" ]]; then
  alias ya="${(q)YANDEX_YA}"
elif [[ -x /usr/local/bin/ya && ${${:-/usr/local/bin/ya}:A} != */Cellar/yazi/* ]]; then
  alias ya=/usr/local/bin/ya
fi

# Syntax highlighting must be the last widget wrapper.
[[ ! -r "$DOTFILES_ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] || source "$DOTFILES_ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
# Ensure a missing optional plugin does not make shell startup return failure.
true
