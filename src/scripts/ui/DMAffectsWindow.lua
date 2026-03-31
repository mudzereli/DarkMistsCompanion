-- ============================================================================
-- Affects Window (Geyser.UserWindow)
-- Snapshot-based affects tracker with expiration
-- ============================================================================
AffectsWindow = AffectsWindow or {}

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

AffectsWindow.config = AffectsWindow.config or {
  fontSize       = 10,
  fontName       = "Bitstream Vera Sans Mono",
  updateInterval = 1,
  textLengthAffectName = 30,
  textLengthAffectMod  = 20,
  deleteOriginalLines  = false,
  timeRatio      = 30, -- 1 real second = 30 game seconds
}

function AffectsWindow.refreshConfig()
  local gs = Darkmists and Darkmists.GlobalSettings or {}
  local cfg = AffectsWindow.config

  cfg.fontSize = gs.fontSize or cfg.fontSize
  cfg.fontName = gs.fontName or cfg.fontName
  cfg.updateInterval = gs.affectsWindowUpdateIntervalSeconds or cfg.updateInterval
  cfg.textLengthAffectName = gs.affectsWindowAffectNameLength or cfg.textLengthAffectName
  cfg.textLengthAffectMod = gs.affectsWindowAffectModLength or cfg.textLengthAffectMod
  if gs.affectsWindowDeleteOriginalLines ~= nil then
    cfg.deleteOriginalLines = gs.affectsWindowDeleteOriginalLines
  end
end

-- ---------------------------------------------------------------------------
-- Runtime State
-- ---------------------------------------------------------------------------

AffectsWindow.window         = nil
AffectsWindow.capturing      = false
AffectsWindow.lastUpdateTime = nil
AffectsWindow.ageTimer       = nil
AffectsWindow.hasFullFormat  = false
AffectsWindow.initialized    = false

AffectsWindow.affectsList    = {}   -- Canonical affect records (active + expired)
AffectsWindow.currentKeys    = {}   -- Snapshot keys for current capture

AffectsWindow.keys = {
  triggerNoAffects = "affectsNoAffects",
  triggerHeader    = "affectsHeader",
  triggerLine      = "affectsLine",
  eventPrompt      = "affectsPromptHandler",
}

local function shouldDeleteOriginalLines()
  return AffectsWindow.config.deleteOriginalLines
end

-- ============================================================================
-- WINDOW CREATION
-- ============================================================================

function AffectsWindow.create()
  if AffectsWindow.window then return end

  AffectsWindow.window = Darkmists.createTabPanel("AffectsWindow", "Current Affects", "Affects")
    
  AffectsWindow.console = Geyser.MiniConsole:new({
    name   = "AffectsWindowConsole",
    x      = "1%",
    y      = "1%",
    width  = "98%",
    height = "98%",
    color = Darkmists.getDefaultBackgroundColor()
  }, AffectsWindow.window)
  AffectsWindow.console:setFontSize(AffectsWindow.config.fontSize)
  AffectsWindow.console:setFont(AffectsWindow.config.fontName)
  AffectsWindow.console:enableAutoWrap()
  AffectsWindow.console:enableScrollBar()

  AffectsWindow.window:show()
  AffectsWindow.window:raiseAll()
  Darkmists.Log("AffectsWindow","Geyser window created")
end

-- ============================================================================
-- CAPTURE LIFECYCLE
-- ============================================================================

-- Start a new snapshot capture
function AffectsWindow.startCapture()
  AffectsWindow.hasFullFormat = false
  AffectsWindow.capturing = true
  AffectsWindow.lastUpdateTime = os.time()

  -- Reset snapshot keyset
  AffectsWindow.currentKeys = {}

  AffectsWindow.startAgeTimer()

  if AffectsWindow.window then
    AffectsWindow.console:clear()
    AffectsWindow.displayHeader()
  end
end

-- End capture and expire missing affects
function AffectsWindow.stopCaptureAndDisplay()
  if not AffectsWindow.capturing then return end
  if shouldDeleteOriginalLines() then
    -- Acknowledge Captured Lines but only if we're deleting stuff
    cecho("\n" .. DarkmistsTheme.infoTag .. "Affects List Captured.")
  end
  AffectsWindow.capturing = false

  -- Expire any active affect whose key did not appear this snapshot
  local affectsList = AffectsWindow.affectsList
  local currentKeys = AffectsWindow.currentKeys
  local expiredByName = {}

  for i = #affectsList, 1, -1 do
    local affect = affectsList[i]

    if not affect.expired and not currentKeys[affect.key] then
      if expiredByName[affect.name] then
        table.remove(affectsList, i)
      else
        affect.expired = true
        affect.expireTime = os.time()
        expiredByName[affect.name] = true
      end
    end
  end
end

-- ============================================================================
-- DISPLAY HELPERS
-- ============================================================================

function AffectsWindow.removeExpiredAffect(affectName)
  for i, affect in ipairs(AffectsWindow.affectsList) do
    if affect.expired and affect.name == affectName then
      table.remove(AffectsWindow.affectsList, i)
      AffectsWindow.refreshDisplay()
      return
    end
  end
end

function AffectsWindow.clearExpiredAffects()
  local changed = false
  for i = #AffectsWindow.affectsList, 1, -1 do
    if AffectsWindow.affectsList[i].expired then
      table.remove(AffectsWindow.affectsList, i)
      changed = true
    end
  end
  if changed then
    AffectsWindow.refreshDisplay()
  end
end

function AffectsWindow.displayHeader()
  if not AffectsWindow.window or not AffectsWindow.lastUpdateTime then return end

  local console = AffectsWindow.console
  local realElapsed = os.time() - AffectsWindow.lastUpdateTime
  local age = AffectsWindow.getAge()

  console:cecho(string.format(
    "%sAge: %s%ss %s(%s%s) %s| ",
    DarkmistsTheme.yellowTag,
    DarkmistsTheme.textTag,
    realElapsed,
    DarkmistsTheme.mutedTag,
    age,
    DarkmistsTheme.mutedTag,
    DarkmistsTheme.textTag
  ))
  resetFormat()

  -- Added separator + themed refresh link
  local textLinkColor = DarkmistsTheme.textTag
  local clearLinkColor = DarkmistsTheme.redTag

  console:cechoLink(
    textLinkColor .. "<u>[Refresh]" .. DarkmistsTheme.textTag,
    function() send("affects") end,
    "Refresh affects list",
    true
  )
  console:cecho(" ")
  console:cechoLink(
    clearLinkColor .. "<u>[Clear Expired]" .. DarkmistsTheme.textTag,
    function() AffectsWindow.clearExpiredAffects() end,
    "Remove all expired affects",
    true
  )

  console:cecho("\n\n")
end

function AffectsWindow.parseDuration(text)
  if text == "PERMANENT" then return math.huge end
  if text == "UNKNOWN" then return -math.huge end

  local mins = 0
  mins = mins + (tonumber(text:match("(%d+)%s+hrs?")) or 0) * 60
  mins = mins + (tonumber(text:match("(%d+)%s+mins?")) or 0)
  return mins
end

function AffectsWindow.formatDuration(minutes, expired)
  if minutes == math.huge then return DarkmistsTheme.goodTag .. "PERMANENT" end
  if minutes == -math.huge then return DarkmistsTheme.goodTag .. "UNKNOWN" end

  if expired then
    return DarkmistsTheme.badTag .. "EXPIRED"
  end

  if minutes <= 0 then return DarkmistsTheme.warnTag .. "EXPIRING" end
  if minutes < 60 then return string.format(DarkmistsTheme.infoTag .. "%dm", minutes) end

  local h, r = math.floor(minutes / 60), minutes % 60
  return r > 0
    and string.format(DarkmistsTheme.infoTag .. "%dh %dm", h, r)
    or  string.format(DarkmistsTheme.infoTag .. "%dh", h)
end

-- ============================================================================
-- LINE PARSING
-- ============================================================================

local lastSpellName = ""

function AffectsWindow.copyCurrentLine()
  if not AffectsWindow.capturing or not AffectsWindow.window then return end

  local line = getCurrentLine()

  if line == "You are affected by the following:" then return end

  -- Exit if we get a condition line
  -- This happens when you type AFF during combat.
  for _, v in ipairs(dmapi.core.state.COMBAT_CONDITIONS) do
    if line:match(v) then return end
  end

  -- Attempt to parse affect variants

  -- Normal Line
  local name, mod, val, dur =
    line:match("^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+for%s+about%s+(.+)$")

  -- Expiring Next Tick
  if not name then
    name, mod, val = line:match(
      "^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+for no time at all$"
    )
    dur = "0"
  end

  -- Permanent Buff
  if not name then
    name, mod, val = line:match(
      "^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+permanently$"
    )
    dur = "PERMANENT"
  end

  if name and dur then
    AffectsWindow.hasFullFormat = true
  end
  
  -- Low-level fallback: only accept simple spell-name lines
  if not name and not AffectsWindow.hasFullFormat then
    -- Must NOT contain ":" or "modifies"
    if line:find(":") or line:find("modifies") then
      return
    end

    -- Must contain letters (not empty/whitespace)
    if not line:match("%a") then
      return
    end

    name = line:match("^%s*(.-)%s*$") -- trim
    mod  = "none"
    val  = 0
    dur  = "UNKNOWN"
  end

  -- Not an affect line
  if not name then
    if shouldDeleteOriginalLines() then
      deleteLine()
    end
    return
  end

  if shouldDeleteOriginalLines() then
    deleteLine()
  end

  -- Handle wrapped spell names
  if name:find("%S") == nil then
    name = lastSpellName
  end
  lastSpellName = name

  local duration = AffectsWindow.parseDuration(dur)
  local key = name .. "|" .. mod .. "|" .. val

  AffectsWindow.currentKeys[key] = true

  -- Refresh existing active entry
  for _, affect in ipairs(AffectsWindow.affectsList) do
    if not affect.expired and affect.key == key then
      affect.captureTime  = os.time()
      affect.durationMins = duration
      return
    end
  end

  -- Replace expired entry of same spell, else insert
  for i, affect in ipairs(AffectsWindow.affectsList) do
    if affect.expired and affect.name == name then
      AffectsWindow.affectsList[i] = {
        name = name,
        modifier = mod,
        modValue = val,
        durationMins = duration,
        captureTime = os.time(),
        expired = false,
        key = key
      }
      return
    end
  end

  table.insert(AffectsWindow.affectsList, {
    name = name,
    modifier = mod,
    modValue = val,
    durationMins = duration,
    captureTime = os.time(),
    expired = false,
    key = key
  })
end

-- ============================================================================
-- DISPLAY
-- ============================================================================

function AffectsWindow.refreshDisplay()
  if not AffectsWindow.window or not AffectsWindow.lastUpdateTime then return end

  local console = AffectsWindow.console
  local cfg = AffectsWindow.config

  console:clear()
  AffectsWindow.displayHeader()
  console:cecho(DarkmistsTheme.blueTag .. "You are affected by the following:\n")

  local now = os.time()
  local activeAffects = {}
  local expiredAffects = {}

  for _, affect in ipairs(AffectsWindow.affectsList) do
    if affect.expired then
      table.insert(expiredAffects, {
        affect = affect
      })
    else
      local remainingMins =
        affect.durationMins -
        math.floor(((now - affect.captureTime) * cfg.timeRatio) / 60)

      table.insert(activeAffects, {
        affect = affect,
        mins = remainingMins
      })
    end
  end

  -- Active: soonest to expire first
  table.sort(activeAffects, function(a, b)
    if a.mins ~= b.mins then
      return a.mins < b.mins
    end
    if a.affect.name ~= b.affect.name then
      return a.affect.name < b.affect.name
    end
    return false
  end)

  -- Render active affects
  for _, item in ipairs(activeAffects) do
    local affect = item.affect
    local dur = AffectsWindow.formatDuration(item.mins, false)
    local mod = string.format("%s %s", affect.modValue, affect.modifier)

    local ln = cfg.textLengthAffectName
    local lm = cfg.textLengthAffectMod
    console:cecho(string.format(
      "%s%-" .. tostring(ln) .. "s%s : %s%-" .. tostring(lm) .. "s %s: %s\n",
      DarkmistsTheme.accentTag,
      affect.name:sub(1, ln),
      DarkmistsTheme.textTag,
      DarkmistsTheme.textTag,
      mod:sub(1, lm),
      DarkmistsTheme.textTag,
      dur
    ))
  end

  -- Render expired affects with clickable X
  for _, item in ipairs(expiredAffects) do
    local affect = item.affect
    local dur = AffectsWindow.formatDuration(0, true)
    local mod = string.format("%s %s", affect.modValue, affect.modifier)
    local name = affect.name

    local ln = cfg.textLengthAffectName - 4
    local lm = cfg.textLengthAffectMod
    console:cecho(string.format(
      DarkmistsTheme.mutedTag .. "%-" .. tostring(ln) .. "s ",
      name:sub(1, ln)
    ))

    console:cechoLink(
      DarkmistsTheme.badTag .. "<u>[X]" .. DarkmistsTheme.textTag,
      [[AffectsWindow.removeExpiredAffect("]] .. name .. [[")]],
      "Remove expired affect",
      true
    )

    console:cecho(string.format(
      DarkmistsTheme.mutedTag .. " : %-" .. tostring(lm) .. "s : %s\n",
      mod:sub(1, lm),
      dur
    ))
  end
end

-- ============================================================================
-- AGE TIMER
-- ============================================================================

function AffectsWindow.getAge()
  if not AffectsWindow.lastUpdateTime then return "Unknown" end

  local mins = math.floor(((os.time() - AffectsWindow.lastUpdateTime)
               * AffectsWindow.config.timeRatio) / 60)

  if mins == 0 then return DarkmistsTheme.goodTag .. "Just updated" end
  if mins < 60 then return string.format("%s%dm", DarkmistsTheme.cyanTag, mins) end

  local h, r = math.floor(mins / 60), mins % 60
  return r > 0 and string.format("%s%dh %dm", DarkmistsTheme.warnTag, h, r)
              or string.format("%s%dh", DarkmistsTheme.warnTag, h)
end

function AffectsWindow.startAgeTimer()
  if AffectsWindow.ageTimer then killTimer(AffectsWindow.ageTimer) end
  AffectsWindow.ageTimer = tempTimer(
    AffectsWindow.config.updateInterval,
    AffectsWindow.refreshDisplay,
    true
  )
end

-- ============================================================================
-- TRIGGERS
-- ============================================================================

local function registerHandlers()
  local function stopCaptureIfActive()
    if AffectsWindow.capturing then
      AffectsWindow.stopCaptureAndDisplay()
      AffectsWindow.refreshDisplay()
    end
  end

  -- If we have no effects, just capture an empty affect list
  -- If we DONT do this, then EXPIRED effects will just show EXPIRING forever
  DarkmistsTrigger.addKeyed(
    AffectsWindow.keys.triggerNoAffects,
    "substring",
    "You are not affected by anything.",
    function()
      AffectsWindow.startCapture()
      stopCaptureIfActive()
    end
  )

  -- Start Capturing Normally when we see the header
  DarkmistsTrigger.addKeyed(
    AffectsWindow.keys.triggerHeader,
    "substring",
    "You are affected by the following:",
    function()
      AffectsWindow.startCapture()
    end
  )

  -- If we saw the header, capture/copy all incoming lines
  DarkmistsTrigger.addKeyed(
    AffectsWindow.keys.triggerLine,
    "regex",
    ".*",
    function()
      if AffectsWindow.capturing then
        AffectsWindow.copyCurrentLine()
      end
    end
  )

  -- Stop capturing once we hit a prompt.
  DarkmistsEvents.add(
    AffectsWindow.keys.eventPrompt,
    "dmapi.world.prompt",
    stopCaptureIfActive
  )

  AffectsWindow.initialized = true
end

function AffectsWindow.init()
  AffectsWindow.refreshConfig()
  AffectsWindow.create()
  if AffectsWindow.initialized then
    return
  end

  registerHandlers()

  Darkmists.Log("AffectsWindow", "Triggers registered")
  Darkmists.Log("AffectsWindow","Initialized. Type 'aff' to capture affects!")
end

function AffectsWindow.destroy()
  if AffectsWindow.ageTimer then
    killTimer(AffectsWindow.ageTimer)
    AffectsWindow.ageTimer = nil
  end

  local keys = AffectsWindow.keys

  if DarkmistsTrigger.registry[keys.triggerNoAffects] then
    killTrigger(DarkmistsTrigger.registry[keys.triggerNoAffects])
    DarkmistsTrigger.registry[keys.triggerNoAffects] = nil
  end

  if DarkmistsTrigger.registry[keys.triggerHeader] then
    killTrigger(DarkmistsTrigger.registry[keys.triggerHeader])
    DarkmistsTrigger.registry[keys.triggerHeader] = nil
  end

  if DarkmistsTrigger.registry[keys.triggerLine] then
    killTrigger(DarkmistsTrigger.registry[keys.triggerLine])
    DarkmistsTrigger.registry[keys.triggerLine] = nil
  end

  if DarkmistsEvents.registry[keys.eventPrompt] then
    killAnonymousEventHandler(DarkmistsEvents.registry[keys.eventPrompt])
    DarkmistsEvents.registry[keys.eventPrompt] = nil
  end

  AffectsWindow.capturing = false
  AffectsWindow.initialized = false
  Darkmists.Log("AffectsWindow", "Destroyed")
end