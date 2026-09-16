DMSounds = {}

DMSounds.version = "1.1.1"
DMSounds.tag = "[<DarkOrchid>DMSounds<r>] "
DMSounds.silenceUrl = DMSounds.silenceUrl or
  "https://github.com/anars/blank-audio/raw/refs/heads/master/5-seconds-of-silence.mp3"
DMSounds.silenceName = DMSounds.silenceName or "5-seconds-of-silence.mp3"
DMSounds.debug = DMSounds.debug or false
DMSounds.config = DMSounds.config or {}
DMSounds.config.silenceDuration = tonumber(DMSounds.config.silenceDuration) or 5
if DMSounds.config.silenceDuration <= 0 then
  DMSounds.config.silenceDuration = 5
end

local ALIAS_KEY = "DMSounds.Commands"
local PROMPT_EVENT_KEY = "DMSounds.Prompt"
local MAP_EVENT_KEY = "DMSounds.MapArea"
local STARTUP_TIMER_KEY = "DMSounds.StartupGrace"
local PENDING_TIMER_KEY = "DMSounds.PendingPlayback"

local function report(message)
  if type(cecho) == "function" then
    cecho("\n" .. DMSounds.tag .. tostring(message) .. "\n")
  end
end

local function debugReport(message)
  if DMSounds.debug then report(message) end
end

local function mudletFunction(name)
  local fn = _G[name]
  return type(fn) == "function" and fn or nil
end

local function globalSetting(key, fallback)
  if Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings[key] ~= nil then
    return Darkmists.GlobalSettings[key]
  end
  return fallback
end

local function saveSettings()
  if Darkmists and type(Darkmists.SaveSettings) == "function" then
    pcall(Darkmists.SaveSettings)
  end
end

local function syncConfig()
  DMSounds.config.enabled = globalSetting("dmsoundsEnabled", false) == true
  local volume = tonumber(globalSetting("dmsoundsVolume", 100)) or 100
  DMSounds.config.volume = math.floor(math.max(0, math.min(100, volume)))
end

local function cancelPendingPlayback()
  if DarkmistsTimer and type(DarkmistsTimer.remove) == "function" then
    pcall(DarkmistsTimer.remove, PENDING_TIMER_KEY)
  end
  DMSounds._pendingTimer = nil
end

local function stopSilence()
  local stopSound = mudletFunction("stopSoundFile")
  if stopSound then
    pcall(stopSound, {tag = "silence"})
  end
end

local function stopAmbience()
  local stopMusicFile = mudletFunction("stopMusic")
  if stopMusicFile then
    pcall(stopMusicFile, {tag = "ambience"})
  end
  DMSounds.currentTrack = nil
end

local function resolveTrackMap()
  local map = {}
  local areaMap = rawget(_G, "DMSoundsAreaMap")
  local catalogue = rawget(_G, "DMSoundsCatalogue")
  if type(areaMap) ~= "table" or type(catalogue) ~= "table" then
    return map
  end

  for areaName, trackName in pairs(areaMap) do
    map[areaName] = catalogue[trackName]
  end
  return map
end

local function getCurrentArea()
  if type(getPlayerRoom) ~= "function"
      or type(getRoomArea) ~= "function"
      or type(getRoomAreaName) ~= "function" then
    return nil
  end

  local ok, area = pcall(function()
    return getRoomAreaName(getRoomArea(getPlayerRoom()))
  end)
  if not ok or not area or area == "" then
    return nil
  end
  return area
end

local function resolveAreaName(areaId)
  if not areaId or type(getRoomAreaName) ~= "function" then return nil end
  local ok, area = pcall(getRoomAreaName, areaId)
  if not ok or not area or area == "" then return nil end
  return area
end

local function playSilenceFile()
  local playSound = mudletFunction("playSoundFile")
  if not playSound then
    report("playSoundFile is unavailable; cannot play transition silence")
    return false
  end

  if not DMSounds.silenceUrl or DMSounds.silenceUrl == "" then
    report("silence url is not set; cannot play the transition silence")
    return false
  end

  local downloadUrl = DMSounds.silenceUrl:match("^(.*[/\\])") or DMSounds.silenceUrl
  local ok, errorMessage = pcall(playSound, {
    name = DMSounds.silenceName,
    url = downloadUrl,
    volume = DMSounds.config.volume,
    tag = "silence",
  })
  if not ok then
    report("could not play silence file: " .. tostring(errorMessage))
    return false
  end

  debugReport("playing transition silence for " .. tostring(DMSounds.config.silenceDuration) .. " seconds")
  return true
end

local function startStartupGrace()
  DMSounds._startupGrace = true
  DMSounds._startupTimer = nil
  if DarkmistsTimer and type(DarkmistsTimer.add) == "function" then
    DMSounds._startupTimer = DarkmistsTimer.add(STARTUP_TIMER_KEY, DMSounds.config.silenceDuration, function()
      DMSounds._startupTimer = nil
      DMSounds._startupGrace = false
    end)
  else
    DMSounds._startupGrace = false
  end
end

local function playTrack(track)
  local playMusic = mudletFunction("playMusicFile")
  if type(track) ~= "table" or not playMusic then
    if not playMusic then
      report("playMusicFile is unavailable; cannot play ambience")
    end
    return false
  end

  local downloadUrl = track.url
  if downloadUrl then
    downloadUrl = downloadUrl:match("^(.*[/\\])") or downloadUrl
  end

  local ok, errorMessage = pcall(playMusic, {
    name = track.filename,
    continue = true,
    url = downloadUrl,
    tag = "ambience",
    volume = DMSounds.config.volume,
  })
  if not ok then
    report("could not play music file " .. tostring(track.filename) .. ": " .. tostring(errorMessage))
    return false
  end

  DMSounds.currentTrack = track
  startStartupGrace()
  debugReport("playing music: " .. tostring(track.filename))
  return true
end

local function getPlayingAmbience()
  local getMusic = mudletFunction("getPlayingMusic")
  if not getMusic then
    return nil, false
  end

  local ok, playing = pcall(getMusic)
  if not ok or type(playing) ~= "table" then
    return nil, false
  end

  for _, music in pairs(playing) do
    if type(music) == "table" and music.tag == "ambience" then
      return music.name, true
    end
  end
  return nil, true
end

local function getActiveAreaName()
  if DMSounds.mapperArea then
    local mapperName = resolveAreaName(DMSounds.mapperArea)
    if mapperName then return mapperName end
  end
  return getCurrentArea()
end

local function playAreaByName(areaName)
  if not DMSounds.config.enabled or not areaName or areaName == "" then return false end
  if areaName == DMSounds.currentArea then
    debugReport("area unchanged: " .. areaName)
    return false
  end

  local track = DMSounds.ambientSoundMap[areaName]
  DMSounds.currentArea = areaName
  cancelPendingPlayback()
  stopAmbience()
  stopSilence()
  playSilenceFile()

  if not track then
    report("no sound file for area: " .. areaName)
    if type(cecho) == "function" then
      cecho(string.format("[\"%s\"] = none,\n", areaName))
    end
    return true
  end

  return playTrack(track)
end

local function restartCurrentTrack()
  local activeArea = getActiveAreaName()
  if not activeArea then return false end
  if activeArea ~= DMSounds.currentArea then
    playAreaByName(activeArea)
    return true
  end

  local track = DMSounds.ambientSoundMap[activeArea]
  if not track then return false end
  cancelPendingPlayback()
  stopAmbience()
  stopSilence()
  playSilenceFile()
  return playTrack(track)
end

function DMSounds.checkPlayback()
  if not DMSounds.config.enabled then return false end

  local activeArea = getActiveAreaName()
  if not activeArea then return false end
  if activeArea ~= DMSounds.currentArea then
    return playAreaByName(activeArea)
  end

  local expectedTrack = DMSounds.ambientSoundMap[activeArea]
  if not expectedTrack then return false end

  local playingTrack, available = getPlayingAmbience()
  if not available then
    debugReport("getPlayingMusic is unavailable; playback watchdog skipped")
    return false
  end
  if playingTrack == expectedTrack.filename then return false end
  if DMSounds._startupGrace then
    debugReport("playback check skipped during startup grace period")
    return false
  end

  debugReport("ambience is not playing; restarting " .. tostring(expectedTrack.filename))
  return restartCurrentTrack()
end

function DMSounds.update()
  if not DMSounds.config.enabled then
    debugReport("music is disabled")
    return false
  end

  local activeArea = getActiveAreaName()
  if not activeArea then return false end
  return playAreaByName(activeArea)
end

function DMSounds.stop()
  cancelPendingPlayback()
  if DarkmistsTimer and type(DarkmistsTimer.remove) == "function" then
    pcall(DarkmistsTimer.remove, STARTUP_TIMER_KEY)
  end
  DMSounds._startupTimer = nil
  DMSounds._startupGrace = false
  stopSilence()
  stopAmbience()
  report("stopped")
end

function DMSounds.playSilence()
  cancelPendingPlayback()
  stopAmbience()
  stopSilence()
  return playSilenceFile()
end

DMSounds.playTrack = playTrack

function DMSounds.setEnabled(enabled)
  DMSounds.config.enabled = enabled == true
  if Darkmists and Darkmists.GlobalSettings then
    Darkmists.GlobalSettings.dmsoundsEnabled = DMSounds.config.enabled
  end

  if DMSounds.config.enabled then
    report("enabled")
    DMSounds.currentArea = ""
    DMSounds.update()
  else
    DMSounds.stop()
    report("disabled")
  end
  return true
end

function DMSounds.toggle()
  return DMSounds.setEnabled(not DMSounds.config.enabled)
end

function DMSounds.status()
  local pending = DMSounds._pendingTimer and "yes" or "no"
  local mapperName = DMSounds.mapperArea and resolveAreaName(DMSounds.mapperArea) or nil
  local source = mapperName and ("map: " .. mapperName) or "prompt"
  report(string.format(
    "enabled: %s | source: %s | area: %s | track: %s | transition pending: %s | volume: %d | silence: %s",
    DMSounds.config.enabled and "yes" or "no",
    source,
    DMSounds.currentArea ~= "" and DMSounds.currentArea or "none",
    (DMSounds.currentTrack and DMSounds.currentTrack.filename) or "none",
    pending,
    DMSounds.config.volume,
    DMSounds.silenceName
  ))
end

function DMSounds.setVolume(value)
  local volume = tonumber(value)
  if not volume or volume < 0 or volume > 100 then
    report("volume must be a number from 0 to 100")
    return false
  end

  DMSounds.config.volume = math.floor(volume)
  if Darkmists and Darkmists.GlobalSettings then
    Darkmists.GlobalSettings.dmsoundsVolume = DMSounds.config.volume
  end
  report("volume set to " .. DMSounds.config.volume)
  return true
end

function DMSounds.help()
  report("DMSounds v" .. DMSounds.version .. " commands: update, check, on, off, toggle, stop, status, version, apply, silence, volume <0-100>, help")
end

local function handleCommand()
  local command = (matches[2] or ""):match("^%s*(.-)%s*$")
  if command == "" or command == "help" then
    if type(expandAlias) == "function" then
      expandAlias("dmc help dmsounds")
    else
      DMSounds.help()
    end
  elseif command == "update" then
    DMSounds.update()
  elseif command == "check" then
    DMSounds.checkPlayback()
  elseif command == "on" then
    DMSounds.setEnabled(true)
    saveSettings()
  elseif command == "off" then
    DMSounds.setEnabled(false)
    saveSettings()
  elseif command == "toggle" then
    DMSounds.toggle()
    saveSettings()
  elseif command == "stop" then
    DMSounds.stop()
  elseif command == "status" then
    DMSounds.status()
  elseif command == "version" then
    report("DMSounds version " .. DMSounds.version)
  elseif command == "apply" or command == "reload" then
    DMSounds.currentArea = ""
    DMSounds.update()
  elseif command == "silence" then
    DMSounds.playSilence()
  else
    local volume = command:match("^volume%s+(.+)$")
    if volume then
      if DMSounds.setVolume(volume) then saveSettings() end
    else
      report("unknown command: " .. command)
      DMSounds.help()
    end
  end
end

local function removeOwnedAlias()
  if not DarkmistsAlias or type(DarkmistsAlias.registry) ~= "table" then return end
  local aliasPattern = [[^dmsounds(?:\s+(.*))?$]]
  local aliasId = DarkmistsAlias.registry[aliasPattern]
  if aliasId and type(killAlias) == "function" then pcall(killAlias, aliasId) end
  DarkmistsAlias.registry[aliasPattern] = nil
end

function DMSounds.cleanup()
  if DarkmistsTimer and type(DarkmistsTimer.remove) == "function" then
    pcall(DarkmistsTimer.remove, STARTUP_TIMER_KEY)
    pcall(DarkmistsTimer.remove, PENDING_TIMER_KEY)
  end
  if DarkmistsEvents and type(DarkmistsEvents.remove) == "function" then
    pcall(DarkmistsEvents.remove, PROMPT_EVENT_KEY)
    pcall(DarkmistsEvents.remove, MAP_EVENT_KEY)
  end
  removeOwnedAlias()

  stopSilence()
  stopAmbience()
  DMSounds.currentArea = ""
  DMSounds.currentTrack = nil
  DMSounds.mapperArea = nil
  DMSounds._pendingTimer = nil
  DMSounds._startupTimer = nil
  DMSounds._startupGrace = false
  DMSounds._initialized = false
end

function DMSounds.init()
  DMSounds.cleanup()
  syncConfig()
  DMSounds.ambientSoundMap = resolveTrackMap()
  DMSounds.currentArea = ""

  if DarkmistsAlias and type(DarkmistsAlias.add) == "function" then
    DarkmistsAlias.add([[^dmsounds(?:\s+(.*))?$]], handleCommand)
  end

  if DarkmistsEvents and type(DarkmistsEvents.add) == "function" then
    DarkmistsEvents.add(PROMPT_EVENT_KEY, "dmapi.world.prompt", function()
      DMSounds.checkPlayback()
    end)
    DarkmistsEvents.add(MAP_EVENT_KEY, "sysMapAreaChanged", function(_, newAreaId)
      local mapperName = resolveAreaName(newAreaId)
      if not mapperName then
        debugReport("ignoring sysMapAreaChanged for unknown area id: " .. tostring(newAreaId))
        return
      end
      DMSounds.mapperArea = newAreaId
      debugReport("mapper area changed to: " .. mapperName)
      playAreaByName(mapperName)
    end)
  end

  DMSounds._initialized = true
  if DMLogger and type(DMLogger.log) == "function" then
    pcall(DMLogger.log, "DMSounds", "Ready")
  end
end

DMSounds.ambientSoundMap = resolveTrackMap()
syncConfig()
