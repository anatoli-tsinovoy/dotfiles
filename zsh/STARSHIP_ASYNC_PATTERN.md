# Async Starship pattern for Zsh

Use this pattern when Starship's `git_status` or toolchain modules delay every prompt. It keeps cheap context current, shows the last slow result immediately, and refreshes slow modules in a managed Zsh worker.

## Prerequisites

- Zsh 5.2 or newer
- Starship with named prompt profiles (`starship prompt --profile NAME`)
- [`mafredri/zsh-async`](https://github.com/mafredri/zsh-async)

Install the worker library somewhere stable, for example:

```sh
git clone --depth=1 https://github.com/mafredri/zsh-async.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-async"
```

## 1. Split the Starship format

Keep the normal format for shells that do not load the async integration. Add fast, slow, and superslow profiles to `~/.config/starship.toml`:

```toml
format = '$os$all'

# This timeout affects slow work in the background profile, not input readiness.
command_timeout = 3000

[profiles]
async-fast = '$os$username$directory$git_branch$git_commit${git_state}__STARSHIP_ASYNC_FAST_SPLIT__$cmd_duration$line_break$jobs$battery$time$status$container$netns$shell$character'
async-slow = '__STARSHIP_ASYNC_SLOW_BEGIN__${all}__STARSHIP_ASYNC_SLOW_END__${custom.aws_identity}$os$username$directory$git_branch$git_commit$git_state$cmd_duration$line_break$jobs$battery$time$status$container$netns$shell$character'
async-superslow = '__STARSHIP_ASYNC_SUPERSLOW_BEGIN__${custom.aws_identity}__STARSHIP_ASYNC_SUPERSLOW_END__'
```

Modules named explicitly in `async-slow` are excluded from `${all}`. The text between the slow markers therefore contains every module not assigned to the fast or superslow profiles. Keep the fast module list explicit after the slow end marker, and name every superslow module there as well so `${all}` cannot run it on the ordinary slow worker.

## 2. Load components in order

In `.zshrc`, initialize Starship first so its `precmd` hook captures status, pipeline status, duration, and jobs. Load the async wrapper afterward:

```zsh
ZSH_PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
source "$ZSH_PLUGIN_DIR/zsh-async/async.zsh"
eval "$(starship init zsh)"
source "$HOME/.zsh/starship-async.zsh"
```

If `zsh-async` is optional, guard both `source` calls with `[[ -r ... ]]`. The wrapper must return without changing `PROMPT` when the worker API is unavailable; normal synchronous Starship is the fallback.

## 3. Implement the wrapper

The wrapper is a small state machine around separate `zsh-async` workers for slow and superslow work:

Scheduling class and cache scope are independent. A job chooses a worker from its latency class (`slow` or `superslow`) and separately declares a cache scope (`directory` or `shell`) plus a cache key. The current slow-module job is directory-scoped; the AWS identity job happens to be both superslow and shell-scoped.

1. Save Starship's original dynamic `PROMPT` and `RPROMPT`.
2. Start unique slow and superslow workers with `async_start_worker NAME -u -n` and register the same callback for both.
3. In a later `precmd` hook:
   - Flush both workers' previous jobs.
   - Increment a shared generation number.
   - Resolve a physical PWD (`${PWD:A}`).
   - Run `starship prompt --profile async-fast` synchronously with Starship's captured `--status`, `--pipestatus`, `--cmd-duration`, `--jobs`, terminal width, and keymap.
   - Split the output at `__STARSHIP_ASYNC_FAST_SPLIT__`.
   - Read each result through the scope-aware cache API: slow modules from `directory:slow_modules:$PWD`, AWS identity from `shell:aws_identity`.
   - Queue the slow-module job on the slow worker and the AWS identity job on the superslow worker.
4. In the shared worker callback:
   - Reject nonzero results.
   - Reject results whose generation or physical PWD no longer matches.
   - Select markers, cache scope, and cache key from the completed job identity—not from its worker or latency class.
   - Extract only the text between that profile's begin and end markers.
   - Update the declared cache scope, rebuild from both cache keys, and redraw without waiting for the other worker.
5. Flush both workers in `preexec`; stop both in `zshexit`.
6. Preserve Starship's existing `zle-keymap-select` widget and refresh only the fast profile when the keymap changes.

### Required safety invariant

Starship enables `PROMPT_SUBST`. Never assign rendered repository-controlled text directly to `PROMPT`; a branch or directory containing `$(command)` could be evaluated by Zsh. Store the rendered prompt in a backing scalar and make `PROMPT` a literal, single-level reference:

```zsh
typeset -g _STARSHIP_ASYNC_RENDERED_PROMPT=''
PROMPT='$_STARSHIP_ASYNC_RENDERED_PROMPT'
```

On any fast-profile failure or missing marker, restore Starship's original dynamic prompt instead of leaving stale directory or status data visible.

## Expected behavior

- First visit to a directory: OS, path, branch, status character, and input line appear immediately; slow segments are temporarily absent.
- When background work completes: Git status and toolchain/package versions appear through an in-place redraw.
- Later prompts in the same directory: the last slow result appears immediately, then refreshes.
- A quick command or `cd`: the old job is cancelled, and generation/PWD checks prevent stale results from repainting the new prompt.

Validate with a clean directory, a dirty large repository, a toolchain-heavy project, a failed command, rapid directory changes, and a directory literally named `$(touch /tmp/prompt-injection-test)`. The final case must not create that file.
