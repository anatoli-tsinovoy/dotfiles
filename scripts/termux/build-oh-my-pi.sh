#!/usr/bin/env bash
# Build and install OMP's Rust N-API addon for native Termux/Android ARM64.
#
# Usage: ./scripts/termux/build-oh-my-pi.sh
# Optional overrides: OMP_ANDROID_REPO_URL, OMP_ANDROID_BRANCH,
# OMP_ANDROID_EXPECTED_SHA, OMP_ANDROID_SOURCE_DIR, OMP_ANDROID_TOOLS_DIR,
# OMP_ANDROID_TARGET_DIR, OMP_ANDROID_OUTPUT_DIR,
# OMP_ANDROID_VERIFY_PROVIDER=1, and CARGO_BUILD_JOBS.
# Native output defaults to $CACHE_ROOT/output/<expected-sha-or-branch> and must
# not overlap the source, tools, or Cargo target caches.
set -euo pipefail

log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }
fail() { log_warn "$*"; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

readonly DEFAULT_REPO_URL="https://github.com/anatoli-tsinovoy/oh-my-pi.git"
readonly BRANCH="${OMP_ANDROID_BRANCH:-termux-android-arm64}"
readonly LOCAL_REPO_DIR="$HOME/oh-my-pi"
readonly CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-pi-termux"
readonly SOURCE_DIR="${OMP_ANDROID_SOURCE_DIR:-$CACHE_ROOT/source}"
readonly TOOLS_DIR="${OMP_ANDROID_TOOLS_DIR:-$CACHE_ROOT/tools}"
readonly TARGET_DIR="${OMP_ANDROID_TARGET_DIR:-${CARGO_TARGET_DIR:-$CACHE_ROOT/target}}"
OUTPUT_DIR=""
REPO_URL=""
FILE_REPO_DIR=""
EXPECTED_SHA=""

if [[ -z "${TERMUX_VERSION:-}" && "${PREFIX:-}" != *com.termux* ]]; then
  fail "This recipe must run in native Termux, not Linux or proot."
fi

for command in bun cargo cmake git llvm-strip make node npm pkg-config realpath rustc; do
  if ! command_exists "$command"; then
    log_warn "Missing required command: $command"
    log_warn "Install prerequisites with: pkg install bun clang cmake coreutils git make nodejs-lts pkg-config rust"
    exit 1
  fi
done

paths_overlap() {
  local first="$1" second="$2"
  [[ "$first" == "$second" || "$first" == "$second"/* || "$second" == "$first"/* ]]
}

configure_output_dir() {
  local output_key source_path tools_path target_path output_path

  output_key="${EXPECTED_SHA:-$BRANCH}"
  OUTPUT_DIR="${OMP_ANDROID_OUTPUT_DIR:-$CACHE_ROOT/output/$output_key}"

  source_path=$(realpath -m -- "$SOURCE_DIR")
  tools_path=$(realpath -m -- "$TOOLS_DIR")
  target_path=$(realpath -m -- "$TARGET_DIR")
  output_path=$(realpath -m -- "$OUTPUT_DIR")
  readonly OUTPUT_DIR="$output_path"

  if paths_overlap "$OUTPUT_DIR" "$source_path"; then
    fail "Output directory must be outside source cache: $OUTPUT_DIR"
  fi
  if paths_overlap "$OUTPUT_DIR" "$tools_path"; then
    fail "Output directory must not overlap tools cache: $OUTPUT_DIR"
  fi
  if paths_overlap "$OUTPUT_DIR" "$target_path"; then
    fail "Output directory must not overlap Cargo target cache: $OUTPUT_DIR"
  fi
}

resolve_repository() {
  if [[ -n "${OMP_ANDROID_REPO_URL:-}" ]]; then
    REPO_URL="$OMP_ANDROID_REPO_URL"
  elif git -C "$LOCAL_REPO_DIR" rev-parse --verify --quiet "refs/heads/$BRANCH^{commit}" &>/dev/null; then
    REPO_URL="file://$LOCAL_REPO_DIR"
  else
    REPO_URL="$DEFAULT_REPO_URL"
  fi

  if [[ "$REPO_URL" == file://* ]]; then
    FILE_REPO_DIR="${REPO_URL#file://}"
    [[ -d "$FILE_REPO_DIR" ]] || fail "Local repository does not exist: $FILE_REPO_DIR"
    git -C "$FILE_REPO_DIR" rev-parse --is-inside-work-tree &>/dev/null ||
      fail "Local repository is not a git checkout: $FILE_REPO_DIR"
  fi

  if [[ "${OMP_ANDROID_EXPECTED_SHA+x}" == x ]]; then
    EXPECTED_SHA="$OMP_ANDROID_EXPECTED_SHA"
    [[ "$EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]] ||
      fail "Expected SHA must be a 40-character lowercase commit SHA"
  elif [[ -n "$FILE_REPO_DIR" ]]; then
    EXPECTED_SHA=$(git -C "$FILE_REPO_DIR" rev-parse --verify --quiet "refs/heads/$BRANCH^{commit}") ||
      fail "Local repository does not contain branch $BRANCH"
  fi

  log_info "Using repository: $REPO_URL"
  if [[ -n "$EXPECTED_SHA" ]]; then
    log_info "Expecting commit: $EXPECTED_SHA"
  else
    log_warn "No expected SHA: remote branch tip will be built"
  fi
}

preflight_source_cache() {
  local source_top dirty
  [[ -e "$SOURCE_DIR" ]] || return 0

  if [[ -n "$FILE_REPO_DIR" && "$SOURCE_DIR" -ef "$FILE_REPO_DIR" ]]; then
    fail "Refusing to use the repository checkout itself as the build cache: $SOURCE_DIR"
  fi

  git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree &>/dev/null ||
    fail "Source cache is non-git: $SOURCE_DIR"
  source_top=$(git -C "$SOURCE_DIR" rev-parse --show-toplevel)
  [[ "$SOURCE_DIR" -ef "$source_top" ]] ||
    fail "Source cache must be a checkout root, not a subdirectory: $SOURCE_DIR"
  dirty=$(git -C "$SOURCE_DIR" status --porcelain --untracked-files=all)
  [[ -z "$dirty" ]] || fail "dirty cache: refusing to overwrite $SOURCE_DIR"
  return 0
}

update_source() {
  preflight_source_cache
  if [[ ! -e "$SOURCE_DIR" ]]; then
    log_info "Cloning OMP Android branch..."
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --depth=1 --filter=blob:none --single-branch --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
  else
    log_info "Updating OMP Android branch..."
    git -C "$SOURCE_DIR" remote set-url origin "$REPO_URL"
    git -C "$SOURCE_DIR" fetch --depth=1 origin "$BRANCH"
    git -C "$SOURCE_DIR" checkout -B "$BRANCH" FETCH_HEAD
  fi

  local actual_sha
  actual_sha=$(git -C "$SOURCE_DIR" rev-parse HEAD)
  if [[ -n "$EXPECTED_SHA" && "$actual_sha" != "$EXPECTED_SHA" ]]; then
    fail "stale SHA: checked out $actual_sha, expected $EXPECTED_SHA"
  fi
  log_ok "Checked out OMP commit $actual_sha"
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

build_addon() {
  local napi="$TOOLS_DIR/node_modules/.bin/napi"

  log_info "Building Android ARM64 native addon (the first build can take 30–45 minutes)..."
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"

  (
    cd "$SOURCE_DIR/crates/pi-natives"
    CARGO_TARGET_DIR="$TARGET_DIR" \
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

read_package_version() {
  node - "$1" <<'NODE'
const path = require("node:path");
const packageRoot = process.argv[2];
process.stdout.write(require(path.join(packageRoot, "package.json")).version);
NODE
}

validate_source_versions() {
  local natives_version coding_agent_version
  natives_version=$(read_package_version "$SOURCE_DIR/packages/natives")
  coding_agent_version=$(read_package_version "$SOURCE_DIR/packages/coding-agent")
  [[ "$natives_version" == "$coding_agent_version" ]] ||
    fail "version mismatch: source natives $natives_version != coding-agent $coding_agent_version"
  log_ok "Source natives and coding-agent versions match: $natives_version"
}


resolve_installed_natives_root() {
  bun -e '
    import fs from "node:fs";
    import path from "node:path";

    const packageRoot = process.argv[1];
    const entrypoint = Bun.resolveSync(
      "@oh-my-pi/pi-natives",
      path.join(packageRoot, "index.js"),
    );

    for (let directory = path.dirname(entrypoint); ; ) {
      try {
        const pkg = JSON.parse(fs.readFileSync(path.join(directory, "package.json"), "utf8"));
        if (pkg.name === "@oh-my-pi/pi-natives") {
          process.stdout.write(directory);
          break;
        }
      } catch {}

      const parent = path.dirname(directory);
      if (parent === directory) {
        throw new Error(
          `Unable to find @oh-my-pi/pi-natives package root above resolved entrypoint ${entrypoint}`,
        );
      }
      directory = parent;
    }
  ' "$1"
}

resolve_android_loader_candidate() {
  bun -e '
    import path from "node:path";
    import { pathToFileURL } from "node:url";
    const loader = process.argv[1];
    const nativeDir = path.dirname(loader);
    const nativesRoot = path.dirname(nativeDir);
    const { initLoaderContext } = await import(pathToFileURL(loader).href);
    const context = initLoaderContext({
      nativeDir,
      platform: "android",
      isCompiledBinary: false,
      leafPackageDir: null,
    });
    const candidate = context.candidates?.[0];
    const relativeCandidate =
      typeof candidate === "string" && path.isAbsolute(candidate)
        ? path.relative(nativesRoot, candidate)
        : null;
    if (
      context.platformTag !== "android-arm64" ||
      !Array.isArray(context.candidates) ||
      typeof candidate !== "string" ||
      !path.isAbsolute(candidate) ||
      relativeCandidate === null ||
      relativeCandidate === ".." ||
      relativeCandidate.startsWith(`..${path.sep}`) ||
      path.isAbsolute(relativeCandidate)
    ) {
      throw new Error(`Invalid Android ARM64 loader candidate from ${loader}`);
    }
    process.stdout.write(candidate);
  ' "$1"
}

verify_provider() {
  local omp_bin="$1" provider_stdout
  provider_stdout=$(mktemp)
  log_info "Running opt-in provider liveness probe..."
  if ! "$omp_bin" --print --no-session --no-title --no-tools --thinking off \
    --no-extensions --no-skills --no-rules -- "reply with exactly ok" </dev/null >"$provider_stdout"; then
    rm -f "$provider_stdout"
    fail "provider failure: OMP provider probe exited non-zero"
  fi
  if ! printf 'ok\n' | cmp -s - "$provider_stdout"; then
    rm -f "$provider_stdout"
    fail "provider failure: expected exact stdout 'ok\\n'"
  fi
  rm -f "$provider_stdout"
  log_ok "Provider liveness probe returned exact ok"
}

install_omp() {
  local source_natives_version source_agent_version npm_root npm_prefix package_root
  local installed_agent_version installed_natives_version natives_root core_addon loader
  local selected_addon omp_bin built_addon package_tarball

  source_natives_version=$(read_package_version "$SOURCE_DIR/packages/natives")
  source_agent_version=$(read_package_version "$SOURCE_DIR/packages/coding-agent")
  [[ "$source_natives_version" == "$source_agent_version" ]] ||
    fail "version mismatch: source natives $source_natives_version != coding-agent $source_agent_version"

  npm_root=$(npm root -g)
  npm_prefix=$(npm prefix -g)
  package_root="$npm_root/@oh-my-pi/pi-coding-agent"
  omp_bin="$npm_prefix/bin/omp"

  log_info "Packing CLI JavaScript from OMP commit ${EXPECTED_SHA:-$(git -C "$SOURCE_DIR" rev-parse HEAD)}..."
  package_tarball=$(
    cd "$SOURCE_DIR/packages/coding-agent"
    bun pm pack --ignore-scripts --destination "$OUTPUT_DIR" |
      sed -n 's#^.*/\([^/]*\.tgz\)$#\1#p'
  )
  [[ -f "$OUTPUT_DIR/$package_tarball" ]] ||
    fail "local coding-agent package was not created: $OUTPUT_DIR/$package_tarball"
  npm install -g --ignore-scripts "$OUTPUT_DIR/$package_tarball"

  [[ -x "$omp_bin" ]] || fail "npm-global omp binary not found or not executable: $omp_bin"
  [[ "$package_root" -ef "$SOURCE_DIR/packages/coding-agent" ]] &&
    fail "local package installation unexpectedly symlinked the disposable source checkout"

  installed_agent_version=$(read_package_version "$package_root")
  [[ "$installed_agent_version" == "$source_agent_version" ]] ||
    fail "version mismatch: installed coding-agent $installed_agent_version != source $source_agent_version"
  natives_root=$(resolve_installed_natives_root "$package_root")
  [[ -d "$natives_root" ]] || fail "installed native package not found for $package_root"
  installed_natives_version=$(read_package_version "$natives_root")
  [[ "$installed_natives_version" == "$source_natives_version" ]] ||
    fail "version mismatch: installed natives $installed_natives_version != source $source_natives_version"
  log_ok "Installed CLI JavaScript from the selected local stack commit"

  loader="$natives_root/native/loader-state.js"
  [[ -f "$loader" ]] || fail "Native loader not found: $loader"
  if ! selected_addon=$(resolve_android_loader_candidate "$loader"); then
    fail "loader shadowing: could not resolve an Android loader candidate"
  fi
  [[ "$selected_addon" == "$npm_root"/* ]] ||
    fail "loader shadowing: selected addon escapes npm-global packages: $selected_addon"

  built_addon="$OUTPUT_DIR/pi_natives.android-arm64.node"
  core_addon="$natives_root/native/pi_natives.android-arm64.node"
  mkdir -p "$(dirname "$core_addon")" "$(dirname "$selected_addon")"
  install -m 755 "$built_addon" "$core_addon"
  if [[ "$selected_addon" != "$core_addon" ]]; then
    install -m 755 "$built_addon" "$selected_addon"
  fi
  [[ -f "$selected_addon" ]] ||
    fail "loader shadowing: selected Android addon is missing: $selected_addon"
  cmp -s "$built_addon" "$core_addon" ||
    fail "loader shadowing: core addon does not match the local build"
  cmp -s "$built_addon" "$selected_addon" ||
    fail "loader shadowing: selected addon does not match the local build"
  bun -e 'require(process.argv[1])' "$selected_addon" ||
    fail "loader shadowing: selected Android addon cannot be required: $selected_addon"
  log_ok "Installed local addon at loader-selected path $selected_addon"

  log_info "Running OMP smoke tests..."
  "$omp_bin" --version
  "$omp_bin" --help >/dev/null
  "$omp_bin" --smoke-test
  if [[ "${OMP_ANDROID_VERIFY_PROVIDER:-0}" == 1 ]]; then
    verify_provider "$omp_bin"
  fi
  log_ok "OMP Android ARM64 installation is ready"
}

resolve_repository
configure_output_dir
update_source
validate_source_versions
install_napi_cli
build_addon
install_omp
