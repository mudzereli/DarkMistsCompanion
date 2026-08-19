-- ============================================================================
-- DMPatterns
-- ----------------------------------------------------------------------------
-- Single source of truth for all MUD line Lua patterns used across the
-- Dark Mists Companion framework.
--
-- Every module that needs to match MUD output should reference a pattern
-- from here rather than inlining a string literal.
--
-- DEBUGGING
--   DMPatterns.debug = true              -- enable match logging
--   DMPatterns.match("XXX", line)        -- wrapped match with optional logging
--   DMPatterns.identify(line)            -- scan all patterns against a line
--   DMPatterns.list()                    -- print all pattern names
-- ============================================================================

DMPatterns = {
  debug    = false,
}

-- Override to redirect debug output (default: echoes to main console)
DMPatterns.logger = function(name, line, captures)
  if not DMPatterns.debug then return end
  local capStr = #captures > 0 and (" → " .. table.concat(captures, ", ")) or ""
  cecho("main", "<grey>[DMPatterns] <lime_green>" .. name .. "<grey> matched: <white>" .. line .. "<lime_green>" .. capStr .. "\n")
end

--- Wrapped match: same as line:match(pattern) but logs on success when debug is on.
-- Preserves multi-return via unpack so it works in multi-assignment contexts.
-- @param name string Pattern constant name (e.g. "DOOR_CLOSED")
-- @param line string The MUD line to test
-- @return Same as line:match — matched string, captures, or nil
function DMPatterns.match(name, line)
  local pattern = rawget(DMPatterns, name)
  if type(pattern) ~= "string" then return nil end

  local results = {line:match(pattern)}
  if #results == 0 then return nil end

  if DMPatterns.debug then
    DMPatterns.logger(name, line, results)
  end
  return unpack(results)
end

--- Identify: test a line against every known pattern and report matches.
-- Useful during development to discover which patterns fire on a given MUD line.
-- @param line string The MUD line to test
function DMPatterns.identify(line)
  if not line or line == "" then return end
  local found = false
  for name, value in pairs(DMPatterns) do
    if type(value) == "string" then
      local matchResult = {line:match(value)}
      if #matchResult > 0 and matchResult[1] ~= nil then
        local capStr = table.concat(matchResult, ", ")
        cecho("main", "<grey>[DMPatterns] ✓ <lime_green>" .. name .. "<grey> → <lime_green>" .. capStr .. "\n")
        found = true
      end
    end
  end
  if not found then
    cecho("main", "<grey>[DMPatterns] ✗ No patterns matched: <red>" .. line .. "\n")
  end
end

--- List: print every registered pattern name and its string representation.
function DMPatterns.list()
  local names = {}
  for name, value in pairs(DMPatterns) do
    if type(value) == "string" then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  cecho("main", "<lime_green>DMPatterns (" .. #names .. " patterns):\n")
  for _, n in ipairs(names) do
    cecho("main", "<grey>  " .. n .. " = <white>" .. tostring(rawget(DMPatterns, n)) .. "\n")
  end
end

-- ============================================================================
-- NAVIGATION / ROOM
-- ============================================================================

DMPatterns.EXITS           = "^%[Exits:%s*(.-)%s*%]$"
DMPatterns.DOOR_CLOSED     = "^The (.+) is closed%.$"
DMPatterns.DOOR_LOCKED     = "^It is locked%.$"

-- ============================================================================
-- CURRENCY / EXPERIENCE
-- ============================================================================

DMPatterns.CURRENCY_FULL   = "^You have (%d+) gold, (%d+) silver, and (%d+) experience %((%d+) exp to level%)"
DMPatterns.CURRENCY_NOLVL  = "^You have (%d+) gold, (%d+) silver, and (%d+) experience%."
DMPatterns.CURRENCY_SCORE  = "^You have scored (%d+) exp, and have (%d+) gold and (%d+) silver coins%."

-- ============================================================================
-- LEVEL UP
-- ============================================================================

DMPatterns.LEVEL_UP        = "^You gain (%d+)/(%d+) hp, (%d+)/(%d+) mana, (%d+)/(%d+) move, and (%d+)/(%d+) practices%."

-- ============================================================================
-- PROMPT
-- ============================================================================

-- Prompt prefix detection (used to identify a prompt line)
DMPatterns.PROMPT_HP_PREFIX     = "^<%d+hp"
DMPatterns.PROMPT_PCT_PREFIX    = "^<%d+%%hp"
DMPatterns.PROMPT_BODY          = "^<(.-)>"

-- Sub-patterns used within prompt body extraction
DMPatterns.PROMPT_VAL_REGEN     = "(%d+)(%a+)%(([-+]?%d+)%)"
DMPatterns.PROMPT_VAL_NOREGEN   = "(%d+)(%a+)"
DMPatterns.PROMPT_PCT_REGEN     = "(%d+)%%(%a+)%(([-+]?%d+)%)"
DMPatterns.PROMPT_PCT_NOREGEN   = "(%d+)%%(%a+)"
DMPatterns.PROMPT_TNL           = "(%d+)tnl"
DMPatterns.PROMPT_RAGE          = "(%d+)%%rg"

-- Legacy exact format matches
DMPatterns.PROMPT_LEGACY_RAGE   = "^<(%d+)hp%s+(%d+)mn%s+(%d+)%%rg%s+(%d+)mv%s+(%d+)tnl>"
DMPatterns.PROMPT_LEGACY_TNL    = "^<(%d+)hp%s+(%d+)mn%s+(%d+)mv%s+(%d+)tnl>"
DMPatterns.PROMPT_LEGACY_SIMPLE = "^<(%d+)hp%s+(%d+)mn%s+(%d+)mv>"

-- ============================================================================
-- VITALS (from "score" command)
-- ============================================================================

DMPatterns.VITALS_RAGE    = "^You have (%d+)/(%d+) hit, (%d+)/(%d+) mana, (%d+)/(%d+) movement, (%d+)%% rage%.$"
DMPatterns.VITALS_NORAGE  = "^You have (%d+)/(%d+) hit, (%d+)/(%d+) mana, (%d+)/(%d+) movement%.$"

-- ============================================================================
-- LEVEL (from "score" command)
-- ============================================================================

DMPatterns.LEVEL_FROM_SCORE = "^Level (%d+), (%d+) years old %((%d+) hours%)%. You are .+%.$"

-- ============================================================================
-- ATTRIBUTES (from "score" command)
-- ============================================================================

DMPatterns.ATTRIBUTES = "^Str:%s*(%d+)%((%d+)%)%s+" ..
  "Int:%s*(%d+)%((%d+)%)%s+" ..
  "Wis:%s*(%d+)%((%d+)%)%s+" ..
  "Dex:%s*(%d+)%((%d+)%)%s+" ..
  "Con:%s*(%d+)%((%d+)%)"

-- ============================================================================
-- SKILLS
-- ============================================================================

DMPatterns.SKILL_IMPROVED     = "become better at ([%a%s'-]+)!$"
DMPatterns.SKILL_LEARNED      = "^You learn from your mistakes%, and your ([%a%s'-]+) (.*) improves%.$"

-- ============================================================================
-- EXPERIENCE GAIN
-- ============================================================================

DMPatterns.XP_GAIN            = "You have earned (%d+) experience points!"
DMPatterns.XP_RECEIVE         = "You receive (%d+) experience points%."

-- ============================================================================
-- INGEST (eat / drink)
-- ============================================================================

DMPatterns.DRINK              = "^You drink (.+) from (.+)%.$"
DMPatterns.EAT                = "^You eat (.+)%.$"
DMPatterns.TOO_FULL           = "^You are too full to eat more%.$"
DMPatterns.TOO_DRUNK          = "^You fail to reach your mouth%.%s+%*Hic%*$"

-- ============================================================================
-- DEATH
-- ============================================================================

DMPatterns.PLAYER_KILLED      = "^You have been KILLED!!$"
DMPatterns.PLAYER_DEAD        = "^You are DEAD!!$"
DMPatterns.MOB_DEAD           = "^(.+) is DEAD!!$"

-- ============================================================================
-- BANK
-- ============================================================================

DMPatterns.BANK_BALANCE       = "^You have (%d+) gold coins and (%d+) silver in your account%.$"
DMPatterns.BANK_NO_ACCOUNT    = "You have no account here!"
DMPatterns.HOUSE_BALANCE      = "^Your house's account has (%d+) gold in it%.$"
DMPatterns.HOUSE_BALANCE_ALT  = "^Your house's balance is (%d+) gold%.$"
DMPatterns.BANK_DEPOSIT       = "^You deposit (%d+) (%a+)%."
DMPatterns.BANK_WITHDRAW      = "^You withdraw (%d+) (%a+) and were charged an additional fee of (%d+) (%a+)%."
DMPatterns.BANK_NO_FUNDS      = "^Sorry, but you do not have that much"
DMPatterns.BANK_NEED_FUNDS    = "^Sorry, but you need"

-- ============================================================================
-- AFFLICTIONS / PERIODIC DAMAGE
-- ============================================================================

DMPatterns.AFFLICTION_SELF    = "^Your ([%a]+) [%a]+ you[!.]$"
DMPatterns.AFFLICTION_OTHER   = "^(.-)'s ([%a]+) [%a]+ (him|her|them)[!.]$"

-- ============================================================================
-- ALCHEMY
-- ============================================================================

DMPatterns.ALCHEMY_TIRED        = "^You are too tired to complete the process"
DMPatterns.ALCHEMY_NO_ITEM      = "^You do not have that to perform alchemy on"
DMPatterns.ALCHEMY_ALREADY_DONE = "^No further alchemy may be performed on that item%."
DMPatterns.ALCHEMY_BOTCH        = "^You botch the brew, and your alchemy process"
DMPatterns.ALCHEMY_NO_MATCH     = "^Your alchemy process results in a gooey mess"
DMPatterns.ALCHEMY_WEAPON_ONLY  = "^The brew reacted strangely%."
DMPatterns.ALCHEMY_DISCOVERED   = "^You have discovered the alchemy formula (.*)!"

-- ============================================================================
-- COMMUNICATION
-- ============================================================================

-- Emoted Say
DMPatterns.COMM_EMOTE_SAY_RECV     = "^(%S+) ([^ ]+) says, '(.*)'$"
DMPatterns.COMM_EMOTE_SAY_SENT     = "^You ([^ ]+) say, '(.*)'$"

-- Say
DMPatterns.COMM_SAY_RECV           = "^(.*) says, '(.*)'$"
DMPatterns.COMM_SAY_SENT           = "^You say, '(.*)'$"

-- Tell
DMPatterns.COMM_TELL_RECV          = "^(.*) tells you, '(.*)'$"
DMPatterns.COMM_TELL_SENT          = "^You tell (.*), '(.*)'$"

-- Yell
DMPatterns.COMM_YELL_RECV          = "^(.*) yells, '(.*)'$"
DMPatterns.COMM_YELL_SENT          = "^You yell, '(.*)'$"

-- Panic Yell
DMPatterns.COMM_PANIC_YELL_SENT    = "^You yell in panic, '(.*)'$"
DMPatterns.COMM_PANIC_YELL_RECV    = "^(.-) yells in panic, '(.*)'$"

-- Mental Blast
DMPatterns.COMM_MENTAL_BLAST_RECV  = "^(.-) mentally blasts '(.*)'$"
DMPatterns.COMM_MENTAL_BLAST_SENT  = "^You mentally blast, '(.*)'$"

-- Mental Blast Panic
DMPatterns.COMM_MP_PANIC_SENT      = "^You mentally blast in panic, '(.*)'$"
DMPatterns.COMM_MP_PANIC_RECV      = "^(.-) mentally blasts in panic, '(.*)'$"

-- Mental Projection
DMPatterns.COMM_MP_SAY_RECV        = "^(.*) mentally projects, '(.*)'$"
DMPatterns.COMM_MP_SAY_SENT        = "^You mentally project, '(.*)'$"

-- Mental Projection Tell
DMPatterns.COMM_MP_TELL_RECV       = "^(.*) mentally projects to you, '(.*)'$"
DMPatterns.COMM_MP_TELL_SENT       = "^You mentally project to (.*), '(.*)'$"

-- Mental Projection Group
DMPatterns.COMM_MP_GROUP_RECV      = "^(.*) mentally projects to the group '(.*)'$"
DMPatterns.COMM_MP_GROUP_SENT      = "^You mentally project to the group '(.*)'$"

-- Group Tell
DMPatterns.COMM_GROUP_TELL_RECV    = "^(.*) tells the group '(.*)'$"
DMPatterns.COMM_GROUP_TELL_SENT    = "^You tell the group '(.*)'$"

-- Channels
DMPatterns.COMM_NEWBIE             = "^%[NEWBIE%] (.*)%: (.*)$"
DMPatterns.COMM_NEWBIE_DISCORD     = "^%[NEWBIE via Discord%] (.*)%: (.*)$"
DMPatterns.COMM_OOC_SENT           = "^%[OOC%] to (.*)%: (.*)$"
DMPatterns.COMM_OOC_RECV           = "^%[OOC%] (.*)%: (.*)$"
DMPatterns.COMM_HOUSE_CHANNEL      = "^%[(.*)%] (.*)%: (.*)$"

-- ============================================================================
-- ONE-LINE EXACT MATCHES
-- ----------------------------------------------------------------------------
-- These convert exact MUD lines to events without Lua pattern matching.
-- They live in dmapi.core.oneLineEvents, but the list of known exact lines
-- is maintained here for discoverability.
-- ============================================================================

DMPatterns.EXACT_WAKE           = "You wake and stand up."
DMPatterns.EXACT_DREAMS         = "In your dreams, or what?"
DMPatterns.EXACT_NO_ITEM        = "You do not have that item."
DMPatterns.EXACT_CANT_FIND      = "You cannot find it."
DMPatterns.EXACT_CANT_GO        = "Alas, you cannot go that way."
DMPatterns.EXACT_EXHAUSTED      = "You are too exhausted."
DMPatterns.EXACT_NOT_ALLOWED    = "You are not allowed in there."
DMPatterns.EXACT_TOO_RELAXED    = "Nah... You feel too relaxed..."
DMPatterns.EXACT_STAND_FIRST    = "Better stand up first."
DMPatterns.EXACT_PITCH_BLACK    = "It is pitch black ... "
DMPatterns.EXACT_CANT_SEE       = "You cannot see a thing!"
DMPatterns.EXACT_ALREADY_EMPTY  = "It is already empty."
DMPatterns.EXACT_HIT_RETURN     = "[Hit Return to continue]"
DMPatterns.EXACT_WELCOME        = "Welcome to Dark Mists.  Please do not feed the mobiles."
DMPatterns.EXACT_CONNECT        = "Welcome to the Dark Mists, a medieval fantasy role-playing and PK MUD!"
DMPatterns.EXACT_RECONNECT      = "Reconnecting."
DMPatterns.EXACT_LOGIN_PROMPT   = "By what name do you wish to be known?"
DMPatterns.EXACT_FLEE           = "You choose a direction at random and begin to run..."
DMPatterns.EXACT_STUN_OFF       = "Your stun wears off."
DMPatterns.EXACT_SENSES         = "You regain your senses."

-- ============================================================================
-- LOOT / ECONOMY
-- ============================================================================

DMPatterns.LOOT_CORPSE_BOTH    = "^You get (%d+) silver coins? and (%d+) gold coins? from the corpse of (.*)%."
DMPatterns.LOOT_CORPSE_SILVER  = "^You get (%d+) silver coins? from the corpse of (.*)%."
DMPatterns.LOOT_CORPSE_GOLD    = "^You get (%d+) gold coins? from the corpse of (.*)%."
DMPatterns.LOOT_SELL           = "^You sell (.*) for (%d+) silver and (%d+) gold pieces%."
DMPatterns.LOOT_SACRIFICE      = "^The gods give you (.*) silver coins? for your sacrifice%."
DMPatterns.LOOT_BUY            = "^You buy (.*) for (%d+) silver%."

-- ============================================================================
-- EQUIPMENT / COMBAT EVENTS
-- ============================================================================

DMPatterns.EQUIP_ZAPPED        = "You are zapped by (.*) and drop it%."
DMPatterns.COMBAT_DISARM       = "(.*) DISARMS you and sends your weapon flying!"

-- ============================================================================
-- SLEEP / REST / STAND
-- ============================================================================

DMPatterns.SLEEP_ON            = "You go to sleep on (.*)%."
DMPatterns.SLEEP               = "You go to sleep%."
DMPatterns.REST_SIT            = "^You sit down"
DMPatterns.REST_ENTER          = "^You rest"
DMPatterns.REST_EXIT           = "^You stop resting"
DMPatterns.STAND_UP            = "^You stand up"

-- ============================================================================
-- THIRST
-- ============================================================================

DMPatterns.THIRST_LEVEL1       = "^You are thirsty%."
DMPatterns.THIRST_LEVEL2       = "^Your mouth is parched!"
DMPatterns.THIRST_LEVEL3       = "^You are beginning to dehydrate!"
DMPatterns.THIRST_LEVEL4       = "^You are dying of thirst!"
DMPatterns.THIRST_QUENCHED     = "^Your thirst is quenched%."

-- ============================================================================
-- HUNGER
-- ============================================================================

DMPatterns.HUNGER_LEVEL1       = "^You are hungry%."
DMPatterns.HUNGER_LEVEL2       = "^You are famished!"
DMPatterns.HUNGER_LEVEL3       = "^You are beginning to starve!"
DMPatterns.HUNGER_LEVEL4       = "^You are starving!"
DMPatterns.HUNGER_STARVATION   = "^Your starvation"
DMPatterns.HUNGER_SATED        = "^You are no longer hungry%."
DMPatterns.HUNGER_FULL         = "^You are full%."

-- ============================================================================
-- WORLD / DISCONNECT
-- ============================================================================

DMPatterns.WORLD_EXIT          = "Alas, all good things must come to an end."

-- ============================================================================
-- WEATHER / TIME
-- ============================================================================

DMPatterns.WEATHER_SUNRISE     = "^The sun rises in the east%.$"
DMPatterns.WEATHER_DAY         = "^The day has begun%.?$"
DMPatterns.WEATHER_SUNSET      = "^The sun slowly disappears in the west%.$"
DMPatterns.WEATHER_NIGHT       = "^The night has begun%.?$"
DMPatterns.WEATHER_SLEET_END   = "^You look up and notice that it is no longer raining sleet%.$"
DMPatterns.WEATHER_RAIN_END     = "^You look up and notice that it is no longer raining%.$"
DMPatterns.WEATHER_RAIN_END2   = "no longer raining"
DMPatterns.WEATHER_STORM       = "^Torrential rain begins to fall as a storm erupts%.$"
DMPatterns.WEATHER_FREEZE_HVY  = "^Pelting freezing rain begins to furiously slap against your face%.$"
DMPatterns.WEATHER_FREEZE      = "^Freezing rain begins to fall against your face%.$"
DMPatterns.WEATHER_THUNDER     = "^The crackling sound of thunder booms%.$"
DMPatterns.WEATHER_THUNDER_END = "^The thunderclap from the storm seems to cease%.$"
DMPatterns.WEATHER_STORM_END   = "storm seems to cease"
DMPatterns.WEATHER_CLOUDY_RAIN = "^The sky appears somewhat cloudy, and it begins to rain%.$"
DMPatterns.WEATHER_BEGINS_RAIN = "begins to rain"
DMPatterns.WEATHER_VERY_CLOUDY = "very cloudy"
DMPatterns.WEATHER_CALM        = "calmness begins"
