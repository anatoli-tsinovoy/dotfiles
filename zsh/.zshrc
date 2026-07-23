
IS_OMP_COMMAND_SHELL=${OMPCODE:+1}
# === Locale ===
export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'

# === TERM (Linux needs this early, macOS sets it via terminal app) ===
# Only set TERM as a last-resort fallback; never override inside tmux
if [[ "$OSTYPE" == linux* && -z "${TMUX-}" ]]; then
  export TERM=xterm-256color
  export COLORTERM=truecolor
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

# Termux-specific config (must be before compinit for completions)
is_termux() {
  [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == *"com.termux"* ]]
}
if is_termux && [[ -f ~/.zshrc.termux ]]; then
  source ~/.zshrc.termux
fi

# === Completion ===
typeset -U fpath
fpath=("${(@)fpath:#${HOME}/.oh-my-zsh(|/*)}")
ZSH_SITE_FUNCTIONS="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
[[ -d "$ZSH_SITE_FUNCTIONS" ]] && fpath=("$ZSH_SITE_FUNCTIONS" "${fpath[@]}")
[[ "$OSTYPE" == darwin* && -d /opt/homebrew/share/zsh/site-functions ]] && fpath=(/opt/homebrew/share/zsh/site-functions "${fpath[@]}")

autoload -Uz compinit && compinit

ZSH_PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
if [[ -z "$IS_OMP_COMMAND_SHELL" ]]; then
  [[ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
  command -v starship &>/dev/null && eval "$(starship init zsh)"
fi

# === Editor ===
export EDITOR='nvim'

# === Common Aliases ===
alias vim="nvim"
alias ls="eza -la --icons --group-directories-first"

# bat theming (ansi theme uses terminal colors, also used by git-delta)
export BAT_THEME="ansi"
# Force delta to use the stowed git config when it is called outside Git
# (for example: `gh pr diff --patch --color=never | delta`).
export GH_PAGER='delta --config "$HOME/.gitconfig"'
gh() {
  if [[ "$1" == "pr" && "$2" == "diff" ]]; then
    local arg has_color=0
    for arg in "${@:3}"; do
      [[ "$arg" == "--color" || "$arg" == --color=* ]] && has_color=1
    done

    if (( has_color )); then
      command gh "$@"
    else
      command gh pr diff --color=never "${@:3}"
    fi
  else
    command gh "$@"
  fi
}
alias bat="bat --color=always"
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"

# fzf with bat preview
alias fzf='fzf --preview-window=right:60%:wrap --preview "bat --color=always --style=numbers {} 2>/dev/null || printf %s "{}" | bat --color=always --wrap=auto -l zsh -p"'

is_inside_container() {
  [[ -f /.dockerenv || -n "${container:-}" ]] && return 0
  local cgroup
  [[ -r /proc/1/cgroup ]] || return 1
  while IFS= read -r cgroup; do
    [[ "$cgroup" == *docker* || "$cgroup" == *kubepods* ]] && return 0
  done < /proc/1/cgroup
  return 1
}

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

# === OpenCode ===
if command -v opencode &>/dev/null; then
  export OMO_SEND_ANONYMOUS_TELEMETRY=0
  export OMO_DISABLE_POSTHOG=1
  alias oc="opencode"
fi

# === oh-my-pi ===
export PLANNOTATOR_REMOTE=1
export PLANNOTATOR_PORT=9999

# uv environment (if installed via install script)
if [[ -f "$HOME/.local/bin/env" ]]; then
  . "$HOME/.local/bin/env"
fi


# glow with custom light/dark styles
if command -v glow &>/dev/null; then
  source ~/.zsh/detect-background.zsh
  glow() {
    local style_dir="${XDG_CONFIG_HOME:-$HOME/.config}/glow"
    local style="$style_dir/simply-dark.json"
    local pager=(-p)
    local arg
    [[ "$(_detect_background)" == "light" ]] && style="$style_dir/simply-light.json"
    for arg in "$@"; do
      [[ "$arg" == "-t" || "$arg" == "--tui" ]] && pager=()
    done
    command glow "${pager[@]}" -w "${GLOW_WIDTH:-0}" -s "$style" "$@"
  }
fi

# thefuck
if command -v thefuck &>/dev/null; then
  fuck() {
    unfunction fuck
    eval "$(thefuck --alias)"
    fuck "$@"
  }
fi

# zoxide (replaces cd)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi


# === AWS SSO Login with Profile ===
awslogin() {
  local -a login_args=(--profile "$1")
  [[ "$OSTYPE" == linux* ]] && ! is_termux && login_args+=(--no-browser)
  aws sso login "${login_args[@]}"
  export AWS_PROFILE="$1"
}

# === Vi-mode keybindings ===
if [[ -z "$IS_OMP_COMMAND_SHELL" && -o zle ]]; then
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

  # === Fancy ^Z ===
  # Source - https://superuser.com/a/378045
  # Posted by Gilles 'SO- stop being evil', modified by community. See post 'Timeline' for change history
  # Retrieved 2026-02-25, License - CC BY-SA 3.0
  #
  # Bind only in ZLE's vi insert/command maps. Foreground raw-mode TUIs (OMP,
  # opencode, nvim) own their first Ctrl+Z; once zsh has the prompt again, this
  # widget can background the stopped job with a second Ctrl+Z.
  fancy-ctrl-z () {
    if [[ $#BUFFER -eq 0 ]]; then
      bg
      zle redisplay
    else
      zle push-input
    fi
  }
  zle -N fancy-ctrl-z
  bindkey -M viins '^Z' fancy-ctrl-z
  bindkey -M vicmd '^Z' fancy-ctrl-z
fi

# === OS-specific configuration ===
# Detect OS and source appropriate config
case "$OSTYPE" in
  darwin*)
    [[ -f ~/.zshrc.macos ]] && source ~/.zshrc.macos
    ;;
  linux*)
    [[ -f ~/.zshrc.linux ]] && source ~/.zshrc.linux
    ;;
esac

# Must be sourced after every other ZLE setup.
if [[ -z "$IS_OMP_COMMAND_SHELL" && -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
