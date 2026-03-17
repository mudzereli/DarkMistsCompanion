-- ============================================================================
-- Dark Mists Enchanter Assistant (DMAPI Integrated + Persistent)
-- ============================================================================
EnchanterAssist = EnchanterAssist or {}

-- ============================================================================
-- CONFIG / STATE
-- ============================================================================

EnchanterAssist.enabled      = true
EnchanterAssist.autoRun      = false
EnchanterAssist.playSoundOnDiscover = true
EnchanterAssist.partCount    = 5

EnchanterAssist.attempted    = {}
EnchanterAssist.missing      = {}

EnchanterAssist.pendingKey   = nil
EnchanterAssist.sleepRefreshTimer = nil
EnchanterAssist.sawFlare     = false
EnchanterAssist.state        = "idle"
EnchanterAssist.sessionTrials   = 0
EnchanterAssist.sessionFormulas = {}

EnchanterAssist.container    = "bag"
EnchanterAssist.sleeper      = "bedroll"
EnchanterAssist.sleepType    = 1   -- 1 = sleep, 0 = consumables
EnchanterAssist.drainItem    = "potion"

EnchanterAssist._lastVitalsCheck = 0
EnchanterAssist._comboIndices = nil
EnchanterAssist._wrapped     = false
EnchanterAssist._savePath    = getMudletHomeDir() .. "/ea_data.lua"
EnchanterAssist.color = DarkmistsTheme.accentTag

local ea_plugin = EnchanterAssist.color .. "EnchanterAssist"
local ea_text = DarkmistsTheme.textTag
local ea_muted = DarkmistsTheme.mutedTag
local ea_good = DarkmistsTheme.goodTag
local ea_warn = DarkmistsTheme.warnTag
local ea_bad = DarkmistsTheme.badTag
local ea_info = DarkmistsTheme.infoTag
local ea_accent = DarkmistsTheme.accentTag
local ea_gold = DarkmistsTheme.goldTag

local ea_red = DarkmistsTheme.red
local ea_orange = DarkmistsTheme.orange
local ea_green = DarkmistsTheme.green
local ea_blue = DarkmistsTheme.blue
local ea_cyan = DarkmistsTheme.cyan
local ea_light_blue = DarkmistsTheme.lightBlue
local ea_dark_blue = DarkmistsTheme.darkBlue
local ea_purple = DarkmistsTheme.purple
local ea_pink = DarkmistsTheme.pink
local ea_brown = DarkmistsTheme.brown
local ea_olive = DarkmistsTheme.olive
local ea_silver = DarkmistsTheme.silver
local ea_warn_color = DarkmistsTheme.warn
local ea_gold_color = DarkmistsTheme.gold
local ea_muted_color = DarkmistsTheme.muted

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

  EnchanterAssist.sleepRefreshTimer = tempTimer(30, function()
    if dmapi.player.status.sleeping then
      send("")  -- refresh prompt/stats
    else
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

local highlightMap = {
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

    Darkmists.Log(ea_plugin, msg)
    return
  end

  local pool = EnchanterAssist._buildPool()
  local n = #pool
  local r = EnchanterAssist.partCount

  if n < r then
      Darkmists.Log(
        ea_plugin,
        ea_warn .. "Not enough materials available."
      )
      return
  end

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
          EnchanterAssist.sessionTrials = EnchanterAssist.sessionTrials + 1

            Darkmists.Log(ea_plugin,
              ea_muted .. "TRY " .. ea_text .. key .. "\n")

          EnchanterAssist.state = "brewing"
          dmapi.core.send("get", "key", EnchanterAssist.container)
          dmapi.core.send("alchemy", "key", table.concat(picks, " "))
          dmapi.core.send("alchemy essence")
          dmapi.core.send("\t")
          return
      end

      indices = EnchanterAssist._nextCombination(indices, n, r)
      EnchanterAssist._comboIndices = indices
  end

  -- exhausted
  Darkmists.Log(
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
      string.format("%s• %s%s\n", ea_accent, ea_text, name),
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

  EnchanterAssist.state = "idle"
  if EnchanterAssist.autoRun then
      EnchanterAssist.run()
  end
end

function EnchanterAssist.stats()

  local n = #EnchanterAssist.allmats

  cecho(--Darkmists.Log(
    --EnchanterAssist.color.."EnchanterAssist",
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

    cecho(--Darkmists.Log(
      --EnchanterAssist.color.."EnchanterAssist",
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
      ea_gold .. "[View All]",
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
  EnchanterAssist.autoRun = false
  EnchanterAssist.state = "idle"
  EnchanterAssist.pendingKey = nil
  EnchanterAssist.sawFlare = false
  EnchanterAssist.sessionTrials     = 0
  EnchanterAssist.sessionFormulas = {}
  EnchanterAssist.missing = {}

  math.randomseed(os.time())   -- seed once per session
  EnchanterAssist._shuffleMaterials()

  EnchanterAssist.save()
  Darkmists.Log(ea_plugin, ea_good .. "Reset complete, Attempts Preserved.")
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
  for pattern, data in pairs(highlightMap) do
    if ln:match(pattern) then
      local color = data[1]
      local tag   = data[2]

      selectCurrentLine()
      fg(color)
      replace(ln .. " " .. tag)
      resetFormat()

      -- mark that we saw a flare during this attempt
      if EnchanterAssist.state == "brewing" then
        EnchanterAssist.sawFlare = true
      end
      return
    end
  end

  if ln:match("^Total:%s+%d+ essences stored across %d+ materials %(%d+/%d+ total known%)$") then
      if EnchanterAssist.state == "brewing" then

          -- silent-known case
          if EnchanterAssist.sawFlare
            and not EnchanterAssist._contains(
                  EnchanterAssist.attempted,
                  EnchanterAssist.pendingKey) then

              Darkmists.Log(
                ea_plugin,
                ea_good .. "Already Known Formula: " .. ea_text .. EnchanterAssist.pendingKey
              )

              EnchanterAssist._add(
                EnchanterAssist.attempted,
                EnchanterAssist.pendingKey
              )

              EnchanterAssist.save()
          end

          EnchanterAssist.finishAttempt()
      end
      return
  end

  if ln:match("^You are too tired to complete the process") then
    -- If autorun is OFF, do not force rest.
    if not EnchanterAssist.autoRun then
        Darkmists.Log(
          ea_plugin,
          ea_warn .. "Too tired - Manual mode, not forcing rest."
        )
        EnchanterAssist.state = "idle"
        return
    end

    -- Do NOT mark attempt
    -- Do NOT advance combo index
    -- Keep pendingKey intact so it retries after rest

    EnchanterAssist.state = "resting"

    Darkmists.Log(
      ea_plugin,
      ea_good .. "Too tired - Forcing Rest"
    )

    local v = dmapi.player.vitals
    local manaPct = v.mnPct or 0
    local movePct = v.mvPct or 0

    if EnchanterAssist.sleepType == 1 then
      -- Sleep mode
      dmapi.core.send("get", EnchanterAssist.sleeper, EnchanterAssist.container)
      dmapi.core.send("drop", EnchanterAssist.sleeper)
      dmapi.core.send("sleep", EnchanterAssist.sleeper)
      tempTimer(3, EnchanterAssist._ensureSleepTimer)
    else
      -- Potion mode (match vitals logic exactly)
      if manaPct < 90 then
        dmapi.core.send("get", EnchanterAssist.drainItem, EnchanterAssist.container)
        dmapi.core.send("quaff", EnchanterAssist.drainItem)
      end

      if movePct < 90 then
        dmapi.core.send("get", "refreshment", EnchanterAssist.container)
        dmapi.core.send("recite", "refreshment", "self")
      end
    end

    return
  end

  local m = ln:match("^You do not have essence of (%w+)%.")
  if m then
    Darkmists.Log(ea_plugin, ea_warn .. "Missing Essence: " .. ea_text .. m)
    dmapi.core.send("put", "key", EnchanterAssist.container)
    EnchanterAssist._add(EnchanterAssist.missing, string.lower(m))
    EnchanterAssist._comboIndices = nil
    EnchanterAssist.save()
    --EnchanterAssist.finishAttempt()
    return
  end

  if ln:match("^You lack the materials")
  or ln:match("^You must only use raw materials")
  or ln:match("^Alchemy only needs one of each kind of ingredient") then
    Darkmists.Log(ea_plugin, ea_bad .. "Bad Materials")
    --EnchanterAssist.finishAttempt()
    return
  end
  
  if  ln:match("^You botch the brew, and your alchemy process") then
    --EnchanterAssist.finishAttempt()
    Darkmists.Log(ea_plugin, ea_bad .. "Skill check failed.")
    return
  end

  if ln:match("^Your alchemy process results in a gooey mess") then
    if EnchanterAssist.state == "brewing" and not EnchanterAssist._contains(EnchanterAssist.attempted, EnchanterAssist.pendingKey) then
      Darkmists.Log(ea_plugin, ea_warn .. "No formula from: " .. ea_text .. EnchanterAssist.pendingKey)
      EnchanterAssist._add(EnchanterAssist.attempted, EnchanterAssist.pendingKey)
      EnchanterAssist.save()
    end
    --EnchanterAssist.finishAttempt()
    return
  end

  local formula = ln:match("^You have discovered the alchemy formula (.*)!")
  if formula then
    if EnchanterAssist.state == "brewing" and not EnchanterAssist._contains(EnchanterAssist.attempted, EnchanterAssist.pendingKey) then
      table.insert(EnchanterAssist.sessionFormulas, formula)
      dmapi.core.send("save")
      local msg = "Formula Discovered! "
        .. ea_text .. formula
        .. " " .. ea_muted .. "("
        .. ea_text .. EnchanterAssist.pendingKey
        .. ea_muted .. ")"
      Darkmists.Log(ea_plugin, msg)
      EnchanterAssist._playDiscoverSound()
      dmapi.core.send("alc info",formula)
      EnchanterAssist._add(EnchanterAssist.attempted, EnchanterAssist.pendingKey)
      EnchanterAssist.save()
    end
    dmapi.core.send("alc", "extract", "key")
    --EnchanterAssist.finishAttempt()
    return
  end
end

-- ============================================================================
-- REST LOGIC (DMAPI VITALS)
-- ============================================================================

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
        killTimer(EnchanterAssist.sleepRefreshTimer)
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

    -- Never interrupt brewing
    if EnchanterAssist.state == "brewing" then
      return
    end

    -- Already trying to rest? Don't resend commands
    if EnchanterAssist.state == "resting" then
      return
    end

    EnchanterAssist.state = "resting"

    if EnchanterAssist.sleepType == 1 then
      dmapi.core.send("get", EnchanterAssist.sleeper, EnchanterAssist.container)
      dmapi.core.send("drop", EnchanterAssist.sleeper)
      dmapi.core.send("sleep", EnchanterAssist.sleeper)
    else
      if manaPct < 20 then
        dmapi.core.send("get", EnchanterAssist.drainItem, EnchanterAssist.container)
        dmapi.core.send("quaff", EnchanterAssist.drainItem)
      end
      if movePct < 20 then
        dmapi.core.send("get", "refreshment", EnchanterAssist.container)
        dmapi.core.send("recite", "refreshment", "self")
      end
    end

    return
  end

end)

-- ============================================================================
-- LOAD STATE
-- ============================================================================

EnchanterAssist.load()
math.randomseed(os.time())   -- seed once per session
EnchanterAssist._shuffleMaterials()
--EnchanterAssist.stats()
Darkmists.Log(ea_plugin, "Ready for Usage!")