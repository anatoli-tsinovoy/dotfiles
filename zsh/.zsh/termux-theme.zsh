_termux_theme_usage() {
  print -u2 'Usage: termux-theme light|dark'
  return 2
}

_termux_theme_emit_osc() {
  local payload="$1"
  if [[ -n ${TMUX:-} ]]; then
    printf '\033Ptmux;\033\033]%s\033\033\\\033\\' "$payload"
  else
    printf '\033]%s\033\\' "$payload"
  fi
}

function termux-theme {
  if [[ -n ${TERMUX_VERSION:-} || ${PREFIX:-} == *com.termux* ]]; then
    command termux-theme-toggle "$@"
    return
  fi

  (( $# == 1 )) || {
    _termux_theme_usage
    return
  }

  local foreground background cursor
  local -a palette
  case "$1" in
    dark)
      foreground='#F3F0DF'
      background='#110034'
      cursor='#8217FF'
      palette=(
        '#110034' '#FF4F44' '#00C8AB' '#FFD44F' '#8217FF' '#FFC9D7' '#00E6BB' '#F3F0DF'
        '#330D81' '#FF6767' '#00E6BB' '#FFE680' '#9A67FF' '#FFC9D7' '#00E6CC' '#F3F0DF'
        '#FF6767' '#FFC9D7' '#9A67FF' '#00E6BB' '#00E6CC' '#FFE680'
      )
      ;;
    light)
      foreground='#110034'
      background='#E5E1CC'
      cursor='#8217FF'
      palette=(
        '#110034' '#CC3E34' '#009A81' '#CD9A1B' '#330D81' '#E69AB3' '#00B39A' '#5F5873'
        '#330D81' '#CC3E34' '#00B39A' '#E6B334' '#6734CD' '#E69AB3' '#009A81' '#5F5873'
        '#CC3E34' '#E69AB3' '#6734CD' '#00B39A' '#009A81' '#E6B334'
      )
      ;;
    *)
      _termux_theme_usage
      return
      ;;
  esac

  local index palette_payload='4'
  for (( index = 1; index <= ${#palette}; index++ )); do
    palette_payload+=";$(( index - 1 ));${palette[$index]}"
  done

  _termux_theme_emit_osc "$palette_payload"
  _termux_theme_emit_osc "10;$foreground;$background;$cursor"
}
