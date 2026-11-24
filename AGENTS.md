# AGENTS.md - AI Agent Instructions for dotfiles Repository

Personal dotfiles for macOS, Linux, and Termux using GNU Stow for symlink management.

## Quick Reference

```bash
# Bootstrap (detects OS automatically: mac, linux, termux)
./install.sh                            # Full setup (packages + stow)
./install.sh --force                    # Force other conflicts; preserve app settings

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
├── omniwm/                # OmniWM + Hammerspoon config (macOS only)
├── ghostty/               # Ghostty config and light/dark themes
├── keycastr/              # Not stowed; io.github.keycastr.plist written key by key by apply_keycastr_settings in install.sh, right after brew bundle
└── tern/                  # Not stowed; applied by apply_tern_settings in install.sh (mac/linux, only with `tern` on PATH)
    ├── settings.json      # Keys merged into <tern config dir>/settings.json
    └── themes/*.css       # CSS themes (@import the omp dotfiles-* themes) symlinked into <tern config dir>/themes/
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
drops Homebrew behind `/usr/bin`. Re-sourcing `~/.zsh/path-macos.zsh` from
`~/.zprofile` restores Homebrew order, so `/usr/bin/env bash` resolves to brew's
bash 5; the `emojify` git pager does not run under Apple's 3.2. The module is
idempotent: `typeset -U path PATH` makes the re-source a reorder.

**Login shell (macOS):** `/opt/homebrew/bin/zsh`, registered in `/etc/shells` and
applied by `set_macos_default_shell` in `install.sh` (needs sudo). `~/.zcompdump` is
keyed by `$ZSH_VERSION` because `compinit -C` skips its own version check and would
otherwise load a dump written by the other zsh.

**GUI launchers** (including `omniwm/.hammerspoon/init.lua` and
`open-in-neovim.applescript`) do not inherit the interactive shell PATH.
Hammerspoon shell bindings prepend Homebrew's bin directories explicitly;
Ghostty commands use `/usr/bin/env` and inherit their caller's environment.

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

## OmniWM and Hammerspoon

The macOS bootstrap installs the OmniWM and Hammerspoon casks, then stows
`omniwm/` with `--no-folding`. Keep `~/.config/omniwm` a real directory:
OmniWM writes generated settings/assets there, while the tracked defaults and
Hammerspoon config remain individual symlinks into this checkout.

OmniWM is a macOS window manager inspired by Niri, not the Niri Wayland
compositor. It uses macOS window/Space APIs; Niri's runtime, IPC and exact
configuration behavior do not transfer directly. OmniWM workspace IDs are
numeric 1–15; the corresponding labels are `1`–`9`, then `a`–`f` for IDs
10–15.

The OmniShell workspace bar is full-width and flush with the top of the screen.
In this mode OmniWM auto-hides the macOS menu bar; use OmniShell's App Menu
widget to reach the focused app's menus. The OmniWM logo widget is hidden.
The `dotfiles` OmniShell palette follows macOS appearance, using the old SketchyBar
light colors in Light mode and dark colors in Dark mode. It keeps OmniShell's
built-in widgets and uses the SketchyBar App Font with a custom glyph overlay for
application icons. The bar is 40 points tall, with 5 points of space above and
below the workspace capsules. `shell/lib/look.luau` sets the capsule inset using
the bundled skin. The profile sets `workspaceBar.backgroundOpacity` to `1.0` so
the theme controls the 50% fill.

The standalone font comes from
[SketchyBar App Font](https://github.com/kvndrsslr/sketchybar-app-font); the
Homebrew cask installs the font only, not the SketchyBar daemon. The tracked
overlay sources are `scripts/macos/sketchybar-app-font/overrides.json` for
app-name mappings and `scripts/macos/sketchybar-app-font/svgs/*.svg` for custom
glyph artwork. Edit the JSON mappings and SVG artwork as needed, then explicitly
rebuild with:

```sh
bash scripts/macos/sketchybar-app-font/install-sketchybar-app-font.sh
```

The bootstrap runs this rebuild after stowing OmniWM; source edits alone do not
refresh `~/.config/omniwm/shell/lib/app-font-map.luau` or the font files under
`~/.config/omniwm/shell/fonts/`. These generated runtime artifacts are not tracked.
After replacing the registered font file, restart OmniWM to load it.

OmniWM draws a 2.5-point teal-to-purple focus border. Fullscreen layout frames
retain outer gaps so a lone tiled window's border clears the bar and screen
edges. JankyBorders is not part of the setup.

OmniShell keeps media, notifications, Wi-Fi, battery details, Control Center,
and the clock/calendar. Its compact audio icons distinguish the active output
and volume level without labels; the volume icon still opens the native mixer.
Hammerspoon previews and cycles outputs on Option+PageUp/Option+PageDown.
The language badge uses A for ABC and א for Hebrew; macOS Control+Space switches
layouts. Hammerspoon sends the settled source ID to the badge after a macOS
source-change event to avoid a stale OmniWM 0.8 reading. No polling.

### Window and command shortcuts

The configured window-manager bindings retain these semantics:

| Action | Shortcut |
| --- | --- |
| Focus left/down/up/right | Option+H/J/K/L |
| Move window left/down/up/right | Option+Shift+H/J/K/L |
| Switch to workspaces 1–9 | Option+1 through Option+9 |
| Switch to workspaces 10–15 (labels a–f) | Control+Option+1 through Control+Option+6 |
| Move window to workspaces 1–9 | Option+Shift+1 through Option+Shift+9 |
| Move window to workspaces 10–15 | Control+Option+Shift+1 through Control+Option+Shift+6 |
| Switch to previous workspace | Option+Tab |
| Move workspace to the right monitor (no wrap; respects workspace home) | Option+Shift+Tab |
| Move focused window to the right monitor (no wrap) | Control+Option+Shift+Tab |
| Toggle fullscreen | Control+Option+Up |
| Balance window sizes | Control+Option+Down |
| Toggle Niri/Dwindle layout | Option+/ |
| Open Menu Anywhere | Shift+Option+M |

Hammerspoon owns the shell/application shortcuts and prepends Homebrew's bin
directories explicitly. Option+G/T/M/V/S/Y/F opens Chrome, Ghostty, Spotify,
WhatsApp, Slack, YouTube and Finder; Option+Shift+T opens the shared tmux
session, Option+Shift+O opens the SSH tunnel, and Option+Shift+C runs ClipSSH.
Option+Shift+S starts an interactive screenshot. These commands do not depend
on a SketchyBar widget.

### First activation and rollback

Before switching, grant Accessibility permission to both OmniWM and Hammerspoon,
and Input Monitoring permission to OmniWM, under System Settings → Privacy &
Security. Enable Displays have separate Spaces in System Settings → Desktop &
Dock → Mission Control. macOS may require a manual logout/login after changing
that setting or granting permissions. `install.sh` never logs out, changes
Login Items, or stops the currently running legacy apps.

Keep AeroSpace, SketchyBar and JankyBorders installed until OmniWM is verified.
Leave currently running bar/borders in the existing session until the approved
permissions/logout transition. At the new session, disable AeroSpace in System
Settings → General → Login Items and enable OmniWM and Hammerspoon there.
Then stop SketchyBar and quit AeroSpace; its old config starts `borders`
standalone, so `brew services stop borders` alone may not stop it:

```sh
brew services stop sketchybar
if pgrep -x borders >/dev/null; then pkill -x borders; fi
```

The Brewfile installs the standalone SketchyBar App Font cask, not SketchyBar or
JankyBorders; the bootstrap does not uninstall any existing copies.

The bootstrap only unlinks `~/.config/aerospace` and
`~/.config/sketchybar` when each is a symlink resolving exactly to this
checkout's former `aerospace/.config/...` paths, including a broken symlink
whose normalized target is that exact path. Real directories, unrelated
symlinks and links to an archived/other checkout are left alone. This occurs
only after the OmniWM app bundle is present and the new package has stowed.
Stow reports unowned-file conflicts rather than overwriting them by default;
`--force` preserves conflicts under `.config/omniwm` and `.hammerspoon`, so
Stow may still stop on a same-file conflict that must be reviewed and merged.
`--force` may remove other unowned conflicts; `--adopt` is unsafe.

For rollback, use a retained worktree at the previous dotfiles commit: unstow
only the new WM package, then re-stow the old one and restore its login/service
items. Stow removes its symlinks without deleting OmniWM's generated settings:

```sh
cd /path/to/current-dotfiles
stow -D --no-folding -t ~ omniwm
cd /path/to/previous-commit-worktree
stow -t ~ aerospace
```

Re-enable AeroSpace in Login Items, start SketchyBar, and launch AeroSpace
(which starts its configured border process) only after restoring the old
configuration:

```sh
brew services start sketchybar
open -a AeroSpace
```

## Chrome PWAs (macOS)

`setup_chrome_pwas` in `install.sh` keeps the YouTube and Netflix Chrome PWAs installed. Chrome
installs PWAs silently only through an enforced `WebAppInstallForceList` policy (MDM or an approved
configuration profile; `defaults write` sets recommended level, which this policy ignores), so the
script asks per missing app, opens its site in Chrome and polls
`~/Applications/Chrome Apps.localized/*.app` until the user clicks Install (any key skips).
Apps are matched by `CrAppModeShortcutURL` in their `Info.plist`, since bundle IDs
(`com.google.Chrome.app.<id>`) differ per install. Netflix serves its manifest only when logged in.
Without a terminal on stdin, missing apps are only reported. Add apps to the `apps` array there.

## Tern

Tern is an invite-only download with no package-manager source, so the user installs it by hand
(macOS: `Tern.app`, with `~/.local/bin/tern` linking to `Tern.app/Contents/MacOS/tern`).
`apply_tern_settings` in `install.sh` runs on macOS and Linux only when `tern` is on PATH, and needs `jq`.

- Config dir: the parent of `tern plugin dir`, which honours `$TERN_CONFIG_DIR` and Tern's per-OS
  default (`~/Library/Application Support/Tern` on macOS).
- `settings.json` is not stowed: Tern saves by writing `settings.json.tmp` and renaming it over the
  file (checked in 0.9.34), which replaces a symlink with a regular file. `install.sh` deep-merges
  `tern/settings.json` into the live file instead; repo keys win, other live keys stay. Tern also
  drops keys equal to its defaults on save, so a repo key set to a default disappears from the live
  file after the next UI change without changing behaviour.
- Settings changed in the Tern UI land only in the live file; copy them into `tern/settings.json`
  or the next `install.sh` reverts them.
- `tern/themes/*.css` are only read by Tern, so they are symlinked into `<config dir>/themes/`.

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
- With Docker-in-Docker, the existing Hammerspoon Option+Shift+O SSH tunnel can reach reports
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

- Keep `macos-titlebar-style = hidden`; OmniWM still matches the invisible window title used by btop.
- Keep exact light/dark palettes in `themes/Dotfiles Dark` and `themes/Dotfiles Light`; their names must match `theme` in `config`.
- Keep one-off commands out of the global `command` setting. Hammerspoon launches btop, tmux and SSH with `open -na Ghostty.app --args ... -e ...`.
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
