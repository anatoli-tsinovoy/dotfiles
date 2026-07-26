# OMP remote microphone forwarding and shell helpers.
# Client-side helpers expose the device microphone over SSH or Eternal Terminal;
# omp-remote bridges that PulseAudio stream into OMP's default ALSA microphone.

# Match PulseAudio's CoreAudio devices to the devices currently selected by macOS.
_omp_pulse_use_coreaudio_default() {
  local device_type="$1"
  local pulse_type="$2"
  local coreaudio_device pulse_device previous_device previous_index
  local stream_type move_command line device_index device_name device_details
  local stream_index attached_index stream_details

  coreaudio_device="$(SwitchAudioSource -c -t "$device_type")" || return
  while IFS= read -r line; do
    if [[ "$line" == $'\tName: '* ]]; then
      pulse_device="${line#$'\tName: '}"
    elif [[ "$line" == $'\t\tdevice.string = "'* ]]; then
      line="${line#$'\t\tdevice.string = \"'}"
      line="${line%\"}"
      if [[ "$line" == "$coreaudio_device" ]]; then
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
        return 0
      fi
    fi
  done < <(pactl list "${pulse_type}s")

  print -u2 "PulseAudio has no $pulse_type matching the current macOS $device_type: $coreaudio_device"
  return 1
}

_omp_pulse_sync_coreaudio_defaults() {
  [[ "$OSTYPE" == darwin* ]] || return 0
  if ! command -v SwitchAudioSource &>/dev/null; then
    print -u2 'OMP audio forwarding on macOS requires SwitchAudioSource'
    return 1
  fi

  _omp_pulse_use_coreaudio_default input source || return
  _omp_pulse_use_coreaudio_default output sink
}

_omp_pulse_watch_coreaudio_defaults() {
  local parent_pid="$1"
  local interval="${OMP_AUDIO_DEVICE_POLL_INTERVAL:-10}"
  local previous_input previous_output current_input current_output

  previous_input="$(SwitchAudioSource -c -t input)" || return
  previous_output="$(SwitchAudioSource -c -t output)" || return
  while command kill -0 "$parent_pid" 2>/dev/null; do
    command sleep "$interval"
    command kill -0 "$parent_pid" 2>/dev/null || return
    current_input="$(SwitchAudioSource -c -t input)" || continue
    current_output="$(SwitchAudioSource -c -t output)" || continue
    if [[ "$current_input" != "$previous_input" || "$current_output" != "$previous_output" ]]; then
      if _omp_pulse_sync_coreaudio_defaults; then
        previous_input="$current_input"
        previous_output="$current_output"
      fi
    fi
  done
}

# Start a local PulseAudio microphone server for OMP forwarding.
_omp_mic_prepare() {
  local port="$1"
  local source_index source_name source_driver source_details
  local default_source

  if ! command -v pulseaudio &>/dev/null || ! command -v pactl &>/dev/null; then
    print -u2 'OMP microphone forwarding requires pulseaudio and pactl'
    return 1
  fi

  if ! pulseaudio --check &>/dev/null; then
    pulseaudio --start --exit-idle-time=-1 || return
  fi

  _omp_pulse_sync_coreaudio_defaults || return

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

  if ! pactl list short modules | command grep -q $'\tmodule-native-protocol-tcp\t.*port='"$port"; then
    pactl load-module module-native-protocol-tcp \
      "listen=127.0.0.1" "port=$port" "auth-anonymous=1" >/dev/null || return
  fi

  default_source="$(pactl get-default-source)" || return
  if [[ -z "$default_source" || "$default_source" == *.monitor ]]; then
    print -u2 'PulseAudio has no default microphone source'
    return 1
  fi
}

# Use SSH only for the audio tunnel and interactive connection.
omp-ssh() {
  local port="${OMP_MIC_PORT:-47130}"
  local watcher_pid

  _omp_mic_prepare "$port" || return
  if [[ "$OSTYPE" == darwin* ]]; then
    _omp_pulse_watch_coreaudio_defaults "$$" &
    watcher_pid=$!
  fi
  print "Forwarding the default microphone to remote TCP port $port"
  {
    command ssh -o ExitOnForwardFailure=yes \
      -R "127.0.0.1:$port:127.0.0.1:$port" "$@"
  } always {
    if [[ -n "$watcher_pid" ]]; then
      command kill "$watcher_pid" 2>/dev/null
      command wait "$watcher_pid" 2>/dev/null
    fi
  }
}

# Use Eternal Terminal's reconnectable reverse tunnel for both audio and shell.
# OMP_MIC_REMOTE_BIND may name a bridge address reachable from a container.
omp-et() {
  local port="${OMP_MIC_PORT:-47130}"
  local remote_bind="${OMP_MIC_REMOTE_BIND:-127.0.0.1}"
  local tunnel="$port:$port"
  local watcher_pid

  _omp_mic_prepare "$port" || return
  if [[ "$remote_bind" != "127.0.0.1" && "$remote_bind" != "localhost" ]]; then
    tunnel="$remote_bind:$port:127.0.0.1:$port"
  fi
  if [[ "$OSTYPE" == darwin* ]]; then
    _omp_pulse_watch_coreaudio_defaults "$$" &
    watcher_pid=$!
  fi
  print "Forwarding the default microphone to $remote_bind:$port"
  {
    command et --reversetunnel "$tunnel" "$@"
  } always {
    if [[ -n "$watcher_pid" ]]; then
      command kill "$watcher_pid" 2>/dev/null
      command wait "$watcher_pid" 2>/dev/null
    fi
  }
}

# The default Docker bridge used by the remote workstation.
omp-et-container() {
  OMP_MIC_REMOTE_BIND="${OMP_MIC_REMOTE_BIND:-172.18.0.1}" omp-et "$@"
}

omp-remote() {
  local host="${OMP_MIC_HOST:-}"
  local port="${OMP_MIC_PORT:-47130}"
  local playback_rate="${OMP_AUDIO_PLAYBACK_RATE:-24000}"
  local runtime_dir capture_fifo playback_fifo alsa_config
  local capture_pid playback_pid capture_fifo_keeper playback_fifo_keeper command_name

  if [[ -z "$host" && -f /.dockerenv ]] && command -v ip &>/dev/null; then
    host="$(ip route show default | command awk 'NR == 1 { print $3 }')"
  fi
  host="${host:-127.0.0.1}"

  for command_name in ffmpeg mkfifo mktemp; do
    if ! command -v "$command_name" &>/dev/null; then
      print -u2 "omp-remote: required command not found: $command_name"
      return 1
    fi
  done

  runtime_dir="$(command mktemp -d "${TMPDIR:-/tmp}/omp-audio.XXXXXXXX")" || return
  capture_fifo="$runtime_dir/capture.f32le"
  playback_fifo="$runtime_dir/playback.f32le"
  alsa_config="$runtime_dir/asound.conf"
  command mkfifo "$capture_fifo" "$playback_fifo" || {
    command rm -rf "$runtime_dir"
    return 1
  }
  exec {capture_fifo_keeper}<>"$capture_fifo"
  exec {playback_fifo_keeper}<>"$playback_fifo"

  print -r -- "pcm.null {
  type null
}

pcm.!default {
  type file
  slave.pcm \"null\"
  file \"$playback_fifo\"
  infile \"$capture_fifo\"
  format \"raw\"
}" >"$alsa_config"

  PULSE_SERVER="tcp:$host:$port" command ffmpeg \
    -nostdin -y -hide_banner -loglevel error \
    -f pulse -i default -ac 1 -ar 16000 -f f32le "$capture_fifo" \
    2>"$runtime_dir/capture.log" &
  capture_pid=$!

  PULSE_SERVER="tcp:$host:$port" command ffmpeg \
    -nostdin -hide_banner -loglevel error \
    -f f32le -ac 1 -ar "$playback_rate" -i "$playback_fifo" \
    -f pulse default \
    2>"$runtime_dir/playback.log" &
  playback_pid=$!

  print "Bridging OMP microphone and speaker audio through tcp:$host:$port"
  {
    command env -u PULSE_SERVER ALSA_CONFIG_PATH="$alsa_config" omp "$@"
  } always {
    command kill "$capture_pid" "$playback_pid" 2>/dev/null
    command wait "$capture_pid" "$playback_pid" 2>/dev/null
    exec {capture_fifo_keeper}>&-
    exec {playback_fifo_keeper}>&-
    command rm -rf "$runtime_dir"
  }
}
