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
    combatRoundInterval = 3.5,
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
    
    -- Combat condition descriptions in order of severity
    COMBAT_CONDITIONS = {
      "is in perfect condition",
      "has a few nicks",
      "has a few scratches",
      "looks a little beat up",
      "has a few bruises",
      "has quite a few bruises",
      "is heavily bruised",
      "has some small wounds",
      "has some nasty cuts",
      "has quite a few wounds",
      "is covered in bleeding wounds",
      "is bleeding profusely",
      "is spurting blood",
      "is gushing blood",
      "is screaming in pain",
      "looks like a bloody mess",
      "is stumbling in pain",
      "is in pretty bad shape",
      "is writhing in agony",
      "is spasming in shock",
      "is catatonic from the intense pain",
      "is stumbling from grave injuries",
      "is convulsing on the ground",
      "nearly dead"
    }
  },
  
  -- One-line event mappings
  oneLineEvents = {
    ["You wake and stand up."] = "dmapi.player.sleep.exit",
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
    deaths = 0
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
    weather = "clear"
  }
}

-- ============================================================================
-- PARSING FUNCTIONS
-- ============================================================================

local parsers = {}

--- Parse exits line: [Exits: north south east]
-- @param line string The line to parse
-- @return table|nil Array of exit directions
function parsers.exits(line)
  local exitsBlob = line:match("^%[Exits:%s*(.-)%s*%]$")
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
function parsers.currency(line)
  local gold, silver, xp, xpToLevel
  
  -- Try: You have X gold, Y silver, and Z experience (W exp to level)
  gold, silver, xp, xpToLevel = line:match(
    "^You have (%d+) gold, (%d+) silver, and (%d+) experience %((%d+) exp to level%)"
  )
  
  if not gold then
    -- Try: You have X gold, Y silver, and Z experience.
    gold, silver, xp = line:match(
      "^You have (%d+) gold, (%d+) silver, and (%d+) experience%."
    )
    xpToLevel = -1
  end
  
  if not gold then
    -- Try: You have scored X exp, and have Y gold and Z silver coins.
    xp, gold, silver = line:match(
      "^You have scored (%d+) exp, and have (%d+) gold and (%d+) silver coins%."
    )
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
function parsers.levelUp(line)
  local hp, hpMax, mn, mnMax, mv, mvMax, prac, pracTotal = line:match(
    "^You gain (%d+)/(%d+) hp, (%d+)/(%d+) mana, (%d+)/(%d+) move, and (%d+)/(%d+) practices%."
  )
  
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
function parsers.prompt(line)
  local hp, mn, mv, rg, tnl

  -- =========================================================================
  -- NEW NUMERIC PROMPT WITH REGEN SUPPORT
  -- Examples:
  -- <500hp(+25) 300mn(+10) 200mv(+5)>
  -- <500hp 300mn(+10) 200mv>
  -- <500hp(+25) 300mn(+10) 55%rg 200mv(+5)>
  -- <500hp 300mn 55%rg 200mv 20420tnl>
  -- =========================================================================

  if line:match("^<%d+hp") then
    local promptBody = line:match("^<(.-)>")
    if not promptBody then return nil end

    local data = {
      line = line,
      tnl = -1
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
    local rageVal = promptBody:match("(%d+)%%rg")
    if rageVal then
      data.rg = tonumber(rageVal)
    end

    -- TNL
    local tnlVal = promptBody:match("(%d+)tnl")
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
    line:match("^<(%d+)hp%s+(%d+)mn%s+(%d+)%%rg%s+(%d+)mv%s+(%d+)tnl>")
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
    line:match("^<(%d+)hp%s+(%d+)mn%s+(%d+)mv%s+(%d+)tnl>")
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
    line:match("^<(%d+)hp%s+(%d+)mn%s+(%d+)mv>")
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

  if line:match("^<%d+%%hp") then
    local promptBody = line:match("^<(.-)>")
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
        dmapi.core.warn("Max HP = 1. Use 'dmapi setvitals <hp> <mn> <mv>' to set correct values")
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
    local rgPct = promptBody:match("(%d+)%%rg")
    if rgPct then
      data.rg = tonumber(rgPct)
    end

    -- TNL
    local tnlVal = promptBody:match("(%d+)tnl")
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
function parsers.vitalsFromScore(line)
  local hp, hpMax, mn, mnMax, mv, mvMax, rg
  
  -- Try with rage: You have 100/100 hit, 50/50 mana, 100/100 movement, 50% rage.
  hp, hpMax, mn, mnMax, mv, mvMax, rg = line:match(
    "^You have (%d+)%/(%d+) hit, (%d+)%/(%d+) mana, (%d+)%/(%d+) movement, (%d+)%% rage%.$"
  )

  if not hp then
    -- Try without rage
    hp, hpMax, mn, mnMax, mv, mvMax = line:match(
      "^You have (%d+)%/(%d+) hit, (%d+)%/(%d+) mana, (%d+)%/(%d+) movement%.$"
    )
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
function parsers.levelFromScore(line)
  local level, years, hours = line:match(
    "^Level (%d+), (%d+) years old %((%d+) hours%)%. You are .+%.$"
  )

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
function parsers.mobCondition(line)
  for _, phrase in ipairs(dmapi.core.state.COMBAT_CONDITIONS) do
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

--- Parse experience gain
-- @param line string The line to parse
-- @return number|nil Experience gained
function parsers.experienceGain(line)
  local gain = line:match("You have earned (%d+) experience points!")
  if gain then return tonumber(gain) end
  
  gain = line:match("You receive (%d+) experience points%.")
  if gain then return tonumber(gain) end
  
  return nil
end

--- Parse skill improvement
-- @param line string The line to parse
-- @return string|nil Skill name
function parsers.skillImproved(line)
  local skill = line:match("become better at ([%a%s'-]+)!$")
  if skill then return skill end
  
  skill = line:match("^You learn from your mistakes%, and your ([%a%s'-]+) (.*) improves%.$")
  if skill then return skill end
  
  return nil
end

--- Parse death detection
-- @param line string The line to parse
-- @return boolean True if player death detected
function parsers.playerDeath(line)
  return line:match("^You have been KILLED!!$") ~= nil
    or line:match("^You are DEAD!!$") ~= nil
end

--- Parse kill detection
-- @param line string The line to parse
-- @return string|nil Mob name if kill detected
function parsers.mobKill(line)
  local mob = line:match("^(.+) is DEAD!!$")
  return mob
end

-- Parse Bank Balances
function parsers.bankBalance(line)
  local gold, silver =
    line:match("^You have (%d+) gold coins and (%d+) silver in your account%.$")

  if gold then
    return {
      gold = tonumber(gold),
      silver = tonumber(silver),
      line = line
    }
  end

  if line:match("You have no account here!") then
    return {
      gold = 0,
      silver = 0,
      line = line
    }
  end

  return nil
end

-- Parse House Balance
function parsers.houseBalance(line)
  local gold =
    line:match("^Your house's account has (%d+) gold in it%.$")

  if not gold then
    gold = line:match("^Your house's balance is (%d+) gold%.$")
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
function parsers.bankDeposit(line)
  local amount, currency =
    line:match("^You deposit (%d+) (%a+)%.")

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
function parsers.bankWithdraw(line)
  local amount, currency, fee, feeCurrency =
    line:match("^You withdraw (%d+) (%a+) and were charged an additional fee of (%d+) (%a+)%.")

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

function parsers.bankWithdrawFail(line)
  if line:match("^Sorry, but you do not have that much (.*) in your account", 1, true)
     or line:match("^Sorry, but you need (.*) in your account", 1, true)
  then
    return { line = line }
  end

  return nil
end


-- ============================================================================
-- CORE UTILITY FUNCTIONS
-- ============================================================================

--- Log a message with dmapi formatting
-- @param message string The message to log
-- @param level string Optional log level (info, warn, error)
function dmapi.core.log(message, level)
  level = level or "info"
  local color = "<dim_gray>"
  
  if level == "warn" then
    color = "<yellow>"
  elseif level == "error" then
    color = "<red>"
  end
  
  cecho(string.format(
    "\n<gray>[%s%s<gray>] %s%s",
    dmapi.settings.themeColor,
    dmapi.meta.name,
    color,
    message
  ))
end

--- Log a warning message
-- @param message string The warning message
function dmapi.core.warn(message)
  dmapi.core.log(message, "warn")
end

--- Log an error message
-- @param message string The error message
function dmapi.core.error(message)
  dmapi.core.log(message, "error")
end

--- Send a command to the MUD
-- @param cmd string The base command
-- @param ... Additional arguments to append
function dmapi.core.send(cmd, ...)
  if not cmd or cmd == "" then return end
  
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
      dmapi.core.log(string.format("%s : %s", eventName, yajl.to_string(data[1])))
    else
      dmapi.core.log(eventName)
    end
  elseif dmapi.settings.debugLevel > 0 then
    dmapi.core.log(eventName)
  end
  
  raiseEvent(eventName, ...)
end

--- Get the last command sent
-- @return string|nil The last command
function dmapi.core.getLastCommand()
  return dmapi.core.state.lastCommand
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
-- LINE TRIGGER - MAIN PARSING LOGIC
-- ============================================================================

--- Main line trigger function - parses all MUD output
-- @param line string The line to parse
function dmapi.core.LineTrigger(line)
  -- Raise generic line event (opt-in for performance)
  -- raiseEvent("dmapi.core.line", {line = line})
  
  -- Check one-line event mappings
  local oneLineEvent = dmapi.core.oneLineEvents[line]
  if oneLineEvent then
    dmapi.core.raiseEvent(oneLineEvent, {line = line})
    return
  end
  
  local sender, message, receiver, channel
  -- Parse tells: Someone tells you, 'message'
  sender, message = line:match("^(.*) tells you, '(.*)'$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.tellreceived", {
      sender = sender,
      receiver = "Me",
      message = message,
      line = line
    })
    return
  end
  -- Parse tells: You tell someone, 'message'
  receiver, message = line:match("^You tell (.*), '(.*)'$")
  if receiver then
    dmapi.core.raiseEvent("dmapi.communication.tellsent", {
      sender = "Me",
      receiver = receiver,
      message = message,
      line = line
    })
    return
  end

  -- Say From Someone Else
  sender, message = line:match("^(.*) says, '(.*)'$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.sayreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return
  end
  -- Say From Player
  message = line:match("^You say, '(.*)'$")
  if message then
    dmapi.core.raiseEvent("dmapi.communication.saysent", {
      sender = "Player",
      message = message,
      line = line
    })
    return
  end

  -- Mental Projection From Someone Else
  sender, message = line:match("^(.*) mentally projects, '(.*)'$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.mpsayreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return
  end
  
  -- Mental Projection From Player
  message = line:match("^You mentally project, '(.*)'$")
  if message then
    dmapi.core.raiseEvent("dmapi.communication.mpsaysent", {
      sender = "Player",
      message = message,
      line = line
    })
    return
  end

  local sender, message, receiver, channel
  -- Parse tells: Someone tells you, 'message'
  sender, message = line:match("^(.*) mentally projects to you, '(.*)'$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.mptellreceived", {
      sender = sender,
      receiver = "Me",
      message = message,
      line = line
    })
    return
  end
  -- Parse tells: You tell someone, 'message'
  receiver, message = line:match("^You mentally project to (.*), '(.*)'$")
  if receiver then
    dmapi.core.raiseEvent("dmapi.communication.mptellsent", {
      sender = "Me",
      receiver = receiver,
      message = message,
      line = line
    })
    return
  end

  -- GTell From Someone Else
  sender, message = line:match("^(.*) tells the group '(.*)'$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.gtellreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return
  end
  -- GTell From Player
  message = line:match("^You tell the group '(.*)'$")
  if message then
    dmapi.core.raiseEvent("dmapi.communication.gtellsent", {
      sender = "Player",
      message = message,
      line = line
    })
    return
  end

  -- Yell From Someone Else
  sender, message = line:match("^(.*) yells, '(.*)'$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.yellreceived", {
      sender = sender,
      message = message,
      line = line
    })
    return
  end
  -- Yell From Player
  message = line:match("^You yell, '(.*)'$")
  if message then
    dmapi.core.raiseEvent("dmapi.communication.yellsent", {
      sender = "Player",
      message = message,
      line = line
    })
    return
  end

  -- Newbie Channel Messages
  sender, message = line:match("^%[NEWBIE%] (.*)%: (.*)$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.newbiechannel", {
      sender = sender,
      message = message,
      line = line
    })
    return
  end
  sender, message = line:match("^%[NEWBIE via Discord%] (.*)%: (.*)$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.newbiechanneldiscord", {
      sender = sender,
      message = message,
      line = line
    })
    return
  end


  -- OOC Messages From Someone Else
  sender, message = line:match("^%[OOC%] (.*)%: (.*)$")
  if sender then
    dmapi.core.raiseEvent("dmapi.communication.oocreceived", {
      sender = sender,
      receiver = "Me",
      message = message,
      line = line
    })
    return
  end
  -- OOC Messages Sent by Player
  receiver, message = line:match("^%[OOC%] to (.*)%: (.*)$")
  if receiver then
    dmapi.core.raiseEvent("dmapi.communication.oocsent", {
      sender = "Me",
      receiver = receiver,
      message = message,
      line = line
    })
    return
  end
  
  -- House Channel Messages
  channel, sender, message = line:match("^%[(.*)%] (.*)%: (.*)$")
  if sender then
    if channel == "CONCLAVE"
    or channel == "CRUSADER"
    or channel == "LIGHT"
    or channel == "BRETHREN"
    or channel == "OUTLAW"
    or channel == "JUSTICAR"
    or channel == "DEPRAVED"
    or channel == "ANCIENT" then
      dmapi.core.raiseEvent("dmapi.communication.housechannel", {
        sender = sender,
        receiver = channel,
        message = message,
        line = line
      })
    end
  end

  -- Parse closed door: The door is closed.
  local closedName = line:match("^The (.+) is closed%.$")
  if closedName then
    dmapi.core.raiseEvent("dmapi.player.navigation.closed", {
      name = closedName,
      line = line
    })
    return
  end
  
  -- Parse locked door
  if line:match("^It is locked%.$") then
    dmapi.core.raiseEvent("dmapi.player.navigation.locked", {line = line})
    return
  end
  
  -- Parse skill improvement
  local skill = parsers.skillImproved(line)
  if skill then
    dmapi.core.raiseEvent("dmapi.player.skill.improved", {
      skill = skill,
      line = line
    })
    return
  end
  
  -- Parse experience gain
  local xpGain = parsers.experienceGain(line)
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
  silver, gold, source = line:match("^You get (%d+) silver coins? and (%d+) gold coins? from the corpse of (.*)%.")
  if not source then
    silver, source = line:match("^You get (%d+) silver coins? from the corpse of (.*)%.")
  end
  if not source then
    gold, source = line:match("^You get (%d+) gold coins? from the corpse of (.*)%.")
  end
  if not source then
    source, silver, gold = line:match("^You sell (.*) for (%d+) silver and (%d+) gold pieces%.")
  end
  if not source then
    silver = line:match("^The gods give you (.*) silver coins? for your sacrifice%.")
    if silver == "one" then
      silver = 1
    end
    if silver then
      source = "sacrifice"
    end
  end
  if not source then
    source, silver = line:match("^You buy (.*) for (%d+) silver%.")
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
  local bankBal = parsers.bankBalance(line)
  if bankBal then
    dmapi.player.bank.gold = bankBal.gold
    dmapi.player.bank.silver = bankBal.silver

    dmapi.core.raiseEvent("dmapi.player.bank.balance", bankBal)
    return
  end

  -- House Balance Updates
  local houseBal = parsers.houseBalance(line)
  if houseBal then
    dmapi.player.bank.house = houseBal.gold

    dmapi.core.raiseEvent("dmapi.player.house.balance", houseBal)
    return
  end

  -- Bank Deposits
  local deposit = parsers.bankDeposit(line)
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
  local withdraw = parsers.bankWithdraw(line)
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
  local withdrawFail = parsers.bankWithdrawFail(line)
  if withdrawFail then
    dmapi.core.raiseEvent("dmapi.player.bank.withdraw.fail", withdrawFail)
    return
  end

  -- Parse equipment zapped
  local zappedItem = line:match("You are zapped by (.*) and drop it%.")
  if zappedItem then
    dmapi.core.raiseEvent("dmapi.player.equipment.zapped", {
      item = zappedItem,
      line = line
    })
    return
  end
  
  -- Parse disarm
  local disarmer = line:match("(.*) DISARMS you and sends your weapon flying!")
  if disarmer then
    dmapi.core.raiseEvent("dmapi.player.combat.disarmed", {
      disarmer = disarmer,
      line = line
    })
    return
  end
  
  -- Parse sleep
  local sleepOn = line:match("You go to sleep on (.*)%.")
  if line:match("You go to sleep%.") or sleepOn then
    dmapi.core.raiseEvent("dmapi.player.sleep.enter", {
      sleepOn = sleepOn,
      line = line
    })
    return
  end
  
  -- Parse rest
  if line:match("^You sit down") 
      or line:match("^You rest") then
    dmapi.player.status.resting = true
    dmapi.core.raiseEvent("dmapi.player.rest.enter", {line = line})
    return
  end
  
  if line:match("^You stop resting")
    or line:match("^You stand up") then
    dmapi.player.status.resting = false
    dmapi.core.raiseEvent("dmapi.player.rest.exit", {line = line})
    return
  end
  
  -- Parse exits
  local exits = parsers.exits(line)
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
  local currencyData = parsers.currency(line)
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
  local vitalsFromScore = parsers.vitalsFromScore(line)
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
  local levelInfo = parsers.levelFromScore(line)
  if levelInfo then
    dmapi.player.level = levelInfo.level
    dmapi.player.age.years = levelInfo.years
    dmapi.player.age.hours = levelInfo.hours
    
    dmapi.core.raiseEvent("dmapi.player.level.updated", levelInfo)
    return
  end
  
  -- Parse prompt
  local vitals = parsers.prompt(line)
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
  local levelUp = parsers.levelUp(line)
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
        line:match("^You are thirsty%.")               and 1
     or line:match("^Your mouth is parched!")          and 2
     or line:match("^You are beginning to dehydrate!") and 3
     or line:match("^You are dying of thirst!")        and 4
     or line:match("^Your thirst is quenched%.")       and 0

  if thirstLevel then
    dmapi.player.status.thirsty = thirstLevel
    dmapi.core.raiseEvent("dmapi.player.thirst.update", {
      intensity = thirstLevel,
      line = line
    })
    return
  end
  
  -- Parse hunger
  local hungerLevel =
        line:match("^You are hungry%.")              and 1
     or line:match("^You are famished!")             and 2
     or line:match("^You are starving!")             and 3
     or line:match("^Your starvation")               and 4
     or line:match("^You are no longer hungry%.")    and 0
     or line:match("^You are full%.")                and -1
     or line:match("^You are too full to eat more%.") and -1

  if hungerLevel then
    dmapi.player.status.hungry = hungerLevel
    dmapi.core.raiseEvent("dmapi.player.hunger.update", {
      intensity = hungerLevel,
      line = line
    })
    return
  end
  
  -- Parse mob condition (combat state)
  local mobState = parsers.mobCondition(line)
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
  if parsers.playerDeath(line) then
    dmapi.player.combat.deaths = dmapi.player.combat.deaths + 1
    dmapi.core.raiseEvent("dmapi.player.death", {
      deaths = dmapi.player.combat.deaths,
      line = line
    })
    return
  end
  
  -- Parse mob kill
  local killedMob = parsers.mobKill(line)
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
  if line:match("Alas, all good things must come to an end.") then
    dmapi.core.raiseEvent("dmapi.world.exit")
    dmapi.player.online = false
    return
  end

  -- Parse weather
  local weather =
        line:match("no longer raining")   and "clear"
     or line:match("very cloudy")         and "cloudy"
     or line:match("calmness begins")     and "calm"
     or line:match("The day has begun")   and "day"
     or line:match("storm seems to cease") and "storm_end"
     or line:match("begins to rain")      and "rain"
     or line:match("The night has begun") and "night"
  
  if weather then
    dmapi.world.time.weather = weather
    
    if weather == "day" then
      dmapi.world.time.isDay = true
    elseif weather == "night" then
      dmapi.world.time.isDay = false
    end
    
    dmapi.core.raiseEvent("dmapi.world.weather.update", {
      weather = weather,
      isDay = dmapi.world.time.isDay,
      line = line
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
  dmapi.core.log(string.format("Sleep status: %s", tostring(sleeping)))
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
    deaths = 0
  }
  dmapi.core.log("Player state reset")
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
tempAlias([[^dmapi(?:\s+(\w+))?(?:\s+(.*))?$]], function()
  local cmd = matches[2]
  local args = matches[3]
  
  if not cmd then
    dmapi.core.log("Commands: debug, status, reset, setvitals, guessvitals")
    return
  end
  
  if cmd == "debug" then
    dmapi.settings.debugLevel = (dmapi.settings.debugLevel + 1) % 3
    dmapi.core.log(string.format("Debug level: %d", dmapi.settings.debugLevel))
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
tempAlias([[^dmapi setvitals\s+(\d+)\s+(\d+)\s+(\d+)$]], function()
  local hpMax = tonumber(matches[2])
  local mnMax = tonumber(matches[3])
  local mvMax = tonumber(matches[4])
  
  dmapi.player.vitals.hpMax = hpMax
  dmapi.player.vitals.mnMax = mnMax
  dmapi.player.vitals.mvMax = mvMax
  
  dmapi.core.log(string.format(
    "Vitals set - HP: %d | MN: %d | MV: %d",
    hpMax, mnMax, mvMax
  ))
end)

--- Guess vitals from level
tempAlias([[^dmapi guessvitals\s+(\d+)$]], function()
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

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Handle sleep state changes
registerNamedEventHandler(
  "dmapi",
  "dmapi.player.sleep.enter.handler",
  "dmapi.player.sleep.enter",
  function()
    dmapi.player.setSleeping(true)
  end
)

registerNamedEventHandler(
  "dmapi",
  "dmapi.player.sleep.exit.handler",
  "dmapi.player.sleep.exit",
  function()
    dmapi.player.setSleeping(false)
  end
)

--- Track last command sent
registerNamedEventHandler(
  "dmapi",
  "dmapi.command.tracker",
  "sysDataSendRequest",
  function(_, command)
    if not command or command == "" then return end
    dmapi.core.state.lastCommand = command
    dmapi.core.raiseEvent("dmapi.core.command.sent", {command = command})
  end
)

--- Reset vitals on world enter
registerNamedEventHandler(
  "dmapi",
  "dmapi.world.enter.reset",
  "dmapi.world.enter",
  function()
    dmapi.player.reset()
    dmapi.player.vitals.hpMax = 1
    dmapi.player.vitals.mnMax = 1
    dmapi.player.vitals.mvMax = 1
    dmapi.player.online = true
    dmapi.core.log("Connected - vitals reset. Use 'score' or 'dmapi setvitals'")
    send("")
    send("")
    send("score")
  end
)

--- End combat after 2 consecutive prompts without combat activity
registerNamedEventHandler(
  "dmapi",
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
  end
)

--- Auto-guess vitals on first level update
registerNamedEventHandler(
  "dmapi",
  "dmapi.vitals.autoguess",
  "dmapi.player.level.updated",
  function(_, data)
    if dmapi.player.vitals.hpMax == 1 then
      expandAlias(string.format("dmapi guessvitals %d", data.level))
    end
  end
)

registerNamedEventHandler(
  "dmapi",
  "dmapi.vitals.checkscore",
  "dmapi.player.vitals.updated",
  function(_, data)
    if dmapi.player.vitals.hpMax == 1 then
      send("score")
    end
  end
)

registerNamedEventHandler(
  "dmapi",
  "dmapi.player.online false",
  "sysDisconnectionEvent",
  function()
    if not dmapi then return end
    if not dmapi.player then return end
    dmapi.player.online = false
  end
)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

dmapi.core.log(string.format(
  "Loading %s v%s by %s",
  dmapi.meta.name,
  dmapi.meta.version,
  dmapi.meta.author
))

dmapi.core.state.initialized = true
dmapi.core.raiseEvent("dmapi.core.loaded")

dmapi.core.log("Loaded successfully. Type 'dmapi' for commands.")