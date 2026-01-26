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

# fzf from git (prefer over system fzf for latest features)
if [[ -d "$HOME/.fzf/bin" ]]; then
  export PATH="$HOME/.fzf/bin:$PATH"
fi

# Cargo (Linux installs tldr, dua via cargo)
if [[ -d "$HOME/.cargo/bin" ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

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
export EDITOR='nvim'

# === Common Aliases ===
alias vim="nvim"
alias ls="eza -la --icons --group-directories-first"

# bat theming (ansi theme uses terminal colors, also used by git-delta)
export BAT_THEME="ansi"
alias bat="bat --color=always"
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"

# fzf with bat preview
alias fzf='fzf --preview-window=right:60%:wrap --preview "bat --color=always --style=numbers {} 2>/dev/null || printf %s "{}" | bat --color=always --wrap=auto -l zsh -p"'

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
