---
name: oh-my-pi-termux-rebase-build
description: Rebase the fork-only oh-my-pi Termux Android PR stack onto upstream main without collapsing its runtime, audio, STT, and TTS concerns, then build, install, and prove the full Android ARM64 stack with build-oh-my-pi.sh. Use for updating, rebuilding, installing, or diagnosing any termux-android-* branch in this dotfiles setup.
compatibility: Native Termux on Android ARM64; ~/oh-my-pi checkout; ~/dotfiles/scripts/termux/build-oh-my-pi.sh; git, Bun, Node, npm, Cargo, CMake, pkg-config, and llvm-strip.
---

# Oh My Pi Termux rebase, build, and liveness

<critical>

- MUST preserve the ordered runtime → audio → STT → TTS branch stack.
- MUST build the recorded rebased TTS stack tip, never an unpinned remote tip.
- MUST use a fresh build cache; NEVER use the working checkout as `SOURCE_DIR`.
- MUST distinguish local native source from npm-installed CLI JavaScript.
- NEVER claim local installation proves Android release publishing support.
- NEVER push rewritten history unless the user explicitly requests it.

</critical>

## Scope

This workflow validates two artifacts from the same recorded stack commit:

1. `pi_natives.android-arm64.node`: compiled from the selected local source checkout.
2. `@oh-my-pi/pi-coding-agent`: packed from that checkout and installed globally.

Matching semver is insufficient: runtime, audio, STT, and TTS changes may be unpublished commits with the same package version. The installed CLI JavaScript and native addon MUST both originate from `OMP_ANDROID_EXPECTED_SHA`.

The fork-only PR stack separates concerns:

| Branch | Parent | Owned concern |
| --- | --- | --- |
| `termux-android-arm64` | `upstream/main` | Android/Termux native runtime, Bionic process management, clipboard gating |
| `termux-android-audio` | `termux-android-arm64` | Android capture/playback, miniaudio/OpenSL ES, Android Opus codec |
| `termux-android-stt` | `termux-android-audio` | Android Transformers.js/ONNX-WASM speech recognition |
| `termux-android-tts` | `termux-android-stt` | Android Transformers.js/ONNX-WASM speech synthesis |

MUST keep each concern on its existing branch. NEVER squash children into `termux-android-arm64`, rebase every branch independently onto `upstream/main`, or make child PRs cumulative against upstream main. Child branches rebase onto the newly rewritten parent branch.

## Hardened build script contract

`~/dotfiles/scripts/termux/build-oh-my-pi.sh` defaults to the local `$HOME/oh-my-pi` checkout and `termux-android-arm64`. Full-stack verification MUST set `OMP_ANDROID_BRANCH=termux-android-tts`; this selects the local fork branch containing runtime, audio, STT, and TTS. If no usable local checkout branch exists, the script falls back to the configured remote repository and branch.

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
4. Install isolated `@napi-rs/cli`, build `crates/pi-natives` with Cargo profile `local`, strip it, and directly load the built addon.
5. Assert `packages/natives` and `packages/coding-agent` source versions match.
6. Pack the selected checkout's coding-agent package without lifecycle scripts and install that local tarball globally.
7. Resolve the installed loader's selected Android candidate, copy the local addon to core and to a distinct selected platform leaf, then byte-compare the selected candidate with the built addon.
8. Invoke the absolute npm-global `omp` for `--version`, `--help`, and `--smoke-test`.
9. Only when `OMP_ANDROID_VERIFY_PROVIDER=1`, require the configured provider probe to return exactly `ok`.

The script performs these installation and liveness checks itself. Its successful exit is the primary build/install proof; do not duplicate its loader, copy, hash, or baseline CLI checks manually.

## Stacked rebase workflow

### Inspect, fetch, and record every boundary

```bash
set -euo pipefail
cd "$HOME/oh-my-pi"

git status --short --branch
test -z "$(git status --porcelain)"
git remote get-url origin
git remote get-url upstream
git fetch --prune origin
git fetch --prune upstream main

UPSTREAM_HEAD="$(git rev-parse upstream/main)"
BASE_OLD="$(git rev-parse termux-android-arm64)"
AUDIO_OLD="$(git rev-parse termux-android-audio)"
STT_OLD="$(git rev-parse termux-android-stt)"
TTS_OLD="$(git rev-parse termux-android-tts)"
BASE_REMOTE_OLD="$(git rev-parse origin/termux-android-arm64)"
AUDIO_REMOTE_OLD="$(git rev-parse origin/termux-android-audio)"
STT_REMOTE_OLD="$(git rev-parse origin/termux-android-stt)"
TTS_REMOTE_OLD="$(git rev-parse origin/termux-android-tts)"

git merge-base --is-ancestor "$BASE_OLD" "$AUDIO_OLD"
git merge-base --is-ancestor "$AUDIO_OLD" "$STT_OLD"
git merge-base --is-ancestor "$STT_OLD" "$TTS_OLD"
```

MUST stop for unexpected local changes, missing branches, or broken ancestry. User work is not disposable.

### Rebase parent first, then restack each child

```bash
git switch termux-android-arm64
git rebase upstream/main
BASE_NEW="$(git rev-parse HEAD)"

git switch termux-android-audio
git rebase --onto "$BASE_NEW" "$BASE_OLD"
AUDIO_NEW="$(git rev-parse HEAD)"

git switch termux-android-stt
git rebase --onto "$AUDIO_NEW" "$AUDIO_OLD"
STT_NEW="$(git rev-parse HEAD)"

git switch termux-android-tts
git rebase --onto "$STT_NEW" "$STT_OLD"
TTS_NEW="$(git rev-parse HEAD)"
```

The old parent SHA is each child's exclusive boundary. `--onto NEW_PARENT OLD_PARENT` replays only that child's commits; using `git rebase upstream/main` on every child duplicates parent commits and destroys the PR stack.

For each conflict:

1. Read the complete conflict plus ours, theirs, and base.
2. Inspect the currently replayed branch commit's intended concern.
3. Trace upstream moves and renames before selecting a side.
4. Port required platform behavior into the current owning subsystem.
5. Delete obsolete paths; NEVER resurrect removed subsystems only to satisfy a conflict.
6. NEVER resolve a child conflict by moving its behavior into a parent branch.

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
| Child needs parent conflict fix | Fix the parent branch, then restart/restack descendants. |

### Verify ancestry and separation

```bash
git merge-base --is-ancestor "$UPSTREAM_HEAD" "$BASE_NEW"
git merge-base --is-ancestor "$BASE_NEW" "$AUDIO_NEW"
git merge-base --is-ancestor "$AUDIO_NEW" "$STT_NEW"
git merge-base --is-ancestor "$STT_NEW" "$TTS_NEW"

test "$(git rev-list --left-right --count "$UPSTREAM_HEAD...$BASE_NEW" | cut -f1)" = 0
test -z "$(git rev-list --merges "$UPSTREAM_HEAD..$TTS_NEW")"
git diff --check "$UPSTREAM_HEAD...$TTS_NEW"
test -z "$(git status --porcelain)"

git log --oneline "$UPSTREAM_HEAD..$BASE_NEW"
git log --oneline "$BASE_NEW..$AUDIO_NEW"
git log --oneline "$AUDIO_NEW..$STT_NEW"
git log --oneline "$STT_NEW..$TTS_NEW"

git rev-list --left-right --count origin/termux-android-arm64...termux-android-arm64
git rev-list --left-right --count origin/termux-android-audio...termux-android-audio
git rev-list --left-right --count origin/termux-android-stt...termux-android-stt
git rev-list --left-right --count origin/termux-android-tts...termux-android-tts
```

Review every adjacent range, not only the final cumulative diff:

- Base range MUST contain runtime support only.
- Audio range MUST contain native audio/codec support only.
- STT range MUST contain recognition runtime support only.
- TTS range MUST contain synthesis runtime support only.

Rebase rewrites all four branch tips. Report divergence for every origin branch. Updating children before parents temporarily exposes invalid PR bases.

### Publish only when explicitly requested

After reviewing every adjacent range, update the fork parent-first with exact leases captured before rebase:

```bash
git push --force-with-lease=refs/heads/termux-android-arm64:"$BASE_REMOTE_OLD" origin termux-android-arm64
git push --force-with-lease=refs/heads/termux-android-audio:"$AUDIO_REMOTE_OLD" origin termux-android-audio
git push --force-with-lease=refs/heads/termux-android-stt:"$STT_REMOTE_OLD" origin termux-android-stt
git push --force-with-lease=refs/heads/termux-android-tts:"$TTS_REMOTE_OLD" origin termux-android-tts
```

NEVER replace exact leases with unconditional force pushes. A lease failure means the remote changed; fetch, inspect, and restack again. NEVER push unless the user explicitly requested publication.

## Provenance-safe build and verification

Use a fresh source cache and an explicit expected SHA. Do not override the repository URL for the normal local-checkout path; the hardened script selects `$HOME/oh-my-pi` by default.

```bash
set -euo pipefail
cd "$HOME/oh-my-pi"

BUILD_BRANCH=termux-android-tts
test "$(git branch --show-current)" = "$BUILD_BRANCH"
HEAD_SHA="$(git rev-parse "$BUILD_BRANCH")"
RUN_DIR="$(mktemp -d "$HOME/.cache/oh-my-pi-termux/run.XXXXXX")"
SOURCE_DIR="$RUN_DIR/source"
TOOLS_DIR="$HOME/.cache/oh-my-pi-termux/tools"
TARGET_DIR="$HOME/.cache/oh-my-pi-termux/target"
OUTPUT_DIR="$RUN_DIR/android-build"
test -z "$(git status --porcelain)"
test ! -e "$SOURCE_DIR"

OMP_ANDROID_BRANCH="$BUILD_BRANCH" \
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

- MUST preserve runtime → audio → STT → TTS ancestry and review every adjacent range.
- MUST build `termux-android-tts` with `OMP_ANDROID_BRANCH` and its recorded `HEAD_SHA`.
- MUST use fresh `SOURCE_DIR` and pass `OMP_ANDROID_EXPECTED_SHA`.
- MUST treat script-selected addon bytes and absolute npm-global smoke as installation proof.
- MUST state that installed CLI JavaScript and native addon share the recorded stack SHA.
- NEVER use a local build to claim npm Android release support.
- NEVER push rebased history without explicit user instruction.

</critical>
