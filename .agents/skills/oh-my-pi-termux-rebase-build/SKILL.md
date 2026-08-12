---
name: oh-my-pi-termux-rebase-build
description: Rebase the oh-my-pi Termux Android branch onto upstream main, reconcile upstream refactors semantically, then build, install, and prove the Android ARM64 native addon with build-oh-my-pi.sh. Use for updating, rebuilding, installing, or diagnosing the termux-android-arm64 branch in this dotfiles setup.
compatibility: Native Termux on Android ARM64; ~/oh-my-pi checkout; ~/dotfiles/scripts/termux/build-oh-my-pi.sh; git, Bun, Node, npm, Cargo, CMake, pkg-config, and llvm-strip.
---

# Oh My Pi Termux rebase, build, and liveness

<critical>

- MUST build the recorded rebased commit, never an unpinned remote tip.
- MUST use a fresh build cache; NEVER use the working checkout as `SOURCE_DIR`.
- MUST distinguish local native source from npm-installed CLI JavaScript.
- NEVER claim local installation proves Android release publishing support.
- NEVER push rewritten history unless the user explicitly requests it.

</critical>

## Scope

This workflow validates two intentionally different artifacts:

1. `pi_natives.android-arm64.node`: compiled from the local rebased source checkout.
2. `@oh-my-pi/pi-coding-agent`: CLI JavaScript installed globally from npm at the matching package version.

The build script compiles local Rust native source; it does not install checkout TypeScript. Equal source package versions prove the native/CLI package contract, not that npm JavaScript came from the same Git commit.

## Hardened build script contract

`~/dotfiles/scripts/termux/build-oh-my-pi.sh` defaults to the local `$HOME/oh-my-pi` checkout and its configured Android branch when that checkout is available. If no usable local checkout exists, it falls back to the configured remote repository and branch.

The script accepts these relevant overrides:

| Variable | Meaning |
| --- | --- |
| `OMP_ANDROID_REPO_URL` | Explicit source repository; use only when intentionally overriding local source selection. |
| `OMP_ANDROID_BRANCH` | Source branch; defaults to the Android branch. |
| `OMP_ANDROID_SOURCE_DIR` | Disposable build cache checkout. |
| `OMP_ANDROID_TOOLS_DIR` | Reusable isolated tools cache. |
| `OMP_ANDROID_TARGET_DIR` | Reusable Cargo target cache; defaults outside disposable source checkout. |
| `OMP_ANDROID_OUTPUT_DIR` | External N-API addon output; set per-run under `RUN_DIR` or reuse a cache outside `SOURCE_DIR`. |
| `OMP_ANDROID_EXPECTED_SHA` | Required 40-character lowercase expected commit SHA; when omitted, derive only from a `file://` repository branch. |
| `OMP_ANDROID_VERIFY_PROVIDER` | Set to `1` for the optional exact-provider-response probe after local smoke succeeds. Any other value skips it. |
| `CARGO_BUILD_JOBS` | Cargo parallelism. |

For a provenance-safe invocation, the script MUST:

1. Refuse a dirty source cache and refuse `SOURCE_DIR` equal to the local working checkout.
2. Fetch/checkout the selected branch into the disposable cache.
3. Require the supplied 40-character lowercase SHA, or derive one only from a `file://` repository branch, after checkout and before native compilation.
4. Install isolated `@napi-rs/cli`, retain the Android `audiopus_sys` patch, build `crates/pi-natives` with Cargo profile `local`, strip it, and directly load the built addon.
5. Assert `packages/natives` and `packages/coding-agent` source versions match before npm installation.
6. Install the matching npm CLI version globally.
7. Resolve the installed loader's selected Android candidate, copy the local addon to core and to a distinct selected platform leaf, then byte-compare the selected candidate with the built addon.
8. Invoke the absolute npm-global `omp` for `--version`, `--help`, and `--smoke-test`.
9. Only when `OMP_ANDROID_VERIFY_PROVIDER=1`, require the configured provider probe to return exactly `ok`.

The script performs these installation and liveness checks itself. Its successful exit is the primary build/install proof; do not duplicate its loader, copy, hash, or baseline CLI checks manually.

## Rebase workflow

### Inspect and fetch

```bash
set -euo pipefail
cd "$HOME/oh-my-pi"

git status --short --branch
test -z "$(git status --porcelain)"
test "$(git branch --show-current)" = termux-android-arm64
git remote get-url upstream
git fetch --prune upstream main

OLD_HEAD="$(git rev-parse HEAD)"
UPSTREAM_HEAD="$(git rev-parse upstream/main)"
git merge-base HEAD upstream/main
```

MUST stop for unexpected local changes. User work is not disposable.

### Rebase and resolve semantically

```bash
git rebase upstream/main
```

For each conflict:

1. Read the complete conflict plus ours, theirs, and base.
2. Inspect the original branch commit's intended behavior.
3. Trace upstream moves and renames before selecting a side.
4. Port required platform behavior into the current owning subsystem.
5. Delete obsolete paths; NEVER resurrect removed subsystems only to satisfy a conflict.

Useful triage:

```bash
git diff --name-only --diff-filter=U
git show --stat REBASE_HEAD
git show --format= REBASE_HEAD -- path/to/conflicted-file
```

Classify before editing:

| Shape | Resolution |
| --- | --- |
| Upstream deleted; branch modified | Find the replacement owner, then port behavior there. |
| Upstream moved/refactored; branch modified | Preserve intent through the current interface. |
| Dependency disappeared | Find the replacement implementation before restoring a dependency. |
| Generated file conflicts | Fix source, regenerate only after rebase completion. |
| Platform-gated code | Require a target-platform build; host checks are insufficient. |

### Verify the rebased graph

```bash
HEAD_SHA="$(git rev-parse HEAD)"
git merge-base --is-ancestor "$UPSTREAM_HEAD" "$HEAD_SHA"
test "$(git rev-list --left-right --count "$UPSTREAM_HEAD...$HEAD_SHA" | cut -f1)" = 0
test -z "$(git rev-list --merges "$UPSTREAM_HEAD..$HEAD_SHA")"
git diff --check "$UPSTREAM_HEAD...$HEAD_SHA"
test -z "$(git status --porcelain)"
git log --oneline "$UPSTREAM_HEAD..$HEAD_SHA"
```

Rebase rewrites branch commits. Report divergence from origin. User-requested publication requires reviewed `git push --force-with-lease`; NEVER push automatically.

## Provenance-safe build and verification

Use a fresh source cache and an explicit expected SHA. Do not override the repository URL for the normal local-checkout path; the hardened script selects `$HOME/oh-my-pi` by default.

```bash
set -euo pipefail
cd "$HOME/oh-my-pi"

HEAD_SHA="$(git rev-parse HEAD)"
RUN_DIR="$(mktemp -d "$HOME/.cache/oh-my-pi-termux/run.XXXXXX")"
SOURCE_DIR="$RUN_DIR/source"
TOOLS_DIR="$HOME/.cache/oh-my-pi-termux/tools"
TARGET_DIR="$HOME/.cache/oh-my-pi-termux/target"
OUTPUT_DIR="$RUN_DIR/android-build"
test -z "$(git status --porcelain)"
test ! -e "$SOURCE_DIR"

OMP_ANDROID_SOURCE_DIR="$SOURCE_DIR" \
OMP_ANDROID_TOOLS_DIR="$TOOLS_DIR" \
OMP_ANDROID_TARGET_DIR="$TARGET_DIR" \
OMP_ANDROID_OUTPUT_DIR="$OUTPUT_DIR" \
OMP_ANDROID_EXPECTED_SHA="$HEAD_SHA" \
OMP_ANDROID_VERIFY_PROVIDER="${OMP_ANDROID_VERIFY_PROVIDER:-0}" \
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-4}" \
bash "$HOME/dotfiles/scripts/termux/build-oh-my-pi.sh"

# Independent acceptance: the recorded disposable source remains clean; addon output is external.
test "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$HEAD_SHA"
test -z "$(git -C "$SOURCE_DIR" status --porcelain)"
test -f "$OUTPUT_DIR/pi_natives.android-arm64.node"
```

Set `OMP_ANDROID_VERIFY_PROVIDER=1` before the build invocation only when the default model, credentials, and network are intentionally part of acceptance. Keep the default `0` for native-only verification.

Provider verification is optional because it consumes a configured provider request. When enabled, it MUST exit successfully and emit exactly `ok`; credential, model, or network failures do not invalidate the local native smoke result.

Start with `CARGO_BUILD_JOBS=4` on multi-core Termux; lower it under memory pressure. Reuse `OMP_ANDROID_TARGET_DIR` across runs: Cargo fingerprints preserve correctness while avoiding cold recompilation after every disposable source clone. Set `OMP_ANDROID_OUTPUT_DIR` under each `RUN_DIR` for isolated output, or to a reusable cache outside `SOURCE_DIR`; NEVER write generated addon output into the source checkout. An interrupted build MAY reuse the same source cache only while it remains clean. Dirty cache? Use a new run directory; NEVER reset or delete user-visible source blindly.

Native Termux MAY warn that `ANDROID_NDK_LATEST_HOME` is missing while the build still succeeds. Compiler dead-code warnings are nonfatal. Final exit status remains authoritative.

## Independent artifact inspection

Use this only to diagnose a failed script or to gather release evidence beyond the script's enforced checks:

```bash
PACKAGE_ROOT="$(npm root -g)/@oh-my-pi/pi-coding-agent"
NATIVES_ROOT="$PACKAGE_ROOT/node_modules/@oh-my-pi/pi-natives"
OMP_BIN="$(npm prefix -g)/bin/omp"
BUILT_ADDON="$OUTPUT_DIR/pi_natives.android-arm64.node"
CORE_ADDON="$NATIVES_ROOT/native/pi_natives.android-arm64.node"

test -x "$OMP_BIN"
test -f "$BUILT_ADDON"
test -f "$CORE_ADDON"
cmp "$BUILT_ADDON" "$CORE_ADDON"
```

A direct core addon load proves only the core path. The installed loader may select a platform leaf first; trust the script's resolved selected-candidate comparison, not an assumed candidate order. Matching semver or a native sentinel is not commit identity; byte comparison establishes addon identity.

## Provider liveness prerequisites

The optional provider probe requires a configured default model, credentials, network access, and provider availability. It is not a substitute for local smoke testing and it is not a release-publishing test.

If it fails after the script's local smoke passes, classify it as provider configuration, credentials, quota, or network failure unless the script reports an installed CLI/native load failure. A response of `ok` with nonzero exit status remains failure.

## Release boundary

Manual Termux installation and npm release support are separate contracts.

Before claiming published Android support, trace `android-arm64` through:

1. Native artifact production.
2. Workflow artifact upload and download.
3. `LEAF_TARGETS` package generation.
4. Android leaf publishing.
5. Core optional-dependency generation.
6. Updater direct-dependency installation.

Advertising an unpublished `@oh-my-pi/pi-natives-android-arm64` package breaks normal installs and updates. Local core-addon fallback proves only this local installation path, never the release topology.

## Failure interpretation

- Expected SHA mismatch → wrong source selection, branch, or cache; stop before build.
- Dirty source cache → use a fresh `SOURCE_DIR`.
- Source package versions differ → incompatible native/CLI source tree; do not install.
- Selected candidate differs from built addon → stale or shadowing installed artifact.
- Local smoke passes; provider probe fails → model, credential, quota, or network problem.
- Host build passes; Android build fails → inspect Android-only cfg/code.
- Manifest references a removed dependency → likely stale conflict resolution.
- Pipeline through `tee` requires `set -o pipefail`; otherwise success may be masked.

<critical>

- MUST record `HEAD_SHA`, use fresh `SOURCE_DIR`, and pass `OMP_ANDROID_EXPECTED_SHA`.
- MUST treat script-selected addon bytes and absolute npm-global smoke as installation proof.
- MUST state local native source and npm CLI JavaScript provenance separately.
- NEVER use a local build to claim npm Android release support.
- NEVER push rebased history without explicit user instruction.

</critical>
