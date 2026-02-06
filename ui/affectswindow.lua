-- ============================================================================
-- Affects Window (Geyser.UserWindow)
-- Snapshot-based affects tracker with expiration
-- ============================================================================

AffectsWindow = AffectsWindow or {}

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

AffectsWindow.config = {
  fontSize       = Darkmists.GlobalSettings.fontSize,
  fontName       = Darkmists.GlobalSettings.fontName,
  updateInterval = Darkmists.GlobalSettings.affectsWindowUpdateIntervalSeconds,
  textLengthAffectName = Darkmists.GlobalSettings.affectsWindowAffectNameLength,
  textLengthAffectMod = Darkmists.GlobalSettings.affectsWindowAffectModLength,
  deleteOriginalLines = false,
  timeRatio      = 30, -- 1 real second = 30 game seconds
}

-- ---------------------------------------------------------------------------
-- Runtime State
-- ---------------------------------------------------------------------------

AffectsWindow.window         = nil
AffectsWindow.capturing      = false
AffectsWindow.lastUpdateTime = nil
AffectsWindow.ageTimer       = nil

AffectsWindow.affectsContent = {}   -- Raw captured output
AffectsWindow.affectsList    = {}   -- Canonical affect records (active + expired)
AffectsWindow.currentKeys    = {}   -- Snapshot keys for current capture

-- ============================================================================
-- WINDOW CREATION
-- ============================================================================

function AffectsWindow.create()
  if AffectsWindow.window then return end

  AffectsWindow.window = Adjustable.Container:new({
    name = "AffectsWindow",

    x = tostring(Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
    width = tostring(100 - Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
    y = "66.66%",
    height = "33.33%",

    titleText = "Current Affects",
    titleTxtColor = "white",
    padding = 10,
    adjLabelstyle = [[
      background-color: #111111;
      border: 2px solid #666666;
    ]],

    lockStyle = "border",
    locked = false,
    autoSave = true,
    autoLoad = true,
  })
    
  AffectsWindow.console = Geyser.MiniConsole:new({
    name   = "AffectsWindowConsole",
    x      = 0,
    y      = 0,
    width  = "100%",
    height = "100%",
    color = "black"
  }, AffectsWindow.window)
  AffectsWindow.console:setFontSize(AffectsWindow.config.fontSize)
  AffectsWindow.console:setFont(AffectsWindow.config.fontName)

  AffectsWindow.window:show()
  AffectsWindow.window:raiseAll()
  cecho("\n<dim_gray>[<white>AffectsWindow<dim_gray>] <green>Geyser window created")
end

-- ============================================================================
-- CAPTURE LIFECYCLE
-- ============================================================================

-- Start a new snapshot capture
function AffectsWindow.startCapture()
  AffectsWindow.capturing      = true
  AffectsWindow.lastUpdateTime = os.time()
  AffectsWindow.affectsContent = {}

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
  AffectsWindow.capturing = false

  -- Expire any active affect whose key did not appear this snapshot
  local expiredByName = {}

  for i = #AffectsWindow.affectsList, 1, -1 do
    local affect = AffectsWindow.affectsList[i]

    if not affect.expired and not AffectsWindow.currentKeys[affect.key] then
      if expiredByName[affect.name] then
        table.remove(AffectsWindow.affectsList, i)
      else
        affect.expired    = true
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

function AffectsWindow.displayHeader()
  if not AffectsWindow.window or not AffectsWindow.lastUpdateTime then return end

  local realElapsed = os.time() - AffectsWindow.lastUpdateTime
  local age         = AffectsWindow.getAge()

  AffectsWindow.console:cecho(
    string.format("<yellow>Age: <white>%ss <dim_gray>(%s<dim_gray>)\n\n",
      realElapsed, age)
  )
end

function AffectsWindow.parseDuration(text)
  if text == "PERMANENT" then return math.huge end

  local mins = 0
  mins = mins + (tonumber(text:match("(%d+)%s+hrs?")) or 0) * 60
  mins = mins + (tonumber(text:match("(%d+)%s+mins?")) or 0)
  return mins
end

function AffectsWindow.formatDuration(minutes, expired)
  if minutes == math.huge then return "<green>PERMANENT" end

  if expired then
    local m = math.abs(minutes)
    if m < 60 then return string.format("<red>EXPIRED (%dm)", m) end
    local h, r = math.floor(m / 60), m % 60
    return r > 0
      and string.format("<red>EXPIRED (%dh %dm)", h, r)
      or  string.format("<red>EXPIRED (%dh)", h)
  end

  if minutes <= 0 then return "<orange>EXPIRING" end
  if minutes < 60 then return string.format("<yellow>%dm", minutes) end

  local h, r = math.floor(minutes / 60), minutes % 60
  return r > 0
    and string.format("<cyan>%dh %dm", h, r)
    or  string.format("<cyan>%dh", h)
end

-- ============================================================================
-- LINE PARSING
-- ============================================================================

local lastSpellName = ""

function AffectsWindow.copyCurrentLine()
  if not AffectsWindow.capturing or not AffectsWindow.window then return end

  local line = getCurrentLine()

  -- Attempt to parse affect variants (explicit, Lua-safe)
  local name, mod, val, dur =
    line:match("^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+for%s+about%s+(.+)$")

  if not name then
    name, mod, val = line:match(
      "^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+for no time at all$"
    )
    dur = "0"
  end

  if not name then
    name, mod, val = line:match(
      "^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+permanently$"
    )
    dur = "PERMANENT"
  end

  -- Not an affect line
  if not name then
    table.insert(AffectsWindow.affectsContent, line)
    return
  end

  -- Handle wrapped spell names
  if name:find("%S") == nil then
    name = lastSpellName
  end
  lastSpellName = name

  local duration = AffectsWindow.parseDuration(dur)
  local key      = name .. "|" .. mod .. "|" .. val

  AffectsWindow.currentKeys[key] = true

  -- Refresh existing active entry
  for _, affect in ipairs(AffectsWindow.affectsList) do
    if not affect.expired and affect.key == key then
      affect.captureTime = os.time()
      affect.durationMins = duration
      return
    end
  end

  -- Replace expired entry of same spell, else insert
  for i, affect in ipairs(AffectsWindow.affectsList) do
    if affect.expired and affect.name == name then
      AffectsWindow.affectsList[i] = {
        name = name, modifier = mod, modValue = val,
        durationMins = duration,
        captureTime = os.time(),
        expired = false,
        key = key
      }
      return
    end
  end

  table.insert(AffectsWindow.affectsList, {
    name = name, modifier = mod, modValue = val,
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

  AffectsWindow.console:clear()
  AffectsWindow.displayHeader()
  AffectsWindow.console:cecho("<ansi_cyan>You are affected by the following:\n")

  local now = os.time()
  local activeAffects  = {}
  local expiredAffects = {}

  for _, affect in ipairs(AffectsWindow.affectsList) do
    if affect.expired then
      local expiredMins =
        math.floor(((now - affect.expireTime) * AffectsWindow.config.timeRatio) / 60)

      table.insert(expiredAffects, {
        affect = affect,
        mins   = -expiredMins
      })
    else
      local remainingMins =
        affect.durationMins -
        math.floor(((now - affect.captureTime) * AffectsWindow.config.timeRatio) / 60)

      table.insert(activeAffects, {
        affect = affect,
        mins   = remainingMins
      })
    end
  end

  -- Active: soonest to expire first
  table.sort(activeAffects, function(a, b)
    return a.mins < b.mins
  end)

  -- Expired: alphabetical
  table.sort(expiredAffects, function(a, b)
    return a.affect.name < b.affect.name
  end)

  -- Render active affects
  for _, item in ipairs(activeAffects) do
    local affect = item.affect
    local dur    = AffectsWindow.formatDuration(item.mins, false)
    local mod    = string.format("%s %s", affect.modValue, affect.modifier)

    local ln = AffectsWindow.config.textLengthAffectName
    local lm = AffectsWindow.config.textLengthAffectMod
    AffectsWindow.console:cecho(string.format(
      "<white>%-"..tostring(ln).."s<white> : <cyan>%-"..tostring(lm).."s <white>: %s\n",
      affect.name:sub(1,ln),
      mod:sub(1,lm),
      dur
    ))
  end

  -- Render expired affects with clickable X
  for _, item in ipairs(expiredAffects) do
    local affect = item.affect
    local dur    = AffectsWindow.formatDuration(item.mins, true)
    local mod    = string.format("%s %s", affect.modValue, affect.modifier)
    local name   = affect.name

    local ln = AffectsWindow.config.textLengthAffectName - 4
    local lm = AffectsWindow.config.textLengthAffectMod
    AffectsWindow.console:cecho(string.format(
      "<dim_gray>%-"..tostring(ln).."s ",
      name:sub(1,ln)
    ))

    AffectsWindow.console:cechoLink(
      "<red>[X]",
      [[AffectsWindow.removeExpiredAffect("]] .. name .. [[")]],
      "Remove expired affect",
      true
    )

    AffectsWindow.console:cecho(string.format(
      "<dim_gray> : <gray>%-"..tostring(lm).."s <white>: %s\n",
      mod:sub(1,lm),
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

  if mins == 0 then return "<green>Just updated" end
  if mins < 60 then return string.format("<cyan>%dm", mins) end

  local h, r = math.floor(mins / 60), mins % 60
  return r > 0 and string.format("<orange>%dh %dm", h, r)
              or string.format("<orange>%dh", h)
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

function AffectsWindow.registerTriggers()
  if AffectsWindow.affectHeaderTrigger then killTrigger(AffectsWindow.affectHeaderTrigger) end
  if AffectsWindow.affectLineTrigger   then killTrigger(AffectsWindow.affectLineTrigger)   end
  if AffectsWindow.promptHandler       then killAnonymousEventHandler(AffectsWindow.promptHandler) end

  AffectsWindow.affectHeaderTrigger = tempTrigger(
    "You are affected by the following:",
    function()
      AffectsWindow.startCapture()
      AffectsWindow.copyCurrentLine()
    end
  )

  AffectsWindow.affectLineTrigger = tempRegexTrigger(
    "^.+\\s+:\\s+modifies.+$",
    function()
      if AffectsWindow.capturing then
        AffectsWindow.copyCurrentLine()
      end
    end
  )

  AffectsWindow.promptHandler = registerAnonymousEventHandler(
    "dmapi.world.prompt",
    function()
      if AffectsWindow.capturing then
        AffectsWindow.stopCaptureAndDisplay()
        AffectsWindow.refreshDisplay()
      end
    end
  )

  cecho("\n<dim_gray>[<white>AffectsWindow<dim_gray>] <green>Triggers registered")
end

-- ============================================================================
-- INIT
-- ============================================================================

tempTimer(0.5, function()
  AffectsWindow.create()
  AffectsWindow.registerTriggers()
  cecho("\n<dim_gray>[<white>AffectsWindow<dim_gray>] <green>Initialized. Type 'aff' to capture affects!")
end)
