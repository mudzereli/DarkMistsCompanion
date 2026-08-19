--[[
================================================================================
  Dark Mists API (dmapi) - Professional Edition
  Version: 2.0.1
  Author: mudzereli
  
  A comprehensive event-driven API for Dark Mists MUD, providing:
  - Player state tracking (vitals, combat, experience, currency)
  - Combat state machine with round tracking
  - World state tracking (room, weather, time)
  - Robust event system for extensibility
  - Comprehensive parsing of MUD output
  
  Usage:
    The API automatically tracks game state and raises events that other
    scripts can listen to. Use registerNamedEventHandler() to respond to
    dmapi events.
    
  Commands:
    dmapi debug           - Toggle debug level (0-2)
    dmapi status          - Show current player state
    dmapi setvitals <hp> <mn> <mv> - Set maximum vitals
    dmapi guessvitals <level>      - Estimate vitals from level
    dmapi reset           - Reset all tracked state
================================================================================
]]--

-- ============================================================================
-- MODULE DEFINITION
-- ============================================================================

dmapi = {
  meta = {
    name = "dmapi",
    version = "2.0.1",
    author = "mudzereli",
    description = "Dark Mists API - Event-driven MUD state tracker"
  },
  
  settings = {
    themeColor = "<dark_slate_blue>",
    debugLevel = 0,
    combatRoundInterval = 3,
    promptTimeout = 3.0  -- Time before considering prompt stale
  }
}

-- ============================================================================
-- CORE STATE
-- ============================================================================

dmapi.core = {
  state = {
    initialized = false,
    combatMissedPrompts = 0,
    lastCombatRoundFired = getEpoch(),
    lastCommand = nil,
    capturingRoom = false,
    exitLineMarker = 0
  },
  
  -- One-line event mappings
  oneLineEvents = {
    ["You wake and stand up."] = {
      "dmapi.player.sleep.exit",
      "dmapi.player.rest.exit"
    },
    ["In your dreams, or what?"] = "dmapi.player.sleep.blocked",
    ["You do not have that item."] = "dmapi.player.inventory.itemnotfound",
    ["You cannot find it."] = "dmapi.player.inventory.itemnotfound",
    ["Alas, you cannot go that way."] = "dmapi.player.navigation.blocked",
    ["You are too exhausted."] = "dmapi.player.navigation.exhausted",
    ["You are not allowed in there."] = "dmapi.player.navigation.blocked",
    ["Nah... You feel too relaxed..."] = "dmapi.player.navigation.blocked",
    ["Better stand up first."] = "dmapi.player.navigation.blocked",
    ["It is pitch black ... "] = "dmapi.player.navigation.darkness",
    ["You cannot see a thing!"] = "dmapi.player.navigation.blinded",
    ["It is already empty."] = "dmapi.player.drink.empty",
    ["[Hit Return to continue]"] = "dmapi.world.pendingreturn",
    ["Welcome to Dark Mists.  Please do not feed the mobiles."] = "dmapi.world.enter",
    ["Welcome to the Dark Mists, a medieval fantasy role-playing and PK MUD!"] = "dmapi.world.connect",
    ["Reconnecting."] = "dmapi.world.enter",
    ["You choose a direction at random and begin to run..."] = "dmapi.player.combat.flee",
    ["Your stun wears off."] = "dmapi.player.affect.stunoff",
    ["You regain your senses."] = "dmapi.player.affect.stunoff",
  }
}

-- ============================================================================
-- PLAYER STATE
-- ============================================================================

dmapi.player = {
  level = 0,
  online = false,  
  age = {
    years = 0,
    hours = 0
  },
  
  currency = {
    gold = 0,
    silver = 0
  },

  bank = {
    gold = 0,
    silver = 0,
    house = 0
  },

  experience = {
    total = 0,
    tnl = 0,
    lastGain = 0,
    totalGained = 0
  },
  
  vitals = {
    estimated = false,
    hp = 0,
    mn = 0,
    mv = 0,
    rg = 0,  -- Rage percentage (if applicable)
    hpMax = 1,
    mnMax = 1,
    mvMax = 1,
    hpRegen = 0,
    mnRegen = 0,
    mvRegen = 0,
    practices = 0
  },
  stats = {
    attributes = {
      str = { base = 0, mod = 0 },
      int = { base = 0, mod = 0 },
      wis = { base = 0, mod = 0 },
      dex = { base = 0, mod = 0 },
      con = { base = 0, mod = 0 }
    }
  },
  status = {
    sleeping = false,
    resting = false,
    hungry = 0,    -- -1=full, 0=not hungry, 1-4=increasing hunger
    thirsty = 0,   -- 0=not thirsty, 1-4=increasing thirst
    stunned = false,
    position = "standing"  -- standing, resting, sleeping, fighting
  },
  
  combat = {
    active = false,
    round = 0,
    target = nil,
    targetHpPct = 0,
    lastActivity = getEpoch(),
    kills = 0,
    deaths = 0,
    damageDealt = 0,
    damageTaken = 0
  },
  
  -- Extensible state for custom modules
  state = {},
  actions = {}
}

-- Add computed properties to vitals
local vitalComputed = {
  hpPct = function(t)
    return (t.hpMax and t.hpMax > 0) and (t.hp / t.hpMax) * 100 or 0
  end,
  mnPct = function(t)
    return (t.mnMax and t.mnMax > 0) and (t.mn / t.mnMax) * 100 or 0
  end,
  mvPct = function(t)
    return (t.mvMax and t.mvMax > 0) and (t.mv / t.mvMax) * 100 or 0
  end
}

setmetatable(dmapi.player.vitals, {
  __index = function(t, k)
    local f = vitalComputed[k]
    if f then return f(t) end
  end
})

-- ============================================================================
-- WORLD STATE
-- ============================================================================

dmapi.world = {
  room = {
    seenAt = getEpoch(),
    vnum = nil,
    name = nil,
    description = nil,
    exits = {},
    mobiles = {},
    items = {}
  },
  
  time = {
    isDay = true,
    weather = "clear",
    weatherDetail = "clear"
  }
}

-- ============================================================================
-- PARSING FUNCTIONS
-- ============================================================================

dmapi.parsers = {}

--- Parse exits line: [Exits: north south east]
-- @param line string The line to parse
-- @return table|nil Array of exit directions
function dmapi.parsers.exits(line)
  local exitsBlob = line:match(DMPatterns.EXITS)
  if not exitsBlob then return nil end

  local exits = {}
  for dir in exitsBlob:gmatch("%S+") do
    table.insert(exits, dir)
  end

  return exits
end

--- Parse currency/experience lines
-- @param line string The line to parse
-- @return table|nil Parsed currency and experience data
function dmapi.parsers.currency(line)
  local gold, silver, xp, xpToLevel
  
  -- Try: You have X gold, Y silver, and Z experience (W exp to level)
  gold, silver, xp, xpToLevel = line:match(DMPatterns.CURRENCY_FULL)
  
  if not gold then
    -- Try: You have X gold, Y silver, and Z experience.
    gold, silver, xp = line:match(DMPatterns.CURRENCY_NOLVL)
    xpToLevel = -1
  end
  
  if not gold then
    -- Try: You have scored X exp, and have Y gold and Z silver coins.
    xp, gold, silver = line:match(DMPatterns.CURRENCY_SCORE)
    xpToLevel = -1
  end
  
  if not gold then return nil end
  
  return {
    gold = tonumber(gold),
    silver = tonumber(silver),
    experience = tonumber(xp),
    experienceToLevel = tonumber(xpToLevel),
    line = line
  }
end

--- Parse level up line
-- @param line string The line to parse
-- @return table|nil Parsed level up data
function dmapi.parsers.levelUp(line)
  local hp, hpMax, mn, mnMax, mv, mvMax, prac, pracTotal = line:match(DMPatterns.LEVEL_UP)
  
  if not hp then return nil end

  return {
    hpGain = tonumber(hp),
    hpMax = tonumber(hpMax),
    mnGain = tonumber(mn),
    mnMax = tonumber(mnMax),
    mvGain = tonumber(mv),
    mvMax = tonumber(mvMax),
    prac = tonumber(prac),
    pracTotal = tonumber(pracTotal),
    line = line
  }
end

--- Parse prompt line with multiple format support
-- @param line string The line to parse
-- @return table|nil Parsed prompt data
function dmapi.parsers.prompt(line)
  local hp, mn, mv, rg, tnl

  -- =========================================================================
  -- NEW NUMERIC PROMPT WITH REGEN SUPPORT
  -- Examples:
  -- <500hp(+25) 300mn(+10) 200mv(+5)>
  -- <500hp 300mn(+10) 200mv>
  -- <500hp(+25) 300mn(+10) 55%rg 200mv(+5)>
  -- <500hp 300mn 55%rg 200mv 20420tnl>
  -- =========================================================================

  if line:match(DMPatterns.PROMPT_HP_PREFIX) then
    local promptBody = line:match(DMPatterns.PROMPT_BODY)
    if not promptBody then return nil end

    local data = {
      line = line,
      tnl = -1,
      timestamp = getEpoch()
    }

    -- Helper: extract value and optional regen (HP/MN/MV only)
    local function extractWithRegen(stat)
      local value, regen = promptBody:match("(%d+)" .. stat .. "%(([-+]?%d+)%)")
      if not value then
        value = promptBody:match("(%d+)" .. stat)
      end

      if value then
        return tonumber(value), regen and tonumber(regen) or 0
      end

      return nil, nil
    end

    -- HP
    data.hp, data.hpRegen = extractWithRegen("hp")

    -- MN
    data.mn, data.mnRegen = extractWithRegen("mn")

    -- MV
    data.mv, data.mvRegen = extractWithRegen("mv")

    -- Rage (percent, NO regen)
    local rageVal = promptBody:match(DMPatterns.PROMPT_RAGE)
    if rageVal then
      data.rg = tonumber(rageVal)
    end

    -- TNL
    local tnlVal = promptBody:match(DMPatterns.PROMPT_TNL)
    if tnlVal then
      data.tnl = tonumber(tnlVal)
    end

    -- Must at minimum have hp/mn/mv
    if data.hp and data.mn and data.mv then
      return data
    end
  end


  -- =========================================================================
  -- LEGACY NUMERIC FORMATS (unchanged)
  -- =========================================================================

  -- <109hp 633mn 0%rg 192mv 20420tnl>
  hp, mn, rg, mv, tnl =
    line:match(DMPatterns.PROMPT_LEGACY_RAGE)
  if hp then
    return {
      hp = tonumber(hp),
      mn = tonumber(mn),
      rg = tonumber(rg),
      mv = tonumber(mv),
      tnl = tonumber(tnl),
      line = line
    }
  end

  -- <109hp 633mn 192mv 20420tnl>
  hp, mn, mv, tnl =
    line:match(DMPatterns.PROMPT_LEGACY_TNL)
  if hp then
    return {
      hp = tonumber(hp),
      mn = tonumber(mn),
      mv = tonumber(mv),
      tnl = tonumber(tnl),
      line = line
    }
  end

  -- <109hp 633mn 192mv>
  hp, mn, mv =
    line:match(DMPatterns.PROMPT_LEGACY_SIMPLE)
  if hp then
    return {
      hp = tonumber(hp),
      mn = tonumber(mn),
      mv = tonumber(mv),
      tnl = -1,
      line = line
    }
  end

  -- =========================================================================
  -- PERCENT PROMPTS WITH OPTIONAL REGEN SUPPORT
  -- Examples:
  -- <75%hp 60%mn 100%mv>
  -- <75%hp(+3) 60%mn(+2) 100%mv(+1)>
  -- <75%hp 60%mn 50%rg 100%mv 1200tnl>
  -- =========================================================================

  if line:match(DMPatterns.PROMPT_PCT_PREFIX) then
    local promptBody = line:match(DMPatterns.PROMPT_BODY)
    if not promptBody then return nil end

    local data = {
      estimated = true,
      line = line,
      tnl = -1
    }

    -- Helper for percent + optional regen
    local function extractPercentWithRegen(stat)
      local pct, regen = promptBody:match("(%d+)%%" .. stat .. "%(([-+]?%d+)%)")
      if not pct then
        pct = promptBody:match("(%d+)%%" .. stat)
      end

      if pct then
        return tonumber(pct), regen and tonumber(regen) or 0
      end

      return nil, nil
    end

    -- HP
    local hpPct, hpRegen = extractPercentWithRegen("hp")
    if hpPct then
      if dmapi.player.vitals.hpMax == 1 then
        dmapi.core.log("Max HP = 1. Use 'dmapi setvitals <hp> <mn> <mv>' to set correct values", "warn")
      end
      data.hp = math.ceil(hpPct / 100 * dmapi.player.vitals.hpMax)
      data.hpRegen = hpRegen
    end

    -- MN
    local mnPct, mnRegen = extractPercentWithRegen("mn")
    if mnPct then
      data.mn = math.ceil(mnPct / 100 * dmapi.player.vitals.mnMax)
      data.mnRegen = mnRegen
    end

    -- MV
    local mvPct, mvRegen = extractPercentWithRegen("mv")
    if mvPct then
      data.mv = math.ceil(mvPct / 100 * dmapi.player.vitals.mvMax)
      data.mvRegen = mvRegen
    end

    -- Rage (no regen)
    local rgPct = promptBody:match(DMPatterns.PROMPT_RAGE)
    if rgPct then
      data.rg = tonumber(rgPct)
    end

    -- TNL
    local tnlVal = promptBody:match(DMPatterns.PROMPT_TNL)
    if tnlVal then
      data.tnl = tonumber(tnlVal)
    end

    if data.hp and data.mn and data.mv then
      return data
    end
  end

  return nil
end

--- Parse vitals from score output
-- @param line string The line to parse
-- @return table|nil Parsed vitals data
function dmapi.parsers.vitalsFromScore(line)
  local hp, hpMax, mn, mnMax, mv, mvMax, rg
  
  -- Try with rage: You have 100/100 hit, 50/50 mana, 100/100 movement, 50% rage.
  hp, hpMax, mn, mnMax, mv, mvMax, rg = line:match(DMPatterns.VITALS_RAGE)

  if not hp then
    -- Try without rage
    hp, hpMax, mn, mnMax, mv, mvMax = line:match(DMPatterns.VITALS_NORAGE)
    rg = -1
  end

  if not hp then return nil end

  return {
    hp = tonumber(hp),
    hpMax = tonumber(hpMax),
    mn = tonumber(mn),
    mnMax = tonumber(mnMax),
    mv = tonumber(mv),
    mvMax = tonumber(mvMax),
    rg = tonumber(rg),
    line = line
  }
end

--- Parse level information from score
-- @param line string The line to parse
-- @return table|nil Parsed level data
function dmapi.parsers.levelFromScore(line)
  local level, years, hours = line:match(DMPatterns.LEVEL_FROM_SCORE)

  if not level then return nil end

  return {
    level = tonumber(level),
    years = tonumber(years),
    hours = tonumber(hours),
    line = line
  }
end

--- Parse mob condition line (combat state)
-- @param line string The line to parse
-- @return table|nil Parsed mob state data
function dmapi.parsers.mobCondition(line)
  for _, phrase in ipairs(DMConstants.COMBAT_CONDITIONS) do
    if line:find(phrase, 1, true) then
      local mob, condition, hpPct = line:match(
        "^(.+)%s+(" .. phrase .. ")[.!]%s+%((%d+%.?%d*)%%%)$"
      )

      if mob then
        return {
          target = mob,
          condition = condition,
          hpPct = tonumber(hpPct),
          line = line
        }
      end
      
      return nil
    end
  end

  return nil
end

--- Parse damage verb lines to extract combat damage information
-- Handles both outgoing damage (player attacking) and incoming damage (being attacked).
-- Uses the DMConstants.DAMAGE_VERBS lookup table to estimate damage ranges.
-- @param line string Raw MUD line
-- @return table|nil Damage info or nil if no damage verb matched
function dmapi.parsers.damageVerb(line)
  if not line or line == "" then return nil end

  -- Build verb list sorted longest-first so compound verbs like
  -- "*** DEMOLISHES ***" match before substrings like "DEMOLISHES"
  local verbList = {}
  for verb in pairs(DMConstants.DAMAGE_VERBS) do
    table.insert(verbList, verb)
  end
  table.sort(verbList, function(a, b) return #a > #b end)

  for _, verb in ipairs(verbList) do
    local verbStart, verbEnd = line:find(verb, 1, true)
    if verbStart then
      local beforeVerb = line:sub(1, verbStart - 1)
      local afterVerb  = line:sub(verbEnd + 1)
      local range      = DMConstants.DAMAGE_VERBS[verb]

      -- OUTGOING: "Your <attack> <verb> <target>[. | (<num>).]"
      -- e.g., "Your pound scratches a centaur warrior student."
      --       "Your pound scratches a centaur warrior student. (4)"
      local attack = beforeVerb:match("^Your%s+(.+)$")
      if attack then
        local actualDamage
        local target, dmg = afterVerb:match("^%s+(.-)%s%((%d+)%)%s*%.?$")
        if target then
          actualDamage = tonumber(dmg)
        else
          target = afterVerb:match("^%s+(.-)[%.!]$")
        end
        if target then
          target = target:gsub("%s+$", "")
          return {
            direction = "outgoing",
            verb = verb,
            attack = attack,
            target = target,
            minDamage = range[1],
            maxDamage = range[2],
            avgDamage = math.ceil((range[1] + range[2]) / 2),
            actualDamage = actualDamage,
            line = line
          }
        end
      end

      -- INCOMING: "<attacker>'s <attack> <verb> you[. | (<num>).]"
      -- e.g., "A centaur warrior student's slash misses you."
      --       "A centaur warrior student's slash wounds you."
      local attackerName, attackType = beforeVerb:match("^(.+)'s%s+(.+)$")
      if attackerName then
        local actualDamage
        local _, dmg = afterVerb:match("^%s+you%.?%s*%((%d+)%)%s*%.?$")
        if dmg then
          actualDamage = tonumber(dmg)
        end
        if afterVerb:match("^%s+you[%.!]") then
          return {
            direction = "incoming",
            verb = verb,
            attack = attackType,
            attacker = attackerName,
            minDamage = range[1],
            maxDamage = range[2],
            avgDamage = math.ceil((range[1] + range[2]) / 2),
            actualDamage = actualDamage,
            line = line
          }
        end

        -- OTHER-ON-OTHER: "<attacker>'s <attack> <verb> <target>[. | ! | (<num>).]"
        -- e.g., "An earth sage elemental's crush MUTILATES a Glyndane cityguard!"
        --       "A malamute's crush devastates a Glyndane cityguard."
        -- Falls through from the incoming check above (target is not "you")
        local actualDmgOther
        local target, dmgOther = afterVerb:match("^%s+(.-)%s%((%d+)%)%s*%.?$")
        if target then
          actualDmgOther = tonumber(dmgOther)
        else
          target = afterVerb:match("^%s+(.-)[%.!]$")
        end
        if target then
          target = target:gsub("%s+$", "")
          return {
            direction = "other",
            verb = verb,
            attack = attackType,
            attacker = attackerName,
            target = target,
            minDamage = range[1],
            maxDamage = range[2],
            avgDamage = math.ceil((range[1] + range[2]) / 2),
            actualDamage = actualDmgOther,
            line = line
          }
        end
      end
    end
  end

  return nil
end

--- Parse experience gain
-- @param line string The line to parse
-- @return number|nil Experience gained
function dmapi.parsers.experienceGain(line)
  local gain = line:match(DMPatterns.XP_GAIN)
  if gain then return tonumber(gain) end
  
  gain = line:match(DMPatterns.XP_RECEIVE)
  if gain then return tonumber(gain) end
  
  return nil
end

--- Parse skill improvement
-- @param line string The line to parse
-- @return string|nil Skill name
function dmapi.parsers.skillImproved(line)
  local skill = line:match(DMPatterns.SKILL_IMPROVED)
  if skill then return skill end
  
  skill = line:match(DMPatterns.SKILL_LEARNED)
  if skill then return skill end
  
  return nil
end

--- Parse eat/drink actions and failures
-- @param line string The line to parse
-- @return table|nil Parsed ingest event data
function dmapi.parsers.ingest(line)
  local item, container = line:match(DMPatterns.DRINK)
  if item and container then
    return {
      action = "drink",
      success = true,
      item = item,
      container = container,
      line = line,
      timestamp = getEpoch()
    }
  end

  item = line:match(DMPatterns.EAT)
  if item then
    return {
      action = "eat",
      success = true,
      item = item,
      line = line,
      timestamp = getEpoch()
    }
  end

  if line:match(DMPatterns.TOO_FULL) then
    return {
      action = "eat",
      success = false,
      reason = "full",
      line = line,
      timestamp = getEpoch()
    }
  end

  if line:match(DMPatterns.TOO_DRUNK) then
    return {
      action = "ingest",
      success = false,
      reason = "drunk",
      line = line,
      timestamp = getEpoch()
    }
  end

  return nil
end

--- Parse death detection
-- @param line string The line to parse
-- @return boolean True if player death detected
function dmapi.parsers.playerDeath(line)
  return line:match(DMPatterns.PLAYER_KILLED) ~= nil
    or line:match(DMPatterns.PLAYER_DEAD) ~= nil
end

--- Parse kill detection
-- @param line string The line to parse
-- @return string|nil Mob name if kill detected
function dmapi.parsers.mobKill(line)
  local mob = line:match(DMPatterns.MOB_DEAD)
  return mob
end

-- Parse Bank Balances
function dmapi.parsers.bankBalance(line)
  local gold, silver =
    line:match(DMPatterns.BANK_BALANCE)

  if gold then
    return {
      gold = tonumber(gold),
      silver = tonumber(silver),
      line = line
    }
  end

  if line:match(DMPatterns.BANK_NO_ACCOUNT) then
    return {
      gold = 0,
      silver = 0,
      line = line
    }
  end

  return nil
end

-- Parse House Balance
function dmapi.parsers.houseBalance(line)
  local gold =
    line:match(DMPatterns.HOUSE_BALANCE)

  if not gold then
    gold = line:match(DMPatterns.HOUSE_BALANCE_ALT)
  end

  if gold then
    return {
      gold = tonumber(gold),
      line = line
    }
  end

  return nil
end

-- Parse Bank Deposits
function dmapi.parsers.bankDeposit(line)
  local amount, currency =
    line:match(DMPatterns.BANK_DEPOSIT)

  if amount and (currency == "gold" or currency == "silver") then
    return {
      amount = tonumber(amount),
      currency = currency,
      line = line
    }
  end

  return nil
end

-- Parse Bank Withdrawals
function dmapi.parsers.bankWithdraw(line)
  local amount, currency, fee, feeCurrency =
    line:match(DMPatterns.BANK_WITHDRAW)

  if amount
     and (currency == "gold" or currency == "silver")
     and (feeCurrency == "gold" or feeCurrency == "silver")
  then
    return {
      amount = tonumber(amount),
      currency = currency,
      fee = tonumber(fee),
      feeCurrency = feeCurrency,
      total = tonumber(amount) + tonumber(fee),
      line = line
    }
  end

  return nil
end

function dmapi.parsers.bankWithdrawFail(line)
  if line:match(DMPatterns.BANK_NO_FUNDS, 1, true)
     or line:match(DMPatterns.BANK_NEED_FUNDS, 1, true)
  then
    return { line = line }
  end

  return nil
end

-- Parse Attributes from Score
function dmapi.parsers.attributes(line)
  local sB,sM,iB,iM,wB,wM,dB,dM,cB,cM =
    line:match(DMPatterns.ATTRIBUTES)

  if not sB then return nil end

  return {
    str = { base = tonumber(sB), mod = tonumber(sM) },
    int = { base = tonumber(iB), mod = tonumber(iM) },
    wis = { base = tonumber(wB), mod = tonumber(wM) },
    dex = { base = tonumber(dB), mod = tonumber(dM) },
    con = { base = tonumber(cB), mod = tonumber(cM) },
    line = line
  }
end

function dmapi.parsers.captureRoomName()
  moveCursorEnd()
  selectSection(0,1)
  if isAnsiFgColor(7) then
    dmapi.core.state.capturingRoom = true
    dmapi.world.room.name = line
    dmapi.core.raiseEvent("dmapi.world.room.name.updated",dmapi.world.room.name)
  end
end

function dmapi.parsers.captureRoomNameContinued()
  local state = dmapi.core.state
  state.exitLineMarker = state.exitLineMarker + 1
  if state.exitLineMarker == 2 then
    state.capturingRoom = false
  end
end

-- ============================================================================
-- CORE UTILITY FUNCTIONS
-- ============================================================================

--- Log a message with dmapi formatting
-- @param message string The message to log
-- @param level string Optional log level (info, warn, error)
function dmapi.core.log(message, level)
  level = level or "info"
  local prefix = string.format("[%s] ", string.upper(level))
  local formattedMessage = prefix .. tostring(message)

  if level == "warn" then
    formattedMessage = DarkmistsTheme.warnTag .. prefix .. DarkmistsTheme.textTag .. tostring(message)
  elseif level == "error" then
    formattedMessage = DarkmistsTheme.badTag .. prefix .. DarkmistsTheme.textTag .. tostring(message)
  else
    formattedMessage = DarkmistsTheme.mutedTag .. prefix .. DarkmistsTheme.textTag .. tostring(message)
  end

  DMLogger.log(dmapi.meta.name, formattedMessage)
end

--- Log a message to main window
-- @param message string The message to log
-- @param level string Optional log level (info, warn, error)
function dmapi.core.debug(message, level)
  level = level or "info"
  local prefix = string.format("[%s] ", string.upper(level))
  local formattedMessage = prefix .. tostring(message)

  if level == "warn" then
    formattedMessage = DarkmistsTheme.warnTag .. prefix .. DarkmistsTheme.textTag .. tostring(message)
  elseif level == "error" then
    formattedMessage = DarkmistsTheme.badTag .. prefix .. DarkmistsTheme.textTag .. tostring(message)
  else
    formattedMessage = DarkmistsTheme.mutedTag .. prefix .. DarkmistsTheme.textTag .. tostring(message)
  end

  DMLogger.notify(dmapi.meta.name, formattedMessage)
end

--- Send a command to the MUD
-- @param cmd string The base command
-- @param ... Additional arguments to append
function dmapi.core.send(cmd, ...)
  if not cmd then return end
  
  local args = {...}
  if #args > 0 then
    for i, a in ipairs(args) do
      if a ~= nil and a ~= "" then
        cmd = cmd .. " " .. tostring(a)
      end
    end
  end
  
  send(cmd)
end

--- Raise an event with optional debugging
-- @param eventName string The event name
-- @param ... Event data
function dmapi.core.raiseEvent(eventName, ...)
  if dmapi.settings.debugLevel > 1 then
    local data = {...}
    if #data > 0 then
      dmapi.core.debug(string.format("%s : %s", eventName, yajl.to_string(data[1])))
    else
      dmapi.core.debug(eventName)
    end
  elseif dmapi.settings.debugLevel > 0 then
    dmapi.core.debug(eventName)
  end
  
  raiseEvent(eventName, ...)

  -- Also fire the catch-all dmapi.communication event for any sub-event,
  -- so listeners can subscribe to a single event instead of all 27 variants.
  local commPrefix = "dmapi.communication."
  if eventName:sub(1, #commPrefix) == commPrefix then
    local commType = eventName:sub(#commPrefix + 1)
    local args = {...}
    local payload
    if type(args[1]) == "table" then
      payload = {}
      for k, v in pairs(args[1]) do payload[k] = v end
      payload.type = commType
    else
      payload = { type = commType }
    end
    local catchAllName = "dmapi.communication"
    if dmapi.settings.debugLevel > 1 then
      dmapi.core.debug(string.format("%s : %s", catchAllName, yajl.to_string(payload)))
    elseif dmapi.settings.debugLevel > 0 then
      dmapi.core.debug(catchAllName)
    end
    raiseEvent(catchAllName, payload)
  end
end

--- Get the last command sent
-- @return string|nil The last command
function dmapi.core.getLastCommand()
  return dmapi.core.state.lastCommand
end

--- Fire damage events for combat verb lines (outgoing/incoming).
-- Parses the line for damage verbs and raises typed events plus
-- accumulates damageDealt/damageTaken on the combat state.
-- @param line string Raw MUD line
-- @return boolean True if a damage verb was matched
local function maybeFireDamageEvent(line)
  local info = dmapi.parsers.damageVerb(line)
  if not info then return false end

  if info.direction == "outgoing" then
    dmapi.player.combat.damageDealt = (dmapi.player.combat.damageDealt or 0) + (info.actualDamage or info.avgDamage or 0)
    dmapi.core.raiseEvent("dmapi.player.combat.damage.outgoing", info)
  elseif info.direction == "incoming" then
    dmapi.player.combat.damageTaken = (dmapi.player.combat.damageTaken or 0) + (info.actualDamage or info.avgDamage or 0)
    dmapi.core.raiseEvent("dmapi.player.combat.damage.incoming", info)
  else
    dmapi.core.raiseEvent("dmapi.player.combat.damage.other", info)
  end

  return true
end

--- Fire periodic damage events for known tick-like afflictions
-- @param line string Raw MUD line
local function maybeFirePeriodicDamage(line)
  if not line or line == "" then return end

  local actor, kind

  local function afflictionToKind(affliction)
    affliction = affliction and affliction:lower() or nil
    if affliction == "sickness" then
      return "plague"
    end
    if affliction == "poison"
      or affliction == "starvation"
      or affliction == "dehydration"
    then
      return affliction
    end
    return nil
  end

  local affliction = line:match(DMPatterns.AFFLICTION_SELF)
  if affliction then
    kind = afflictionToKind(affliction)
    if kind then
      actor = "You"
    end
  end

  if not kind then
    local otherActor, otherAffliction = line:match(DMPatterns.AFFLICTION_OTHER)
    kind = afflictionToKind(otherAffliction)
    if kind then
      actor = otherActor
    end
  end

  if not kind then return end

  dmapi.core.raiseEvent("dmapi.player.damage.periodic", {
    actor = actor or "You",
    isPlayer = actor == nil or actor == "You",
    kind = kind,
    line = line,
    timestamp = getEpoch()
  })
end

--- Fire alchemy outcome events from raw line matches
-- @param line string Raw MUD line
local function maybeFireAlchemyOutcome(line)
  if not line or line == "" then return false end

  if line:match(DMPatterns.ALCHEMY_TIRED) then
    dmapi.core.raiseEvent("dmapi.player.alchemy.tired", {
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  if line:match(DMPatterns.ALCHEMY_NO_ITEM) then
    dmapi.core.raiseEvent("dmapi.player.alchemy.noitem", {
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  if line:match(DMPatterns.ALCHEMY_ALREADY_DONE) then
    dmapi.core.raiseEvent("dmapi.player.alchemy.alreadydone", {
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  if line:match(DMPatterns.ALCHEMY_BOTCH) then
    dmapi.core.raiseEvent("dmapi.player.alchemy.botch", {
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  if line:match(DMPatterns.ALCHEMY_NO_MATCH) then
    dmapi.core.raiseEvent("dmapi.player.alchemy.nomatch", {
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  if line:match(DMPatterns.ALCHEMY_WEAPON_ONLY) then
    dmapi.core.raiseEvent("dmapi.player.alchemy.weapononly", {
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  local formula = line:match(DMPatterns.ALCHEMY_DISCOVERED)
  if formula then
    dmapi.core.raiseEvent("dmapi.player.alchemy.discovered", {
      formula = formula,
      line = line,
      timestamp = getEpoch()
    })
    return true
  end

  return false
end

--- Fire a combat round event if enough time has passed
-- @param mobState table The mob state data
local function maybeFireCombatRound(mobState)
  local now = getEpoch()
  
  if (now - dmapi.core.state.lastCombatRoundFired) >= dmapi.settings.combatRoundInterval then
    dmapi.core.state.lastCombatRoundFired = now
    dmapi.player.combat.round = dmapi.player.combat.round + 1
    
    dmapi.core.raiseEvent("dmapi.player.combat.round", {
      target = mobState.target,
      condition = mobState.condition,
      hpPct = mobState.hpPct,
      round = dmapi.player.combat.round,
      line = mobState.line,
      timestamp = now
    })
  end
end

-- ============================================================================
-- COMMUNICATION HANDLERS
-- ============================================================================

local HOUSE_CHANNELS = {
  CONCLAVE = true,
  CRUSADER = true,
  LIGHT = true,
  BRETHREN = true,
  OUTLAW = true,
  JUSTICAR = true,
  DEPRAVED = true,
  ANCIENT = true,
  SCHOLAR = true,
  VALOR = true,
  LEGION = true,
  GAR = true,
  GML = true,
  SG = true,
  OE = true,
  DRE = true,
  KEY = true,
  HIVEMIND = true
}

local function handleCommunicationLine(line)
  local sender, emote, message, receiver, channel

  -- EMOTED SAY: Role-played speech with an emote action (e.g., "Warrior smiles says, 'Hello!'")
  -- Used for immersive roleplay and emotional expression in dialogue
  sender, emote, message = line:match(DMPatterns.COMM_EMOTE_SAY_RECV)
  if sender and emote and message then
    local firstWord = sender:lower()
    if firstWord ~= "the" and firstWord ~= "a" and firstWord ~= "an" then
      dmapi.core.raiseEvent("dmapi.communication.emotedsayreceived", {
        sender = sender,
        emote = emote,
        message = message,
        line = line
      })
      return true
    end
  end

  -- Player's own emoted say (sent by player)
  emote, message = line:match(DMPatterns.COMM_EMOTE_SAY_SENT)
  if emote and message then
    dmapi.core.raiseEvent("dmapi.communication.emotedsaysent", {
      sender = "You",
      emote = emote,
      message = message,
      line = line
    })
    return true
  end

  -- PANIC YELL: Emergency/distress signal used in combat or danger situations
  -- Higher priority message that alerts nearby players to danger
  message = line:match(DMPatterns.COMM_PANIC_YELL_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.yellpanicsent", {
      sender = "You",
      message = message,
      line = line
    })
    return true
  end

  -- Receiving another player's panic yell
  sender, message = line:match(DMPatterns.COMM_PANIC_YELL_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.yellpanicreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- MENTAL BLAST: Psychic yell; telepathic communication heard far and wide
  -- Like yell but transmitted telepathically instead of vocally
  sender, message = line:match(DMPatterns.COMM_MENTAL_BLAST_RECV)
  if sender and message then
    dmapi.core.raiseEvent("dmapi.communication.mentalblastreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own mental blast (sent by player); psychic yell version
  message = line:match(DMPatterns.COMM_MENTAL_BLAST_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.mentalblastsent", {
      sender = "You",
      message = message,
      line = line
    })
    return true
  end

  -- MENTAL BLAST PANIC: Emergency telepathic distress signal
  -- Combines mental projection with urgency/alarm
  message = line:match(DMPatterns.COMM_MP_PANIC_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.mentalblastpanicsent", {
      sender = "You",
      message = message,
      line = line
    })
    return true
  end

  -- Receiving another player's panic mental blast
  sender, message = line:match(DMPatterns.COMM_MP_PANIC_RECV)
  if sender and message then
    dmapi.core.raiseEvent("dmapi.communication.mentalblastpanicreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- TELL: Private direct message from another player
  -- Only visible to sender and recipient; used for private conversations
  sender, message = line:match(DMPatterns.COMM_TELL_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.tellreceived", {
      sender = sender,
      receiver = "Me",
      message = message,
      line = line
    })
    return true
  end

  -- Player's own tell (sent by player)
  receiver, message = line:match(DMPatterns.COMM_TELL_SENT)
  if receiver then
    dmapi.core.raiseEvent("dmapi.communication.tellsent", {
      sender = "Me",
      receiver = receiver,
      message = message,
      line = line
    })
    return true
  end

  -- SAY: Public local communication heard by everyone in the same room
  -- Standard roleplay dialogue; immersive and socially visible
  sender, message = line:match(DMPatterns.COMM_SAY_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.sayreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own say (sent by player)
  message = line:match(DMPatterns.COMM_SAY_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.saysent", {
      sender = "Player",
      message = message,
      line = line
    })
    return true
  end

  -- MENTAL PROJECTION: Non-hostile telepathic communication
  -- Used for friendly psychic messages, mystical communication, or supernatural abilities
  sender, message = line:match(DMPatterns.COMM_MP_SAY_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.mpsayreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own mental projection (sent by player)
  message = line:match(DMPatterns.COMM_MP_SAY_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.mpsaysent", {
      sender = "Player",
      message = message,
      line = line
    })
    return true
  end

  -- MENTAL PROJECTION TELL: Private telepathic direct message
  -- Combines mental projection with targeted delivery like a tell
  sender, message = line:match(DMPatterns.COMM_MP_TELL_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.mptellreceived", {
      sender = sender,
      receiver = "Me",
      message = message,
      line = line
    })
    return true
  end

  -- MENTAL PROJECTION GROUP: Telepathic message sent to party/group
  sender, message = line:match(DMPatterns.COMM_MP_GROUP_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.mpgtellreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own mental projection group message (sent by player)
  message = line:match(DMPatterns.COMM_MP_GROUP_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.mpgtellsent", {
      sender = "Player",
      message = message,
      line = line
    })
    return true
  end

  -- Player's own mental projection tell (sent by player)
  receiver, message = line:match(DMPatterns.COMM_MP_TELL_SENT)
  if receiver then
    dmapi.core.raiseEvent("dmapi.communication.mptellsent", {
      sender = "Me",
      receiver = receiver,
      message = message,
      line = line
    })
    return true
  end

  -- GROUP TELL: Message to your adventuring group/party
  -- Visible only to grouped members; used for team coordination
  sender, message = line:match(DMPatterns.COMM_GROUP_TELL_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.gtellreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own group tell (sent by player)
  message = line:match(DMPatterns.COMM_GROUP_TELL_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.gtellsent", {
      sender = "Player",
      message = message,
      line = line
    })
    return true
  end

  -- YELL: Loud public communication heard across a wide area
  -- Used for announcements or urgent public messages; more far-reaching than say
  sender, message = line:match(DMPatterns.COMM_YELL_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.yellreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own yell (sent by player)
  message = line:match(DMPatterns.COMM_YELL_SENT)
  if message then
    dmapi.core.raiseEvent("dmapi.communication.yellsent", {
      sender = "Player",
      message = message,
      line = line
    })
    return true
  end

  -- NEWBIE CHANNEL: Public channel for new player questions and assistance
  -- Used for onboarding, mentoring, and new player support
  sender, message = line:match(DMPatterns.COMM_NEWBIE)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.newbiechannel", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- NEWBIE CHANNEL DISCORD RELAY: Messages relayed from Discord server to in-game newbie channel
  -- Allows Discord users to assist new players in-game
  sender, message = line:match(DMPatterns.COMM_NEWBIE_DISCORD)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.newbiechanneldiscord", {
      sender = sender,
      message = message,
      line = line
    })
    return true
  end

  -- Player's own OOC message (sent by player)
  receiver, message = line:match(DMPatterns.COMM_OOC_SENT)
  if receiver then
    dmapi.core.raiseEvent("dmapi.communication.oocsent", {
      sender = "Me",
      receiver = receiver,
      message = message,
      line = line
    })
    return true
  end

  -- OOC (OUT OF CHARACTER): Non-roleplay meta-communication
  -- Used for discussing game mechanics, rules, strategy outside of roleplay
  sender, message = line:match(DMPatterns.COMM_OOC_RECV)
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.oocreceived", {
      sender = sender,
      receiver = "Me",
      message = message,
      line = line
    })
    return true
  end

  -- HOUSE CHANNELS: Guild/organization-specific communication channels
  -- Each house (faction, guild) has its own private channel for member coordination
  -- Examples: CONCLAVE, CRUSADER, LIGHT, BRETHREN, OUTLAW, JUSTICAR, etc.
  channel, sender, message = line:match(DMPatterns.COMM_HOUSE_CHANNEL)
  if sender and HOUSE_CHANNELS[channel] then
    dmapi.core.raiseEvent("dmapi.communication.housechannel", {
      sender = sender,
      receiver = channel,
      message = message,
      line = line
    })
    return true
  end

  return false
end

-- ============================================================================
-- LINE TRIGGER - MAIN PARSING LOGIC
-- ============================================================================

--- Main line trigger function - parses all MUD output
-- @param line string The line to parse
function dmapi.core.LineTrigger(line)
  -- Raise generic line event (opt-in for performance)
  raiseEvent("dmapi.core.line", {line = line})
  
  -- Check one-line event mappings
  local oneLineEvent = dmapi.core.oneLineEvents[line]
  if oneLineEvent then
    if type(oneLineEvent) == "table" then
      for _, eventName in ipairs(oneLineEvent) do
        dmapi.core.raiseEvent(eventName, {line = line})
      end
    else
      dmapi.core.raiseEvent(oneLineEvent, {line = line})
    end
    return
  end

  if handleCommunicationLine(line) then
    return
  end

  if maybeFireAlchemyOutcome(line) then
    return
  end

  -- Emit raw periodic-damage cues after communication parsing to avoid chat false positives.
  maybeFirePeriodicDamage(line)

  -- Parse damage verb lines (outgoing/incoming combat damage).
  -- Returns early if matched to avoid falling through to unrelated parsers.
  if maybeFireDamageEvent(line) then
    return
  end

  -- Parse ingest successes and failures.
  local ingest = dmapi.parsers.ingest(line)
  if ingest then
    if ingest.success then
      dmapi.core.raiseEvent("dmapi.player.ingest", ingest)
    else
      dmapi.core.raiseEvent("dmapi.player.ingest.fail", ingest)
    end
  end

  -- Parse closed door: The door is closed.
  local closedName = line:match(DMPatterns.DOOR_CLOSED)
  if closedName then
    dmapi.core.raiseEvent("dmapi.player.navigation.closed", {
      name = closedName,
      line = line
    })
    return
  end
  
  -- Parse locked door
  if line:match(DMPatterns.DOOR_LOCKED) then
    dmapi.core.raiseEvent("dmapi.player.navigation.locked", {line = line})
    return
  end
  
  -- Parse skill improvement
  local skill = dmapi.parsers.skillImproved(line)
  if skill then
    dmapi.core.raiseEvent("dmapi.player.skill.improved", {
      skill = skill,
      line = line
    })
    return
  end
  
  -- Parse experience gain
  local xpGain = dmapi.parsers.experienceGain(line)
  if xpGain then
    dmapi.player.experience.lastGain = xpGain
    dmapi.player.experience.total = dmapi.player.experience.total + xpGain
    dmapi.player.experience.totalGained = dmapi.player.experience.totalGained + xpGain
    dmapi.player.experience.tnl = math.max(0, dmapi.player.experience.tnl - xpGain)
    
    dmapi.core.raiseEvent("dmapi.player.experience.gain", {
      amount = xpGain,
      total = dmapi.player.experience.total,
      tnl = dmapi.player.experience.tnl,
      line = line
    })
    return
  end
  
  local silver, gold, source
  -- Parse coin gains from corpses
  silver, gold, source = line:match(DMPatterns.LOOT_CORPSE_BOTH)
  if not source then
    silver, source = line:match(DMPatterns.LOOT_CORPSE_SILVER)
  end
  if not source then
    gold, source = line:match(DMPatterns.LOOT_CORPSE_GOLD)
  end
  if not source then
    source, silver, gold = line:match(DMPatterns.LOOT_SELL)
  end
  if not source then
    silver = line:match(DMPatterns.LOOT_SACRIFICE)
    if silver == "one" then
      silver = 1
    end
    if silver then
      source = "sacrifice"
    end
  end
  if not source then
    source, silver = line:match(DMPatterns.LOOT_BUY)
    -- we want to make the silver negative since we're purchasing
    if silver then
      silver = silver * -1
    end
  end
  if source then
    silver = tonumber(silver) or 0
    gold = tonumber(gold) or 0
    -- if the purchase makes us dip below 0 silver, then recalculate our gold/silver
    if dmapi.player.currency.silver + silver < 0 then
      local totalSilver = (dmapi.player.currency.gold * 100) + dmapi.player.currency.silver
      totalSilver = totalSilver + silver
      dmapi.player.currency.gold = math.floor(totalSilver/100)
      dmapi.player.currency.silver = ((totalSilver/100)-math.floor(totalSilver/100))*100
    else
      dmapi.player.currency.silver = dmapi.player.currency.silver + silver
      dmapi.player.currency.gold = dmapi.player.currency.gold + gold
    end
    
    dmapi.core.raiseEvent("dmapi.player.currency.gain", {
      silver = silver,
      gold = gold,
      source = source,
      line = line
    })
    return
  end

  -- Bank Balance Updates
  local bankBal = dmapi.parsers.bankBalance(line)
  if bankBal then
    dmapi.player.bank.gold = bankBal.gold
    dmapi.player.bank.silver = bankBal.silver

    dmapi.core.raiseEvent("dmapi.player.bank.balance", bankBal)
    return
  end

  -- House Balance Updates
  local houseBal = dmapi.parsers.houseBalance(line)
  if houseBal then
    dmapi.player.bank.house = houseBal.gold

    dmapi.core.raiseEvent("dmapi.player.house.balance", houseBal)
    return
  end

  -- Bank Deposits
  local deposit = dmapi.parsers.bankDeposit(line)
  if deposit then
    if deposit.currency == "gold" then
      dmapi.player.currency.gold = dmapi.player.currency.gold - deposit.amount
      dmapi.player.bank.gold = dmapi.player.bank.gold + deposit.amount
    elseif deposit.currency == "silver" then
      dmapi.player.currency.silver = dmapi.player.currency.silver - deposit.amount
      dmapi.player.bank.silver = dmapi.player.bank.silver + deposit.amount
    end

    dmapi.core.raiseEvent("dmapi.player.bank.deposit", deposit)
    return
  end

  -- Bank Withdrawals
  local withdraw = dmapi.parsers.bankWithdraw(line)
  if withdraw then
    if withdraw.currency == "gold" then
      dmapi.player.currency.gold = dmapi.player.currency.gold + withdraw.amount
      dmapi.player.bank.gold = dmapi.player.bank.gold - withdraw.amount - withdraw.fee
    elseif withdraw.currency == "silver" then
      dmapi.player.currency.silver = dmapi.player.currency.silver + withdraw.amount
      dmapi.player.bank.silver = dmapi.player.bank.silver - withdraw.amount - withdraw.fee
    end

    dmapi.core.raiseEvent("dmapi.player.bank.withdraw", withdraw)
    return
  end

  -- Bank Withdrawal Failure
  local withdrawFail = dmapi.parsers.bankWithdrawFail(line)
  if withdrawFail then
    dmapi.core.raiseEvent("dmapi.player.bank.withdraw.fail", withdrawFail)
    return
  end

  -- Parse equipment zapped
  local zappedItem = line:match(DMPatterns.EQUIP_ZAPPED)
  if zappedItem then
    dmapi.core.raiseEvent("dmapi.player.equipment.zapped", {
      item = zappedItem,
      line = line
    })
    return
  end
  
  -- Parse disarm
  local disarmer = line:match(DMPatterns.COMBAT_DISARM)
  if disarmer then
    dmapi.core.raiseEvent("dmapi.player.combat.disarmed", {
      disarmer = disarmer,
      line = line
    })
    return
  end

  -- Parse sleep
  local sleepOn = line:match(DMPatterns.SLEEP_ON)
  if line:match(DMPatterns.SLEEP) or sleepOn then
    dmapi.core.raiseEvent("dmapi.player.sleep.enter", {
      sleepOn = sleepOn,
      line = line
    })
    return
  end
  
  -- Parse rest
  if line:match(DMPatterns.REST_SIT) 
      or line:match(DMPatterns.REST_ENTER) then
    dmapi.player.status.resting = true
    dmapi.core.raiseEvent("dmapi.player.rest.enter", {line = line})
    return
  end
  
  if line:match(DMPatterns.REST_EXIT)
    or line:match(DMPatterns.STAND_UP) then
    dmapi.player.status.resting = false
    dmapi.core.raiseEvent("dmapi.player.rest.exit", {line = line})
    return
  end
  
  -- Parse exits
  local exits = dmapi.parsers.exits(line)
  if exits then
    dmapi.world.room.exits = exits
    dmapi.world.room.seenAt = getEpoch()
    dmapi.core.raiseEvent("dmapi.world.room.exits.updated", {
      exits = exits,
      line = line
    })
    return
  end
  
  -- Parse currency
  local currencyData = dmapi.parsers.currency(line)
  if currencyData then
    dmapi.player.currency.gold = currencyData.gold
    dmapi.player.currency.silver = currencyData.silver
    dmapi.player.experience.total = currencyData.experience
    
    if currencyData.experienceToLevel >= 0 then
      dmapi.player.experience.tnl = currencyData.experienceToLevel
    end
    
    dmapi.core.raiseEvent("dmapi.player.currency.update", currencyData)
    return
  end
  
  -- Parse vitals from score
  local vitalsFromScore = dmapi.parsers.vitalsFromScore(line)
  if vitalsFromScore then
    dmapi.player.vitals.estimated = false
    dmapi.player.vitals.hp = vitalsFromScore.hp
    dmapi.player.vitals.hpMax = vitalsFromScore.hpMax
    dmapi.player.vitals.mn = vitalsFromScore.mn
    dmapi.player.vitals.mnMax = vitalsFromScore.mnMax
    dmapi.player.vitals.mv = vitalsFromScore.mv
    dmapi.player.vitals.mvMax = vitalsFromScore.mvMax
    
    if vitalsFromScore.rg >= 0 then
      dmapi.player.vitals.rg = vitalsFromScore.rg
    end
    
    dmapi.core.raiseEvent("dmapi.player.vitals.updated", vitalsFromScore)
    return
  end
  
  -- Parse level from score
  local levelInfo = dmapi.parsers.levelFromScore(line)
  if levelInfo then
    dmapi.player.level = levelInfo.level
    dmapi.player.age.years = levelInfo.years
    dmapi.player.age.hours = levelInfo.hours
    
    dmapi.core.raiseEvent("dmapi.player.level.updated", levelInfo)
    return
  end
  
  -- Parse prompt
  local vitals = dmapi.parsers.prompt(line)
  if vitals then
    if not dmapi.player.online then
      dmapi.player.online = true
      dmapi.core.raiseEvent("dmapi.world.enter")
    end
    dmapi.player.vitals.hp = vitals.hp
    dmapi.player.vitals.mn = vitals.mn
    dmapi.player.vitals.mv = vitals.mv

    if vitals.hpRegen then
      dmapi.player.vitals.hpRegen = tonumber(vitals.hpRegen)
    end
    if vitals.mnRegen then
      dmapi.player.vitals.mnRegen = tonumber(vitals.mnRegen)
    end
    if vitals.mvRegen then
      dmapi.player.vitals.mvRegen = tonumber(vitals.mvRegen)
    end
    
    -- Auto-update max if current exceeds known max
    if dmapi.player.vitals.hp > dmapi.player.vitals.hpMax then
      dmapi.player.vitals.hpMax = dmapi.player.vitals.hp
    end
    if dmapi.player.vitals.mn > dmapi.player.vitals.mnMax then
      dmapi.player.vitals.mnMax = dmapi.player.vitals.mn
    end
    if dmapi.player.vitals.mv > dmapi.player.vitals.mvMax then
      dmapi.player.vitals.mvMax = dmapi.player.vitals.mv
    end
    
    if vitals.tnl and vitals.tnl >= 0 then
      dmapi.player.experience.tnl = vitals.tnl
    end
    
    if vitals.rg then
      dmapi.player.vitals.rg = vitals.rg
    end
    
    dmapi.core.raiseEvent("dmapi.player.vitals.updated", vitals)
    dmapi.core.raiseEvent("dmapi.world.prompt", vitals)
    return
  end
  
  -- Parse level up
  local levelUp = dmapi.parsers.levelUp(line)
  if levelUp then
    dmapi.player.vitals.estimated = false
    dmapi.player.vitals.hpMax = levelUp.hpMax
    dmapi.player.vitals.mnMax = levelUp.mnMax
    dmapi.player.vitals.mvMax = levelUp.mvMax
    dmapi.player.vitals.practices = levelUp.pracTotal
    
    dmapi.core.raiseEvent("dmapi.player.levelup", levelUp)
    return
  end
  
  -- Parse thirst
  local thirstLevel =
        line:match(DMPatterns.THIRST_LEVEL1)               and 1
     or line:match(DMPatterns.THIRST_LEVEL2)          and 2
     or line:match(DMPatterns.THIRST_LEVEL3) and 3
     or line:match(DMPatterns.THIRST_LEVEL4)        and 4
     or line:match(DMPatterns.THIRST_QUENCHED)       and 0

  if thirstLevel then
    dmapi.player.status.thirsty = thirstLevel

    dmapi.core.raiseEvent("dmapi.player.thirst.update", {
      intensity = thirstLevel,
      line = line,
      timestamp = getEpoch()
    })
    return
  end
  
  -- Parse hunger
  local hungerLevel =
        line:match(DMPatterns.HUNGER_LEVEL1)              and 1
     or line:match(DMPatterns.HUNGER_LEVEL2)             and 2
     or line:match(DMPatterns.HUNGER_LEVEL3)  and 3
     or line:match(DMPatterns.HUNGER_LEVEL4)             and 4
     or line:match(DMPatterns.HUNGER_STARVATION)               and 4
     or line:match(DMPatterns.HUNGER_SATED)    and 0
     or line:match(DMPatterns.HUNGER_FULL)                and -1
     or line:match(DMPatterns.TOO_FULL) and -1

  if hungerLevel then
    dmapi.player.status.hungry = hungerLevel

    dmapi.core.raiseEvent("dmapi.player.hunger.update", {
      intensity = hungerLevel,
      line = line,
      timestamp = getEpoch()
    })
    return
  end
  
  -- Parse mob condition (combat state)
  local mobState = dmapi.parsers.mobCondition(line)
  if mobState then
    -- Start combat if not already active
    if not dmapi.player.combat.active then
      dmapi.player.combat.round = 0
      dmapi.player.combat.active = true
      dmapi.player.combat.target = mobState.target
      
      dmapi.core.raiseEvent("dmapi.player.combat.start", {
        target = mobState.target,
        line = line
      })
    end
    
    dmapi.player.combat.target = mobState.target
    dmapi.player.combat.targetHpPct = mobState.hpPct
    dmapi.player.combat.lastActivity = getEpoch()
    dmapi.core.state.combatMissedPrompts = 0
    
    dmapi.core.raiseEvent("dmapi.player.combat.mobstate", mobState)
    maybeFireCombatRound(mobState)
    return
  end
  
  -- Parse player death
  if dmapi.parsers.playerDeath(line) then
    dmapi.player.combat.deaths = dmapi.player.combat.deaths + 1
    dmapi.core.raiseEvent("dmapi.player.death", {
      deaths = dmapi.player.combat.deaths,
      line = line
    })
    return
  end
  
  -- Parse mob kill
  local killedMob = dmapi.parsers.mobKill(line)
  if killedMob then
    dmapi.player.combat.kills = dmapi.player.combat.kills + 1
    dmapi.core.raiseEvent("dmapi.player.combat.kill", {
      mob = killedMob,
      kills = dmapi.player.combat.kills,
      line = line
    })
    return
  end
  
  -- dmapi.world.exit
  if line:match(DMPatterns.WORLD_EXIT) then
    dmapi.core.raiseEvent("dmapi.world.exit")
    dmapi.player.online = false
    return
  end

  -- Parse Attributes from Score
  local attrs = dmapi.parsers.attributes(line)
  if attrs then
    dmapi.player.stats.attributes = attrs

    dmapi.core.raiseEvent("dmapi.player.stats.attributes.updated", attrs)
    return
  end
  
  -- Parse weather
  local weather, weatherDetail

  if line:match(DMPatterns.WEATHER_SUNRISE)
    or line:match(DMPatterns.WEATHER_DAY) then
    weather = "day"
    weatherDetail = "sunrise"
  elseif line:match(DMPatterns.WEATHER_SUNSET)
    or line:match(DMPatterns.WEATHER_NIGHT) then
    weather = "night"
    weatherDetail = "sunset"
  elseif line:match(DMPatterns.WEATHER_SLEET_END) then
    weather = "clear"
    weatherDetail = "sleet_end"
  elseif line:match(DMPatterns.WEATHER_RAIN_END)
    or line:match(DMPatterns.WEATHER_RAIN_END2) then
    weather = "clear"
    weatherDetail = "rain_end"
  elseif line:match(DMPatterns.WEATHER_STORM) then
    weather = "storm"
    weatherDetail = "storm_rain"
  elseif line:match(DMPatterns.WEATHER_FREEZE_HVY) then
    weather = "storm"
    weatherDetail = "freezing_rain_heavy"
  elseif line:match(DMPatterns.WEATHER_FREEZE) then
    weather = "rain"
    weatherDetail = "freezing_rain"
  elseif line:match(DMPatterns.WEATHER_THUNDER) then
    weather = "storm"
    weatherDetail = "thunder"
  elseif line:match(DMPatterns.WEATHER_THUNDER_END)
    or line:match(DMPatterns.WEATHER_STORM_END) then
    weather = "storm_end"
    weatherDetail = "storm_end"
  elseif line:match(DMPatterns.WEATHER_CLOUDY_RAIN)
    or line:match(DMPatterns.WEATHER_BEGINS_RAIN) then
    weather = "rain"
    weatherDetail = "rain"
  elseif line:match(DMPatterns.WEATHER_VERY_CLOUDY) then
    weather = "cloudy"
    weatherDetail = "cloudy"
  elseif line:match(DMPatterns.WEATHER_CALM) then
    weather = "calm"
    weatherDetail = "calm"
  end
  
  if weather then
    dmapi.world.time.weather = weather
    dmapi.world.time.weatherDetail = weatherDetail or weather
    
    if weather == "day" then
      dmapi.world.time.isDay = true
    elseif weather == "night" then
      dmapi.world.time.isDay = false
    end
    
    dmapi.core.raiseEvent("dmapi.world.weather.update", {
      weather = weather,
      detail = dmapi.world.time.weatherDetail,
      isDay = dmapi.world.time.isDay,
      line = line,
      timestamp = getEpoch()
    })
    return
  end
end

-- ============================================================================
-- PLAYER STATE FUNCTIONS
-- ============================================================================

--- Set sleeping status
-- @param sleeping boolean Sleep state
function dmapi.player.setSleeping(sleeping)
  dmapi.player.status.sleeping = sleeping
  if dmapi.settings.debugLevel > 0 then
    dmapi.core.debug(string.format("Sleep status: %s", tostring(sleeping)))
  end
end

--- Reset all player state
function dmapi.player.reset()
  dmapi.player.level = 0
  dmapi.player.age = {
    years = 0,
    hours = 0
  }
  dmapi.player.currency = {
    gold = 0,
    silver = 0
  }
  dmapi.player.bank = {
    gold = 0,
    silver = 0,
    house = 0
  }
  dmapi.player.experience = {
    total = 0,
    tnl = 0,
    lastGain = 0,
    totalGained = 0
  }
  dmapi.player.vitals.hp = 0;
  dmapi.player.vitals.mn = 0;
  dmapi.player.vitals.mv = 0;
  dmapi.player.vitals.rg = 0;  -- Rage percentage (if applicable)
  dmapi.player.vitals.hpMax = 1;
  dmapi.player.vitals.mnMax = 1;
  dmapi.player.vitals.mvMax = 1;
  dmapi.player.vitals.hpRegen = 0;
  dmapi.player.vitals.mnRegen = 0;
  dmapi.player.vitals.mvRegen = 0;
  dmapi.player.vitals.practices = 0;
  dmapi.player.status = {
    sleeping = false,
    resting = false,
    hungry = 0,    -- -1=full, 0=not hungry, 1-4=increasing hunger
    thirsty = 0,   -- 0=not thirsty, 1-4=increasing thirst
    stunned = false,
    position = "standing"  -- standing, resting, sleeping, fighting
  }
  dmapi.player.combat = {
    active = false,
    round = 0,
    target = nil,
    targetHpPct = 0,
    lastActivity = getEpoch(),
    kills = 0,
    deaths = 0,
    damageDealt = 0,
    damageTaken = 0
  }
  if dmapi.settings.debugLevel > 0 then
    dmapi.core.debug("Player state reset")
  end
end

--- Get current player status summary
-- @return table Status summary
function dmapi.player.getStatus()
  return {
    level = dmapi.player.level,
    hp = string.format("%d/%d (%d%%)", 
      dmapi.player.vitals.hp, 
      dmapi.player.vitals.hpMax, 
      dmapi.player.vitals.hpPct
    ),
    mn = string.format("%d/%d (%d%%)", 
      dmapi.player.vitals.mn, 
      dmapi.player.vitals.mnMax, 
      dmapi.player.vitals.mnPct
    ),
    mv = string.format("%d/%d (%d%%)", 
      dmapi.player.vitals.mv, 
      dmapi.player.vitals.mvMax, 
      dmapi.player.vitals.mvPct
    ),
    xp = string.format("%d (%d tnl)", 
      dmapi.player.experience.total, 
      dmapi.player.experience.tnl
    ),
    currency = string.format("%dg %ds", 
      dmapi.player.currency.gold, 
      dmapi.player.currency.silver
    ),
    combat = dmapi.player.combat.active,
    kills = dmapi.player.combat.kills,
    deaths = dmapi.player.combat.deaths
  }
end

-- ============================================================================
-- COMMAND ALIASES
-- ============================================================================

--- Main dmapi command handler
function dmapi.RegisterAliases()
  -- Main dmapi command handler
  DarkmistsAlias.add([[^dmapi(?:\s+(\w+))?(?:\s+(.*))?$]], function()
    local cmd = matches[2]
    local args = matches[3]

    if not cmd then
      dmapi.core.log("Commands: debug, status, reset, setvitals, guessvitals")
      return
    end

    if cmd == "debug" then
      dmapi.settings.debugLevel = (dmapi.settings.debugLevel + 1) % 3
      dmapi.core.debug(string.format("Debug level: %d", dmapi.settings.debugLevel))
      return
    end

    if cmd == "status" then
      local status = dmapi.player.getStatus()
      dmapi.core.log(string.format("Level %d | %s | %s | %s | %s | %s",
        status.level,
        status.hp,
        status.mn,
        status.mv,
        status.xp,
        status.currency
      ))
      dmapi.core.log(string.format("Combat: %s | Kills: %d | Deaths: %d",
        tostring(status.combat),
        status.kills,
        status.deaths
      ))
      return
    end

    if cmd == "reset" then
      dmapi.player.reset()
      return
    end

    dmapi.core.log("Unknown command. Use 'dmapi' for help.")
  end)

  --- Set vitals command
  DarkmistsAlias.add([[^dmapi setvitals\s+(\d+)\s+(\d+)\s+(\d+)$]], function()
    local hpMax = tonumber(matches[2])
    local mnMax = tonumber(matches[3])
    local mvMax = tonumber(matches[4])

    dmapi.player.vitals.hpMax = hpMax
    dmapi.player.vitals.mnMax = mnMax
    dmapi.player.vitals.mvMax = mvMax

    if dmapi.settings.debugLevel > 0 then
      dmapi.core.debug(string.format(
        "Vitals set - HP: %d | MN: %d | MV: %d",
        hpMax, mnMax, mvMax
      ))
    end
  end)

  --- Guess vitals from level
  DarkmistsAlias.add([[^dmapi guessvitals\s+(\d+)$]], function()
    local level = tonumber(matches[2])

    -- Estimate: ~15 HP/MN/MV per level (adjust based on class/race)
    dmapi.player.vitals.hpMax = 15 * level
    dmapi.player.vitals.mnMax = 15 * level
    dmapi.player.vitals.mvMax = 15 * level
    dmapi.player.vitals.estimated = true 

    dmapi.core.log(string.format(
      "Vitals estimated for level %d - HP: %d | MN: %d | MV: %d",
      level,
      dmapi.player.vitals.hpMax,
      dmapi.player.vitals.mnMax,
      dmapi.player.vitals.mvMax
    ))
  end)
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function dmapi.RegisterEvents()

  --- Handle sleep state changes
  DarkmistsEvents.add(
    "dmapi.player.sleep.blocked.handler",
    "dmapi.player.sleep.blocked",
    function()
      dmapi.player.setSleeping(true)
    end,
    false
  )

  DarkmistsEvents.add(
    "dmapi.player.sleep.enter.handler",
    "dmapi.player.sleep.enter",
    function()
      dmapi.player.setSleeping(true)
    end,
    false
  )

  DarkmistsEvents.add(
    "dmapi.player.sleep.exit.handler",
    "dmapi.player.sleep.exit",
    function()
      dmapi.player.setSleeping(false)
    end,
    false
  )

  --- Track last command sent
  DarkmistsEvents.add(
    "dmapi.command.tracker",
    "sysDataSendRequest",
    function(_, command)
      if not command or command == "" then return end
      dmapi.core.state.lastCommand = command
    end,
    false
  )

  --- Reset vitals on world enter
  DarkmistsEvents.add(
    "dmapi.world.enter.reset",
    "dmapi.world.enter",
    function()
      dmapi.player.reset()
      dmapi.player.vitals.hpMax = 1
      dmapi.player.vitals.mnMax = 1
      dmapi.player.vitals.mvMax = 1
      dmapi.player.online = true
      if dmapi.settings.debugLevel > 0 then
        dmapi.core.debug("Connected - vitals reset. Use 'score' or 'dmapi setvitals'")
      end
      send("")
      send("")
      send("score")
    end,
    false
  )

  --- End combat after 2 consecutive prompts without combat activity
  DarkmistsEvents.add(
    "dmapi.combat.end.tracker",
    "dmapi.player.vitals.updated",
    function()
      if dmapi.player.combat.active then
        dmapi.core.state.combatMissedPrompts = dmapi.core.state.combatMissedPrompts + 1
        
        if dmapi.core.state.combatMissedPrompts >= 2 then
          dmapi.player.combat.active = false
          local target = dmapi.player.combat.target
          dmapi.player.combat.round = 0
          dmapi.player.combat.target = nil
          dmapi.player.combat.targetHpPct = 0
          dmapi.core.state.combatMissedPrompts = 0
          
          dmapi.core.raiseEvent("dmapi.player.combat.end", {
            target = target,
            round = dmapi.player.combat.round
          })
        end
      end
    end,
    false
  )

  --- Auto-guess vitals on first level update
  DarkmistsEvents.add(
    "dmapi.vitals.autoguess",
    "dmapi.player.level.updated",
    function(_, data)
      if dmapi.player.vitals.hpMax == 1 then
        expandAlias(string.format("dmapi guessvitals %d", data.level))
      end
    end,
    false
  )

  DarkmistsEvents.add(
    "dmapi.player.online false",
    "sysDisconnectionEvent",
    function()
      if not dmapi then return end
      if not dmapi.player then return end
      dmapi.player.online = false
    end,
    false
  )
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function dmapi.init()
  dmapi.core.log(string.format(
    "Loading %s v%s by %s",
    dmapi.meta.name,
    dmapi.meta.version,
    dmapi.meta.author
  ))

  dmapi.RegisterAliases()
  dmapi.RegisterEvents()
  dmapi.core.state.initialized = true
  dmapi.core.raiseEvent("dmapi.core.loaded")

  dmapi.core.log("Loaded successfully. Type 'dmapi' for commands.")
end