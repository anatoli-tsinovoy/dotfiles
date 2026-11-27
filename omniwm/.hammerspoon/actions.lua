local homebrewPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
local retainedHotkeys = {}
local pendingOutput
local outputTimer
local outputAlert
local inputSourceTimer
local hiddenApplicationWatcher

local actions = {
  homebrewPath = homebrewPath,
}

function actions.run(program, arguments)
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

function actions.openApp(name)
  actions.run("open", { "-a", name })
end

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

actions.cycleOutput = cycleOutput

local function bindHotkey(binding)
  local callback = function()
    binding.action(table.unpack(binding.args or {}))
  end
  local repeatCallback = binding.repeatable and callback or nil
  local hotkey = hs.hotkey.bind(binding.modifiers, binding.key, callback, nil, repeatCallback)
  if hotkey then
    table.insert(retainedHotkeys, hotkey)
  end
end

function actions.bind(bindings)
  for _, binding in ipairs(bindings) do
    bindHotkey(binding)
  end
end

function actions.startWatchers()
  -- OmniWM 0.8 can read the previous layout during the source-change notification.
  inputSourceTimer = hs.timer.delayed.new(0.2, function()
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
  hiddenApplicationWatcher = hs.application.watcher.new(function(_, event, application)
    if event == hs.application.watcher.hidden and application then
      application:unhide()
    end
  end)
  hiddenApplicationWatcher:start()
end

return actions
