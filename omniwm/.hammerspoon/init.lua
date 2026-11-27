local actions = require("actions")

-- Applications and commands carried over from AeroSpace.
actions.bind({
  { modifiers = { "alt" }, key = "g", action = actions.openApp, args = { "Google Chrome" } },
  {
    modifiers = { "alt" },
    key = "t",
    action = actions.run,
    args = { "osascript", { "-e", 'tell application "Ghostty" to activate' } },
  },
  {
    modifiers = { "alt", "shift" },
    key = "t",
    action = actions.run,
    args = {
      "open",
      {
        "-na", "Ghostty.app", "--args", "--window-save-state=never", "--title=tmux-init",
        "-e", "/usr/bin/env", "PATH=" .. actions.homebrewPath, "zsh", "-lc",
        "exec tmux new-session -A -s init",
      },
    },
  },
  {
    modifiers = { "alt", "shift" },
    key = "o",
    action = actions.run,
    args = {
      "open",
      {
        "-na", "Ghostty.app", "--args", "--window-save-state=never", "--title=ssh-tunnel",
        "-e", "/usr/bin/env", "bash", hs.configdir .. "/ssh-tunnel.sh",
      },
    },
  },
  {
    modifiers = { "alt", "shift" },
    key = "escape",
    action = actions.run,
    args = {
      "open",
      {
        "-na", "Ghostty.app", "--args", "--window-save-state=never", "--title=btop",
        "-e", "/opt/homebrew/bin/btop",
      },
    },
  },
  {
    modifiers = { "alt", "shift" },
    key = "c",
    action = actions.run,
    args = { "zsh", { "-ic", "clipssh" } },
  },
  { modifiers = { "alt" }, key = "m", action = actions.openApp, args = { "Spotify" } },
  { modifiers = { "alt" }, key = "v", action = actions.openApp, args = { "WhatsApp" } },
  { modifiers = { "alt" }, key = "s", action = actions.openApp, args = { "Slack" } },
  { modifiers = { "alt" }, key = "y", action = actions.openApp, args = { "YouTube" } },
  { modifiers = { "alt" }, key = "f", action = actions.openApp, args = { "Finder" } },
  {
    modifiers = { "cmd", "alt", "shift" },
    key = "l",
    action = actions.run,
    args = {
      "open",
      { "-a", "Google Chrome", os.getenv("HOME") .. "/.private/redirect1.html" },
    },
  },
  {
    modifiers = { "ctrl", "cmd", "alt", "shift" },
    key = "l",
    action = actions.run,
    args = {
      "open",
      { "-a", "Google Chrome", os.getenv("HOME") .. "/.private/redirect2.html" },
    },
  },
  {
    modifiers = { "alt", "shift" },
    key = "s",
    action = actions.run,
    args = { "screencapture", { "-i", "-c" } },
  },
  { modifiers = { "alt" }, key = "pageup", action = actions.cycleOutput, args = { -1 }, repeatable = true },
  { modifiers = { "alt" }, key = "pagedown", action = actions.cycleOutput, args = { 1 }, repeatable = true },
})

actions.startWatchers()
