-- ============================================================================
-- Dark Mists Enchanter Assistant (DMAPI Integrated + Persistent)
-- ============================================================================
EnchanterAssist = {}

-- ============================================================================
-- CONFIG / STATE
-- ============================================================================

EnchanterAssist.enabled      = true
EnchanterAssist.autoRun      = false
EnchanterAssist.playSoundOnDiscover = true
EnchanterAssist.partCount    = 5
EnchanterAssist.deterministicOrder = false

EnchanterAssist.attempted    = {}
EnchanterAssist.missing      = {}

EnchanterAssist.pendingKey   = nil
EnchanterAssist.sleepRefreshTimer = nil
EnchanterAssist.sawFlare     = false
EnchanterAssist._attemptResolved = false
EnchanterAssist._hardStopRequested = false
EnchanterAssist.state        = "idle"
EnchanterAssist.sessionTrials   = 0
EnchanterAssist.sessionFormulas = {}

EnchanterAssist.container    = "bag"
EnchanterAssist.sleeper      = "bedroll"
EnchanterAssist.sleepType    = 1   -- 1 = sleep, 0 = consumables
EnchanterAssist.drainItem    = "potion"

EnchanterAssist._lastVitalsCheck = 0
EnchanterAssist._lastPotionRecovery = 0
EnchanterAssist.potionRecoveryTimer = nil
EnchanterAssist._comboIndices = nil
EnchanterAssist._wakePending = false
EnchanterAssist._wrapped     = false
EnchanterAssist._savePath    = getMudletHomeDir() .. "/ea_data.lua"
EnchanterAssist.color = "<cyan>"

local ea_plugin = "EnchanterAssist"
local ea_text = "<white>"
local ea_muted = "<dim_gray>"
local ea_good = "<green>"
local ea_warn = "<yellow>"
local ea_bad = "<red>"
local ea_info = "<cyan>"
local ea_accent = "<cyan>"
local ea_gold = "<gold>"

local ea_red = "red"
local ea_orange = "orange"
local ea_green = "green"
local ea_blue = "blue"
local ea_cyan = "cyan"
local ea_light_blue = "blue"
local ea_dark_blue = "blue"
local ea_purple = "purple"
local ea_pink = "pink"
local ea_brown = "sienna"
local ea_olive = "olive"
local ea_silver = "silver"
local ea_warn_color = "yellow"
local ea_gold_color = "gold"
local ea_muted_color = "gray"

local highlightMap = {}

function EnchanterAssist.applyTheme()
  local theme = rawget(_G, "DarkmistsTheme") or {}

  EnchanterAssist.color = theme.accentTag or EnchanterAssist.color or "<cyan>"

  ea_plugin = EnchanterAssist.color .. "EnchanterAssist"
  ea_text = theme.textTag or "<white>"
  ea_muted = theme.mutedTag or "<dim_gray>"
  ea_good = theme.goodTag or "<green>"
  ea_warn = theme.warnTag or "<yellow>"
  ea_bad = theme.badTag or "<red>"
  ea_info = theme.infoTag or "<cyan>"
  ea_accent = theme.accentTag or "<cyan>"
  ea_gold = theme.goldTag or "<gold>"

  ea_red = theme.red or "red"
  ea_orange = theme.orange or "orange"
  ea_green = theme.green or "green"
  ea_blue = theme.blue or "blue"
  ea_cyan = theme.cyan or "cyan"
  ea_light_blue = theme.blue or "blue"
  ea_dark_blue = theme.blue or "blue"
  ea_purple = theme.purple or "purple"
  ea_pink = theme.pink or "pink"
  ea_brown = theme.brown or "sienna"
  ea_olive = theme.olive or "olive"
  ea_silver = theme.silver or "silver"
  ea_warn_color = theme.warn or "yellow"
  ea_gold_color = theme.gold or "gold"
  ea_muted_color = theme.muted or "gray"

  highlightMap = {
    ["^(.*) is momentarily encased in an aura of semitranslucent power%."] = {ea_cyan, "(SAVES)"},
    ["^(.*) glows a brief light blue%."] = {ea_light_blue, "(ATTRIBUTES)"},
    ["^(.*) flares orange%."] = {ea_orange, "(RESOURCES)"},
    ["^(.*) is more sturdy%."] = {ea_purple, "(-AC)"},
    ["^(.*) glows a brief dark blue%."] = {ea_dark_blue, "(OFFENSIVE)"},
    ["^(.*) vibrates for a moment%."] = {ea_blue, "(SLOW or HASTE)"},
    ["^(.*) flares bright green, and you feel a sense of calm%."] = {ea_green, "(RESOURCE REGENERATION)"},
    ["^(.*) seems a lot less metallic%."] = {ea_brown, "(NONMETAL)"},
    ["^(.*) begins to glow brightly%."] = {ea_pink, "(GLOWING)"},
    ["^(.*) begins to hum%."] = {ea_red, "(HUMMING)"},
    ["^(.*) emits a shimmering wave through the air%."] = {ea_cyan, "(ADDED AFFECT)"},
    ["^(.*) glows a sickly green%."] = {ea_olive, "(CURSE)"},
    ["^(.*) seems heavier%."] = {ea_muted_color, "(DOUBLE WEIGHT)"},
    ["^(.*) is less sturdy%."] = {ea_warn_color, "(+AC)"},
    ["^(.*) is more resistant to fire%."] = {ea_orange, "(BURN PROOF)"},
    ["^(.*) almost escapes your grasp%."] = {ea_purple, "(FLYING)"},
    ["^(.*) looks a bit more expensive in quality%."] = {ea_gold_color, "(ADDED VALUE)"},
    ["^(.*) fades out and back into existence%."] = {ea_cyan, "(INVIS)"},
    ["^(.*) fades out of existence%."] = {ea_cyan, "(INVIS)"},
    ["^(.*) seems lighter%."] = {ea_brown, "(HALF WEIGHT)"},
    ["^(.*) sticks to your hands%."] = {ea_red, "(NOREMOVE)"},
    ["^(.*) flares with a blinding silver aura, a pulse of energy emanating from it%."] = {ea_silver, "(IMMUNITY)"},
    ["^(.*) begins to radiate a soft silver aura, shimmering vibrantly%."] = {ea_silver, "(RESIST)"}
  }
end

EnchanterAssist.allmats = {
  "softwood","fire","skin","ivory","sandstone","bread","ice","coral","canvas",
  "clay","tin","wax","dragonscale","bronze","etherealness","diamond","shell",
  "elysium","copper","quartz","metal","hemp","platinum","brass","silk","ebony",
  "crystal","hardwood","stone","paper","meat","adamantite","pewter","food",
  "flesh","obsidian","granite","marble","water","parchment","gold","silver",
  "glass","bone","mithril","leather","iron","cloth","wood","steel"
}

-- ============================================================================
-- UTIL
-- ============================================================================

function EnchanterAssist._raiseTrialEvent(event, data)
  raiseEvent(event, data or {})
end

function EnchanterAssist._contains(set, key)
  return set[key] ~= nil
end

function EnchanterAssist._add(set, key)
  set[key] = true
end

function EnchanterAssist._buildPool()
  local pool = {}
  for _, mat in ipairs(EnchanterAssist.allmats) do
    if not EnchanterAssist._contains(EnchanterAssist.missing, mat) then
      table.insert(pool, mat)
    end
  end
  return pool
end

function EnchanterAssist._pick(pool, count)
  local result = {}
  for i = 1, count do
    local idx = math.random(#pool)
    table.insert(result, pool[idx])
    table.remove(pool, idx)
  end
  table.sort(result)
  return result
end

function EnchanterAssist._shuffleMaterials()
  local t = EnchanterAssist.allmats
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

function EnchanterAssist._ensureSleepTimer()

  if not dmapi.player.status.sleeping then
    return
  end

  if EnchanterAssist.sleepRefreshTimer then
    return
  end

  EnchanterAssist.sleepRefreshTimer = DarkmistsTimer.add("EnchanterAssist.SleepRefresh", 30, function()
    if dmapi.player.status.sleeping then
      send("")  -- refresh prompt/stats
    else
      DarkmistsTimer.remove("EnchanterAssist.SleepRefresh")
      EnchanterAssist.sleepRefreshTimer = nil
    end
  end, true)

end

function EnchanterAssist._playDiscoverSound()
  if not EnchanterAssist.playSoundOnDiscover then return end

  local soundPath = getMudletHomeDir() ..
    "/DarkMistsCompanion/assets/sounds/bubbling.wav"

  -- Normalize slashes (safety for Windows)
  soundPath = soundPath:gsub("\\", "/")

  playSoundFile({
    name = soundPath,
    volume = 75,
    priority = 75,
    tag = "ea_discover"
  })
end

function EnchanterAssist._nextCombination(indices, n, r)
    -- indices = current combination (1-based)
    -- n = pool size
    -- r = partCount

    local i = r
    while i > 0 and indices[i] == n - r + i do
        i = i - 1
    end

    if i == 0 then
        return nil -- exhausted
    end

    indices[i] = indices[i] + 1

    for j = i + 1, r do
        indices[j] = indices[j - 1] + 1
    end

    return indices
end

function EnchanterAssist._nCr(n, r)
  if r > n then return 0 end
  if r == 0 then return 1 end

  local result = 1
  for i = 1, r do
    result = result * (n - r + i) / i
  end

  return math.floor(result + 0.5)
end

function EnchanterAssist._pickRandomUnattemptedCombination(pool, r)
  local n = #pool
  if n < r then return nil, nil end

  -- Pass 1: count unattempted combinations
  local count = 0
  local idx = {}
  for i = 1, r do idx[i] = i end
  while idx do
    local picks = {}
    for i = 1, r do picks[i] = pool[idx[i]] end
    table.sort(picks)
    if not EnchanterAssist.attempted[r .. ":" .. table.concat(picks, "|")] then
      count = count + 1
    end
    idx = EnchanterAssist._nextCombination(idx, n, r)
  end

  if count == 0 then return nil, nil end

  -- Pass 2: return the randomly chosen N-th unattempted combination
  local target = math.random(count)
  local found  = 0
  idx = {}
  for i = 1, r do idx[i] = i end
  while idx do
    local picks = {}
    for i = 1, r do picks[i] = pool[idx[i]] end
    table.sort(picks)
    local key = r .. ":" .. table.concat(picks, "|")
    if not EnchanterAssist.attempted[key] then
      found = found + 1
      if found == target then return picks, key end
    end
    idx = EnchanterAssist._nextCombination(idx, n, r)
  end

  return nil, nil
end

function EnchanterAssist._isBelowRestThreshold()
  if not dmapi or not dmapi.player or not dmapi.player.vitals then
    return false
  end

  local v = dmapi.player.vitals
  local manaPct = v.mnPct or 0
  local movePct = v.mvPct or 0

  return (manaPct < 20) or (movePct < 20)
end

function EnchanterAssist._wakeThenResumeRun(message)
  if not (dmapi and dmapi.player and dmapi.player.status and dmapi.player.status.sleeping) then
    return false
  end

  EnchanterAssist.state = "resting"

  if message and message ~= "" then
    DMLogger.notify(ea_plugin, message)
  end

  if EnchanterAssist._wakePending then
    return true
  end

  EnchanterAssist._wakePending = true
  dmapi.core.send("wake")

  tempTimer(0.4, function()
    EnchanterAssist._wakePending = false

    if dmapi and dmapi.player and dmapi.player.status and dmapi.player.status.sleeping then
      return
    end

    if EnchanterAssist.state == "resting" then
      EnchanterAssist.state = "idle"
    end

    EnchanterAssist.run()
  end)

  return true
end

function EnchanterAssist._getPotionVitals()
  if not (dmapi and dmapi.player and dmapi.player.vitals) then
    return nil
  end

  return dmapi.player.vitals
end

function EnchanterAssist._continuePotionRecovery()
  local v = EnchanterAssist._getPotionVitals()
  if not v then
    return true
  end

  local now = getEpoch()
  if now - EnchanterAssist._lastPotionRecovery < 10 then
    return true
  end

  EnchanterAssist._lastPotionRecovery = now
  local manaPct = v.mnPct or 0
  local movePct = v.mvPct or 0

  if manaPct < 90 then
    dmapi.core.send("get", EnchanterAssist.drainItem, EnchanterAssist.container)
    dmapi.core.send("c drain", EnchanterAssist.drainItem)
  end

  if movePct < 90 then
    dmapi.core.send("get", "refreshment", EnchanterAssist.container)
    dmapi.core.send("recite", "refreshment", "self")
  end

  return true
end

function EnchanterAssist._stopPotionRecoveryTimer()
  if EnchanterAssist.potionRecoveryTimer then
    DarkmistsTimer.remove("EnchanterAssist.PotionRecovery")
    EnchanterAssist.potionRecoveryTimer = nil
  end
end

function EnchanterAssist._ensurePotionRecoveryTimer()
  if EnchanterAssist.sleepType ~= 0 then
    return
  end

  if EnchanterAssist.potionRecoveryTimer then
    return
  end

  EnchanterAssist.potionRecoveryTimer = DarkmistsTimer.add("EnchanterAssist.PotionRecovery", 10, function()
    if EnchanterAssist.sleepType ~= 0
      or EnchanterAssist.state ~= "resting"
      or not EnchanterAssist.autoRun then
      EnchanterAssist._stopPotionRecoveryTimer()
      return
    end

    local v = EnchanterAssist._getPotionVitals()
    if v then
      local manaPct = v.mnPct or 0
      local movePct = v.mvPct or 0

      if manaPct > 90 and movePct > 90 then
        EnchanterAssist.state = "idle"
        EnchanterAssist._stopPotionRecoveryTimer()
        EnchanterAssist.run()
        return
      end
    end

    EnchanterAssist._continuePotionRecovery()
  end, true)
end

function EnchanterAssist._startRestCycle(message)
  if EnchanterAssist.state == "resting" then
    return true
  end

  if dmapi and dmapi.player and dmapi.player.status and dmapi.player.status.sleeping then
    if EnchanterAssist.sleepType == 0 then
      return EnchanterAssist._wakeThenResumeRun(ea_warn .. "Potion mode active - waking before restore.")
    end
    EnchanterAssist.state = "resting"
    return true
  end

  EnchanterAssist.state = "resting"
  EnchanterAssist._lastPotionRecovery = 0

  if message and message ~= "" then
    DMLogger.notify(ea_plugin, message)
  end

  local v = dmapi.player.vitals
  local manaPct = v.mnPct or 0
  local movePct = v.mvPct or 0

  if EnchanterAssist.sleepType == 1 then
    dmapi.core.send("get", EnchanterAssist.sleeper, EnchanterAssist.container)
    dmapi.core.send("drop", EnchanterAssist.sleeper)
    dmapi.core.send("sleep", EnchanterAssist.sleeper)
    tempTimer(3, EnchanterAssist._ensureSleepTimer)
  else
    EnchanterAssist._ensurePotionRecoveryTimer()
    return EnchanterAssist._continuePotionRecovery()
  end

  return true
end

function EnchanterAssist._abortAttempt(reason)
  if EnchanterAssist.state ~= "brewing" and not EnchanterAssist.pendingKey then
    return
  end

  EnchanterAssist.state = "idle"
  EnchanterAssist.pendingKey = nil
  EnchanterAssist.sawFlare = false
  EnchanterAssist._attemptResolved = false
  EnchanterAssist._hardStopRequested = false
  EnchanterAssist._wakePending = false

  if reason and reason ~= "" then
    DMLogger.notify(ea_plugin, ea_warn .. "Attempt canceled: " .. ea_text .. reason)
  end
end

function EnchanterAssist.hardStop()
  EnchanterAssist.autoRun = false
  EnchanterAssist._wakePending = false
  EnchanterAssist._stopPotionRecoveryTimer()

  if EnchanterAssist.state == "brewing" then
    EnchanterAssist._hardStopRequested = true
    DMLogger.notify(ea_plugin, ea_warn .. "Hard stop armed - finishing current attempt, then stopping.")
    return
  end

  EnchanterAssist._hardStopRequested = false
  EnchanterAssist.state = "idle"
  EnchanterAssist.pendingKey = nil
  EnchanterAssist.sawFlare = false
  EnchanterAssist._attemptResolved = false

  DMLogger.notify(ea_plugin, ea_warn .. "Hard stop complete.")
end

-- ============================================================================
-- PERSISTENCE
-- ============================================================================

function EnchanterAssist.save()
  local data = {
    config = {
      partCount = EnchanterAssist.partCount,
      container = EnchanterAssist.container,
      sleeper   = EnchanterAssist.sleeper,
      sleepType = EnchanterAssist.sleepType,
      drainItem = EnchanterAssist.drainItem,
      playSoundOnDiscover = EnchanterAssist.playSoundOnDiscover,
      deterministicOrder = EnchanterAssist.deterministicOrder,
    },
    attempted = EnchanterAssist.attempted,
    missing   = EnchanterAssist.missing
  }

  table.save(EnchanterAssist._savePath, data)
  Darkmists.Log(ea_plugin, ea_muted .. "Data saved to: " .. ea_text .. EnchanterAssist._savePath)
end

function EnchanterAssist.load()
  if not io.exists(EnchanterAssist._savePath) then return end

  local data = {}
  table.load(EnchanterAssist._savePath,data)
  EnchanterAssist.attempted = data.attempted or {}
  EnchanterAssist.missing   = data.missing or {}

  if data.config then
    EnchanterAssist.partCount = data.config.partCount or 5
    EnchanterAssist.container = data.config.container or "bag"
    EnchanterAssist.sleeper   = data.config.sleeper or "bedroll"
    EnchanterAssist.playSoundOnDiscover = data.config.playSoundOnDiscover ~= false
    EnchanterAssist.sleepType = data.config.sleepType or 1
    EnchanterAssist.drainItem = data.config.drainItem or "potion"
    EnchanterAssist.deterministicOrder = data.config.deterministicOrder ~= false
  end

  Darkmists.Log(ea_plugin, "Data loaded from: " .. ea_text .. EnchanterAssist._savePath)
end

-- ============================================================================
-- CORE RUN
-- ============================================================================
function EnchanterAssist.run()
  if not EnchanterAssist.enabled then return end

  if EnchanterAssist.state ~= "idle" then
    local msg = ea_warn .. "Waiting - "

    if EnchanterAssist.state == "brewing" then
      msg = msg .. ea_warn .. "Brewing"
      if EnchanterAssist.pendingKey then
        msg = msg .. " " .. ea_muted .. "(" .. ea_text .. EnchanterAssist.pendingKey .. ea_muted .. ")"
      end
    elseif EnchanterAssist.state == "resting" then
      msg = msg .. ea_good .. "Resting"
    else
      msg = msg .. ea_text .. EnchanterAssist.state
    end

    DMLogger.notify(ea_plugin, msg)
    return
  end

  if EnchanterAssist._wakeThenResumeRun(ea_warn .. "Already sleeping - waking before attempt.") then
    return
  end

  if EnchanterAssist._isBelowRestThreshold() then
    EnchanterAssist._startRestCycle(ea_warn .. "Low resources - resting before next trial.")
    return
  end

  local pool = EnchanterAssist._buildPool()
  local n = #pool
  local r = EnchanterAssist.partCount

  if n < r then
      DMLogger.notify(
        ea_plugin,
        ea_warn .. "Not enough materials available."
      )
      return
  end

  if EnchanterAssist.deterministicOrder then
    -- initialize indices if needed
    if not EnchanterAssist._comboIndices then
      EnchanterAssist._comboIndices = {}
      for i = 1, r do
        EnchanterAssist._comboIndices[i] = i
      end
    end

    local indices = EnchanterAssist._comboIndices

    while indices do
      -- build key from indices
      local picks = {}
      for i = 1, r do
        table.insert(picks, pool[indices[i]])
      end
      table.sort(picks)

      local key = r .. ":" .. table.concat(picks, "|")

      if not EnchanterAssist.attempted[key] then
        -- store next state for future call
        EnchanterAssist._comboIndices =
            EnchanterAssist._nextCombination(indices, n, r)

        EnchanterAssist.pendingKey = key
        EnchanterAssist.sawFlare = false
        EnchanterAssist._attemptResolved = false
        EnchanterAssist.sessionTrials = EnchanterAssist.sessionTrials + 1

        DMLogger.notify(ea_plugin,
          ea_muted .. "TRY " .. ea_text .. key .. "\n")

        EnchanterAssist.state = "brewing"
        EnchanterAssist._raiseTrialEvent("ea.trial.start", { key = key, partCount = r, trial = EnchanterAssist.sessionTrials })
        dmapi.core.send("get", "key", EnchanterAssist.container)
        dmapi.core.send("alchemy", "key", table.concat(picks, " "))
        dmapi.core.send("alchemy essence")
        dmapi.core.send("\t")
        return
      end

      indices = EnchanterAssist._nextCombination(indices, n, r)
      EnchanterAssist._comboIndices = indices
    end
  else
    local picks, key = EnchanterAssist._pickRandomUnattemptedCombination(pool, r)

    if picks and key then
      EnchanterAssist.pendingKey = key
      EnchanterAssist.sawFlare = false
      EnchanterAssist._attemptResolved = false
      EnchanterAssist.sessionTrials = EnchanterAssist.sessionTrials + 1

      DMLogger.notify(ea_plugin,
        ea_muted .. "TRY " .. ea_text .. key .. "\n")

      EnchanterAssist.state = "brewing"
      EnchanterAssist._raiseTrialEvent("ea.trial.start", { key = key, partCount = r, trial = EnchanterAssist.sessionTrials })
      dmapi.core.send("get", "key", EnchanterAssist.container)
      dmapi.core.send("alchemy", "key", table.concat(picks, " "))
      dmapi.core.send("alchemy essence")
      dmapi.core.send("\t")
      return
    end
  end

  -- exhausted
  DMLogger.notify(
      ea_plugin,
      ea_bad .. "No new combinations remain for "..r.."-part."
  )
  EnchanterAssist.autoRun = false
  EnchanterAssist.state = "idle"
end

function EnchanterAssist.showSessionFormulas()

  local discoveredCount = #EnchanterAssist.sessionFormulas

  if discoveredCount == 0 then
    cecho("\n" .. ea_warn .. "No formulas discovered this session.\n")
    return
  end

  cecho("\n" .. ea_info .. "===== Session Formulas =====\n")

  for _, name in ipairs(EnchanterAssist.sessionFormulas) do
    cechoLink(
      string.format("%s• %s<u>%s</u>\n", ea_accent, ea_text, name),
      function()
        send("alch info " .. name)
      end,
      "Click to view formula info",
      true
    )
  end

  cecho(ea_info .. "============================\n")
end

function EnchanterAssist.finishAttempt()
  EnchanterAssist.sawFlare   = false
  EnchanterAssist.pendingKey = nil
  EnchanterAssist._attemptResolved = false

  EnchanterAssist.state = "idle"
  if EnchanterAssist._hardStopRequested then
      EnchanterAssist._hardStopRequested = false
      DMLogger.notify(ea_plugin, ea_warn .. "Hard stop complete.")
      return
  end

  if EnchanterAssist.autoRun then
      EnchanterAssist.run()
  end
end

function EnchanterAssist.stats()

  local n = #EnchanterAssist.allmats

  cecho(
    "\n" .. ea_info .. "===== EnchanterAssist Progress ====="
  )

  for r = 1, 5 do

    local totalCombos = EnchanterAssist._nCr(n, r)

    local attemptedForMode = 0
    for key,_ in pairs(EnchanterAssist.attempted) do
      if key:match("^"..r..":") then
        attemptedForMode = attemptedForMode + 1
      end
    end

    local percent = 0
    if totalCombos > 0 then
      percent = (attemptedForMode / totalCombos) * 100
    end

    local lineColor = ea_muted
    if r == EnchanterAssist.partCount then
      lineColor = ea_good
    end

    cecho(
      string.format(
        "\n%s%d-part | %7d / %7d (%6.2f%%)",
        lineColor,
        r,
        attemptedForMode,
        totalCombos,
        percent
      )
    )
  end

  cecho("\n" .. ea_info .. "-------- Session Statistics --------")

  cecho(string.format(
    "\n%sTrials Attempted:    %s%4d",
    ea_text,
    ea_good,
    EnchanterAssist.sessionTrials
  ))

  local discoveredCount = #EnchanterAssist.sessionFormulas

  cecho(string.format(
    "\n%sFormulas Discovered: %s%4d ",
    ea_text,
    ea_accent,
    discoveredCount
  ))

  if discoveredCount > 0 then
    cechoLink(
      ea_gold .. "<u>[View All]</u>",
      function()
        EnchanterAssist.showSessionFormulas()
      end,
      "Show all discovered formulas",
      true
    )
  end
  
  cecho("\n" .. ea_info .. "====================================")
end

function EnchanterAssist.reset()
  EnchanterAssist._comboIndices = nil
  EnchanterAssist._wakePending = false
  EnchanterAssist.autoRun = false
  EnchanterAssist._hardStopRequested = false
  EnchanterAssist.state = "idle"
  EnchanterAssist.pendingKey = nil
  EnchanterAssist.sawFlare = false
  EnchanterAssist._attemptResolved = false
  EnchanterAssist.missing = {}
  EnchanterAssist.sessionTrials     = 0
  EnchanterAssist.sessionFormulas = {}
  EnchanterAssist._lastPotionRecovery = 0
  EnchanterAssist._stopPotionRecoveryTimer()

  math.randomseed(math.floor(((getEpoch and getEpoch()) or os.time()) * 1000))  -- millisecond precision
  EnchanterAssist._shuffleMaterials()

  EnchanterAssist.save()
  DMLogger.notify(ea_plugin, ea_good .. "Reset complete, Attempts preserved.")
end

function EnchanterAssist.statsMissing()

  cecho("\n" .. ea_info .. "===== Missing Materials =====")

  local count = 0
  for mat,_ in pairs(EnchanterAssist.missing) do
    count = count + 1
    cecho("\n" .. ea_warn .. "• " .. ea_text .. mat)
  end

  if count == 0 then
    cecho("\n" .. ea_good .. "None")
  else
    cecho("\n" .. ea_muted .. "("..count.." total)")
  end

  cecho("\n")
end

-- ============================================================================
-- Line Handler
-- ============================================================================
function EnchanterAssist.on_line(ln)
  if EnchanterAssist.enabled and EnchanterAssist.state == "brewing" then
    for pattern, data in pairs(highlightMap) do
      if ln:match(pattern) then
        local color = data[1]
        local tag   = data[2]

        selectCurrentLine()
        fg(color)
        replace(ln .. " " .. tag)
        resetFormat()

        -- mark that we saw a flare during this attempt
        EnchanterAssist.sawFlare = true
        return
      end
    end
  end

  if ln:match("^Total:%s+%d+ essences stored across %d+ materials %(%d+/%d+ total known%)$") then
      if EnchanterAssist.state == "brewing" then
        -- silent-known case
        if EnchanterAssist.sawFlare
          and not EnchanterAssist._contains(
                EnchanterAssist.attempted,
                EnchanterAssist.pendingKey) then

            DMLogger.notify(
              ea_plugin,
              ea_good .. "Already Known Formula: " .. ea_text .. EnchanterAssist.pendingKey
            )

            EnchanterAssist._add(
              EnchanterAssist.attempted,
              EnchanterAssist.pendingKey
            )

            EnchanterAssist.save()
            dmapi.core.send("alc", "extract", "key")
            EnchanterAssist._attemptResolved = true
        end

        if not EnchanterAssist._attemptResolved then
          return
        end

        EnchanterAssist.finishAttempt()
      end
      return
  end

  local m = ln:match("^You do not have essence of (%w+)%.")
  if m then
    DMLogger.notify(ea_plugin, ea_warn .. "Missing Essence: " .. ea_text .. m)
    local essence = string.lower(m)
    if not EnchanterAssist._contains(EnchanterAssist.missing, essence) then
      EnchanterAssist._add(EnchanterAssist.missing, essence)
      EnchanterAssist._comboIndices = nil
      EnchanterAssist.save()
    end
    if EnchanterAssist.state == "brewing" then
      EnchanterAssist._attemptResolved = true
    end
    return
  end

  if ln:match("^You lack the materials")
  or ln:match("^You must only use raw materials")
  or ln:match("^Alchemy only needs one of each kind of ingredient") then
    DMLogger.notify(ea_plugin, ea_bad .. "Bad Materials")
    if EnchanterAssist.state == "brewing" then
      EnchanterAssist._attemptResolved = true
    end
    return
  end
end

-- ============================================================================
-- REST LOGIC (DMAPI VITALS)
-- ============================================================================

function EnchanterAssist.init()
  EnchanterAssist.applyTheme()

  -- Use DarkmistsEvents so handlers are deduped/managed across reloads
  DarkmistsEvents.add("EnchanterAssist.NewLine", "dmapi.core.line", function(_, data)
    EnchanterAssist.on_line(data.line)
  end)

  DarkmistsEvents.add("EnchanterAssist.Vitals", "dmapi.player.vitals.updated", function()

    -- Only process vitals when either:
    --  • autorun is enabled (normal operation), or
    --  • we're currently in `resting` and need to detect recovery even if autorun
    --    was temporarily disabled. In all other cases, skip processing.
    if not EnchanterAssist.autoRun then
      if EnchanterAssist.state ~= "resting" then
        return
      end
    end

    local v = dmapi.player.vitals
    local manaPct = v.mnPct or 0
    local movePct = v.mvPct or 0

    local low  = (manaPct < 20) or (movePct < 20)
    local high = (manaPct > 90) and (movePct > 90)

    -------------------------------------------------
    -- IF SLEEPING
    -------------------------------------------------
    if dmapi.player.status.sleeping then

      -- Start refresh timer if not running
      EnchanterAssist._ensureSleepTimer()

      -- Wake when fully recovered
      if high then
        if EnchanterAssist.sleepRefreshTimer then
          DarkmistsTimer.remove("EnchanterAssist.SleepRefresh")
          EnchanterAssist.sleepRefreshTimer = nil
        end

        EnchanterAssist.state = "idle"
        dmapi.core.send("wake")

        tempTimer(0.3, function()
          if EnchanterAssist.autoRun and EnchanterAssist.state == "idle" then
            EnchanterAssist.run()
          end
        end)
      end

      return
    end

    local now = getEpoch()

    -- throttle to once every 3 seconds
    if EnchanterAssist.state ~= "resting"
      and now - EnchanterAssist._lastVitalsCheck < 3 then
      return
    end

    EnchanterAssist._lastVitalsCheck = now
    -- Exit resting (potion mode support)
    if high and EnchanterAssist.state == "resting" and not dmapi.player.status.sleeping then
      EnchanterAssist._stopPotionRecoveryTimer()
      EnchanterAssist.state = "idle"
      tempTimer(0.2, function()
        if EnchanterAssist.autoRun then
          EnchanterAssist.run()
        end
      end)
    end
    -------------------------------------------------
    -- IF LOW RESOURCES
    -------------------------------------------------
    if low then
      -- Never interrupt brewing. Let current attempt resolve, then rest gate blocks next trial.
      if EnchanterAssist.state == "brewing" then
        return
      end

      EnchanterAssist._startRestCycle()

      return
    end

  end)

  DarkmistsEvents.add("EnchanterAssist.AlchemyTired", "dmapi.player.alchemy.tired", function(_, data)
    if EnchanterAssist.state ~= "brewing" then
      return
    end

    -- If autorun is OFF, do not force rest.
    if not EnchanterAssist.autoRun then
      DMLogger.notify(
        ea_plugin,
        ea_warn .. "Too tired - Manual mode, not forcing rest."
      )
      EnchanterAssist.state = "idle"
      return
    end

    -- Do NOT mark attempt
    -- Do NOT advance combo index
    -- Keep pendingKey intact so it retries after rest
    EnchanterAssist._raiseTrialEvent("ea.trial.tired", { key = EnchanterAssist.pendingKey, line = data and data.line })
    EnchanterAssist._startRestCycle(ea_good .. "Too tired - Forcing Rest")
  end)

  DarkmistsEvents.add("EnchanterAssist.AlchemyNoItem", "dmapi.player.alchemy.noitem", function(_, data)
    if EnchanterAssist.state ~= "brewing" then
      return
    end

    DMLogger.notify(ea_plugin, ea_warn .. "Out of keys - stopping Enchanter Assist.")
    EnchanterAssist._raiseTrialEvent("ea.trial.noitem", { key = EnchanterAssist.pendingKey, line = data and data.line })
    EnchanterAssist.hardStop()
    EnchanterAssist.finishAttempt()
  end)

  DarkmistsEvents.add("EnchanterAssist.AlchemyAlreadyDone", "dmapi.player.alchemy.alreadydone", function(_, data)
    if EnchanterAssist.state ~= "brewing" then
      return
    end

    DMLogger.notify(ea_plugin, ea_warn .. "Item already alchemied - restarting attempt.")
    EnchanterAssist._raiseTrialEvent("ea.trial.alreadydone", { key = EnchanterAssist.pendingKey, line = data and data.line })
    EnchanterAssist.finishAttempt()
  end)

  DarkmistsEvents.add("EnchanterAssist.AlchemyBotch", "dmapi.player.alchemy.botch", function(_, data)
    if EnchanterAssist.state ~= "brewing" then
      return
    end

    EnchanterAssist._raiseTrialEvent("ea.trial.botch", { key = EnchanterAssist.pendingKey, line = data and data.line })
    EnchanterAssist._attemptResolved = true
    DMLogger.notify(ea_plugin, ea_bad .. "Skill check failed.")
  end)

  DarkmistsEvents.add("EnchanterAssist.AlchemyNomatch", "dmapi.player.alchemy.nomatch", function(_, data)
    if EnchanterAssist.state ~= "brewing" then
      return
    end

    if not EnchanterAssist._contains(EnchanterAssist.attempted, EnchanterAssist.pendingKey) then
      DMLogger.notify(ea_plugin, ea_warn .. "No formula from: " .. ea_text .. EnchanterAssist.pendingKey)
      EnchanterAssist._add(EnchanterAssist.attempted, EnchanterAssist.pendingKey)
      EnchanterAssist.save()
    end

    EnchanterAssist._raiseTrialEvent("ea.trial.nomatch", { key = EnchanterAssist.pendingKey, line = data and data.line })
    EnchanterAssist._attemptResolved = true
  end)

  DarkmistsEvents.add("EnchanterAssist.AlchemyDiscovered", "dmapi.player.alchemy.discovered", function(_, data)
    if EnchanterAssist.state ~= "brewing" then
      return
    end

    local formula = data and data.formula
    if formula and not EnchanterAssist._contains(EnchanterAssist.attempted, EnchanterAssist.pendingKey) then
      table.insert(EnchanterAssist.sessionFormulas, formula)
      dmapi.core.send("save")
      local msg = "Formula Discovered! "
        .. ea_text .. formula
        .. " " .. ea_muted .. "("
        .. ea_text .. EnchanterAssist.pendingKey
        .. ea_muted .. ")"
      DMLogger.notify(ea_plugin, msg)
      EnchanterAssist._playDiscoverSound()
      EnchanterAssist._raiseTrialEvent("ea.trial.discovered", { key = EnchanterAssist.pendingKey, formula = formula, line = data and data.line })
      dmapi.core.send("alc info",formula)
      EnchanterAssist._add(EnchanterAssist.attempted, EnchanterAssist.pendingKey)
      EnchanterAssist.save()
    end
    dmapi.core.send("alc", "extract", "key")
    EnchanterAssist._attemptResolved = true
  end)

  DarkmistsEvents.add("EnchanterAssist.WorldEnter", "dmapi.world.enter", function()
    EnchanterAssist._abortAttempt("reconnected")
  end)

  DarkmistsEvents.add("EnchanterAssist.Disconnect", "sysDisconnectionEvent", function()
    EnchanterAssist._abortAttempt("disconnected")
  end)

  EnchanterAssist.load()
  math.randomseed(math.floor(((getEpoch and getEpoch()) or os.time()) * 1000))  -- millisecond precision
  EnchanterAssist._shuffleMaterials()
  --EnchanterAssist.stats()

  if Darkmists and Darkmists.Log then
    Darkmists.Log(ea_plugin, "Ready for Usage!")
  end
end