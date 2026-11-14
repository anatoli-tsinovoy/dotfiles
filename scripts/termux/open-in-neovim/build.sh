#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:-}"
if [[ -z "$HOME_DIR" ]]; then
  printf 'error: HOME is unset; set HOME before building Open in Neovim.\n' >&2
  exit 1
fi

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME_DIR/.cache}"
OUTPUT_DIR="$CACHE_ROOT/dotfiles/open-in-neovim"
APK_PATH="$OUTPUT_DIR/open-in-neovim.apk"
KEYSTORE_PATH="$OUTPUT_DIR/open-in-neovim.keystore"
KEY_PASSWORD_FILE="$OUTPUT_DIR/open-in-neovim.keystore.pass"
KEY_ALIAS='open-in-neovim'
COMPILE_SDK="${ANDROID_COMPILE_SDK:-35}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if [[ ! "$COMPILE_SDK" =~ ^[0-9]+$ ]]; then
  fail "ANDROID_COMPILE_SDK must be a numeric Android API level, got: $COMPILE_SDK"
fi

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$SDK_ROOT" ]]; then
  for candidate in "$HOME_DIR/Android/Sdk" "$HOME_DIR/Android/sdk" "$HOME_DIR/.android/sdk" "${PREFIX:-/nonexistent}/share/android-sdk"; do
    if [[ -d "$candidate/platforms" && -d "$candidate/build-tools" ]]; then
      SDK_ROOT="$candidate"
      break
    fi
  done
fi
if [[ -z "$SDK_ROOT" || ! -d "$SDK_ROOT" ]]; then
  fail 'Android SDK not found. Set ANDROID_SDK_ROOT (or ANDROID_HOME) to an SDK containing platforms and build-tools.'
fi
ANDROID_JAR="$SDK_ROOT/platforms/android-$COMPILE_SDK/android.jar"
[[ -f "$ANDROID_JAR" ]] || fail "Android API $COMPILE_SDK platform is missing: $ANDROID_JAR. Install that SDK platform or set ANDROID_COMPILE_SDK."

version_is_newer() {
  local left="$1" right="$2" i left_part right_part count
  local -a left_parts right_parts
  IFS='.' read -r -a left_parts <<< "$left"
  IFS='.' read -r -a right_parts <<< "$right"
  count="${#left_parts[@]}"
  if (( ${#right_parts[@]} > count )); then
    count="${#right_parts[@]}"
  fi
  for ((i = 0; i < count; i++)); do
    left_part="${left_parts[i]:-0}"
    right_part="${right_parts[i]:-0}"
    if (( 10#$left_part > 10#$right_part )); then
      return 0
    fi
    if (( 10#$left_part < 10#$right_part )); then
      return 1
    fi
  done
  return 1
}

BUILD_TOOLS_DIR=''
if [[ -n "${ANDROID_BUILD_TOOLS_VERSION:-}" ]]; then
  BUILD_TOOLS_DIR="$SDK_ROOT/build-tools/$ANDROID_BUILD_TOOLS_VERSION"
  [[ -d "$BUILD_TOOLS_DIR" ]] || fail "Requested Android build-tools version is missing: $BUILD_TOOLS_DIR"
else
  best_version=''
  for candidate in "$SDK_ROOT"/build-tools/*; do
    [[ -d "$candidate" ]] || continue
    version="${candidate##*/}"
    [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || continue
    complete=true
    for tool in aapt2 d8 zipalign apksigner; do
      [[ -x "$candidate/$tool" ]] || complete=false
    done
    [[ "$complete" == true ]] || continue
    if [[ -z "$best_version" ]] || version_is_newer "$version" "$best_version"; then
      best_version="$version"
      BUILD_TOOLS_DIR="$candidate"
    fi
  done
fi
[[ -n "$BUILD_TOOLS_DIR" ]] || fail "No complete Android build-tools installation found under $SDK_ROOT/build-tools. Install a version containing aapt2, d8, zipalign, and apksigner."

AAPT2="$BUILD_TOOLS_DIR/aapt2"
D8="$BUILD_TOOLS_DIR/d8"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
for tool in "$AAPT2" "$D8" "$ZIPALIGN" "$APKSIGNER"; do
  [[ -x "$tool" ]] || fail "Required Android SDK tool is unavailable or not executable: $tool"
done

if [[ -n "${JAVA_HOME:-}" ]]; then
  JDK_BIN="$JAVA_HOME/bin"
else
  JAVAC_IN_PATH="$(command -v javac || true)"
  [[ -n "$JAVAC_IN_PATH" ]] || fail 'JDK javac is missing. Install a JDK and set JAVA_HOME.'
  JDK_BIN="$(dirname -- "$JAVAC_IN_PATH")"
fi
for tool in javac java jar keytool; do
  [[ -x "$JDK_BIN/$tool" ]] || fail "JDK tool is missing: $JDK_BIN/$tool. Install a complete JDK and set JAVA_HOME."
done
JAVAC="$JDK_BIN/javac"
JAR="$JDK_BIN/jar"
KEYTOOL="$JDK_BIN/keytool"
PATH="$JDK_BIN:$PATH"
export PATH

SOURCE_FILE="$SCRIPT_DIR/src/com/dotfiles/openinneovim/MainActivity.java"
[[ -f "$SOURCE_FILE" ]] || fail "Android activity source is missing: $SOURCE_FILE"
[[ -f "$SCRIPT_DIR/AndroidManifest.xml" ]] || fail "Android manifest is missing: $SCRIPT_DIR/AndroidManifest.xml"

umask 077
mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"
[[ ! -L "$KEYSTORE_PATH" ]] || fail "Refusing to use a symlink as the signing keystore: $KEYSTORE_PATH"
[[ ! -L "$KEY_PASSWORD_FILE" ]] || fail "Refusing to use a symlink as the signing password file: $KEY_PASSWORD_FILE"

if [[ -e "$KEYSTORE_PATH" && ! -s "$KEYSTORE_PATH" ]]; then
  fail "Signing keystore is empty or incomplete: $KEYSTORE_PATH. Preserve the original key or remove only a known failed build artifact."
fi
if [[ -e "$KEYSTORE_PATH" && ! -s "$KEY_PASSWORD_FILE" ]]; then
  fail "Signing keystore password file is missing or empty: $KEY_PASSWORD_FILE. Restore the matching file; do not generate a replacement key for upgrades."
fi
if [[ -e "$KEY_PASSWORD_FILE" && ! -s "$KEY_PASSWORD_FILE" ]]; then
  fail "Signing password file is empty: $KEY_PASSWORD_FILE."
fi
if [[ ! -e "$KEY_PASSWORD_FILE" ]]; then
  command -v od >/dev/null 2>&1 || fail 'The POSIX od utility is required to create the private signing password.'
  command -v tr >/dev/null 2>&1 || fail 'The POSIX tr utility is required to create the private signing password.'
  password="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
  [[ "${#password}" -eq 64 ]] || fail 'Could not generate a signing password from /dev/urandom.'
  printf '%s' "$password" > "$KEY_PASSWORD_FILE"
  unset password
fi
chmod 600 "$KEY_PASSWORD_FILE"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/open-in-neovim-build.XXXXXX")" || fail 'Could not create a temporary build directory.'
trap 'rm -rf "$WORK_DIR"; if [[ -n "${TEMP_APK:-}" ]]; then rm -f "$TEMP_APK"; fi' EXIT
TEMP_APK=''
CLASS_DIR="$WORK_DIR/classes"
DEX_DIR="$WORK_DIR/dex"
mkdir -p "$CLASS_DIR" "$DEX_DIR"

if [[ ! -e "$KEYSTORE_PATH" ]]; then
  TEMP_KEYSTORE="$WORK_DIR/open-in-neovim.keystore"
  "$KEYTOOL" -genkeypair \
    -keystore "$TEMP_KEYSTORE" \
    -storetype PKCS12 \
    -storepass:file "$KEY_PASSWORD_FILE" \
    -keypass:file "$KEY_PASSWORD_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 3072 \
    -validity 10000 \
    -dname 'CN=Open in Neovim'
  [[ -s "$TEMP_KEYSTORE" ]] || fail 'keytool did not create the Open in Neovim signing keystore.'
  mv "$TEMP_KEYSTORE" "$KEYSTORE_PATH"
  chmod 600 "$KEYSTORE_PATH"
fi
chmod 600 "$KEYSTORE_PATH"

"$JAVAC" -encoding UTF-8 -source 8 -target 8 \
  -classpath "$ANDROID_JAR" -d "$CLASS_DIR" "$SOURCE_FILE"
"$JAR" cf "$WORK_DIR/classes.jar" -C "$CLASS_DIR" .
"$D8" --lib "$ANDROID_JAR" --min-api 26 --output "$DEX_DIR" "$WORK_DIR/classes.jar"
[[ -s "$DEX_DIR/classes.dex" ]] || fail 'D8 did not produce classes.dex.'

UNSIGNED_APK="$WORK_DIR/open-in-neovim-unsigned.apk"
ALIGNED_APK="$WORK_DIR/open-in-neovim-aligned.apk"
SIGNED_APK="$WORK_DIR/open-in-neovim-signed.apk"
"$AAPT2" link \
  --manifest "$SCRIPT_DIR/AndroidManifest.xml" \
  -I "$ANDROID_JAR" \
  --min-sdk-version 26 \
  --target-sdk-version 28 \
  --version-code 1 \
  --version-name 1.0 \
  -o "$UNSIGNED_APK"
[[ -s "$UNSIGNED_APK" ]] || fail 'aapt2 did not produce the unsigned APK.'
"$JAR" uf "$UNSIGNED_APK" -C "$DEX_DIR" classes.dex
"$ZIPALIGN" -f -p 4 "$UNSIGNED_APK" "$ALIGNED_APK"
"$APKSIGNER" sign \
  --ks "$KEYSTORE_PATH" \
  --ks-key-alias "$KEY_ALIAS" \
  --ks-pass "file:$KEY_PASSWORD_FILE" \
  --out "$SIGNED_APK" \
  "$ALIGNED_APK"
"$APKSIGNER" verify "$SIGNED_APK"

TEMP_APK="$(mktemp "$OUTPUT_DIR/.open-in-neovim.apk.XXXXXX")" || fail 'Could not create a temporary APK in the output directory.'
cp "$SIGNED_APK" "$TEMP_APK"
chmod 600 "$TEMP_APK"
mv -f "$TEMP_APK" "$APK_PATH"
TEMP_APK=''
cp "$APK_PATH" "$SCRIPT_DIR/open-in-neovim.apk"
chmod 644 "$SCRIPT_DIR/open-in-neovim.apk"
printf 'Built APK: %s\nSigning keystore: %s\n' "$APK_PATH" "$KEYSTORE_PATH"
