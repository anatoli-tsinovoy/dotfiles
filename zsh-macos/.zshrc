# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
IS_CURSOR_TERMINAL=$([[ $PAGER == 'sh -c "head -n 10000 | cat"' ]] && echo 1 || echo 0)
# IS_CURSOR_TERMINAL=$([[ $PAGER == "head -n 10000 | cat" ]] && echo 1 || echo 0)
# IS_CURSOR_TERMINAL=$([[ -n $CURSOR_TRACE_ID ]] && echo 1 || echo 0)
if [ $IS_CURSOR_TERMINAL -eq 0 ]; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/$USER/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
if [ $IS_CURSOR_TERMINAL -eq 0 ]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME="robbyrussell" # Use a simpler theme in Cursor
fi

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

HOMEBREW_AUTO_UPDATE_SECS=86400  # one day

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  podman
  docker
)
autoload -Uz compinit && compinit

source $ZSH/oh-my-zsh.sh
# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8


# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi


# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
alias python="/opt/homebrew/bin/python3"
# alias pip="/opt/homebrew/bin/pip3"

autoload zmv
alias zcp='zmv -C'
alias zln='zmv -L'
alias vlc='/Applications/VLC.app/Contents/MacOS/VLC'
export DOCKER_HOST=unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')
alias code='cursor'
alias ls='eza -la --icons --group-directories-first'
alias vim='nvim'
alias bat="bat --color=always --theme auto:system --theme-dark default --theme-light GitHub"
fbat="bat --color=always --theme auto:system --theme-dark default --theme-light GitHub"
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"

alias fzf='fzf --preview-window=right:60%:wrap --preview "${fbat} --style=numbers {} 2>/dev/null || printf %s "{}" | ${fbat} --wrap=auto -l zsh -p"'
# alias fzf='fzf --preview "bat --color=always --style=numbers --theme auto:system --theme-dark default --theme-light GitHub {}"'
alias lzd='lazydocker'


export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion


export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$PATH"
export PATH="/usr/local/bin/convert:$PATH"

eval $(thefuck --alias)

# add binaries to PATH if they aren't added yet
# affix colons on either side of $PATH to simplify matching
case ":${PATH}:" in
    *:"$HOME/.local/bin":*)
        ;;
    *)
        # Prepending path in case a system-installed binary needs to be overridden
        export PATH="$HOME/.local/bin:$PATH"
        ;;
esac

eval "$(uv generate-shell-completion zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [ $IS_CURSOR_TERMINAL -eq 0 ]; then
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

bindkey -v
bindkey -v '^?' backward-delete-char
bindkey '^K' kill-line
bindkey '^Y' yank
bindkey -M viins '^A' beginning-of-line
bindkey -M vicmd '^A' beginning-of-line
bindkey -M viins '^E' end-of-line
bindkey -M vicmd '^E' end-of-line

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Quick Action runner function
quickaction() {
  if [ $# -ne 2 ]; then
    echo "Usage: quickaction \"Service Name\" file"
    echo "Available services:"
    ls -1 ~/Library/Services/ | sed 's/\.workflow$//'
    return 1
  fi

  local service_name="$1"
  local input_file="$2"

  if [ ! -d ~/Library/Services/"$service_name.workflow" ]; then
    echo "Service '$service_name' not found"
    echo "Available services:"
    ls -1 ~/Library/Services/ | sed 's/\.workflow$//'
    return 1
  fi
  local absolute_path
  
  # Convert relative path to absolute path
  if [[ "$input_file" = /* ]]; then
    # Already absolute path
    absolute_path="$input_file"
  else
    # Convert relative path to absolute path
    absolute_path="$(cd "$(dirname "$input_file")" && pwd)/$(basename "$input_file")"
  fi
  
  automator -i "$absolute_path" ~/Library/Services/"$service_name.workflow"
}

git-lfs-dl() {
  for input_file in "$@"; do
    quickaction "Download from Git LFS" "$input_file"
  done
}

eval "$(zoxide init zsh --cmd cd)"

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
