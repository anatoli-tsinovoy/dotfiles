#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
APK_PATH="${1:-$SCRIPT_DIR/open-in-neovim/open-in-neovim.apk}"

log_info() { printf 'ℹ️  %s\n' "$*"; }
log_ok() { printf '✅ %s\n' "$*"; }
log_warn() { printf '⚠️  %s\n' "$*" >&2; }

fail() {
  log_warn "$*"
  exit 1
}

if [[ $# -gt 1 ]]; then
  fail 'Usage: scripts/termux/install-open-in-neovim.sh [prebuilt-apk-path]'
fi

if [[ -z "${TERMUX_VERSION:-}" && "${PREFIX:-}" != *com.termux* ]]; then
  fail 'This installer must run inside native Termux.'
fi

if [[ ! -f "$APK_PATH" || ! -r "$APK_PATH" ]]; then
  fail "APK not found or unreadable: $APK_PATH. The bundled APK is expected at $SCRIPT_DIR/open-in-neovim/open-in-neovim.apk; provide an APK path explicitly to use a different APK."
fi

if ! command -v am >/dev/null 2>&1; then
  fail 'am is unavailable; install or repair the Termux base utilities before opening the APK installer.'
fi

if ! command -v stow >/dev/null 2>&1; then
  if ! command -v pkg >/dev/null 2>&1; then
    fail 'GNU Stow is missing and the Termux pkg command is unavailable. Install stow, then rerun this script.'
  fi
  log_info 'Installing GNU Stow...'
  pkg install -y stow
fi

mkdir -p "$HOME/.termux" "$HOME/.local/bin"
log_info 'Stowing the Termux package (without replacing conflicting user files)...'
# .termux contains ignored runtime state, including an absolute login-shell symlink.
stow --no-folding --dir="$REPO_DIR" --target="$HOME" termux

HELPER_PATH="$HOME/.local/bin/termux-open-in-neovim"
PRIMARY_PROPERTIES_PATH="$HOME/.termux/termux.properties"
SECONDARY_PROPERTIES_PATH="$HOME/.config/termux/termux.properties"
[[ -x "$HELPER_PATH" ]] || fail "The helper was not stowed as an executable at $HELPER_PATH."

is_native_properties_file() {
  [[ -f "$1" && ! -L "$1" && -r "$1" ]]
}

is_readable_properties_file() {
  [[ -f "$1" && -r "$1" ]]
}

PROPERTIES_DEST="$PRIMARY_PROPERTIES_PATH"
PROPERTIES_SOURCE=''
if is_native_properties_file "$PRIMARY_PROPERTIES_PATH"; then
  PROPERTIES_DEST="$PRIMARY_PROPERTIES_PATH"
  PROPERTIES_SOURCE="$PRIMARY_PROPERTIES_PATH"
elif is_native_properties_file "$SECONDARY_PROPERTIES_PATH"; then
  PROPERTIES_DEST="$SECONDARY_PROPERTIES_PATH"
  PROPERTIES_SOURCE="$SECONDARY_PROPERTIES_PATH"
else
  if [[ -L "$PRIMARY_PROPERTIES_PATH" ]]; then
    if [[ ! -e "$PRIMARY_PROPERTIES_PATH" ]]; then
      fail "The primary Termux settings path is a dangling symlink: $PRIMARY_PROPERTIES_PATH."
    fi
    if [[ ! -f "$PRIMARY_PROPERTIES_PATH" ]]; then
      fail "The primary Termux settings path is not a regular file: $PRIMARY_PROPERTIES_PATH."
    fi
    if [[ -r "$PRIMARY_PROPERTIES_PATH" ]]; then
      PROPERTIES_SOURCE="$PRIMARY_PROPERTIES_PATH"
    else
      fail "The primary Termux settings file is not readable: $PRIMARY_PROPERTIES_PATH."
    fi
  elif [[ -e "$PRIMARY_PROPERTIES_PATH" ]]; then
    if [[ ! -f "$PRIMARY_PROPERTIES_PATH" ]]; then
      fail "The primary Termux settings path is not a regular file: $PRIMARY_PROPERTIES_PATH."
    fi
    fail "The primary Termux settings file is not readable: $PRIMARY_PROPERTIES_PATH."
  fi

  if [[ -z "$PROPERTIES_SOURCE" ]] && is_readable_properties_file "$SECONDARY_PROPERTIES_PATH"; then
    PROPERTIES_SOURCE="$SECONDARY_PROPERTIES_PATH"
  fi
fi

ALLOW_EXTERNAL_APPS_SETTING='allow-external-apps = true'
PROPERTIES_TMP="$(mktemp "${PROPERTIES_DEST}.XXXXXX")"
trap 'if [[ -n "${PROPERTIES_TMP:-}" ]]; then rm -f -- "$PROPERTIES_TMP"; fi' EXIT
if [[ -n "$PROPERTIES_SOURCE" ]]; then
  awk -v setting="$ALLOW_EXTERNAL_APPS_SETTING" '
    /^[[:space:]]*allow-external-apps([[:space:]]*[=:]|[[:space:]]+|$)/ {
      if (!found) {
        print setting
        found = 1
      }
      next
    }
    { print }
    END {
      if (!found) print setting
    }
  ' "$PROPERTIES_SOURCE" > "$PROPERTIES_TMP"
else
  printf '%s\n' "$ALLOW_EXTERNAL_APPS_SETTING" > "$PROPERTIES_TMP"
fi
mv -fT -- "$PROPERTIES_TMP" "$PROPERTIES_DEST"
PROPERTIES_TMP=''
trap - EXIT

if command -v termux-reload-settings >/dev/null 2>&1; then
  am start --user "${TERMUX__USER_ID:-0}" -W \
    -n com.termux/com.termux.app.TermuxActivity
  termux-reload-settings
fi

bash "$SCRIPT_DIR/setup-storage.sh"
log_ok 'Termux helper and RUN_COMMAND setting are ready.'
printf 'Security: RUN_COMMAND allows an app to execute commands as your Termux user. Open "Open in Neovim" from the launcher to approve its RUN_COMMAND permission request; grant it only to this trusted app.\n'

PACKAGE_NAME='com.dotfiles.openinneovim'
INSTALLED_APK_PATH=''
if command -v pm >/dev/null 2>&1; then
  INSTALLED_APK_PATHS="$(pm path --user 0 "$PACKAGE_NAME" 2>/dev/null || true)"
  while IFS= read -r installed_apk_line; do
    case "$installed_apk_line" in
      package:*/base.apk)
        INSTALLED_APK_PATH="${installed_apk_line#package:}"
        break
        ;;
    esac
  done <<< "$INSTALLED_APK_PATHS"
fi

if [[ -n "$INSTALLED_APK_PATH" && -r "$INSTALLED_APK_PATH" ]] \
  && command -v cmp >/dev/null 2>&1 \
  && cmp -s -- "$APK_PATH" "$INSTALLED_APK_PATH"; then
  log_ok 'The installed APK is identical; skipping Android installation.'
  printf 'Open "Open in Neovim" from the launcher if its RUN_COMMAND permission request has not yet been approved.\n'
  exit 0
fi

printf 'Approve the Android installation prompt. After installation, open "Open in Neovim" from the launcher and approve its RUN_COMMAND permission request on first launch.\n'

log_info 'Opening Android package installer; confirm installation on the device.'
APK_PATH="$(realpath -- "$APK_PATH")"
APK_URI='content://com.termux.files'
LC_ALL=C
for ((i = 0; i < ${#APK_PATH}; i++)); do
  character="${APK_PATH:i:1}"
  case "$character" in
    [a-zA-Z0-9.~_/-]) APK_URI+="$character" ;;
    *)
      printf -v escaped '%%%02X' "'$character"
      APK_URI+="$escaped"
      ;;
  esac
done
# INSTALL_PACKAGE bypasses generic VIEW handlers, including Termux's importer.
am start --user "${TERMUX__USER_ID:-0}" \
  -a android.intent.action.INSTALL_PACKAGE -d "$APK_URI" -f 0x10000001
printf 'No installation completion or RUN_COMMAND permission grant is assumed; approve both in Android when prompted.\n'
