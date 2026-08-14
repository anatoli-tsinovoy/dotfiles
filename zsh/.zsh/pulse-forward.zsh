# PulseAudio forwarding over SSH or Eternal Terminal.

# Match PulseAudio's CoreAudio devices to the devices currently selected by macOS.
_pa_use_coreaudio_default() {
  local device_type="$1"
  local pulse_type="$2"
  local coreaudio_device pulse_device pulse_coreaudio_device pulse_device_class
  local previous_device previous_index
  local stream_type move_command line device_index device_name device_details
  local stream_index attached_index stream_details

  coreaudio_device="$(SwitchAudioSource -c -t "$device_type")" || return
  while IFS= read -r line; do
    if [[ "$line" == $'\tName: '* ]]; then
      pulse_device="${line#$'\tName: '}"
      pulse_coreaudio_device=
      pulse_device_class=
    elif [[ "$line" == $'\t\tdevice.string = "'* ]]; then
      pulse_coreaudio_device="${line#$'\t\tdevice.string = \"'}"
      pulse_coreaudio_device="${pulse_coreaudio_device%\"}"
    elif [[ "$line" == $'\t\tdevice.class = "'* ]]; then
      pulse_device_class="${line#$'\t\tdevice.class = \"'}"
      pulse_device_class="${pulse_device_class%\"}"
    fi

    if [[ "$pulse_coreaudio_device" == "$coreaudio_device" && "$pulse_device_class" == sound ]]; then
      break
    fi
  done < <(pactl list "${pulse_type}s")

  if [[ "$pulse_coreaudio_device" != "$coreaudio_device" || "$pulse_device_class" != sound ]]; then
    print -u2 "PulseAudio has no $pulse_type matching the current macOS $device_type: $coreaudio_device"
    return 1
  fi

  previous_device="$(pactl "get-default-$pulse_type")" || return
  [[ "$pulse_device" == "$previous_device" ]] && return 0
  pactl "set-default-$pulse_type" "$pulse_device" || return

  while IFS=$'\t' read -r device_index device_name device_details; do
    if [[ "$device_name" == "$previous_device" ]]; then
      previous_index="$device_index"
      break
    fi
  done < <(pactl list short "${pulse_type}s")
  [[ -n "$previous_index" ]] || return 0

  if [[ "$pulse_type" == sink ]]; then
    stream_type="sink-inputs"
    move_command="move-sink-input"
  else
    stream_type="source-outputs"
    move_command="move-source-output"
  fi
  while IFS=$'\t' read -r stream_index attached_index stream_details; do
    if [[ "$attached_index" == "$previous_index" ]]; then
      pactl "$move_command" "$stream_index" "$pulse_device" || return
    fi
  done < <(pactl list short "$stream_type")
}

_pa_sync_coreaudio_defaults() {
  [[ "$OSTYPE" == darwin* ]] || return 0
  if ! command -v SwitchAudioSource &>/dev/null; then
    print -u2 'PulseAudio forwarding on macOS requires SwitchAudioSource'
    return 1
  fi

  _pa_use_coreaudio_default input source || return
  _pa_use_coreaudio_default output sink
}

_pa_watch_coreaudio_defaults() {
  local parent_pid="$1"
  local interval="${PULSE_DEVICE_POLL_INTERVAL:-10}"
  local previous_input previous_output current_input current_output

  previous_input="$(SwitchAudioSource -c -t input)" || return
  previous_output="$(SwitchAudioSource -c -t output)" || return
  while command kill -0 "$parent_pid" 2>/dev/null; do
    command sleep "$interval"
    command kill -0 "$parent_pid" 2>/dev/null || return
    current_input="$(SwitchAudioSource -c -t input)" || continue
    current_output="$(SwitchAudioSource -c -t output)" || continue
    if [[ "$current_input" != "$previous_input" || "$current_output" != "$previous_output" ]]; then
      if _pa_sync_coreaudio_defaults; then
        previous_input="$current_input"
        previous_output="$current_output"
      fi
    fi
  done
}

# Prepare a PulseAudio server for forwarding.
_pa_prepare() {
  local port="$1"
  # PULSE_SERVER may point at this TCP tunnel before the local server is ready.
  # Reuse an existing PulseAudio listener left by an earlier invocation; otherwise,
  # prepare PulseAudio through its native local connection.
  local PULSE_SERVER
  local tcp_server="tcp:127.0.0.1:$port"

  local source_index source_name source_driver source_details
  local default_source

  if ! command -v pulseaudio &>/dev/null || ! command -v pactl &>/dev/null; then
    print -u2 'PulseAudio forwarding requires pulseaudio and pactl'
    return 1
  fi

  if PULSE_SERVER="$tcp_server" pactl info &>/dev/null; then
    PULSE_SERVER="$tcp_server"
    export PULSE_SERVER
  else
    unset PULSE_SERVER
    if ! pulseaudio --check &>/dev/null; then
      pulseaudio --start --exit-idle-time=-1 || return
    fi
  fi

  _pa_sync_coreaudio_defaults || return

  if is_termux && ! pactl list short modules | command grep -q $'\tmodule-sles-source\t'; then
    if ! pactl load-module module-sles-source >/dev/null 2>&1; then
      print -u2 'Unable to open the Android microphone.'
      print -u2 'Install the Termux:API Android app from the same source as Termux,'
      print -u2 'grant Termux:API microphone permission, then retry the connection.'
      return 1
    fi
  fi

  if is_termux; then
    while IFS=$'\t' read -r source_index source_name source_driver source_details; do
      if [[ "$source_driver" == "module-sles-source.c" ]]; then
        pactl set-default-source "$source_name" || return
        break
      fi
    done < <(pactl list short sources)
  fi

  if [[ "$PULSE_SERVER" != "$tcp_server" ]] &&
    ! pactl list short modules | command grep -q $'\tmodule-native-protocol-tcp\t.*port='"$port"; then
    if ! pactl load-module module-native-protocol-tcp \
      "listen=127.0.0.1" "port=$port" "auth-anonymous=1" >/dev/null 2>&1; then
      print -u2 "Unable to expose PulseAudio on 127.0.0.1:$port."
      print -u2 'Check whether another process is already using that port.'
      return 1
    fi
  fi

  default_source="$(pactl get-default-source)" || return
  if [[ -z "$default_source" || "$default_source" == *.monitor ]]; then
    print -u2 'PulseAudio has no default microphone source'
    return 1
  fi
}

_pa_parse_remote_bind() {
  REPLY="$1"
  shift
  reply=("$@")

  if (( ${#reply} >= 3 )) && [[ "$reply[-2]" == --container ]]; then
    REPLY="$reply[-1]"
    reply[-2,-1]=()
  elif (( ${#reply} >= 1 )) && [[ "$reply[-1]" == --container ]]; then
    REPLY=172.18.0.1
    reply[-1]=()
  else
    local index
    for (( index = 1; index <= ${#reply}; index++ )); do
      if [[ "$reply[$index]" == --container ]]; then
        REPLY=172.18.0.1
        reply[$index]=()
        break
      elif [[ "$reply[$index]" == --container=* ]]; then
        REPLY="${reply[$index]#--container=}"
        reply[$index]=()
        break
      fi
    done
  fi
}

sshpa() {
  local port="${PULSE_FORWARD_PORT:-47130}"
  local remote_bind tunnel watcher_pid
  local REPLY
  local -a reply

  _pa_parse_remote_bind "${PULSE_REMOTE_BIND:-127.0.0.1}" "$@"
  remote_bind="$REPLY"
  tunnel="$remote_bind:$port:127.0.0.1:$port"

  _pa_prepare "$port" || return
  if [[ "$OSTYPE" == darwin* ]]; then
    _pa_watch_coreaudio_defaults "$$" &
    watcher_pid=$!
  fi
  print "Forwarding PulseAudio to $remote_bind:$port"
  {
    _remote_exec ssh -o ExitOnForwardFailure=yes -R "$tunnel" "${reply[@]}"
  } always {
    if [[ -n "$watcher_pid" ]]; then
      command kill "$watcher_pid" 2>/dev/null
      command wait "$watcher_pid" 2>/dev/null
    fi
  }
}

etpa() {
  local port="${PULSE_FORWARD_PORT:-47130}"
  local remote_bind
  local tunnel="$port:$port"
  local watcher_pid
  local REPLY
  local -a reply

  _pa_parse_remote_bind "${PULSE_REMOTE_BIND:-127.0.0.1}" "$@"
  remote_bind="$REPLY"

  _pa_prepare "$port" || return
  if [[ "$remote_bind" != "127.0.0.1" && "$remote_bind" != "localhost" ]]; then
    tunnel="$remote_bind:$port:127.0.0.1:$port"
  fi
  if [[ "$OSTYPE" == darwin* ]]; then
    _pa_watch_coreaudio_defaults "$$" &
    watcher_pid=$!
  fi
  print "Forwarding PulseAudio to $remote_bind:$port"
  {
    _remote_exec et --reversetunnel "$tunnel" "${reply[@]}"
  } always {
    if [[ -n "$watcher_pid" ]]; then
      command kill "$watcher_pid" 2>/dev/null
      command wait "$watcher_pid" 2>/dev/null
    fi
  }
}
