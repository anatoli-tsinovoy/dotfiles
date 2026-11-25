local home = os.getenv("HOME")
local homebrewPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

local function run(program, arguments)
  local argv = { "PATH=" .. homebrewPath, program }
  for _, argument in ipairs(arguments or {}) do
    table.insert(argv, argument)
  end

  local task = hs.task.new("/usr/bin/env", function(exitCode, _, stderr)
    if exitCode ~= 0 then
      local message = (stderr or ""):gsub("%s+$", "")
      hs.alert.show(message ~= "" and message or (program .. " exited " .. tostring(exitCode)))
    end
  end, argv)

  if not task or not task:start() then
    hs.alert.show("Unable to start " .. program)
  end
  return task
end

local hotkeys = {}
local function bind(modifiers, key, callback, repeatCallback)
  local hotkey = hs.hotkey.bind(modifiers, key, callback, nil, repeatCallback)
  if hotkey then
    table.insert(hotkeys, hotkey)
  end
end

local function openApp(name)
  run("open", { "-a", name })
end

-- Applications and commands carried over from AeroSpace.
bind({ "alt" }, "g", function() openApp("Google Chrome") end)
bind({ "alt" }, "t", function()
  run("osascript", { "-e", 'tell application "Ghostty" to activate' })
end)
bind({ "alt", "shift" }, "t", function()
  run("open", {
    "-na", "Ghostty.app", "--args", "--window-save-state=never", "--title=tmux-init",
    "-e", "/usr/bin/env", "PATH=" .. homebrewPath, "zsh", "-lc",
    "exec tmux new-session -A -s init",
  })
end)
bind({ "alt", "shift" }, "o", function()
  run("open", {
    "-na", "Ghostty.app", "--args", "--window-save-state=never", "--title=ssh-tunnel",
    "-e", "/usr/bin/env", "bash", hs.configdir .. "/ssh-tunnel.sh",
  })
end)
bind({ "alt", "shift" }, "escape", function()
  run("open", {
    "-na", "Ghostty.app", "--args", "--window-save-state=never", "--title=btop",
    "-e", "/opt/homebrew/bin/btop",
  })
end)
bind({ "alt", "shift" }, "c", function()
  run("zsh", { "-ic", "clipssh" })
end)
bind({ "alt" }, "m", function() openApp("Spotify") end)
bind({ "alt" }, "v", function() openApp("WhatsApp") end)
bind({ "alt" }, "s", function() openApp("Slack") end)
bind({ "alt" }, "y", function() openApp("YouTube") end)
bind({ "alt" }, "f", function() openApp("Finder") end)
bind({ "cmd", "alt", "shift" }, "l", function()
  run("open", { "-a", "Google Chrome", home .. "/.private/redirect1.html" })
end)
bind({ "ctrl", "cmd", "alt", "shift" }, "l", function()
  run("open", { "-a", "Google Chrome", home .. "/.private/redirect2.html" })
end)
bind({ "alt", "shift" }, "s", function()
  run("screencapture", { "-i", "-c" })
end)

-- Cycle output devices without SwitchAudioSource; apply after the key sequence settles.
local pendingOutput
local outputTimer
local outputAlert
local function showOutputAlert(message)
  if outputAlert then
    hs.alert.closeSpecific(outputAlert)
  end
  outputAlert = hs.alert.show(message, 0.8)
end

local function cycleOutput(direction)
  local devices = hs.audiodevice.allOutputDevices() or {}
  if #devices == 0 then
    if outputTimer then
      outputTimer:stop()
      outputTimer = nil
    end
    pendingOutput = nil
    showOutputAlert("No audio outputs available")
    return
  end

  local currentUID = pendingOutput and pendingOutput.uid
  if not currentUID then
    local current = hs.audiodevice.defaultOutputDevice()
    currentUID = current and current:uid()
  end

  local currentIndex
  for index, device in ipairs(devices) do
    if device:uid() == currentUID then
      currentIndex = index
      break
    end
  end
  if not currentIndex then
    currentIndex = direction > 0 and 0 or 1
  end

  local targetIndex = ((currentIndex - 1 + direction) % #devices) + 1
  local candidates = {}
  for offset = 0, #devices - 1 do
    local index = ((targetIndex - 1 + direction * offset) % #devices) + 1
    local device = devices[index]
    candidates[#candidates + 1] = { uid = device:uid(), name = device:name() }
  end
  local target = candidates[1]
  pendingOutput = { uid = target.uid, candidates = candidates }
  showOutputAlert("Audio: " .. target.name)

  if outputTimer then
    outputTimer:stop()
  end
  outputTimer = hs.timer.doAfter(0.35, function()
    outputTimer = nil
    local selection = pendingOutput
    pendingOutput = nil
    if not selection then
      return
    end

    local available = {}
    for _, device in ipairs(hs.audiodevice.allOutputDevices() or {}) do
      available[device:uid()] = device
    end
    for _, candidate in ipairs(selection.candidates) do
      local device = available[candidate.uid]
      if device and device:setDefaultOutputDevice() then
        local current = hs.audiodevice.defaultOutputDevice()
        if current and current:uid() == candidate.uid then
          showOutputAlert("Audio: " .. candidate.name)
          return
        end
      end
    end
    showOutputAlert("Could not select an audio output")
  end)
end

bind({ "alt" }, "pageup", function() cycleOutput(-1) end, function() cycleOutput(-1) end)
bind({ "alt" }, "pagedown", function() cycleOutput(1) end, function() cycleOutput(1) end)

-- OmniWM 0.8 can read the previous layout during the source-change notification.
local inputSourceTimer = hs.timer.delayed.new(0.2, function()
  local source = hs.keycodes.currentSourceID()
  if source then
    local task = hs.task.new("/usr/bin/env", function(exitCode, _, stderr)
      if exitCode ~= 0 then
        hs.printf("OmniShell input source update failed: %s", stderr)
      end
    end, {
      "PATH=" .. homebrewPath, "omniwmctl", "shell", "set", "dotfilesInputSourceID", source,
    })
    if task then
      task:start()
    end
  end
end)
hs.keycodes.inputSourceChanged(function() inputSourceTimer:start() end)
inputSourceTimer:start()

-- Respond only to native app-hide events; window minimization and OmniWM parking are separate.
local hiddenApplicationWatcher = hs.application.watcher.new(function(_, event, application)
  if event == hs.application.watcher.hidden and application then
    application:unhide()
  end
end)
hiddenApplicationWatcher:start()
