-- ============================================================================
-- DM Tick Tracker
-- ----------------------------------------------------------------------------
-- Informational-only tracker that learns probable Dark Mists tick cadence
-- from authoritative world tick cues first, with prompt regen used only as
-- secondary corroboration and fallback when no better cue is present.
-- ============================================================================
DMTickTracker = {}

DMTickTracker.enabled = true
DMTickTracker.notifyEnabled = true
DMTickTracker.debugShowStatusMessages = false
DMTickTracker.notifyIntervalSeconds = 1
DMTickTracker.defaultAverageTickSeconds = 30
DMTickTracker.minObservedInterval = 15
DMTickTracker.maxObservedInterval = 45
DMTickTracker.minQualifiedRatio = 0.05
DMTickTracker.windowPaddingSeconds = 5
DMTickTracker.regenCorroborationWindowSeconds = 5
DMTickTracker.ingestSuppressionSeconds = 5
DMTickTracker.pulseTimer = nil
DMTickTracker.pulseGeneration = 0
DMTickTracker.lastNotifyAt = 0
DMTickTracker.lastAnnouncedWindowAt = 0
DMTickTracker.lastConfirmedNotifyAt = 0

local function trackerSep()
  return DarkmistsTheme.mutedTag .. " | " .. DarkmistsTheme.textTag
end

local function trackerPlugin()
  return DarkmistsTheme.accentTag .. "TickTracker"
end

local function getStatusTag(status)
  if status == "Tick Window Open" then return DarkmistsTheme.goodTag end
  if status == "Awaiting Next Pulse" then return DarkmistsTheme.warnTag end
  if status == "Tracking" then return DarkmistsTheme.infoTag end
  return DarkmistsTheme.mutedTag
end

local function formatCue(cue)
  cue = cue or "none"

  if cue == "damage" then
    return DarkmistsTheme.warnTag .. cue .. DarkmistsTheme.textTag
  elseif cue == "weather" then
    return DarkmistsTheme.infoTag .. cue .. DarkmistsTheme.textTag
  elseif cue == "hunger" or cue == "thirst" then
    return DarkmistsTheme.accentTag .. cue .. DarkmistsTheme.textTag
  end

  return DarkmistsTheme.mutedTag .. cue .. DarkmistsTheme.textTag
end

local function clamp(value, minValue, maxValue)
  return math.max(minValue, math.min(maxValue, value))
end

local function countRecentCues(now)
  local total = 0

  for _, cueAt in pairs(DMTickTracker.lastCueAt or {}) do
    if cueAt and cueAt > 0 and math.abs(now - cueAt) <= 5 then
      total = total + 1
    end
  end

  return total
end

local function formatSeconds(value)
  if value == nil then return "?" end
  return string.format("%ds", math.max(0, math.floor(value + 0.5)))
end

local function getButtonBarIndicatorColors(status)
  local seconds = status and status.estimatedSecondsUntilNextTick
  local imminentThreshold = math.max(2, tonumber(DMTickTracker.notifyIntervalSeconds) or 3)

  if seconds ~= nil and seconds <= imminentThreshold then
    return "#8B2E2E", "#F8F8F8" -- red: tick imminent
  elseif status and status.isTickWindowOpen then
    return "#8A7A1F", "#F8F8F8" -- yellow: inside tick window
  end

  return "#2E6B3A", "#F8F8F8" -- green: outside tick window
end

function DMTickTracker.ensureButtonBarIndicator()
  if not ButtonBar or not ButtonBar.container then return nil end

  if DMTickTracker._buttonBarIndicatorParent ~= ButtonBar.container then
    DMTickTracker._buttonBarIndicator = nil
    DMTickTracker._buttonBarIndicatorParent = ButtonBar.container
  end

  if DMTickTracker._buttonBarIndicator then
    return DMTickTracker._buttonBarIndicator
  end

  local width = math.max(88, math.floor((ButtonBar.fontWidth or 8) * 12))
  local xPos = math.max(0, ButtonBar.nextX or 0)

  DMTickTracker._buttonBarIndicator = Geyser.Label:new({
    name = "DMTickTrackerIndicator",
    x = xPos,
    y = 0,
    width = width,
    height = "100%",
    message = "<center>⏱ --</center>",
  }, ButtonBar.container)

  ButtonBar.nextX = xPos + width
  DMTickTracker._buttonBarIndicator:setFontSize(ButtonBar.fontSize or 12)
  return DMTickTracker._buttonBarIndicator
end

function DMTickTracker.updateButtonBarIndicator()
  local label = DMTickTracker.ensureButtonBarIndicator()
  if not label then return end

  local status = DMTickTracker.getStatus()
  local bgColor, fgColor = getButtonBarIndicatorColors(status)
  local seconds = status.estimatedSecondsUntilNextTick
  local text = seconds and (tostring(math.max(0, math.floor(seconds + 0.5))) .. "s") or "--"

  label:setStyleSheet(([[
    QLabel {
      background-color: %s;
      color: %s;
      border-left: 1px solid #222222;
      border-right: 1px solid #222222;
      padding-left: 6px;
      padding-right: 6px;
      font-weight: bold;
    }
  ]]):format(bgColor, fgColor))

  label:echo("<center>⏱ " .. text .. "</center>")
end

local function getQualifiedJumpCategories(data)
  local previous = DMTickTracker.lastPromptSnapshot or {}
  local qualified = {}
  local gains = {}
  local checks = {
    {
      key = "hp",
      current = tonumber(data and data.hp) or 0,
      previous = tonumber(previous.hp) or 0,
      explicit = tonumber(data and data.hpRegen) or 0,
    },
    {
      key = "mn",
      current = tonumber(data and data.mn) or 0,
      previous = tonumber(previous.mn) or 0,
      explicit = tonumber(data and data.mnRegen) or 0,
    },
    {
      key = "mv",
      current = tonumber(data and data.mv) or 0,
      previous = tonumber(previous.mv) or 0,
      explicit = tonumber(data and data.mvRegen) or 0,
    },
  }

  for _, item in ipairs(checks) do
    local observedDelta = 0
    if item.previous > 0 and item.current > item.previous then
      observedDelta = item.current - item.previous
    end

    local gain = math.max(item.explicit, observedDelta)
    gains[item.key] = gain

    local baseline = item.previous > 0 and item.previous or item.current
    local qualifiesByRatio = baseline > 0
      and gain > 0
      and (gain / baseline) > (DMTickTracker.minQualifiedRatio or 0.05)

    if qualifiesByRatio then
      table.insert(qualified, item.key)
    end
  end

  return qualified, gains
end

local function isPrimaryTickCue(kind)
  return kind == "hunger"
    or kind == "thirst"
    or kind == "weather"
    or kind == "damage"
end

local function hadRecentPrimaryCue(now, withinSeconds)
  now = now or getEpoch()
  withinSeconds = tonumber(withinSeconds) or DMTickTracker.regenCorroborationWindowSeconds or 5

  for kind, cueAt in pairs(DMTickTracker.lastCueAt or {}) do
    if isPrimaryTickCue(kind)
      and cueAt
      and cueAt > 0
      and math.abs(now - cueAt) <= withinSeconds
    then
      return true, kind, cueAt
    end
  end

  return false, nil, nil
end

local function shouldUseStateCue(kind, data)
  if kind ~= "hunger" and kind ~= "thirst" then
    return true
  end

  local intensity = tonumber(data and data.intensity)
  if intensity ~= nil and intensity <= 0 then
    return false
  end

  local now = (data and data.timestamp) or getEpoch()
  local lastIngestAt = tonumber(DMTickTracker.lastIngestAt) or 0
  local suppressFor = tonumber(DMTickTracker.ingestSuppressionSeconds) or 5

  if lastIngestAt > 0 and (now - lastIngestAt) <= suppressFor then
    return false
  end

  return true
end

local function resetIfPulseExpired(now)
  now = now or getEpoch()

  if (DMTickTracker.lastObservedTickAt or 0) <= 0 then
    return false
  end

  local maxAge = tonumber(DMTickTracker.maxObservedInterval) or 45
  if (now - DMTickTracker.lastObservedTickAt) <= maxAge then
    return false
  end

  local avg = clamp(
    math.floor((tonumber(DMTickTracker.averageTickSeconds) or DMTickTracker.defaultAverageTickSeconds) + 0.5),
    DMTickTracker.minObservedInterval,
    DMTickTracker.maxObservedInterval
  )
  local pad = DMTickTracker.windowPaddingSeconds

  DMTickTracker.lastObservedTickAt = now
  DMTickTracker.lastObservedSource = "timer"
  DMTickTracker.earliestNextTickAt = now + clamp(
    avg - pad,
    DMTickTracker.minObservedInterval,
    DMTickTracker.maxObservedInterval
  )
  DMTickTracker.latestNextTickAt = now + clamp(
    avg + pad,
    DMTickTracker.minObservedInterval,
    DMTickTracker.maxObservedInterval
  )
  DMTickTracker.lastAnnouncedWindowAt = 0
  DMTickTracker.confidence = clamp((DMTickTracker.confidence or 0) - 0.05, 0.20, 0.95)

  DMTickTracker.updateButtonBarIndicator()
  return true
end

function DMTickTracker.observeTick(now, source, data)
  now = now or getEpoch()

  local forceTick = data and data.forceTick
  local previous = DMTickTracker.lastObservedTickAt or 0
  if previous > 0 then
    local interval = now - previous
    local duplicateWindow = math.max(10, math.floor(DMTickTracker.minObservedInterval / 2))

    if interval < duplicateWindow then
      if not forceTick then
        return false
      end
    end

    if interval >= DMTickTracker.minObservedInterval
      and interval <= DMTickTracker.maxObservedInterval then
      local nextSampleCount = DMTickTracker.sampleCount + 1
      DMTickTracker.averageTickSeconds =
        ((DMTickTracker.averageTickSeconds * DMTickTracker.sampleCount) + interval)
        / nextSampleCount
      DMTickTracker.sampleCount = nextSampleCount
    elseif not forceTick then
      DMTickTracker.confidence = math.max(0.15, DMTickTracker.confidence - 0.10)
    end
  else
    DMTickTracker.sampleCount = 1
  end

  DMTickTracker.lastObservedTickAt = now
  DMTickTracker.lastObservedSource = source
  if data then
    DMTickTracker.lastRegenPulse = data
  end

  local avg = clamp(
    math.floor(DMTickTracker.averageTickSeconds + 0.5),
    DMTickTracker.minObservedInterval,
    DMTickTracker.maxObservedInterval
  )
  local pad = DMTickTracker.windowPaddingSeconds

  DMTickTracker.earliestNextTickAt = now + clamp(
    avg - pad,
    DMTickTracker.minObservedInterval,
    DMTickTracker.maxObservedInterval
  )
  DMTickTracker.latestNextTickAt = now + clamp(
    avg + pad,
    DMTickTracker.minObservedInterval,
    DMTickTracker.maxObservedInterval
  )

  local cueBonus = math.min(0.20, countRecentCues(now) * 0.05)
  DMTickTracker.confidence = clamp(
    math.min(0.85, DMTickTracker.sampleCount / 6) + cueBonus,
    0.20,
    0.95
  )

  DMTickTracker.updateButtonBarIndicator()
  return true
end

function DMTickTracker.manualTick()
  if not DMTickTracker.enabled then return false end

  local now = getEpoch()
  local payload = {
    cue = "manual",
    timestamp = now,
    forceTick = true,
    tickCategories = { "manual" },
    tickGains = { hp = 0, mn = 0, mv = 0 },
  }

  if DMTickTracker.observeTick(now, "manual", payload) then
    DMTickTracker.maybeAnnounceConfirmedTick(payload)
    return true
  end

  return false
end

function DMTickTracker.buildNotifyMessage()
  local status = DMTickTracker.getStatus()
  local confidencePct = math.floor(((status.confidence or 0) * 100) + 0.5)
  local statusText = getStatusTag(status.status) .. status.status .. DarkmistsTheme.textTag

  if status.status == "Uncalibrated" then
    return "Tick " .. statusText
      .. trackerSep() .. DarkmistsTheme.mutedTag .. "waiting for first tick cue" .. DarkmistsTheme.textTag
      .. trackerSep() .. DarkmistsTheme.mutedTag .. "cue=" .. DarkmistsTheme.textTag .. formatCue(status.recentCueKind)
  end

  local now = getEpoch()
  local earliestIn = status.earliestNextTickAt and math.max(0, status.earliestNextTickAt - now) or nil
  local latestIn = status.latestNextTickAt and math.max(0, status.latestNextTickAt - now) or nil

  return "Tick " .. statusText
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "avg " .. DarkmistsTheme.infoTag
    .. math.floor((status.averageTickSeconds or DMTickTracker.defaultAverageTickSeconds) + 0.5) .. "s" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "next " .. DarkmistsTheme.infoTag .. formatSeconds(earliestIn)
    .. DarkmistsTheme.mutedTag .. "-" .. DarkmistsTheme.infoTag .. formatSeconds(latestIn) .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "age " .. DarkmistsTheme.textTag .. formatSeconds(status.lastTickAgeSeconds)
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "conf " .. DarkmistsTheme.goodTag .. confidencePct .. "%" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "cue=" .. DarkmistsTheme.textTag .. formatCue(status.recentCueKind)
end

function DMTickTracker.buildWindowOpenMessage()
  local status = DMTickTracker.getStatus()
  local confidencePct = math.floor(((status.confidence or 0) * 100) + 0.5)

  return DarkmistsTheme.goodTag .. "Tick window open" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "avg " .. DarkmistsTheme.infoTag
    .. math.floor((status.averageTickSeconds or DMTickTracker.defaultAverageTickSeconds) + 0.5) .. "s" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "conf " .. DarkmistsTheme.goodTag .. confidencePct .. "%" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "cue=" .. DarkmistsTheme.textTag .. formatCue(status.recentCueKind)
end

function DMTickTracker.buildConfirmedMessage(data)
  local gains = (data and data.tickGains) or {}
  local hp = tonumber(gains.hp) or tonumber(data and data.hpRegen) or 0
  local mn = tonumber(gains.mn) or tonumber(data and data.mnRegen) or 0
  local mv = tonumber(gains.mv) or tonumber(data and data.mvRegen) or 0
  local total = hp + mn + mv
  local confidencePct = math.floor((DMTickTracker.confidence or 0) * 100 + 0.5)
  local categories = (data and data.tickCategories) or {}
  local label = (data and data.cue)

  if not label or label == "" then
    label = (#categories > 0) and table.concat(categories, "+")
      or DMTickTracker.lastObservedSource
      or "multi"
  end

  return DarkmistsTheme.goodTag .. "Confirmation event received" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "source " .. DarkmistsTheme.accentTag .. label .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "gains "
    .. DarkmistsTheme.goodTag .. "+" .. hp .. "hp" .. DarkmistsTheme.textTag .. " "
    .. DarkmistsTheme.infoTag .. "+" .. mn .. "mn" .. DarkmistsTheme.textTag .. " "
    .. DarkmistsTheme.accentTag .. "+" .. mv .. "mv" .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "total " .. DarkmistsTheme.infoTag .. "+" .. total .. DarkmistsTheme.textTag
    .. trackerSep() .. DarkmistsTheme.mutedTag .. "conf " .. DarkmistsTheme.goodTag .. confidencePct .. "%" .. DarkmistsTheme.textTag
end

function DMTickTracker.emitNotify(message, now, opts)
  if not DMTickTracker.notifyEnabled or not message then return false end

  opts = opts or {}
  now = now or getEpoch()
  local minGap = math.max(1, tonumber(DMTickTracker.notifyIntervalSeconds) or 5)
  local lastNotifyAt = DMTickTracker.lastNotifyAt or 0

  if not opts.bypassThrottle and lastNotifyAt > 0 and (now - lastNotifyAt) < minGap then
    return false
  end

  DMTickTracker.lastNotifyAt = now

  if DMLogger and DMLogger.notify then
    DMLogger.notify(opts.plugin or trackerPlugin(), message)
    return true
  end

  return false
end

function DMTickTracker.maybeAnnounceWindowOpen(now)
  if not DMTickTracker.notifyEnabled then return false end
  if not DMTickTracker.debugShowStatusMessages then return false end
  if DMTickTracker.earliestNextTickAt <= 0 or DMTickTracker.latestNextTickAt <= 0 then return false end
  if not DMTickTracker.isTickWindowOpen(now) then return false end

  local lastAnnounced = DMTickTracker.lastAnnouncedWindowAt or 0
  if lastAnnounced >= DMTickTracker.lastObservedTickAt then
    return false
  end

  if DMTickTracker.emitNotify(DMTickTracker.buildWindowOpenMessage(), now) then
    DMTickTracker.lastAnnouncedWindowAt = now
    return true
  end

  return false
end

function DMTickTracker.maybeAnnounceConfirmedTick(data)
  if not DMTickTracker.notifyEnabled or not data then return false end

  local now = data.timestamp or getEpoch()
  if DMTickTracker.lastConfirmedNotifyAt == now then
    return false
  end

  if DMTickTracker.emitNotify(DMTickTracker.buildConfirmedMessage(data), now, { bypassThrottle = true }) then
    DMTickTracker.lastConfirmedNotifyAt = now
    return true
  end

  return false
end

function DMTickTracker.stopPulse()
  DMTickTracker.pulseGeneration = (DMTickTracker.pulseGeneration or 0) + 1

  if DMTickTracker.pulseTimer then
    DarkmistsTimer.remove("DMTickTracker.Pulse")
    DMTickTracker.pulseTimer = nil
  end
end

function DMTickTracker.startPulse()
  DMTickTracker.stopPulse()

  if not DMTickTracker.enabled or not DMTickTracker.notifyEnabled then
    return
  end

  local generation = (DMTickTracker.pulseGeneration or 0) + 1
  DMTickTracker.pulseGeneration = generation

  local timerId
  timerId = DarkmistsTimer.add("DMTickTracker.Pulse", DMTickTracker.notifyIntervalSeconds, function()
    if (DMTickTracker.pulseGeneration or 0) ~= generation then
      if timerId then
        pcall(killTimer, timerId)
      end
      return
    end

    if not DMTickTracker.enabled or not DMTickTracker.notifyEnabled then
      return
    end

    local now = getEpoch()
    if resetIfPulseExpired(now) then
      return
    end

    local sentWindowNotice = DMTickTracker.maybeAnnounceWindowOpen(now)
    if DMTickTracker.debugShowStatusMessages and not sentWindowNotice then
      DMTickTracker.emitNotify(DMTickTracker.buildNotifyMessage(), now)
    end

    DMTickTracker.updateButtonBarIndicator()
  end, true)

  DMTickTracker.pulseTimer = timerId
end

function DMTickTracker.refreshConfig()
  local gs = Darkmists and Darkmists.GlobalSettings or {}

  if gs.tickTrackerEnabled ~= nil then
    DMTickTracker.enabled = gs.tickTrackerEnabled
  end
  if gs.tickTrackerNotifyEnabled ~= nil then
    DMTickTracker.notifyEnabled = gs.tickTrackerNotifyEnabled
  end
  if gs.tickTrackerNotifyIntervalSeconds then
    DMTickTracker.notifyIntervalSeconds = gs.tickTrackerNotifyIntervalSeconds
  end
end

function DMTickTracker.reset()
  DMTickTracker.lastObservedTickAt = 0
  DMTickTracker.earliestNextTickAt = 0
  DMTickTracker.latestNextTickAt = 0
  DMTickTracker.averageTickSeconds = DMTickTracker.defaultAverageTickSeconds
  DMTickTracker.sampleCount = 0
  DMTickTracker.confidence = 0
  DMTickTracker.lastRegenPulse = nil
  DMTickTracker.lastObservedSource = nil
  DMTickTracker.lastPromptSnapshot = nil
  DMTickTracker.lastCueKind = nil
  DMTickTracker.lastCueLine = nil
  DMTickTracker.lastPrimaryCueAt = 0
  DMTickTracker.lastConfirmedCategories = {}
  DMTickTracker.lastNotifyAt = 0
  DMTickTracker.lastAnnouncedWindowAt = 0
  DMTickTracker.lastConfirmedNotifyAt = 0
  DMTickTracker.lastIngestAt = 0
  DMTickTracker.lastCueAt = {
    hunger = 0,
    thirst = 0,
    weather = 0,
    damage = 0,
  }

  DMTickTracker.updateButtonBarIndicator()
end

function DMTickTracker.noteCue(kind, data)
  if not DMTickTracker.enabled then return end
  if not shouldUseStateCue(kind, data) then return end

  local timestamp = (data and data.timestamp) or getEpoch()
  DMTickTracker.lastCueKind = kind
  DMTickTracker.lastCueLine = data and data.line or nil
  DMTickTracker.lastCueAt[kind] = timestamp

  if isPrimaryTickCue(kind) then
    DMTickTracker.lastPrimaryCueAt = timestamp

    local payload = data or {}
    payload.cue = kind
    payload.timestamp = timestamp
    payload.forceTick = true
    payload.tickCategories = { kind }
    payload.tickGains = payload.tickGains or { hp = 0, mn = 0, mv = 0 }

    if DMTickTracker.observeTick(timestamp, kind, payload) then
      DMTickTracker.maybeAnnounceConfirmedTick(payload)
    end
  end
end

function DMTickTracker.onRegenPulse(data)
  if not DMTickTracker.enabled or not data then return end

  local categories, gains = getQualifiedJumpCategories(data)
  local now = data.timestamp or getEpoch()

  DMTickTracker.lastPromptSnapshot = {
    hp = tonumber(data.hp) or 0,
    mn = tonumber(data.mn) or 0,
    mv = tonumber(data.mv) or 0,
    timestamp = now,
  }

  data.tickCategories = categories
  data.tickGains = gains

  if #categories >= 2 then
    DMTickTracker.lastConfirmedCategories = categories
  end

  local hadPrimaryCue = hadRecentPrimaryCue(now, DMTickTracker.regenCorroborationWindowSeconds)
  if hadPrimaryCue then
    DMTickTracker.lastRegenPulse = data
    DMTickTracker.confidence = clamp((DMTickTracker.confidence or 0) + 0.03, 0.20, 0.95)
    return
  end

  if #categories < 2 then
    return
  end

  if DMTickTracker.observeTick(now, "regen", data) then
    DMTickTracker.maybeAnnounceConfirmedTick(data)
  end
end

function DMTickTracker.isTickWindowOpen(now)
  now = now or getEpoch()

  return DMTickTracker.lastObservedTickAt > 0
    and DMTickTracker.earliestNextTickAt > 0
    and now >= DMTickTracker.earliestNextTickAt
    and now <= DMTickTracker.latestNextTickAt
end

function DMTickTracker.getStatus()
  local now = getEpoch()
  resetIfPulseExpired(now)

  local status = "Uncalibrated"

  if DMTickTracker.lastObservedTickAt > 0 then
    status = "Tracking"

    if DMTickTracker.isTickWindowOpen(now) then
      status = "Tick Window Open"
    elseif DMTickTracker.latestNextTickAt > 0 and now > DMTickTracker.latestNextTickAt then
      status = "Awaiting Next Pulse"
    end
  end

  local earliestNextTickAt = DMTickTracker.earliestNextTickAt > 0 and DMTickTracker.earliestNextTickAt or nil
  local latestNextTickAt = DMTickTracker.latestNextTickAt > 0 and DMTickTracker.latestNextTickAt or nil
  local estimatedNextTickAt = nil

  if earliestNextTickAt and latestNextTickAt then
    estimatedNextTickAt = math.floor((earliestNextTickAt + latestNextTickAt) / 2)
  end

  return {
    enabled = DMTickTracker.enabled,
    notifyEnabled = DMTickTracker.notifyEnabled,
    notifyIntervalSeconds = DMTickTracker.notifyIntervalSeconds,
    status = status,
    isTracking = status ~= "Uncalibrated",
    isTickWindowOpen = DMTickTracker.isTickWindowOpen(now),
    sampleCount = DMTickTracker.sampleCount,
    confidence = DMTickTracker.confidence,
    confidencePercent = math.floor((DMTickTracker.confidence or 0) * 100 + 0.5),
    averageTickSeconds = DMTickTracker.averageTickSeconds,
    lastObservedTickAt = DMTickTracker.lastObservedTickAt > 0 and DMTickTracker.lastObservedTickAt or nil,
    lastObservedSource = DMTickTracker.lastObservedSource,
    lastTickAgeSeconds = DMTickTracker.lastObservedTickAt > 0 and (now - DMTickTracker.lastObservedTickAt) or nil,
    earliestNextTickAt = earliestNextTickAt,
    latestNextTickAt = latestNextTickAt,
    estimatedNextTickAt = estimatedNextTickAt,
    secondsUntilWindowOpen = earliestNextTickAt and math.max(0, earliestNextTickAt - now) or nil,
    secondsUntilWindowClose = latestNextTickAt and math.max(0, latestNextTickAt - now) or nil,
    estimatedSecondsUntilNextTick = estimatedNextTickAt and math.max(0, estimatedNextTickAt - now) or nil,
    recentCueKind = DMTickTracker.lastCueKind,
    recentCueLine = DMTickTracker.lastCueLine,
    lastConfirmedCategories = DMTickTracker.lastConfirmedCategories or {},
  }
end

function DMTickTracker.getPulseInfo()
  return DMTickTracker.getStatus()
end

function DMTickTracker.init()
  DMTickTracker.refreshConfig()
  DMTickTracker.reset()
  DMTickTracker.startPulse()
  tempTimer(0, function() DMTickTracker.updateButtonBarIndicator() end)

  if DarkmistsAlias and DarkmistsAlias.add then
    DarkmistsAlias.add([[^tick\s+(?:pass|now|manual)$]], function()
      DMTickTracker.manualTick()
    end)
  end

  if not DarkmistsEvents then return end

  DarkmistsEvents.add("DMTickTracker.WorldEnter", "dmapi.world.enter", function()
    DMTickTracker.reset()
  end)

  DarkmistsEvents.add("DMTickTracker.WorldExit", "dmapi.world.exit", function()
    DMTickTracker.reset()
  end)

  DarkmistsEvents.add("DMTickTracker.RegenPulse", "dmapi.player.regen.pulse", function(_, data)
    DMTickTracker.onRegenPulse(data)
  end)

  DarkmistsEvents.add("DMTickTracker.Ingest", "dmapi.player.ingest", function(_, data)
    DMTickTracker.lastIngestAt = (data and data.timestamp) or getEpoch()
  end)

  DarkmistsEvents.add("DMTickTracker.Hunger", "dmapi.player.hunger.update", function(_, data)
    DMTickTracker.noteCue("hunger", data)
  end)

  DarkmistsEvents.add("DMTickTracker.Thirst", "dmapi.player.thirst.update", function(_, data)
    DMTickTracker.noteCue("thirst", data)
  end)

  DarkmistsEvents.add("DMTickTracker.Weather", "dmapi.world.weather.update", function(_, data)
    DMTickTracker.noteCue("weather", data)
  end)

  DarkmistsEvents.add("DMTickTracker.PeriodicDamage", "dmapi.player.damage.periodic", function(_, data)
    DMTickTracker.noteCue("damage", data)
  end)
end
