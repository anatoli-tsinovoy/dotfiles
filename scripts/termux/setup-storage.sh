#!/usr/bin/env bash
set -euo pipefail

TERMUX_PACKAGE='com.termux'
STORAGE_DIR="$HOME/storage"
SHARED_STORAGE_ROOT='/storage/emulated/0'

log_info() { printf 'ℹ️  %s\n' "$*"; }
log_ok() { printf '✅ %s\n' "$*"; }
log_warn() { printf '⚠️  %s\n' "$*" >&2; }
fail() {
  log_warn "$*"
  exit 1
}

if [[ -z "${TERMUX_VERSION:-}" && "${PREFIX:-}" != *com.termux* ]]; then
  fail 'Storage setup must be run from Termux.'
fi

android_user_id="${TERMUX__USER_ID:-0}"
if [[ ! "$android_user_id" =~ ^[0-9]+$ || "$android_user_id" == 0* && "$android_user_id" != 0 ]]; then
  android_user_id=0
fi

shared_storage_accessible() {
  [[ -d "$SHARED_STORAGE_ROOT" && -r "$SHARED_STORAGE_ROOT" && -x "$SHARED_STORAGE_ROOT" ]]
}

storage_links_ready() {
  [[ -d "$STORAGE_DIR/shared" && -r "$STORAGE_DIR/shared" && -x "$STORAGE_DIR/shared" ]]
}

storage_links_created() {
  [[ -L "$STORAGE_DIR/shared" || -e "$STORAGE_DIR/shared" ]]
}

bring_termux_to_foreground() {
  if [[ -t 0 && -t 1 ]]; then
    return 0
  fi
  command -v am >/dev/null 2>&1 || fail 'Android activity manager (am) is unavailable; open Termux in the foreground before continuing.'
  if ! am start -W --user "$android_user_id" -n "$TERMUX_PACKAGE/.app.TermuxActivity" >/dev/null; then
    fail 'Could not bring Termux to the foreground. Open Termux before continuing; no storage files were changed.'
  fi
}

open_storage_settings() {
  local sdk
  sdk="$(getprop ro.build.version.sdk 2>/dev/null || true)"
  if [[ "$sdk" =~ ^[0-9]+$ ]] && (( sdk >= 30 )); then
    if am start -W --user "$android_user_id" \
      -a android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION \
      -d "package:$TERMUX_PACKAGE" >/dev/null; then
      return 0
    fi
  fi

  am start -W --user "$android_user_id" \
    -a android.settings.APPLICATION_DETAILS_SETTINGS \
    -d "package:$TERMUX_PACKAGE" >/dev/null
}

wait_for_user_approval() {
  local check_function="$1"
  local message="$2"
  local attempts=60
  local attempt

  if "$check_function"; then
    return 0
  fi

  printf '%s\n' "$message"
  if [[ -t 0 && -t 1 ]]; then
    if ! IFS= read -r -p 'After approving storage access in Android, return here and press Enter: ' _; then
      return 1
    fi
    attempts=15
  fi

  for ((attempt = 0; attempt < attempts; attempt++)); do
    if "$check_function"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

handle_existing_storage() {
  if shared_storage_accessible; then
    log_ok 'Shared storage is accessible; leaving the existing ~/storage tree untouched.'
    return 0
  fi

  log_info 'Shared storage access is unavailable. Opening Termux storage permissions in Android Settings; existing ~/storage contents and symlinks will not be rebuilt.'
  bring_termux_to_foreground
  command -v am >/dev/null 2>&1 || fail 'Android activity manager (am) is unavailable; ~/storage was left untouched.'
  if ! open_storage_settings; then
    fail 'Could not open Termux storage settings. ~/storage was left untouched; Android approval is required.'
  fi

  if wait_for_user_approval shared_storage_accessible \
    'Grant Termux storage access in Android Settings. On Android 11 or later, enable “Allow access to manage all files” if shown.'; then
    log_ok 'Shared storage access is available; the existing ~/storage tree was left untouched.'
    return 0
  fi

  fail 'Android storage approval is still pending or was not granted. The existing ~/storage tree was left untouched; this run stops before APK installation.'
}

if [[ -e "$STORAGE_DIR" || -L "$STORAGE_DIR" ]]; then
  handle_existing_storage
  exit 0
fi

command -v termux-setup-storage >/dev/null 2>&1 \
  || fail 'Native termux-setup-storage is unavailable; no storage files were changed.'
command -v am >/dev/null 2>&1 \
  || fail 'Android activity manager (am) is unavailable; no storage files were changed.'

bring_termux_to_foreground

# Recheck immediately before the native command. Its existing-directory path
# rebuilds ~/storage, so never accept its interactive confirmation accidentally.
if [[ -e "$STORAGE_DIR" || -L "$STORAGE_DIR" ]]; then
  handle_existing_storage
  exit 0
fi

log_info 'Starting native Termux storage permission and symlink setup.'
if ! termux-setup-storage </dev/null; then
  if [[ -e "$STORAGE_DIR" || -L "$STORAGE_DIR" ]]; then
    handle_existing_storage
    exit 0
  fi
  fail 'Native Termux storage setup did not complete; no APK installation will be started.'
fi

if storage_links_ready; then
  log_ok 'Termux shared-storage links are ready.'
  exit 0
fi

if wait_for_user_approval storage_links_created \
  'Approve any Android storage permission prompt. Termux setup remains in the foreground until shared-storage links are ready.'; then
  if storage_links_ready; then
    log_ok 'Termux shared-storage links are ready.'
  else
    handle_existing_storage
  fi
  exit 0
fi

fail 'Android storage approval is still pending or was not granted. This run stops before APK installation.'
