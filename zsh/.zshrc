# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
IS_CURSOR_TERMINAL=$([[ $PAGER == 'sh -c "head -n 10000 | cat"' ]] && echo 1 || echo 0)
if [ $IS_CURSOR_TERMINAL -eq 0 ]; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# === Locale ===
export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'

# === TERM (Linux needs this early, macOS sets it via terminal app) ===
if [[ "$(uname -s)" == "Linux" ]]; then
  export TERM=xterm-256color
fi

# === PATH setup (early, so tools are available for rest of config) ===
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Cargo (Linux installs tldr, dua via cargo)
if [[ -d "$HOME/.cargo/bin" ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# === Linux-specific setup (must be before bat/fzf config below) ===
if [[ "$(uname -s)" == "Linux" ]]; then
  # fd-find is named 'fdfind' on Debian/Ubuntu
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    alias fd="fdfind"
  fi
  # bat is named 'batcat' on Debian/Ubuntu - set variable for use below
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    _bat_cmd="batcat"
  fi
fi
: ${_bat_cmd:=bat}

# === Oh My Zsh ===
export ZSH="$HOME/.oh-my-zsh"

if [ $IS_CURSOR_TERMINAL -eq 0 ]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME="robbyrussell"
fi

# Plugins
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

# Docker plugin only on Linux, outside containers, with docker installed
is_inside_container() {
  [[ -f /.dockerenv ]] || [[ -n "${container:-}" ]] || grep -qsE '(docker|kubepod)' /proc/1/cgroup 2>/dev/null
}
if [[ "$(uname -s)" == "Linux" ]] && ! is_inside_container && command -v docker &>/dev/null; then
  plugins+=(docker)
fi

autoload -Uz compinit && compinit
source $ZSH/oh-my-zsh.sh

# === Editor ===
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# === Common Aliases ===
alias vim="nvim"
alias ls="eza -la --icons --group-directories-first"

# bat theming (base config; macOS overrides with --theme auto:system)
alias bat="$_bat_cmd --color=always"
fbat="$_bat_cmd --color=always"
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | $_bat_cmd -p -lman'"

# fzf with bat preview
alias fzf='fzf --preview-window=right:60%:wrap --preview "${fbat} --style=numbers {} 2>/dev/null || printf %s "{}" | ${fbat} --wrap=auto -l zsh -p"'

# lazydocker (only outside containers)
if ! is_inside_container && command -v lazydocker &>/dev/null; then
  alias lzd='lazydocker'
fi

# zmv (batch rename)
autoload zmv
alias zcp='zmv -C'
alias zln='zmv -L'

# bun
if [[ -d "$HOME/.bun" ]]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# uv environment (if installed via install script)
if [[ -f "$HOME/.local/bin/env" ]]; then
  . "$HOME/.local/bin/env"
fi

# uv shell completion
if command -v uv &>/dev/null; then
  eval "$(uv generate-shell-completion zsh)"
fi

# thefuck
if command -v thefuck &>/dev/null; then
  eval $(thefuck --alias)
fi

# zoxide (replaces cd)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# === Powerlevel10k config ===
if [ $IS_CURSOR_TERMINAL -eq 0 ]; then
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

# === Vi-mode keybindings ===
bindkey -v
bindkey -v '^?' backward-delete-char
bindkey '^K' kill-line
bindkey '^Y' yank
bindkey -M viins '^A' beginning-of-line
bindkey -M vicmd '^A' beginning-of-line
bindkey -M viins '^E' end-of-line
bindkey -M vicmd '^E' end-of-line
bindkey -M vicmd '^R' vi-redo
bindkey -M viins '^[f' forward-word
bindkey -M viins '^[b' backward-word

# === fzf keybindings (MUST be after vi-mode to preserve Tab binding) ===
if command -v fzf &>/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  elif [[ -f "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh"
    source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/completion.zsh"
  elif [[ -f "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
  fi
fi

# === OS-specific configuration ===
# Detect OS and source appropriate config
case "$(uname -s)" in
  Darwin)
    [[ -f ~/.zshrc.macos ]] && source ~/.zshrc.macos
    ;;
  Linux)
    [[ -f ~/.zshrc.linux ]] && source ~/.zshrc.linux
    ;;
esac
