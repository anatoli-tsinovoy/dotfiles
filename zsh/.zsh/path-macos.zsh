# macOS PATH ordering. Sourced from ~/.zshenv.macos and again from ~/.zprofile.
#
# Homebrew must outrank /usr/bin, otherwise `#!/usr/bin/env bash` resolves to
# Apple's bash 3.2 instead of brew's bash 5: emojify (the `git` pager) refuses
# to run under 3.2, and repo scripts use mapfile and other bash 4+ builtins.
# Same for zsh, so a `zsh` subshell matches the brew login shell.
#
# ~/.zshenv runs before /etc/zprofile, whose path_helper rebuilds PATH with the
# /etc/paths entries first — pushing /opt/homebrew/bin behind /usr/bin again.
# ~/.zprofile re-sources this file afterwards to restore the order; `typeset -U`
# makes that a reorder instead of a second copy, and also collapses the
# duplicates later prepends in ~/.zshrc would otherwise leave behind.
typeset -U path PATH
path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  /usr/local/et-bin
  /usr/local/bin
  $path
)
export PATH
