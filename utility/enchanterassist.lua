-- ============================================================================
-- Dark Mists Enchanter Assistant (DMAPI Integrated + Persistent)
-- ============================================================================
EnchanterAssist = EnchanterAssist or {}

-- ============================================================================
-- CONFIG / STATE
-- ============================================================================

EnchanterAssist.enabled      = true
EnchanterAssist.autoRun      = false
EnchanterAssist.partCount    = 5

EnchanterAssist.attempted    = {}
EnchanterAssist.missing      = {}

EnchanterAssist.pendingKey   = nil
EnchanterAssist.pendingTimer = nil
EnchanterAssist.sleepRefreshTimer = nil
EnchanterAssist.sawFlare     = false
EnchanterAssist.inProgress   = false

EnchanterAssist.container    = "bag"
EnchanterAssist.sleeper      = "bedroll"
EnchanterAssist.sleepType    = 1   -- 1 = sleep, 0 = consumables
EnchanterAssist.drainItem    = "potion"
EnchanterAssist.color        = "<cornflower_blue>"

EnchanterAssist._wrapped     = false
EnchanterAssist._savePath    = getMudletHomeDir() .. "/ea_data.lua"

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
  ["^(.*) is momentarily encased in an aura of semitranslucent power%."] = {"pale_turquoise", "(SAVES)"},
  ["^(.*) glows a brief light blue%."] = {"cornflower_blue", "(ATTRIBUTES)"},
  ["^(.*) flares orange%."] = {"orange", "(RESOURCES)"},
  ["^(.*) is more sturdy%."] = {"plum", "(-AC)"},
  ["^(.*) glows a brief dark blue%."] = {"dark_slate_blue", "(OFFENSIVE)"},
  ["^(.*) vibrates for a moment%."] = {"royal_blue", "(SLOW or HASTE)"},
  ["^(.*) flares bright green, and you feel a sense of calm%."] = {"medium_sea_green", "(RESOURCE REGENERATION)"},
  ["^(.*) seems a lot less metallic%."] = {"sienna", "(NONMETAL)"},
  ["^(.*) begins to glow brightly%."] = {"deep_pink", "(GLOWING)"},
  ["^(.*) begins to hum%."] = {"firebrick", "(HUMMING)"},
  ["^(.*) emits a shimmering wave through the air%."] = {"light_steel_blue", "(ADDED AFFECT)"},
  ["^(.*) glows a sickly green%."] = {"olive_drab", "(CURSE)"},
  ["^(.*) seems heavier%."] = {"dim_gray", "(DOUBLE WEIGHT)"},
  ["^(.*) is less sturdy%."] = {"light_coral", "(+AC)"},
  ["^(.*) almost escapes your grasp%."] = {"ansi_magenta", "(FLYING)"},
  ["^(.*) looks a bit more expensive in quality%."] = {"dark_khaki", "(ADDED VALUE)"},
  ["^(.*) fades out and back into existence%."] = {"light_cyan", "(INVIS)"},
  ["^(.*) fades out of existence%."] = {"light_cyan", "(INVIS)"},
  ["^(.*) seems lighter%."] = {"rosy_brown", "(HALF WEIGHT)"},
  ["^(.*) sticks to your hands%."] = {"ansi_red", "(NOREMOVE)"},
  ["^(.*) flares with a blinding silver aura, a pulse of energy emanating from it%."] = {"light_gray", "(IMMUNITY)"},
  ["^(.*) begins to radiate a soft silver aura, shimmering vibrantly%."] = {"silver", "(RESIST)"}
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
    },
    attempted = EnchanterAssist.attempted,
    missing   = EnchanterAssist.missing
  }

  table.save(EnchanterAssist._savePath, data)
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Data saved to: <white>"..EnchanterAssist._savePath)
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
    EnchanterAssist.sleepType = data.config.sleepType or 1
    EnchanterAssist.drainItem = data.config.drainItem or "potion"
  end
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Data loaded from: <white>"..EnchanterAssist._savePath)
end

-- ============================================================================
-- CORE RUN
-- ============================================================================
function EnchanterAssist.run()
  if not EnchanterAssist.enabled then return end

  if EnchanterAssist.inProgress then
    Darkmists.Log(
      EnchanterAssist.color.."EnchanterAssist",
      "<dark_khaki>Waiting on current attempt..."
    )
    return
  end

  EnchanterAssist.inProgress = true

  local pool = EnchanterAssist._buildPool()

  if #pool < EnchanterAssist.partCount then
    Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","<dark_khaki>Not enough materials available.")
    EnchanterAssist.inProgress = false
    EnchanterAssist.autoRun = false
    return
  end

  local picks = EnchanterAssist._pick(pool, EnchanterAssist.partCount)
  local key   = EnchanterAssist.partCount .. ":" .. table.concat(picks, "|")

  local maxAttempts = 999999999999
  local attempts = 0

  while EnchanterAssist._contains(EnchanterAssist.attempted, key) do
    attempts = attempts + 1
    if attempts >= maxAttempts or #pool <= 1 then
      Darkmists.Log(
        EnchanterAssist.color.."EnchanterAssist",
        "<red>No new combinations remain for "..EnchanterAssist.partCount.."-part."
      )
      EnchanterAssist.inProgress = false
      EnchanterAssist.autoRun = false
      return
    end

    print("Pool size:", #pool)
    picks = EnchanterAssist._pick(pool, EnchanterAssist.partCount)
    key   = EnchanterAssist.partCount .. ":" .. table.concat(picks, "|")
  end

  EnchanterAssist.pendingKey   = key
  EnchanterAssist.sawFlare     = false

  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","TRY <white>" .. key.."\n")

  dmapi.core.send("get", "key", EnchanterAssist.container)
  dmapi.core.send("alchemy", "key", table.concat(picks, " "))

  -- Start fallback completion timer
  if EnchanterAssist.pendingTimer then
    killTimer(EnchanterAssist.pendingTimer)
  end

  EnchanterAssist.pendingTimer = tempTimer(8, function()

    if EnchanterAssist.inProgress
      and EnchanterAssist.sawFlare
      and not EnchanterAssist._contains(
          EnchanterAssist.attempted,
          EnchanterAssist.pendingKey) then

      Darkmists.Log(
        EnchanterAssist.color.."EnchanterAssist",
        "<medium_sea_green>Already Known Formula: <white>"..EnchanterAssist.pendingKey
      )

      EnchanterAssist._add(
        EnchanterAssist.attempted,
        EnchanterAssist.pendingKey
      )
      
      EnchanterAssist.save()

      dmapi.core.send("alc", "extract", "key")
    end
    EnchanterAssist.finishAttempt()
  end)
end

function EnchanterAssist.finishAttempt()
  EnchanterAssist.sawFlare     = false
  EnchanterAssist.inProgress   = false

  if EnchanterAssist.autoRun then
    tempTimer(1, EnchanterAssist.run)
  end
end

function EnchanterAssist.stats()

  local n = #EnchanterAssist.allmats

  cecho(--Darkmists.Log(
    --EnchanterAssist.color.."EnchanterAssist",
    "\n<cadet_blue>===== EnchanterAssist Progress ====="
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

    local lineColor = "<dim_gray>"
    if r == EnchanterAssist.partCount then
      lineColor = "<medium_sea_green>"
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
end

function EnchanterAssist.reset()
  EnchanterAssist.autoRun = false
  EnchanterAssist.pendingKey = nil
  EnchanterAssist.inProgress = false
  EnchanterAssist.missing = {}
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","<medium_sea_green>Reset complete, Attempts Preserved.")
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
      if EnchanterAssist.inProgress then
        EnchanterAssist.sawFlare = true
      end
      return
    end
  end

  local m = ln:match("^You do not have essence of (%w+)%.")
  if m then
    if EnchanterAssist.pendingTimer then
      killTimer(EnchanterAssist.pendingTimer)
      EnchanterAssist.pendingTimer = nil
    end
    Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","<dark_khaki>Missing Essence: <white>"..m)
    dmapi.core.send("put", "key", EnchanterAssist.container)
    EnchanterAssist._add(EnchanterAssist.missing, string.lower(m))
    EnchanterAssist.save()
    EnchanterAssist.finishAttempt()
    return
  end

  if ln:match("^You lack the materials")
  or ln:match("^You must only use raw materials")
  or ln:match("^Alchemy only needs one of each kind of ingredient") then
    if EnchanterAssist.pendingTimer then
      killTimer(EnchanterAssist.pendingTimer)
      EnchanterAssist.pendingTimer = nil
    end
    Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","<red>Bad Materials")
    EnchanterAssist.finishAttempt()
    return
  end
  
  if  ln:match("^You botch the brew, and your alchemy process") then
    if EnchanterAssist.pendingTimer then
      killTimer(EnchanterAssist.pendingTimer)
      EnchanterAssist.pendingTimer = nil
      EnchanterAssist.finishAttempt()
    end
    Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","<red>Skill check failed.")
    return
  end

  if ln:match("^Your alchemy process results in a gooey mess") then
    if EnchanterAssist.pendingTimer then
      killTimer(EnchanterAssist.pendingTimer)
      EnchanterAssist.pendingTimer = nil
    end
    if EnchanterAssist.inProgress and not EnchanterAssist._contains(EnchanterAssist.attempted, EnchanterAssist.pendingKey) then
      Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","<dark_khaki>No formula from: <white>"..EnchanterAssist.pendingKey)
      EnchanterAssist._add(EnchanterAssist.attempted, EnchanterAssist.pendingKey)
      EnchanterAssist.save()
    end
    EnchanterAssist.finishAttempt()
    return
  end

  local formula = ln:match("^You have discovered the alchemy formula (.*)!")
  if formula then
    if EnchanterAssist.pendingTimer then
      killTimer(EnchanterAssist.pendingTimer)
      EnchanterAssist.pendingTimer = nil
    end
    if EnchanterAssist.inProgress and not EnchanterAssist._contains(EnchanterAssist.attempted, EnchanterAssist.pendingKey) then
      local msg = "Formula Discovered! <white>%s <dim_gray>(<white>%s<dim_gray)"
      Darkmists.Log(EnchanterAssist.color.."EnchanterAssist",msg:format(formula,EnchanterAssist.pendingKey))
      dmapi.core.send("alc info",formula)
      EnchanterAssist._add(EnchanterAssist.attempted, EnchanterAssist.pendingKey)
      EnchanterAssist.save()
    end
    dmapi.core.send("alc", "extract", "key")
    EnchanterAssist.finishAttempt()
    return
  end
end

-- ============================================================================
-- REST LOGIC (DMAPI VITALS)
-- ============================================================================

registerNamedEventHandler(
  "darkmists.enchanter",
  "EnchanterAssist.newline",
  "dmapi.core.line",
  function(_,data)
    EnchanterAssist.on_line(data.line)
  end
)

registerNamedEventHandler(
  "darkmists.enchanter",
  "EnchanterAssist.vitals",
  "dmapi.player.vitals.updated",
  function()

    if not EnchanterAssist.autoRun then return end

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
      if not EnchanterAssist.sleepRefreshTimer then
        EnchanterAssist.sleepRefreshTimer = tempTimer(30, function()
          if dmapi.player.status.sleeping then
            send("")  -- refresh prompt/stats
          else
            EnchanterAssist.sleepRefreshTimer = nil
          end
        end,true)
      end

      -- Wake when fully recovered
      if high then
        if EnchanterAssist.sleepRefreshTimer then
          killTimer(EnchanterAssist.sleepRefreshTimer)
          EnchanterAssist.sleepRefreshTimer = nil
        end

        dmapi.core.send("wake")
        tempTimer(1, EnchanterAssist.run)
      end

      return
    end

    -------------------------------------------------
    -- IF LOW RESOURCES
    -------------------------------------------------
    if low then

      -- Cancel any active trial immediately
      if EnchanterAssist.inProgress then
        if EnchanterAssist.pendingTimer then
          killTimer(EnchanterAssist.pendingTimer)
          EnchanterAssist.pendingTimer = nil
        end

        EnchanterAssist.inProgress = false
        EnchanterAssist.sawFlare   = false
        EnchanterAssist.pendingKey = nil
      end

      -- Start sleep cycle
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

  end
)

-- ============================================================================
-- ALIASES
-- ============================================================================
-- =============================================================================
-- ENCHANTER ASSIST (EA) COMMAND
-- =============================================================================
tempAlias("^ea(?:\\s+(.*))?$", function()
  local c = DarkmistsMeta.colors.default
  local arg = matches[2] and matches[2]:trim() or ""

  -- HELP
  if arg == "" or arg == "help" then
    cecho([[
<ansi_cyan>EnchanterAssist Module:
    <dim_gray>Automation helper for enchantment workflow management.
    Controls draining, sleeping, part counts, and execution flow.

<ansi_cyan>EA Module Commands:
  ]]..c..[[ea run
    <dim_gray>Execute a single enchantment cycle.

  ]]..c..[[ea auto
    <dim_gray>Toggle automatic running mode.

  ]]..c..[[ea 1-5
    <dim_gray>Set enchantment part count (1–5),
    save configuration, and immediately run.

  ]]..c..[[ea stats
    <dim_gray>Display current session statistics.

  ]]..c..[[ea reset
    <dim_gray>Reset session statistics.

<ansi_cyan>Configuration Commands:
  ]]..c..[[ea set container <name>
    <dim_gray>Set container holding enchantment items.

  ]]..c..[[ea set sleeper <name>
    <dim_gray>Set sleeper target.

  ]]..c..[[ea set sleepmode <sleep|consume>
    <dim_gray>Choose sleep behavior type.

  ]]..c..[[ea set drain <item>
    <dim_gray>Set item used for draining.

<ansi_cyan>Control:
  ]]..c..[[ea enable
  ]]..c..[[ea disable
    <dim_gray>Enable or disable EnchanterAssist entirely.
]])
    return
  end
end)

tempAlias("^ea run$", function() EnchanterAssist.run() end)

tempAlias("^ea auto$", function()
  EnchanterAssist.autoRun = not EnchanterAssist.autoRun
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","AutoRun: " .. tostring(EnchanterAssist.autoRun))
end)

tempAlias("^ea 1$", function() EnchanterAssist.partCount = 1 EnchanterAssist.save() EnchanterAssist.run() end)
tempAlias("^ea 2$", function() EnchanterAssist.partCount = 2 EnchanterAssist.save() EnchanterAssist.run() end)
tempAlias("^ea 3$", function() EnchanterAssist.partCount = 3 EnchanterAssist.save() EnchanterAssist.run() end)
tempAlias("^ea 4$", function() EnchanterAssist.partCount = 4 EnchanterAssist.save() EnchanterAssist.run() end)
tempAlias("^ea 5$", function() EnchanterAssist.partCount = 5 EnchanterAssist.save() EnchanterAssist.run() end)

tempAlias("^ea reset$", EnchanterAssist.reset)

tempAlias("^ea stats$", EnchanterAssist.stats)

-- ============================================================================
-- CONFIG COMMANDS
-- ============================================================================

-- ea set container <name>
tempAlias("^ea set container (.+)$", function()
  EnchanterAssist.container = matches[2]
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Container set to: " .. EnchanterAssist.container)
end)

-- ea set sleeper <name>
tempAlias("^ea set sleeper (.+)$", function()
  EnchanterAssist.sleeper = matches[2]
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Sleeper set to: " .. EnchanterAssist.sleeper)
end)

-- ea set sleepmode <sleep|consume>
tempAlias("^ea set sleepmode (sleep|consume)$", function()
  if matches[2] == "sleep" then
    EnchanterAssist.sleepType = 1
  else
    EnchanterAssist.sleepType = 0
  end
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Sleep mode set to: " .. matches[2])
end)

-- ea set drain <item>
tempAlias("^ea set drain (.+)$", function()
  EnchanterAssist.drainItem = matches[2]
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Drain item set to: " .. EnchanterAssist.drainItem)
end)

-- ea enable / disable
tempAlias("^ea (enable|disable)$", function()
  if matches[2] == "enable" then
    EnchanterAssist.enabled = true
  else
    EnchanterAssist.enabled = false
  end
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Status: " .. tostring(EnchanterAssist.enabled))
end)

-- ============================================================================
-- LOAD STATE
-- ============================================================================

EnchanterAssist.load()
EnchanterAssist.stats()
Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Ready for Usage!")