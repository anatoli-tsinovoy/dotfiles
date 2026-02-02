_detect_background() {
  [[ "$TERM" == "dumb" ]] && { echo "dark"; return; }
  local old_settings response r g b
  exec {tty_fd}<>/dev/tty 2>/dev/null || { echo "dark"; return; }
  old_settings=$(stty -g <&$tty_fd 2>/dev/null)
  stty raw -echo min 0 time 1 <&$tty_fd 2>/dev/null
  print -nu $tty_fd '\e]11;?\e\\'
  response=""
  while IFS= read -rs -t 0.1 -k 1 -u $tty_fd char 2>/dev/null; do
    response+="$char"
    [[ "$char" == '\' ]] && break
  done
  [[ -n "$old_settings" ]] && stty "$old_settings" <&$tty_fd 2>/dev/null
  exec {tty_fd}<&-
  if [[ "$response" =~ 'rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)' ]]; then
    r=$((16#${match[1]:0:2})) g=$((16#${match[2]:0:2})) b=$((16#${match[3]:0:2}))
    (( (r * 299 + g * 587 + b * 114) / 1000 < 128 )) && echo "dark" || echo "light"
    return
  fi
  echo "dark"
}
