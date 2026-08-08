---
name: termux-remote-terminal
description: Diagnose and change behavior across Termux, OpenSSH or Eternal Terminal, remote Linux, Docker containers, tmux, OSC terminal controls, and PulseAudio reverse tunnels. Use for terminal themes, per-session state, PTY transport, nested remote shells, container networking, tmux escape handling, or audio forwarding in this dotfiles repository.
compatibility: This repository's Termux, zsh, Eternal Terminal, Docker, and tmux setup; some diagnostics require network access to the configured remote host.
---

# Termux remote terminal pipeline

Use this skill when a task crosses any part of this stack:

```text
Android Termux TerminalSession
  <-> local PTY
  <-> et client or OpenSSH client
  <-> network
  <-> etserver or sshd on the remote host
  <-> remote shell PTY
  <-> docker exec PTY
  <-> tmux client/server and pane PTY
  <-> process in the container
```

Reason about input, output, process ownership, filesystem namespaces, and network namespaces separately. A command available at the innermost prompt does not execute on the Termux device.

## Repository map

Relevant files:

- `zsh/.zsh/termux-theme.zsh`: sourced `termux-theme` function, OSC query, palette emission, and local persistence.
- `zsh/.zsh/termux-themes/{light,dark}.properties`: the only palette sources of truth.
- `zsh/.zsh/pulse-forward.zsh`: `sshpa` and `etpa` reverse-audio tunnel helpers.
- `zsh/.zshrc.linux`: selects the host or container-gateway PulseAudio endpoint.
- `tmux/.tmux.conf`: terminal features and tmux behavior.
- `termux/.termux/`: Termux app settings; it does not contain the shared palette definitions.

Do not introduce a second palette definition or another theme command. The public interface is exclusively:

```console
termux-theme
termux-theme light
termux-theme dark
```

## Connect and traverse the stack

Set generic identifiers before traversing the stack:

```console
REMOTE=user@host
CONTAINER=dev-container
SESSION=work
et "$REMOTE"
docker ps --format '{{.Names}}'
docker exec -it "$CONTAINER" zsh
tmux list-sessions
tmux attach-session -t "$SESSION"
```

`docker exec -it` matters: `-i` keeps stdin connected and `-t` allocates the PTY required by interactive shells and tmux.

When testing an existing tmux session:

1. Attach a new client; do not type into a pane running the user's application.
2. Press `Ctrl-b c` to create an isolated temporary window.
3. Run the experiment there.
4. Run `exit` to remove that window.
5. Press `Ctrl-b d` to detach only the test client.

For automated work, run ET as a supervised interactive process rather than an ordinary finite shell command. Wait for a real prompt before sending input. Remove remote `/tmp` files and temporary tmux windows afterward.

## Transport properties

### Eternal Terminal

ET transports PTY bytes transparently. Live tests confirmed that OSC bytes emitted directly and from a remote container reached the local terminal endpoint unchanged.

ET is not OpenSSH. OpenSSH escapes such as `~?` and `~C` do not apply to an ET session. Do not propose them as a control path for this workflow.

### OpenSSH

OpenSSH escape processing belongs to the outer local SSH client, not the remote shell. `~C` additionally requires `EnableEscapeCommandline yes`; local commands require `PermitLocalCommand yes`. These details are irrelevant when the connection is ET.

### Containers

A container has separate process, filesystem, and network namespaces:

- A remote/container command cannot call Android services such as `termux-reload-settings` on the Termux device.
- Files under the local Termux home are not automatically visible remotely.
- Reverse tunnels bind on the remote host; a container normally reaches them through its default-route gateway, not its own `127.0.0.1`.

### tmux

Current tmux understands OSC 4, 10, 11, and 12. Let tmux parse these sequences normally when later queries must reflect the applied palette.

Do not DCS-wrap theme OSC sequences with `ESC P tmux; ... ESC \\`. Passthrough reaches the outer terminal, but bypasses tmux's palette state. Tmux also consumes terminal OSC 10/11 replies, so a passthrough query cannot reliably return directly to the pane.

`allow-passthrough on` remains useful for unrelated protocols, but it is not the correct theme path.

Emit special colors separately. Tmux does not accept Termux's combined OSC 10 form:

```text
OSC 10 ; foreground ST
OSC 11 ; background ST
OSC 12 ; cursor ST
```

Do not send `OSC 10;foreground;background;cursor` through tmux.

## Termux palette state

There are two distinct states:

1. `~/.termux/colors.properties` is the persisted default used for new sessions and settings reloads.
2. Each live `TerminalSession` owns its actual in-memory `TerminalColors.mCurrentColors` palette.

Changing `colors.properties` from another Termux session does not identify or mutate the target session's actual palette. A settings reload resets the session currently selected by the Termux activity; it is not a general all-session update.

Consequences:

- Do not infer the visible palette solely from `colors.properties` or `.current-theme`.
- Do not recommend switching to a second local Termux session to update the first.
- Use an OSC query over the same PTY that displays the target session.

## Query the actual background

The correct query is OSC 11, not OSC 4:

```text
ESC ] 11 ; ? BEL
```

Termux responds with the current dynamic background:

```text
ESC ] 11 ; rgb:rrrr/gggg/bbbb BEL
```

OSC 4 addresses indexed palette entries. Palette index 0 is not the terminal's dynamic background, and Termux does not provide the required active-background semantics through OSC 4.

A robust query must:

1. Open `/dev/tty`, not stdin or captured stdout.
2. Save terminal settings with `stty -g`.
3. Enter raw, no-echo mode.
4. Send `OSC 11;?` with BEL termination.
5. Read until BEL with a short timeout.
6. Restore terminal settings unconditionally, including failure paths.
7. Parse `rgb:rrrr/gggg/bbbb` and classify luminance.

The repository implementation uses the weighted threshold:

```text
299 * red + 587 * green + 114 * blue >= 32768 * 1000
```

Light values meet the threshold; lower values are dark.

Inside current tmux, a bare OSC 11 query is answered from tmux's pane/client color state. The verified transition was:

```text
before=dark -> termux-theme -> light -> termux-theme -> dark
```

Before the first palette application, multiple attached clients with different backgrounds are inherently ambiguous because tmux may choose one attached client's background. Once the pane applies a theme, tmux tracks and distributes that palette consistently.

`tmux display-message -p '#{client_theme}'` is diagnostic only. It may be empty when the outer terminal did not answer tmux's startup query.

## Apply a palette

The shared property files define:

- `foreground`
- `background`
- `cursor`
- indexed colors `color0` through `color21`

Runtime emission is:

```text
OSC 4 ; 0 ; color0 ; ... ; 21 ; color21 ST
OSC 10 ; foreground ST
OSC 11 ; background ST
OSC 12 ; cursor ST
```

Local Termux behavior:

- `termux-theme` queries the actual current background and flips it.
- An explicit argument selects that palette.
- It copies the shared palette into `~/.termux/colors.properties`, updates `.current-theme`, and calls `termux-reload-settings` when available.

Remote/container behavior:

- `termux-theme` queries over the PTY and flips the actual visible palette.
- Explicit `light` or `dark` remains the fallback when the query times out or a terminal does not support it.
- Runtime OSC updates the active terminal path; it does not write the Termux device's persisted default.

## Theme verification

Check syntax first:

```console
zsh -n zsh/.zsh/termux-theme.zsh
zsh -n zsh/.zshrc
bash -n install.sh
```

Verify all generated values against the shared property files, including colors 0-21 and OSC 10/11/12. Test both explicit modes and the no-argument cycle.

Live stack smoke test:

```console
et "$REMOTE"
docker exec -it "$CONTAINER" zsh
tmux attach-session -t "$SESSION"
# Create an isolated tmux window.
source /path/to/termux-theme.zsh
before=$(_termux_theme_detect)
termux-theme
first=$(_termux_theme_detect)
termux-theme
second=$(_termux_theme_detect)
printf 'before=%s first=%s second=%s\n' "$before" "$first" "$second"
```

Expected transition is `dark light dark` or `light dark light`.

A harness PTY can prove byte transport and tmux state transitions, but it is not a visible Android `TerminalSession`. State that boundary when visual repaint was not directly observed.

## PulseAudio reverse forwarding

The same layering rules apply to audio.

From the local machine:

```console
sshpa "$REMOTE"
etpa "$REMOTE"
```

For applications in a remote container:

```console
etpa "$REMOTE" --container
```

`--container` uses the repository's default container-gateway bind address. Override it when the bridge differs:

```console
etpa "$REMOTE" --container=GATEWAY_ADDRESS
```

Both helpers default to port `47130`; override with `PULSE_FORWARD_PORT`. `PULSE_REMOTE_BIND` changes the default remote bind address.

`zsh/.zshrc.linux` sets `PULSE_SERVER` automatically:

- remote host: `tcp:127.0.0.1:47130`
- container: `tcp:<default-route-gateway>:47130`

Termux microphone capture requires the matching Termux:API app, microphone permission, and PulseAudio's `module-sles-source`. The forwarding helper selects a non-monitor source and exposes PulseAudio only on the requested tunnel endpoint.

## Failure diagnosis

Work from the outermost layer inward:

1. Confirm the local terminal supports or answers the relevant OSC query.
2. Confirm ET or SSH has an interactive PTY.
3. Confirm the remote shell receives exact bytes.
4. Confirm `docker exec` used `-it` and the container sees the expected environment.
5. Confirm the intended tmux server/session and `TMUX` value.
6. Distinguish tmux parsing from DCS passthrough.
7. Query `/dev/tty`; do not rely on redirected stdin/stdout.
8. Preserve and restore tty modes on every error path.
9. For network services, identify which namespace owns each loopback address.
10. Remove temporary windows, files, tunnels, and test clients after verification.
