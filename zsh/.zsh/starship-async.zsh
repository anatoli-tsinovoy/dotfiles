# Render stable prompt elements synchronously and refresh expensive Starship
# modules in the background. Cached slow modules remain visible while refreshing.

[[ -o interactive ]] || return 0
(( ${+commands[starship]} )) || return 0

# zsh-async is optional. Keep Starship's normal dynamic prompt untouched when it
# was not installed or could not be loaded.
(( ${+functions[async_start_worker]} )) || return 0
(( ${+functions[async_register_callback]} )) || return 0
(( ${+functions[async_flush_jobs]} )) || return 0
(( ${+functions[async_job]} )) || return 0
(( ${+functions[async_stop_worker]} )) || return 0
(( ${_STARSHIP_ASYNC_INITIALIZED:-0} )) && return 0

autoload -Uz add-zsh-hook

typeset -g _STARSHIP_ASYNC_INITIALIZED=0
typeset -g _STARSHIP_ASYNC_BIN="${commands[starship]}"
typeset -g _STARSHIP_ASYNC_WORKER="_starship_async_$$"
typeset -g _STARSHIP_ASYNC_JOB_NAME='_starship_async_render_slow'
typeset -g _STARSHIP_ASYNC_FAST_MARKER='__STARSHIP_ASYNC_FAST_SPLIT__'
typeset -g _STARSHIP_ASYNC_SLOW_BEGIN='__STARSHIP_ASYNC_SLOW_BEGIN__'
typeset -g _STARSHIP_ASYNC_SLOW_END='__STARSHIP_ASYNC_SLOW_END__'
typeset -g _STARSHIP_ASYNC_RESULT_PREFIX='__STARSHIP_ASYNC_RESULT__:'
typeset -g _STARSHIP_ASYNC_GENERATION=0
typeset -g _STARSHIP_ASYNC_ACTIVE_GENERATION=0
typeset -g _STARSHIP_ASYNC_ACTIVE_PWD=''
typeset -g _STARSHIP_ASYNC_NEEDS_REDRAW=0
typeset -g _STARSHIP_ASYNC_REDRAW_GENERATION=0
typeset -g _STARSHIP_ASYNC_REDRAW_PWD=''
typeset -g _STARSHIP_ASYNC_FAST_PREFIX=''
typeset -g _STARSHIP_ASYNC_FAST_SUFFIX=''
typeset -g _STARSHIP_ASYNC_RENDERED_PROMPT=''
typeset -gA _STARSHIP_ASYNC_SLOW_CACHE

# Save Starship's command-substitution prompt before replacing it with the
# single-level backing-scalar reference used by the async prompt.
typeset -g _STARSHIP_ASYNC_ORIGINAL_PROMPT="${PROMPT-}"
typeset -g _STARSHIP_ASYNC_ORIGINAL_RPROMPT="${RPROMPT-}"
typeset -g _STARSHIP_ASYNC_ORIGINAL_KEYMAP_WIDGET=''
if [[ -o zle && -v widgets[zle-keymap-select] ]]; then
  _STARSHIP_ASYNC_ORIGINAL_KEYMAP_WIDGET="${widgets[zle-keymap-select]#user:}"
fi

_starship_async_restore_prompt() {
  PROMPT="$_STARSHIP_ASYNC_ORIGINAL_PROMPT"
  RPROMPT="$_STARSHIP_ASYNC_ORIGINAL_RPROMPT"
  _STARSHIP_ASYNC_RENDERED_PROMPT=''
}

_starship_async_render_fast() {
  local worker_pwd="$1"
  local fast slow
  local -a prompt_args=(
    "--terminal-width=${COLUMNS:-80}"
    "--keymap=${KEYMAP:-}"
    "--status=${STARSHIP_CMD_STATUS:-}"
    "--pipestatus=${STARSHIP_PIPE_STATUS[*]:-}"
    "--cmd-duration=${STARSHIP_DURATION:-}"
    "--jobs=${STARSHIP_JOBS_COUNT:-0}"
  )

  fast="$("$_STARSHIP_ASYNC_BIN" prompt --profile async-fast "${prompt_args[@]}")" || {
    _starship_async_restore_prompt
    return 1
  }
  if [[ "$fast" != *"$_STARSHIP_ASYNC_FAST_MARKER"* ]]; then
    _starship_async_restore_prompt
    return 1
  fi

  _STARSHIP_ASYNC_FAST_PREFIX="${fast%%$_STARSHIP_ASYNC_FAST_MARKER*}"
  _STARSHIP_ASYNC_FAST_SUFFIX="${fast#*$_STARSHIP_ASYNC_FAST_MARKER}"
  slow="${_STARSHIP_ASYNC_SLOW_CACHE["$worker_pwd"]-}"
  _STARSHIP_ASYNC_RENDERED_PROMPT="${_STARSHIP_ASYNC_FAST_PREFIX}${slow}${_STARSHIP_ASYNC_FAST_SUFFIX}"

  # Do not put Starship output directly in PROMPT: promptsubst would rescan it
  # and execute command substitutions contained in untrusted repository names.
  PROMPT='$_STARSHIP_ASYNC_RENDERED_PROMPT'
  RPROMPT=''
  return 0
}

_starship_async_render_slow() {
  local generation="$1"
  local worker_pwd="$2"
  local last_status="$3"
  local pipestatus="$4"
  local duration="$5"
  local jobs="$6"
  local width="$7"
  local keymap="$8"
  local rendered
  local -a prompt_args

  builtin cd -q -- "$worker_pwd" || return 1
  prompt_args=(
    "--terminal-width=$width"
    "--keymap=$keymap"
    "--status=$last_status"
    "--pipestatus=$pipestatus"
    "--cmd-duration=$duration"
    "--jobs=$jobs"
  )
  rendered="$("$_STARSHIP_ASYNC_BIN" prompt --profile async-slow "${prompt_args[@]}")" || return $?
  [[ "$rendered" == *"$_STARSHIP_ASYNC_SLOW_BEGIN"*"$_STARSHIP_ASYNC_SLOW_END"* ]] || return 1

  # Prefix the result with an integer generation and a byte-safe path length.
  # This lets the callback reject a result even if it raced async_flush_jobs.
  print -r -n -- "${_STARSHIP_ASYNC_RESULT_PREFIX}${generation}:${#worker_pwd}:${worker_pwd}${rendered}"
}

_starship_async_maybe_redraw() {
  local has_next="${1:-0}"
  local current_pwd

  (( has_next )) && return 0
  if (( _STARSHIP_ASYNC_NEEDS_REDRAW )) &&
    [[ "$_STARSHIP_ASYNC_REDRAW_GENERATION" == "$_STARSHIP_ASYNC_ACTIVE_GENERATION" ]] &&
    [[ "$_STARSHIP_ASYNC_REDRAW_PWD" == "$_STARSHIP_ASYNC_ACTIVE_PWD" ]] &&
    [[ "$_STARSHIP_ASYNC_ACTIVE_GENERATION" != 0 ]]; then
    current_pwd="${PWD:A}"
    if [[ "$current_pwd" == "$_STARSHIP_ASYNC_REDRAW_PWD" && -o zle ]]; then
      zle reset-prompt
    fi
  fi
  _STARSHIP_ASYNC_NEEDS_REDRAW=0
  _STARSHIP_ASYNC_REDRAW_GENERATION=0
  _STARSHIP_ASYNC_REDRAW_PWD=''
}

_starship_async_callback() {
  local job_name="${1-}"
  local result_code="${2-}"
  local output="${3-}"
  local has_next="${6:-0}"
  local payload generation path_len encoded result_pwd rendered slow current_pwd

  if [[ "$job_name" == "$_STARSHIP_ASYNC_JOB_NAME" && "$result_code" == 0 ]] &&
    [[ "$output" == "$_STARSHIP_ASYNC_RESULT_PREFIX"* ]]; then
    payload="${output#$_STARSHIP_ASYNC_RESULT_PREFIX}"
    generation="${payload%%:*}"
    if [[ "$generation" == <-> ]]; then
      payload="${payload#*:}"
      path_len="${payload%%:*}"
      if [[ "$path_len" == <-> ]]; then
        encoded="${payload#*:}"
        if (( path_len > 0 && path_len <= ${#encoded} )); then
          result_pwd="${encoded[1,$path_len]}"
          rendered="${encoded[$(( path_len + 1 )),-1]}"
          current_pwd="${PWD:A}"
          if [[ "$generation" == "$_STARSHIP_ASYNC_ACTIVE_GENERATION" &&
            "$result_pwd" == "$_STARSHIP_ASYNC_ACTIVE_PWD" &&
            "$result_pwd" == "$current_pwd" ]]; then
            if [[ "$rendered" == *"$_STARSHIP_ASYNC_SLOW_BEGIN"*"$_STARSHIP_ASYNC_SLOW_END"* ]]; then
              slow="${rendered#*$_STARSHIP_ASYNC_SLOW_BEGIN}"
              slow="${slow%%$_STARSHIP_ASYNC_SLOW_END*}"
              _STARSHIP_ASYNC_SLOW_CACHE["$result_pwd"]="$slow"
              _STARSHIP_ASYNC_RENDERED_PROMPT="${_STARSHIP_ASYNC_FAST_PREFIX}${slow}${_STARSHIP_ASYNC_FAST_SUFFIX}"
              _STARSHIP_ASYNC_NEEDS_REDRAW=1
              _STARSHIP_ASYNC_REDRAW_GENERATION="$generation"
              _STARSHIP_ASYNC_REDRAW_PWD="$result_pwd"
            fi
          fi
        fi
      fi
    fi
  fi

  _starship_async_maybe_redraw "$has_next"
}

_starship_async_precmd() {
  local worker_pwd="${PWD:A}"
  local generation
  local last_status="${STARSHIP_CMD_STATUS:-}"
  local pipestatus="${STARSHIP_PIPE_STATUS[*]:-}"
  local duration="${STARSHIP_DURATION:-}"
  local jobs="${STARSHIP_JOBS_COUNT:-0}"
  local width="${COLUMNS:-80}"
  local keymap="${KEYMAP:-}"

  _STARSHIP_ASYNC_ACTIVE_GENERATION=0
  _STARSHIP_ASYNC_ACTIVE_PWD=''
  _STARSHIP_ASYNC_NEEDS_REDRAW=0
  async_flush_jobs "$_STARSHIP_ASYNC_WORKER" 2>/dev/null
  (( ++_STARSHIP_ASYNC_GENERATION ))
  generation="$_STARSHIP_ASYNC_GENERATION"

  if ! _starship_async_render_fast "$worker_pwd"; then
    return 0
  fi

  _STARSHIP_ASYNC_ACTIVE_GENERATION="$generation"
  _STARSHIP_ASYNC_ACTIVE_PWD="$worker_pwd"
  async_job "$_STARSHIP_ASYNC_WORKER" "$_STARSHIP_ASYNC_JOB_NAME" \
    "$generation" "$worker_pwd" "$last_status" "$pipestatus" "$duration" "$jobs" "$width" "$keymap" || {
    _STARSHIP_ASYNC_ACTIVE_GENERATION=0
    _STARSHIP_ASYNC_ACTIVE_PWD=''
  }
}

_starship_async_preexec() {
  _STARSHIP_ASYNC_ACTIVE_GENERATION=0
  _STARSHIP_ASYNC_ACTIVE_PWD=''
  _STARSHIP_ASYNC_NEEDS_REDRAW=0
  async_flush_jobs "$_STARSHIP_ASYNC_WORKER" 2>/dev/null
}

_starship_async_keymap_select() {
  local ret=0
  local worker_pwd="${PWD:A}"

  if [[ -n "$_STARSHIP_ASYNC_ORIGINAL_KEYMAP_WIDGET" ]] &&
    (( ${+functions[$_STARSHIP_ASYNC_ORIGINAL_KEYMAP_WIDGET]} )); then
    "$_STARSHIP_ASYNC_ORIGINAL_KEYMAP_WIDGET" "$@" || ret=$?
  fi

  # Recompute only the fast profile so vi-mode character/keymap changes are
  # reflected immediately; the slow profile remains exclusively asynchronous.
  _starship_async_render_fast "$worker_pwd" || {
    _STARSHIP_ASYNC_ACTIVE_GENERATION=0
    _STARSHIP_ASYNC_ACTIVE_PWD=''
    async_flush_jobs "$_STARSHIP_ASYNC_WORKER" 2>/dev/null
  }
  zle reset-prompt
  return $ret
}

_starship_async_zshexit() {
  async_stop_worker "$_STARSHIP_ASYNC_WORKER" 2>/dev/null
  _STARSHIP_ASYNC_INITIALIZED=0
}

if ! async_start_worker "$_STARSHIP_ASYNC_WORKER" -u -n; then
  return 0
fi
async_register_callback "$_STARSHIP_ASYNC_WORKER" _starship_async_callback
typeset -g _STARSHIP_ASYNC_INITIALIZED=1

add-zsh-hook precmd _starship_async_precmd
add-zsh-hook preexec _starship_async_preexec
add-zsh-hook zshexit _starship_async_zshexit

if [[ -o zle ]]; then
  zle -N zle-keymap-select _starship_async_keymap_select
fi
