# AGENTS.md - AI Agent Instructions for dotfiles Repository

Personal dotfiles for macOS, Linux, and Termux using GNU Stow for symlink management.

## Quick Reference

```bash
# Bootstrap (detects OS automatically: mac, linux, termux)
./install.sh                            # Full setup (packages + stow)
./install.sh --force                    # Force: remove conflicting targets

# Verification (NO AUTOMATED TESTS)
bash -n script.sh                       # Syntax check bash
shellcheck script.sh                    # Lint bash (if installed)
zsh -n ~/.zshrc                         # Syntax check zsh after stow
stylua --check nvim/                    # Check lua formatting

# Container testing (recommended for Linux changes)
podman run -it -v ./:/root/dotfiles:ro python:3.13-slim bash
```

## Project Structure

```
dotfiles/
├── install.sh             # Entry point (detects OS, installs packages, runs stow)
├── Brewfile               # macOS packages (Homebrew)
├── Aptfile                # Linux packages (apt via aptfile)
├── TermuxPkgfile          # Termux packages (pkg)
├── scripts/
│   ├── linux/install-binaries.sh   # Tools not in apt (neovim, fzf, bun, uv)
│   ├── termux/install-packages.sh  # Termux pkg installer
│   ├── macos/macos-defaults.sh     # macOS system preferences
│   ├── macos/sketchybar-app-font/  # Explicit installer generates local SVG overlays from overrides.json; startup loads existing artifacts only
│   └── tailscale-et.sh             # Tailscale + ET setup (mac/linux only)
├── shims/                 # OS-specific binary wrappers
│   ├── linux/.local/bin/  # bat fallback, fd→fdfind, node→bun
│   └── macos/.local/bin/  # docker→podman
├── termux/                # Termux-specific config
│   ├── .termux/           # Termux app settings
│   └── .local/bin/        # Termux-specific helpers
├── zsh/                   # Unified zsh config (ORDER-SENSITIVE)
├── nvim/                  # LazyVim-based Neovim config
├── git/                   # .gitconfig + .gitconfig.macos
├── aerospace/             # Tiling WM + sketchybar (macOS only)
└── ghostty/               # Ghostty config and light/dark themes
```

## Shell Script Style

```bash
#!/usr/bin/env bash
set -euo pipefail                       # ALWAYS at top

# Logging helpers (emoji prefixes)
log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_skip() { echo "⏭️  $*"; }
log_warn() { echo "⚠️  $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# IDEMPOTENT pattern - always check before install
install_tool() {
  command_exists tool && { log_skip "tool installed"; return 0; }
  log_info "Installing tool..." && log_ok "tool installed"
}

# Available helpers in install.sh / install-binaries.sh:
# - run_privileged: sudo wrapper (skips sudo if root)
# - detect_os: returns "mac", "linux", or "termux"
# - is_inside_container: true if in docker/podman
# - get_arch: returns "x86_64" or "aarch64"
# - get_github_release_version "owner/repo": fetches latest version
```

**Quoting:** Always `"$var"`, `"$@"`. Use `${var:-default}` for defaults.

## Critical: zsh Config Order

The `.zshrc` is **order-sensitive**. Sections must execute in sequence:

1. **PATH setup** - tools available for rest of config
2. **Termux config** - sourced BEFORE compinit (sets fpath for completions)
3. **Oh My Zsh + compinit** - loads plugins and completions
4. **Tool aliases** (bat theming, fzf preview)
5. **Vi-mode keybindings** - resets some bindings
6. **OS-specific config** - `.zshrc.macos`, `.zshrc.linux` sourced at END

**Termux detection:** `is_termux()` checks `$TERMUX_VERSION` or `$PREFIX` containing `com.termux`.

**Startup order (macOS):** `~/.zshenv` → `/etc/zprofile` → `~/.zprofile` → `~/.zshrc`.
`/etc/zprofile` runs `path_helper`, which rebuilds PATH with `/etc/paths` first and
drops Homebrew behind `/usr/bin`, so `~/.zprofile` re-sources
`~/.zsh/path-macos.zsh` afterwards. That ordering is what makes
`#!/usr/bin/env bash` resolve to brew's bash 5 instead of Apple's 3.2 — `emojify`
(the git pager) refuses to run under 3.2 and sketchybar scripts use `mapfile`. The
module is idempotent: `typeset -U path PATH` makes the re-source a reorder.

**Login shell (macOS):** `/opt/homebrew/bin/zsh`, registered in `/etc/shells` and
applied by `set_macos_default_shell` in `install.sh` (needs sudo). `~/.zcompdump` is
keyed by `$ZSH_VERSION` because `compinit -C` skips its own version check and would
otherwise load a dump written by the other zsh.

**GUI launchers** (`aerospace.toml`, `open-in-neovim.applescript`) use
`/usr/bin/env zsh|bash`, never a Homebrew path. They can: AeroSpace substitutes its
own PATH for `exec-and-forget` (`aerospace list-exec-env-vars` — Homebrew first,
unlike the AeroSpace process env), and Ghostty, which executes the `-e` command and
surface commands, inherits that same PATH. Only launchd-spawned processes
(Automator, `do shell script`) get the bare `/usr/bin:/bin:/usr/sbin:/sbin`.

## Stow Package Layout

Packages mirror home directory structure:

```
nvim/.config/nvim/init.lua  →  ~/.config/nvim/init.lua
zsh/.zshrc                  →  ~/.zshrc
termux/.termux/colors.properties → ~/.termux/colors.properties
```

**NEVER use `stow --adopt`** - overwrites repo files with target files.

## OS-Specific Notes

| OS | Package Manager | Binary Names | Notes |
|----|-----------------|--------------|-------|
| macOS | Homebrew | upstream | Uses podman (docker shim provided) |
| Linux | apt + aptfile | bat, fdfind | Bat comes from GitHub release .deb; shims wrap remaining name mismatches |
| Termux | pkg | upstream | No sudo, no systemd, skips tailscale-et.sh |

**Termux detection must happen BEFORE Linux** in `detect_os()` because `uname -s` returns "Linux" on both.

## Android file actions in Termux

`scripts/termux/open-in-neovim/` contains the bundled APK, source, and build
instructions for **Open in Neovim** and **Show location in Termux** in one app.
These repository assets are Stow-ignored. On Termux, `./install.sh` stows the
helper and runs `scripts/termux/install-open-in-neovim.sh` to install the bundled
`scripts/termux/open-in-neovim/open-in-neovim.apk`.

The remaining setup steps are Android UI approvals: approve Termux shared-storage
access, allow APK installation from Termux if prompted, confirm installation,
and tap **Open** to approve the app's automatic `RUN_COMMAND` permission request.
The installer cannot silently install apps or grant Android permissions.
`scripts/termux/setup-storage.sh` runs native storage setup only when `~/storage`
is absent; existing storage trees are never rebuilt. Missing access opens the
Android permission settings instead.

Setup enables `allow-external-apps` while preserving existing settings in a
regular properties file. Native Termux ignores symlinked `termux.properties`;
setup migrates such settings without overwriting the symlink target. Reloading
is performed with Termux in the foreground. External-app access permits arbitrary
Termux commands, so grant `RUN_COMMAND` only to trusted apps.

Normal device bootstrap needs no APK copying, SDK/JDK, or SSH. Maintainers rebuild
the app on a machine with a JDK and Android SDK platform/build-tools:
```sh
ANDROID_HOME=/path/to/Android/Sdk scripts/termux/open-in-neovim/build.sh
```
The build output and persistent signing key/password live under
`${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/open-in-neovim/`. Keep the signing key
and its matching `.keystore.pass` outside the repository for upgrades. After
changing app source, run `build.sh` to rebuild and refresh the bundled
`scripts/termux/open-in-neovim/open-in-neovim.apk`.

The app passes original shared-storage paths to
`termux/.local/bin/termux-open-in-neovim` through Termux's `RUN_COMMAND` API; it
does not copy files into Downloads. In a file manager's Open with or Share menu:

- **Open in Neovim** edits the original; quitting leaves a shell in its parent.
- **Show location in Termux** prints the resolved original path and opens a shell
  in its parent directory without starting or requiring Neovim.

Private/cloud providers may expose only a `content://` URI with no accessible
path. Those show the URI and an explanation in Termux, without importing a copy.

## SketchyBar appearance reload

The hidden `DARK_LIGHT` item subscribes to macOS `AppleInterfaceThemeChangedNotification`.
On an appearance change, its plugin restarts the Homebrew service via
`launchctl kickstart -kp "gui/$UID/sh.brew.sketchybar"` to reload the palette.
The display-change plugin uses the same service target. Launchd enforces a 10-second
minimum runtime, so allow for that delay when checking repeated appearance switches.

## SketchyBar app font

The `font-sketchybar-app-font` cask remains the untouched stock input. `install.sh` generates a separate local overlay font and cached app map from ordered app-pattern-to-ligature entries in `scripts/macos/sketchybar-app-font/overrides.json` and custom artwork in its `svgs/` directory. SketchyBar startup only loads the existing local font and generated map; it does not run the installer or rebuild artifacts. After changing an SVG or override, or upgrading the cask, refresh explicitly and reload SketchyBar:
```sh
scripts/macos/sketchybar-app-font/install-sketchybar-app-font.sh
sketchybar --reload
```

## agent-reports

`zsh/.local/bin/agent-reports` runs [agent-reports](https://github.com/DeprecatedLuke/agent-reports) per machine
(macOS and Linux) from upstream's `Dockerfile` targets: `app` (Rust API, data in volume `agent-reports-data`) and
`web-static` (nginx). Both run in podman, or in docker if podman is missing, on network `agent-reports`. The server
is not started by `install.sh`; run it once per machine:

```sh
agent-reports up       # clone/pull ~/.local/share/agent-reports, build images per commit, (re)start
agent-reports status   # containers + health
agent-reports down     # remove containers, keep the volume
```

- Upstream's Traefik is replaced by an `/api` proxy spliced into upstream `web/nginx.conf` after its single
  `server_tokens off;` line. If upstream changes that line, `up` fails instead of serving without `/api`. The proxy
  injects the session cookie, the same way upstream's Vite dev proxy does, so the browser never logs in. Only
  publish it on localhost by default; the opt-in tunnel mapping below is bound separately.
- Per-machine token and nginx snippets live in `~/.local/state/agent-reports/`.
- The omp plugin is installed by `install.sh` (`setup_agent_reports_plugin`, mac/linux): it is a subdirectory of
  upstream, which `omp plugin install` cannot fetch, so it is `omp plugin link`ed from the same checkout. Its
  `session` setting is the placeholder `"<url> local"`: the proxy overwrites the Cookie header with the real token,
  so plugin settings hold no secret (on Linux containers `omp-plugins.lock.json` resolves into this repo). Set
  `AGENT_REPORTS_URL` before `install.sh` too when the server is not on `localhost:8790`.
- macOS needs `podman machine start`. Linux dev containers need a reachable engine: docker-in-docker, rootless
  podman, or a mounted docker socket. Docker-in-docker (privileged devcontainer with its own `dockerd`, as on
  `orange`) works like the Mac on `localhost`. `up` does not start `dockerd`; on an overlayfs root it must run
  with `--storage-driver=vfs`, as DrawRecog's `docker-compose-dind.yml` starts it. Default overlay storage fails
  the build with `mount source: "overlay" ... invalid argument`.
  With a mounted socket, published ports land on the docker host, and loopback there is not
  reachable from the dev container. Bind the bridge gateway instead:
  `AGENT_REPORTS_BIND=$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}')`
  (usually `172.17.0.1`), then set `AGENT_REPORTS_URL=http://$AGENT_REPORTS_BIND:8790`.
- With Docker-in-Docker, the existing AeroSpace Alt+Shift+O SSH tunnel can reach reports
  through an opt-in second publish while preserving the default localhost mapping:
  ```sh
  agent-reports up --docker-port          # default secondary port 18790
  agent-reports up --docker-port 18790     # explicit port
  ```
  `--docker-port` requires a detectable Docker/Podman container and `ip`; it selects the
  IPv4 source address for the default route using `ip -4 route get 1.1.1.1`. It fails
  rather than bind an unspecified address if the container or route address cannot be
  detected. Plain `agent-reports up` never adds this exposure and does not require `ip`.
  The option sets the secondary bind to `<detected-ip>:PORT` and the browser URL to
  `http://localhost:PORT`, overriding `AGENT_REPORTS_TUNNEL_BIND` and
  `AGENT_REPORTS_PUBLIC_URL`; it does not change `AGENT_REPORTS_URL` (default:
  `http://localhost:8790`). The existing environment-only tunnel settings remain supported.
  In the shortcut, set its internal address to the detected IP and use `PORT` for both
  local and remote ports: it forwards `localhost:PORT` to `<detected-ip>:PORT` on the SSH
  host. The shortcut's internal address defaults to `172.18.0.2`, but the detected
  address can differ or change when the container is recreated.
  The proxy injects the session cookie, so anyone who can reach the published port gets
  full API access. Keep the binding on a trusted interface; `0.0.0.0` or a LAN address is
  an intentional exposure, not a fix. `AGENT_REPORTS_PUBLIC_URL` (default: the plugin
  URL) is the browser origin the server puts in report links and security policies.
- The API container runs as distroless `nonroot` (65532) with `no-new-privileges`; `up` chowns the volume first.

## Ghostty

Ghostty config lives in `ghostty/.config/ghostty/` and stows to `~/.config/ghostty/`.

- Keep `macos-titlebar-style = hidden`; AeroSpace still matches the invisible window title used by btop.
- Keep exact light/dark palettes in `themes/Dotfiles Dark` and `themes/Dotfiles Light`; their names must match `theme` in `config`.
- Keep one-off commands out of the global `command` setting. AeroSpace and SketchyBar launch btop, tmux, and SSH with `open -na Ghostty.app --args ... -e ...`.
- `scripts/macos/btop/install-btop.sh` builds `/Applications/btop.app` for Spotlight, Raycast, and Alfred.
- Validate the staged config without stowing:

```bash
XDG_CONFIG_HOME="$PWD/ghostty/.config" \
  /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config
```

## Lua Style (Neovim)

2-space indent, 120 column width. LazyVim plugin format:

```lua
return {
  {
    "author/plugin-name",
    opts = { key = "value" },
  },
}
```

## File Types & Formatters

| Type | Formatter | Notes |
|------|-----------|-------|
| `.sh` | shfmt | shellcheck for linting, `bash -n` for syntax |
| `.lua` | stylua | 2-space indent, 120 cols |
| `.json/.jsonc` | prettier | Use `$schema` when available |
| `.toml` | - | Single quotes, `#` comments |

## Agent Rules

1. **No automated tests** - verify by syntax check and container testing
2. **Edit in repo** - never edit `~/.config/` directly (they're symlinks)
3. **Cross-platform** - changes to shared packages affect all 3 OS targets
4. **Order matters** - especially in `.zshrc` (Termux before compinit)
5. **Idempotency** - all install functions must be safe to run multiple times
6. **Container detection** - skip lazydocker/docker when inside containers
7. **No sudo on Termux** - use pkg directly, never run_privileged

## Common Patterns

### Adding a new tool (Linux)
1. Add to `Aptfile` if available via apt
2. Otherwise add install function to `scripts/linux/install-binaries.sh`
3. If binary name differs, add shim to `shims/linux/.local/bin/`

### Adding a new tool (macOS)
1. Add to `Brewfile` (brew or cask)
2. If podman-related, may need shim in `shims/macos/.local/bin/`

### Adding a new tool (Termux)
1. Add to `TermuxPkgfile` (one package per line)
2. Termux uses upstream binary names (no shims needed for bat/fd)

### Adding new dotfiles
1. Create package: `mkdir -p newpkg/.config/newpkg`
2. Add config files mirroring home structure
3. Add `run_stow -t ~ newpkg` to `install.sh`
4. Verify: `stow -n -t ~ newpkg` (dry-run)
