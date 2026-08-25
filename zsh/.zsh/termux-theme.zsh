_TERMUX_THEME_DIR="${${(%):-%N}:A:h}/termux-themes"

_termux_theme_usage() {
  print -u2 'Usage: termux-theme [light|dark]'
  return 2
}

_termux_theme_file() {
  print -r -- "$_TERMUX_THEME_DIR/$1.properties"
}

_termux_theme_emit_osc() {
  printf '\033]%s\033\\' "$1"
}

_termux_theme_passthrough_osc() {
  printf '\033Ptmux;\033\033]%s\a\033\\' "$1"
}

_termux_theme_detect() {
  local tty_fd saved_tty response
  local red green blue
  local read_status=1

  exec {tty_fd}<>/dev/tty || return 1
  saved_tty="$(stty -g <&$tty_fd)" || {
    exec {tty_fd}>&-
    return 1
  }

  {
    stty raw -echo <&$tty_fd || return 1
    printf '\033]11;?\a' >&$tty_fd
    IFS= read -r -t 1 -d $'\a' response <&$tty_fd
    read_status=$?
  } always {
    stty "$saved_tty" <&$tty_fd
    exec {tty_fd}>&-
  }

  (( read_status == 0 )) || return 1
  [[ "$response" =~ $'\033]11;rgb:([[:xdigit:]]{4})/([[:xdigit:]]{4})/([[:xdigit:]]{4})$' ]] || return 1

  red=$(( 16#${match[1]} ))
  green=$(( 16#${match[2]} ))
  blue=$(( 16#${match[3]} ))
  if (( 299 * red + 587 * green + 114 * blue >= 32768000 )); then
    print light
  else
    print dark
  fi
}

_termux_theme_detect_or_explain() {
  local theme
  theme="$(_termux_theme_detect)" || {
    print -u2 'Could not query the active terminal background; use termux-theme light|dark.'
    return 1
  }
  print -r -- "$theme"
}

_termux_theme_emit() {
  local theme_file="$1"
  local key value index palette_payload='4'
  local -A colors

  [[ -r "$theme_file" ]] || {
    print -u2 "Theme file not found: $theme_file"
    return 1
  }

  while IFS='=' read -r key value; do
    case "$key" in
      foreground|background|cursor|color*) colors[$key]="$value" ;;
    esac
  done <"$theme_file"

  for key in foreground background cursor; do
    [[ -n ${colors[$key]:-} ]] || {
      print -u2 "Missing $key in $theme_file"
      return 1
    }
  done

  for (( index = 0; index <= 21; index++ )); do
    key="color$index"
    value="${colors[$key]:-}"
    [[ -n "$value" ]] || {
      print -u2 "Missing $key in $theme_file"
      return 1
    }
    palette_payload+=";$index;$value"
  done

  # The terminal-clipboard tmux proxy consumes palette OSCs. Send a complete
  # copy through it first so Termux updates the outer session and its decor;
  # the bare copy below remains authoritative for tmux's palette state.
  case "${TERM:-}" in
    screen*|tmux*)
      _termux_theme_passthrough_osc "$palette_payload"
      _termux_theme_passthrough_osc "10;${colors[foreground]}"
      _termux_theme_passthrough_osc "11;${colors[background]}"
      _termux_theme_passthrough_osc "12;${colors[cursor]}"
      ;;
  esac

  _termux_theme_emit_osc "$palette_payload"
  _termux_theme_emit_osc "10;${colors[foreground]}"
  _termux_theme_emit_osc "11;${colors[background]}"
  _termux_theme_emit_osc "12;${colors[cursor]}"
}

_termux_theme_set_local() {
  local theme="$1"
  local theme_file="$(_termux_theme_file "$theme")"
  local termux_dir="$HOME/.termux"

  [[ -d "$termux_dir" ]] || {
    print -u2 "Termux directory not found: $termux_dir"
    return 1
  }
  [[ -r "$theme_file" ]] || {
    print -u2 "Theme file not found: $theme_file"
    return 1
  }

  cp "$theme_file" "$termux_dir/colors.properties"
  print -r -- "$theme" >"$termux_dir/.current-theme"
  command -v termux-reload-settings &>/dev/null && command termux-reload-settings
  print "Theme set to: $theme"
}

function termux-theme {
  local requested_theme
  local is_termux=false
  [[ -n ${TERMUX_VERSION:-} || ${PREFIX:-} == *com.termux* ]] && is_termux=true

  case "$#" in
    0)
      case "$(_termux_theme_detect_or_explain)" in
        light) requested_theme=dark ;;
        dark) requested_theme=light ;;
        *) return 1 ;;
      esac
      ;;
    1)
      case "$1" in
        light|dark) requested_theme="$1" ;;
        *) _termux_theme_usage; return ;;
      esac
      ;;
    *)
      _termux_theme_usage
      return
      ;;
  esac

  if $is_termux; then
    _termux_theme_set_local "$requested_theme"
  else
    _termux_theme_emit "$(_termux_theme_file "$requested_theme")"
  fi
}
