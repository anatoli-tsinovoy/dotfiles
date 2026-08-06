#!/usr/bin/env bash
# Build and install OMP's Rust N-API addon for native Termux/Android ARM64.
#
# Usage: ./scripts/termux/build-oh-my-pi.sh
# Optional overrides: OMP_ANDROID_REPO_URL, OMP_ANDROID_BRANCH,
# OMP_ANDROID_SOURCE_DIR, OMP_ANDROID_TOOLS_DIR, and CARGO_BUILD_JOBS.
set -euo pipefail

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

readonly REPO_URL="${OMP_ANDROID_REPO_URL:-https://github.com/anatoli-tsinovoy/oh-my-pi.git}"
readonly BRANCH="${OMP_ANDROID_BRANCH:-termux-android-arm64}"
readonly CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-pi-termux"
readonly SOURCE_DIR="${OMP_ANDROID_SOURCE_DIR:-$CACHE_ROOT/source}"
readonly TOOLS_DIR="${OMP_ANDROID_TOOLS_DIR:-$CACHE_ROOT/tools}"
readonly OUTPUT_DIR="$SOURCE_DIR/packages/natives/native/android-build"

if [[ -z "${TERMUX_VERSION:-}" && "${PREFIX:-}" != *com.termux* ]]; then
  log_warn "This recipe must run in native Termux, not Linux or proot."
  exit 1
fi

for command in bun cargo cmake git llvm-strip make node npm pkg-config rustc; do
  if ! command_exists "$command"; then
    log_warn "Missing required command: $command"
    log_warn "Install prerequisites with: pkg install bun clang cmake git make nodejs-lts pkg-config rust"
    exit 1
  fi
done

update_source() {
  if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    log_info "Cloning OMP Android branch..."
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --depth=1 --filter=blob:none --single-branch --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
    return
  fi

  log_info "Updating OMP Android branch..."
  git -C "$SOURCE_DIR" remote set-url origin "$REPO_URL"
  git -C "$SOURCE_DIR" fetch --depth=1 origin "$BRANCH"
  git -C "$SOURCE_DIR" checkout -B "$BRANCH" FETCH_HEAD
}

install_napi_cli() {
  local required_version installed_version=""
  required_version=$(node - "$SOURCE_DIR" <<'NODE'
const path = require("node:path");
const sourceDir = process.argv[2];
const packageJson = require(path.join(sourceDir, "packages/natives/package.json"));
const spec = packageJson.devDependencies["@napi-rs/cli"];
const version = spec === "catalog:"
  ? require(path.join(sourceDir, "package.json")).workspaces.catalog["@napi-rs/cli"]
  : spec;
if (!version) throw new Error("Unable to resolve @napi-rs/cli version");
process.stdout.write(version);
NODE
  )

  if [[ -f "$TOOLS_DIR/node_modules/@napi-rs/cli/package.json" ]]; then
    installed_version=$(node -p "require('$TOOLS_DIR/node_modules/@napi-rs/cli/package.json').version")
  fi

  if [[ "$installed_version" == "$required_version" ]]; then
    log_skip "@napi-rs/cli $required_version already installed"
    return
  fi

  log_info "Installing isolated @napi-rs/cli $required_version..."
  mkdir -p "$TOOLS_DIR"
  printf '{"private":true}\n' >"$TOOLS_DIR/package.json"
  npm install --prefix "$TOOLS_DIR" --ignore-scripts "@napi-rs/cli@$required_version"
}

patch_audiopus_sys_android() {
  local build_script
  build_script=$(
    cargo metadata --manifest-path "$SOURCE_DIR/crates/pi-natives/Cargo.toml" --format-version 1 |
      node -e '
        let input = "";
        process.stdin.setEncoding("utf8");
        process.stdin.on("data", chunk => input += chunk);
        process.stdin.on("end", () => {
          const pkg = JSON.parse(input).packages.find(candidate => candidate.name === "audiopus_sys");
          if (!pkg) throw new Error("audiopus_sys package not found in Cargo metadata");
          process.stdout.write(require("node:path").join(require("node:path").dirname(pkg.manifest_path), "build.rs"));
        });
      '
  )

  node - "$build_script" <<'NODE'
const fs = require("node:fs");
const buildScript = process.argv[2];
const androidCfg = '#[cfg(any(windows, target_os = "android", target_os = "macos", target_env = "musl"))]';
const upstreamCfg = '#[cfg(any(windows, target_os = "macos", target_env = "musl"))]';
const source = fs.readFileSync(buildScript, "utf8");
if (source.includes(androidCfg)) process.exit(0);
if (!source.includes(upstreamCfg)) {
  throw new Error(`Unsupported audiopus_sys build script: ${buildScript}`);
}
fs.writeFileSync(buildScript, source.replace(upstreamCfg, androidCfg));
NODE
}

build_addon() {
  local napi="$TOOLS_DIR/node_modules/.bin/napi"

  log_info "Building Android ARM64 native addon (the first build can take 30–45 minutes)..."
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"

  (
    cd "$SOURCE_DIR/crates/pi-natives"
    CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}" \
      CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      PCRE2_SYS_STATIC=1 \
      RUSTC_BOOTSTRAP=1 \
      RUSTFLAGS='-C target-cpu=generic' \
      "$napi" build \
      --manifest-path Cargo.toml \
      --package-json-path "$SOURCE_DIR/packages/natives/package.json" \
      --platform \
      --no-js \
      --dts index.d.ts \
      -o "$OUTPUT_DIR" \
      --profile local
  )

  local addon="$OUTPUT_DIR/pi_natives.android-arm64.node"
  [[ -f "$addon" ]] || { log_warn "Build completed without $addon"; exit 1; }
  llvm-strip --strip-unneeded "$addon"
  bun -e 'const addon = require(process.argv[1]); console.log(`Loaded ${Object.keys(addon).length} native exports`)' "$addon"
  log_ok "Android native addon built"
}

install_omp() {
  local version package_root natives_root addon loader
  version=$(node -p "require('$SOURCE_DIR/packages/natives/package.json').version")
  package_root="$(npm root -g)/@oh-my-pi/pi-coding-agent"

  if [[ ! -f "$package_root/package.json" ]] || \
    [[ "$(node -p "require('$package_root/package.json').version" 2>/dev/null || true)" != "$version" ]]; then
    log_info "Installing matching OMP CLI $version..."
    npm install -g "@oh-my-pi/pi-coding-agent@$version"
  else
    log_skip "OMP CLI $version already installed"
  fi

  natives_root="$package_root/node_modules/@oh-my-pi/pi-natives"
  addon="$natives_root/native/pi_natives.android-arm64.node"
  loader="$natives_root/native/loader-state.js"

  [[ -f "$loader" ]] || { log_warn "Native loader not found: $loader"; exit 1; }
  install -m 755 "$OUTPUT_DIR/pi_natives.android-arm64.node" "$addon"

  node - "$loader" <<'NODE'
const fs = require("node:fs");
const loader = process.argv[2];
let source = fs.readFileSync(loader, "utf8");
if (!source.includes('"android-arm64"')) {
  const marker = "const SUPPORTED_PLATFORMS = [";
  if (!source.includes(marker)) throw new Error(`Platform list not found in ${loader}`);
  source = source.replace(marker, `${marker}"android-arm64", `);
  fs.writeFileSync(loader, source);
}
NODE

  log_info "Running OMP smoke tests..."
  bun -e 'const addon = require(process.argv[1]); console.log(`Loaded ${Object.keys(addon).length} installed native exports`)' "$addon"
  omp --version
  omp --help >/dev/null
  log_ok "OMP Android ARM64 installation is ready"
}

update_source
install_napi_cli
patch_audiopus_sys_android
build_addon
install_omp
