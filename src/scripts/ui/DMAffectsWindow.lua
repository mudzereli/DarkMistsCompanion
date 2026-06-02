-- ============================================================================
-- Affects Window (Geyser.UserWindow)
-- Snapshot-based affects tracker with expiration
-- ============================================================================
AffectsWindow = {}

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
-- Tunable settings for the affects snapshot view.
-- `timeRatio` maps real seconds to in-game seconds (used for expiry math).
-- `deleteOriginalLines` controls whether source AFF output is removed
-- after capture (useful for keeping scrollback tidy).
AffectsWindow.config = {
  fontSize       = 10,
  fontName       = getFont(),
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

AffectsWindow.ignoreSet      = {}   -- Spell names that auto-remove on expiry
AffectsWindow.showIgnored    = false -- Toggle for inline ignored-list display

AffectsWindow.affectsList    = {}   -- Canonical affect records (active + expired)
-- `affectsList` stores canonical affect records; entries may be marked
-- `expired` and remain until explicitly cleared. `currentKeys` is a
-- transient set of keys observed during the current snapshot capture
-- used to detect disappeared affects at snapshot end.
AffectsWindow.currentKeys    = {}   -- Snapshot keys for current capture

AffectsWindow.keys = {
  triggerNoAffects = "affectsNoAffects",
  triggerHeader    = "affectsHeader",
  triggerLine      = "affectsLine",
  eventPrompt      = "affectsPromptHandler",
}

local function shouldDeleteOriginalLines()
  -- Helper wrapper so callers don't reference config directly.
  -- Returning true causes source AFF lines to be removed after capture.
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
-- Begin a snapshot capture. The capture window records successive AFF
-- output lines until the prompt is seen. `lastUpdateTime` is used to
-- compute age and for display; `currentKeys` is reset for this snapshot.
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
-- Stop the current snapshot and mark any affect not seen in this
-- snapshot as expired. We track `expiredByName` so multiple entries
-- for the same spell name are collapsed: the first missing entry is
-- marked expired and subsequent duplicates are removed to avoid
-- duplicate expired lines in the listing.
function AffectsWindow.stopCaptureAndDisplay()
  if not AffectsWindow.capturing then return end
  if shouldDeleteOriginalLines() then
    -- Acknowledge Captured Lines but only if we're deleting stuff
    cecho("\n" .. DarkmistsTheme.infoTag .. "Affects List Captured.")
  end
  AffectsWindow.capturing = false

  -- Expire any active affect whose key did not appear this snapshot.
  -- Affects whose name is in the ignoreSet are removed immediately
  -- instead of being marked expired.
  local affectsList = AffectsWindow.affectsList
  local currentKeys = AffectsWindow.currentKeys
  local ignoreSet = AffectsWindow.ignoreSet
  local expiredByName = {}

  for i = #affectsList, 1, -1 do
    local affect = affectsList[i]

    if not affect.expired and not currentKeys[affect.key] then
      if ignoreSet[affect.name] then
        table.remove(affectsList, i)
      elseif expiredByName[affect.name] then
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

-- Sync the ignoreSet hashmap into Darkmists.GlobalSettings and persist.
-- Called after every ignore/unignore to survive reloads.
local function saveIgnoreSet()
  local gs = Darkmists and Darkmists.GlobalSettings
  if not gs then return end
  gs.affectsWindowIgnoredSpells = {}
  for name in pairs(AffectsWindow.ignoreSet) do
    table.insert(gs.affectsWindowIgnoredSpells, name)
  end
  Darkmists.SaveSettings()
end

-- Add a spell name to the auto-remove set and purge any currently
-- expired entries for that name from the display.
function AffectsWindow.ignoreAffect(affectName)
  AffectsWindow.ignoreSet[affectName] = true
  -- Remove any current expired entries for this name
  for i = #AffectsWindow.affectsList, 1, -1 do
    local a = AffectsWindow.affectsList[i]
    if a.expired and a.name == affectName then
      table.remove(AffectsWindow.affectsList, i)
    end
  end
  saveIgnoreSet()
  AffectsWindow.refreshDisplay()
end

-- Remove a spell name from the auto-remove set so future expirations
-- will appear in the expired list again. If the set becomes empty,
-- auto-collapse the management section so it doesn't get stuck open
-- with no way to dismiss it.
function AffectsWindow.unignoreAffect(affectName)
  AffectsWindow.ignoreSet[affectName] = nil
  if AffectsWindow.countIgnored() == 0 then
    AffectsWindow.showIgnored = false
  end
  saveIgnoreSet()
  AffectsWindow.refreshDisplay()
end

-- Toggle visibility of the inline ignored-list section.
function AffectsWindow.toggleShowIgnored()
  AffectsWindow.showIgnored = not AffectsWindow.showIgnored
  AffectsWindow.refreshDisplay()
end

-- Count ignored spell names.
function AffectsWindow.countIgnored()
  local n = 0
  for _ in pairs(AffectsWindow.ignoreSet) do n = n + 1 end
  return n
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
    textLinkColor .. "<u>[Refresh]</u>" .. DarkmistsTheme.textTag,
    function() send("affects") end,
    "Refresh affects list",
    true
  )
  console:cecho(" ")
  console:cechoLink(
    clearLinkColor .. "<u>[Clear]" .. DarkmistsTheme.textTag,
    function() AffectsWindow.clearExpiredAffects() end,
    "Remove all expired affects",
    true
  )

  -- Ignored-list toggle: show count and link to expand/collapse the
  -- inline ignored-spell management section.
  local ignoredCount = AffectsWindow.countIgnored()
  if ignoredCount > 0 then
    console:cecho(" ")
    console:cechoLink(
      DarkmistsTheme.mutedTag .. "<u>[»:" .. tostring(ignoredCount) .. "]",
      function() AffectsWindow.toggleShowIgnored() end,
      "Toggle ignored affects list",
      true
    )
    console:cecho(DarkmistsTheme.textTag)
  end

  console:cecho("\n\n")
end

function AffectsWindow.parseDuration(text)
  -- Parse human-readable duration strings into minutes.
  -- Special tokens map to sentinels: PERMANENT -> math.huge, UNKNOWN -> -math.huge
  if text == "PERMANENT" then return math.huge end
  if text == "UNKNOWN" then return -math.huge end

  local mins = 0
  mins = mins + (tonumber(text:match("(%d+)%s+hrs?")) or 0) * 60
  mins = mins + (tonumber(text:match("(%d+)%s+mins?")) or 0)
  return mins
end

function AffectsWindow.formatDuration(minutes, expired)
  -- Render duration strings with theme tags. `expired` forces an
  -- EXPIRED label regardless of numeric minutes. Minutes <= 0 are
  -- shown as EXPIRING (imminent) to draw attention.
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

-- Parse the current AFF output line and record/update an affect entry.
-- This function accepts multiple variants of AFF output (full format,
-- edge-case phrases like "no time at all", permanent, and a simple
-- fallback of just the spell name). It also guards against capturing
-- prompts or combat condition lines.
function AffectsWindow.copyCurrentLine()
  if not AffectsWindow.capturing or not AffectsWindow.window then return end

  local line = getCurrentLine()

  if line == "You are affected by the following:" then return end

  -- Exit early for condition lines (e.g. typing AFF while in combat).
  for _, v in ipairs(dmapi.core.state.COMBAT_CONDITIONS) do
    if line:match(v) then return end
  end

  -- Attempt to parse affect variants (full-text formats first)

  -- Normal Line: "Name : modifies X by Y for about Z"
  local name, mod, val, dur =
    line:match("^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+for%s+about%s+(.+)$")

  -- Expiring Next Tick: maps to duration 0
  if not name then
    name, mod, val = line:match(
      "^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+for no time at all$"
    )
    dur = "0"
  end

  -- Permanent Buff: map to a sentinel token
  if not name then
    name, mod, val = line:match(
      "^(.-)%s+:%s+modifies%s+(.-)%s+by%s+(.-)%s+permanently$"
    )
    dur = "PERMANENT"
  end

  if name and dur then
    AffectsWindow.hasFullFormat = true
  end
  
  -- Low-level fallback: accept plain spell-name lines only when we
  -- haven't yet observed the full format. Reject lines containing
  -- ":" or the word "modifies" so we don't mis-parse partial text.
  if not name and not AffectsWindow.hasFullFormat then
    if line:find(":") or line:find("modifies") then
      return
    end
    if not line:match("%a") then
      return
    end

    name = line:match("^%s*(.-)%s*$") -- trim
    mod  = "none"
    val  = 0
    dur  = "UNKNOWN"
  end

  -- Not an affect line: optionally delete source and bail out.
  if not name then
    if shouldDeleteOriginalLines() then
      deleteLine()
    end
    return
  end

  if shouldDeleteOriginalLines() then
    deleteLine()
  end

  -- Handle wrapped/continued spell names: use the last seen non-empty name
  if name:find("%S") == nil then
    name = lastSpellName
  end
  lastSpellName = name

  local duration = AffectsWindow.parseDuration(dur)
  -- Compose a stable key including name/mod/value so reapplications
  -- of the same effect refresh the existing entry instead of creating
  -- duplicates.
  local key = name .. "|" .. mod .. "|" .. val

  AffectsWindow.currentKeys[key] = true

  -- Refresh existing active entry (by exact key match)
  for _, affect in ipairs(AffectsWindow.affectsList) do
    if not affect.expired and affect.key == key then
      affect.captureTime  = os.time()
      affect.durationMins = duration
      return
    end
  end

  -- If an expired entry with the same spell name exists, replace it
  -- (preserves ordering and avoids duplicate expired records).
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

  -- Insert new active affect
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

-- Rebuild the console display from the canonical affect list.
-- When `showIgnored` is active, only the ignored-spell management
-- view is rendered (the main affects list is hidden). Otherwise the
-- full active + expired list is shown.
function AffectsWindow.refreshDisplay()
  if not AffectsWindow.window or not AffectsWindow.lastUpdateTime then return end

  local console = AffectsWindow.console
  local cfg = AffectsWindow.config

  console:clear()
  AffectsWindow.displayHeader()

  -- Ignored-management mode: replace the affects list entirely
  if AffectsWindow.showIgnored then
    local names = {}
    for name in pairs(AffectsWindow.ignoreSet) do
      table.insert(names, name)
    end
    table.sort(names)

    console:cecho("\n" .. DarkmistsTheme.mutedTag .. "── Auto-Removed on Expiry ──\n")
    if #names == 0 then
      console:cecho(DarkmistsTheme.mutedTag .. "  (none)\n")
    else
      for _, name in ipairs(names) do
        console:cecho(string.format(
          DarkmistsTheme.mutedTag .. "  %-" .. tostring(cfg.textLengthAffectName) .. "s ",
          name:sub(1, cfg.textLengthAffectName)
        ))
        console:cechoLink(
          DarkmistsTheme.goodTag .. "<u>[Track Again]" .. DarkmistsTheme.textTag,
          [[AffectsWindow.unignoreAffect("]] .. name .. [[")]],
          "Resume tracking this affect after expiry",
          true
        )
        console:cecho("\n")
      end
    end
    return
  end

  -- Normal mode: active + expired affects
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

  -- Render expired affects with clickable X and Ignore
  -- Expired affects show [X] to remove once and [Ignore] to add the
  -- spell name to the auto-remove set so future expirations disappear
  -- silently. We render them after active affects so the active list
  -- remains prominent.
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

    console:cecho(" ")
    console:cechoLink(
      DarkmistsTheme.mutedTag .. "<u>[»]" .. DarkmistsTheme.textTag,
      [[AffectsWindow.ignoreAffect("]] .. name .. [[")]],
      "Always auto-remove this affect on expiry",
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
  -- Compute a human-friendly age label by converting elapsed real
  -- seconds to in-game minutes using `timeRatio` and formatting the
  -- result for display in the header.
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
  -- Ensure only one repeating age timer exists; replace any previous
  -- timer to avoid duplicate callbacks after reloads.
  if AffectsWindow.ageTimer then
    DarkmistsTimer.remove("AffectsWindow.AgeTimer")
  end
  AffectsWindow.ageTimer = DarkmistsTimer.add(
    "AffectsWindow.AgeTimer",
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
  -- If we have no effects, capture an empty list. Without this explicit
  -- trigger, previously-expired affects could linger as EXPIRING forever
  -- because no snapshot would mark them expired.
  DarkmistsTrigger.addKeyed(
    AffectsWindow.keys.triggerNoAffects,
    "substring",
    "You are not affected by anything.",
    function()
      AffectsWindow.startCapture()
      stopCaptureIfActive()
    end
  )

  -- Start capturing when the AFF header appears
  DarkmistsTrigger.addKeyed(
    AffectsWindow.keys.triggerHeader,
    "substring",
    "You are affected by the following:",
    function()
      AffectsWindow.startCapture()
    end
  )

  -- Capture any following lines while capturing is active. We use a
  -- catch-all regex here but only process lines if `capturing` is true.
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

  -- Stop capturing once we hit a prompt event (AFF output finished)
  DarkmistsEvents.add(
    AffectsWindow.keys.eventPrompt,
    "dmapi.world.prompt",
    stopCaptureIfActive
  )

end

function AffectsWindow.init()
  AffectsWindow.refreshConfig()

  -- Restore persisted ignore list from settings
  local gs = Darkmists and Darkmists.GlobalSettings
  local saved = gs and gs.affectsWindowIgnoredSpells
  if type(saved) == "table" then
    for _, name in ipairs(saved) do
      AffectsWindow.ignoreSet[name] = true
    end
  end

  AffectsWindow.create()
  registerHandlers()

  Darkmists.Log("AffectsWindow", "Triggers registered")
  Darkmists.Log("AffectsWindow","Initialized. Type 'aff' to capture affects!")
end

function AffectsWindow.destroy()
  -- Remove timers and unregister triggers/events to keep reloads clean.
  if AffectsWindow.ageTimer then
    DarkmistsTimer.remove("AffectsWindow.AgeTimer")
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

  DarkmistsEvents.remove(keys.eventPrompt)

  AffectsWindow.capturing = false
  Darkmists.Log("AffectsWindow", "Destroyed")
end