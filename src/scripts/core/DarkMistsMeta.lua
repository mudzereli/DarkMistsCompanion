-- =============================================================================
-- dm_meta.lua
-- -----------------------------------------------------------------------------
-- Dark Mists meta / UI helpers.
--
-- Responsibilities:
--   • dm help        → discoverability
--   • dm version     → sanity check after reloads
--   • dm status      → operational confidence
--
-- Non-goals:
--   • No automation
--   • No game logic
--   • No state mutation
--
-- Safe to reload at any time.
-- =============================================================================

-- =============================================================================
-- META REGISTRY
-- =============================================================================

DarkMistsMeta = {}

DarkMistsMeta.meta = {
  name    = "DarkMistsCompanion",
  version = "unknown",
}

local dm_text = (DarkmistsTheme and DarkmistsTheme.textTag) or ""
local dm_header_color = (DarkmistsTheme and DarkmistsTheme.infoTag) or ""
local dm_link_color = (DarkmistsTheme and DarkmistsTheme.accentTag) or ""
local dm_muted = (DarkmistsTheme and DarkmistsTheme.mutedTag) or ""
local dm_good = (DarkmistsTheme and DarkmistsTheme.goodTag) or ""
local dm_warn = (DarkmistsTheme and DarkmistsTheme.warnTag) or ""
local dm_bad = (DarkmistsTheme and DarkmistsTheme.badTag) or ""

DarkMistsMeta.helpIndex = {
  dmc = {
    title = "Dark Mists Companion",
    desc = "Central help hub for the Dark Mists Companion Mudlet package.",
    info  = [[
Central help hub for the Dark Mists Mudlet package.

Includes:
• Feature discovery
• Version information
• Runtime status checks
    ]],
  },

  ["walk"] = {
    title   = "Map Destinations",
    command = "walk",
    desc    = "Saved destinations and map-based navigation",
  },

  ui = {
    title   = "UI Mode",
    desc    = "Toggle between Full UI and Minimal UI layouts",
    info  = [[
  Switch between interface layouts.

  • dmc ui       — Toggle UI mode
  • dmc ui on    — Enable Full UI
  • dmc ui off   — Enable Minimal UI

  Minimal UI removes borders and extra windows.
  Full UI restores all interface panels.
    ]],
  },

  infobox = {
    title = "Profile Info Box",
    desc  = "Set the extra profile information shown on the Mudlet profile screen.",
    info  = [[
Update the Mudlet profile information box.

• dmc infobox <text>  — set the info box text
• dmc infobox clear   — clear the info box

This is informational only and safe to change any time.
    ]],
  },

  map = {
    title = "World Map",
    desc = "Fully interactable Mudlet world map with ~15,000 rooms.",
    info  = [[
Fully interactable Mudlet world map with ~15,000 rooms.

• Automatically tracks your position
• Areas match in-game zones
• Available even while offline
• Used by the 'walk' command for navigation
    ]],
  },

  es = {
    title = "Enchanter Assist",
    command = "es",
    desc = "Track and complete Alchemy trial combinations."
  },
  
  ch = {
    title   = "Chat History",
    command = "ch",
    desc    = "Separate chat window with filtered channels",
  },

  sb = {
    title   = "Status Bars",
    command = "sb",
    desc    = "HP, Mana, Moves, XP, and enemy status bars",
  },

  dmid = {
    title   = "Item Tracker",
    command = "dmid",
    desc    = "Clickable item identification and lookup",
  },

  who = {
    title = "Who Window",
    desc = "Persistent WHO list window.",
    info  = [[
Persistent WHO list window.

• Updates automatically when WHO output is seen
• Prevents scrollback loss
• Designed for awareness, not automation
    ]],
  },

  affects = {
    title = "Affects Window",
    desc = "Tracks active affects and buff durations.",
    info  = [[
Tracks active affects and buff durations.

• Updates from affects / score output
• Provides timing awareness
• No gameplay decisions or automation
    ]],
  },

  skillups = {
    title   = "Skill Ups",
    command = "skillups",
    desc    = "Displays recent skill increases",
    info  = "Displays recent skill increases",
  },

  statroll = {
    title = "Stat Roller",
    desc = "Character creation stat rolling helper.",
    info  = [[
Character creation stat rolling helper.

• Assists with maximizing stat rolls
• Only active during character creation
• No effect on gameplay afterward
    ]],
  },

  spam = {
    title = "Spam Prevention",
    desc = "Prevent accidental command spam by denying repeated commands.",
    info  = [[
Prevents accidental command spam by tracking consecutive identical commands
and denying them after a configurable threshold.

• dmc spam status         – show enabled status, threshold, and fallback
• dmc spam on / off       – enable or disable spam prevention
• dmc spam threshold <n>  – set repeat limit (default: 20)
• dmc spam fallback <cmd> – send this command instead when threshold hit
• dmc spam fallback clear – disable fallback, just deny

When the threshold is reached for a repeated command:
  – current send is denied (denyCurrentSend)
  – fallback command is sent (if configured)
  – notification is shown with repeat count

Example:
  dmc spam threshold 15
  dmc spam fallback look
    ]],
  },

  cmud = {
    title = "CMud Scripting",
    desc  = "CMUD-style aliases, triggers, and variables stored across sessions.",
    info  = [[
CMUD-compatible scripting layer. Aliases, triggers, and variables
are saved to disk and restored on each login.

Prefix every command with # (e.g. #alias, #trigger).

──── ALIASES ────────────────────────────────────────────────────
  #alias {name} {body}     – define or update an alias
  #alias {name}            – show alias definition
  #alias                   – list all aliases
  #unalias {name}          – remove an alias

  Body syntax:
    %1 %2 …     positional args from the alias invocation
    %%1 %%2 …   delayed expansion (survive inner alias calls)
    @VarName    expands a stored variable
    | or ;      command separator (configurable)

──── TRIGGERS ───────────────────────────────────────────────────
  #trigger {name} {pattern} {body}   – CMUD wildcard pattern
  #rxtrigger {name} {pattern} {body} – raw PCRE regex pattern
  #trigger {name}                    – show trigger definition
  #trigger                           – list all triggers
  #untrigger {name}                  – remove a trigger

  Wildcard tokens (for #trigger / #action):
    *         any sequence of characters
    ?         any single character
    %d        one or more digits (0-9)
    %n        signed number (+ or -)
    %w        one or more alpha characters
    %a        one or more alphanumeric characters
    %s        one or more whitespace characters
    %x        one or more non-whitespace characters
    %p        punctuation
    %t        a direction command (north, south, …)
    [abc]     any characters in range
    (pat)     capture group → %1 … %99 in body
    {a|b|c}   alternation (match any listed value)
    {^str}    negation (do NOT match str)
    &nn       exactly nn characters
    &VarName  capture into @VarName variable
    ~x        literal x  (escape next character)
    ~~        literal ~
    ^ $       line anchors

──── VARIABLES ──────────────────────────────────────────────────
  #var {name} {value}      – set a variable
  #var {name}              – show variable value
  #var                     – list all variables
  #unvar {name}            – remove a variable
  name = value             – shorthand assignment (no # needed)

  Reference a variable with @VarName in alias/trigger bodies.
  &VarName captures in trigger patterns auto-assign the variable.

──── ENABLE / DISABLE ───────────────────────────────────────────
  #T+ {name}               – enable alias / trigger / variable
  #T- {name}               – disable alias / trigger / variable

  Disabled items remain defined but inactive until re-enabled.
  Listings show enabled names in green and disabled names in yellow.

──── ASYNC DELAY ────────────────────────────────────────────────
  #WAIT {ms}               – pause N milliseconds then continue
  #WAIT                    – wait for the next MUD line then continue

  Shorthand prefixes are accepted (e.g. #WA 5000).
  Use inside alias bodies to sequence timed or event-driven commands.

──── UTILITY ────────────────────────────────────────────────────
  #show {text}             – echo text (variable expansion applies)
  #send {text}             – send text to server
  #repeat {n} {command}    – run command n times
  #{n} {command}           – shorthand for #repeat
  #sep {char}              – set command separator character (default: |)
  #sep                     – show current separator

──── CROSS-INVOCATION ───────────────────────────────────────────
  Alias bodies can call other aliases by name (cross-invocation).
  Trigger bodies can also invoke aliases the same way.
  Self-recursion is blocked with a warning.

──── EXAMPLES ───────────────────────────────────────────────────
  #alias z {zap %1}
  #trigger hitme {You are hit by * for %d damage.} {#show ouch}
  #rxtrigger hpline {^HP:\s*(\d+)/(\d+)} {#var hp %1|#var hpmax %2}
  #trigger getitem {* drops &ItemName} {#show Dropped: @ItemName}

  -- wait 5 s then look
  #alias j {#WA 5000|l}

  -- loot, wait for next MUD line, then look
  #alias loot {get all corpse|#WA|l}

  -- disable a trigger without removing it
  #T- hitme
  #T+ hitme
    ]],
  },
}

local helpSections = {
  {
    title = "Misc",
    keys  = { "dmc", "spam", "infobox" },
  },
  {
    title = "Interface",
    keys  = {"ui", "ch", "sb", "dmid", "who", "affects" },
  },
  {
    title = "Travel & Map",
    keys  = { "map", "walk" },
  },
  {
    title = "Character",
    keys  = { "skillups", "statroll", "es" },
  },
  {
    title = "Scripting",
    keys  = { "cmud" },
  },
}

-- =============================================================================
-- OUTPUT HELPERS (local to this file)
-- =============================================================================

-- Section header
local function dm_header(title)
  cecho("\n"..dm_header_color.."[" .. title .. "]"..dm_text.."\n")
end

local function dm_link(label, command)
  cechoLink(
    string.format(dm_link_color.."%-10s"..dm_text, label),
    function() expandAlias(command) end,
    "Click to run: " .. command,
    true
  )
end

function DarkMistsMeta.init()
  -- Resolve package identity at init time so module load order is safe.
  DarkMistsMeta.meta.name = (Darkmists and Darkmists.NAME) or DarkMistsMeta.meta.name
  DarkMistsMeta.meta.version = (Darkmists and Darkmists.VERSION) or DarkMistsMeta.meta.version

  -- Resolve theme tags at init time so load order is safe.
  dm_text = (DarkmistsTheme and DarkmistsTheme.textTag) or dm_text
  dm_header_color = (DarkmistsTheme and DarkmistsTheme.infoTag) or dm_header_color
  dm_link_color = (DarkmistsTheme and DarkmistsTheme.accentTag) or dm_link_color
  dm_muted = (DarkmistsTheme and DarkmistsTheme.mutedTag) or dm_muted
  dm_good = (DarkmistsTheme and DarkmistsTheme.goodTag) or dm_good
  dm_warn = (DarkmistsTheme and DarkmistsTheme.warnTag) or dm_warn
  dm_bad = (DarkmistsTheme and DarkmistsTheme.badTag) or dm_bad

  -- Resolve dynamic alias at init time after ItemTracker exists.
  if ItemTracker and ItemTracker.settings and ItemTracker.settings.alias then
    DarkMistsMeta.helpIndex.dmid.command = ItemTracker.settings.alias
  end

  -- ===================================================================
  -- UI MODE COMMANDS
  -- ===================================================================

  DarkmistsAlias.add([[^dmc\s+ui(?:\s+(on|off))?$]], function()
    local state = matches[2]

    -- Explicit ON
    if state == "on" then
      if not Darkmists.GlobalSettings.minimalMode then
        cecho("\n"..dm_muted.."[UI] "..dm_text.."Already in "..dm_good.."FULL UI"..dm_muted.." mode.\n")
        return
      end

      cecho("\n"..dm_muted.."[UI] "..dm_text.."Enabling "..dm_good.."FULL UI"..dm_muted.." mode...\n")
      Darkmists.EnableUI()
      return
    end

    -- Explicit OFF
    if state == "off" then
      if Darkmists.GlobalSettings.minimalMode then
        cecho("\n"..dm_muted.."[UI] "..dm_text.."Already in "..dm_warn.."MINIMAL UI"..dm_muted.." mode.\n")
        return
      end

      cecho("\n"..dm_muted.."[UI] "..dm_text.."Switching to "..dm_warn.."MINIMAL UI"..dm_muted.." mode...\n")
      Darkmists.DisableUI()
      return
    end

    -- Toggle
    if Darkmists.GlobalSettings.minimalMode then
      cecho("\n"..dm_muted.."[UI] "..dm_text.."Enabling "..dm_good.."FULL UI"..dm_muted.." mode...\n")
      Darkmists.EnableUI()
    else
      cecho("\n"..dm_muted.."[UI] "..dm_text.."Switching to "..dm_warn.."MINIMAL UI"..dm_muted.." mode...\n")
      Darkmists.DisableUI()
    end
  end)

  -- ===================================================================
  -- PROFILE INFO BOX COMMANDS
  -- ===================================================================

  DarkmistsAlias.add([[^dmc\s+infobox(?:\s+(.*))?$]], function()
    local args = matches[2]
    local setInfo = rawget(_G, "setProfileInformation")
    local clearInfo = rawget(_G, "clearProfileInformation")
    local getInfo = rawget(_G, "getProfileInformation")

    if type(setInfo) ~= "function" or type(clearInfo) ~= "function" or type(getInfo) ~= "function" then
      cecho("\n"..dm_muted.."[InfoBox] "..dm_bad.."This Mudlet client does not support profile information commands.\n")
      return
    end

    args = args and args:gsub("^%s*(.-)%s*$", "%1") or ""

    if args == "" then
      cecho("\n"..dm_header_color.."Profile Info Box:\n")
      local currentInfo = getInfo() or ""

      if currentInfo == "" then
        cecho(dm_muted.."Current text: "..dm_text.."(empty)\n\n")
      else
        cecho(dm_muted.."Current text:\n")
        cecho(dm_good..currentInfo.."\n\n")
      end

      cecho(dm_text.."dmc infobox <text>"..dm_muted.."  – set the profile info text\n")
      cecho(dm_text.."dmc infobox clear"..dm_muted.."   – clear the profile info text\n")
      return
    end

    if args == "clear" or args == "reset" or args == "off" then
      clearInfo()
      cecho("\n"..dm_muted.."[InfoBox] "..dm_good.."Profile information cleared.\n")
      return
    end

    setInfo(args)
    cecho("\n"..dm_muted.."[InfoBox] "..dm_text.."Profile information updated: "..dm_good..args.."\n")
  end)

  -- =============================================================================
  -- dm help
  -- =============================================================================

  DarkmistsAlias.add("^dmc help (.*)$", function()
    local key   = matches[2]
    local entry = DarkMistsMeta.helpIndex[key]

    if not entry then
      cecho("\n"..dm_bad.."[DM] Unknown help topic: "..dm_text .. key .. "\n")
      return
    end

    -- If the feature has a real command, just run it
    if entry.command then
      expandAlias(entry.command)
      return
    end

    -- Otherwise, show informational help
    dm_header(entry.title)
    cecho(dm_muted .. (entry.info or "No additional information available.") .. "\n")
  end)

  DarkmistsAlias.add("^dmc(?:\\s+help)?$", function()
    dm_header(DarkMistsMeta.meta.name)

    cecho(string.format(
      dm_muted.."Version: "..dm_text.."%s\n\n",
      DarkMistsMeta.meta.version
    ))

    for _, section in ipairs(helpSections) do
      cecho(dm_header_color .. section.title .. ":\n")

      for _, key in ipairs(section.keys) do
        local info = DarkMistsMeta.helpIndex[key]
        if info then
          local cmd = (key == "dmc") and "dmc help" or ("dmc help " .. key)
          dm_link(("  <u>%s [%s]</u>"):format(info.title,key), cmd)
          cecho("\n"..dm_muted.."    " .. info.desc .. "\n")
        end
      end

      cecho("\n")
    end

    cecho(dm_muted.."Click a feature or type "..dm_text.."dmc help <feature>\n")
  end)

  -- ===================================================================
  -- CHAT HISTORY (CH) COMMANDS
  -- ===================================================================

  DarkmistsAlias.add([[^ch(?:\s+(\w+))?$]], function()
    local cmd = matches[2]

    if cmd == "refresh" then
      ChatHistory.refresh()
      cecho("\n"..dm_muted.."["..dm_text.."ChatHistory"..dm_muted.."] "..dm_good.."Refreshed")
    else
      cecho("\n"..dm_header_color.."Chat History:\n")
      cecho(dm_muted.."Chat History provides a separate chat window that contains recent \nmessages from various channels (All, OOC, Direct, Local).\n")
      cecho("\n"..dm_header_color.."Chat History Commands:\n")
      cecho(dm_text.."ch refresh"..dm_muted.." – Refresh window\n")
    end
  end)

  -- ===================================================================
  -- STATUS BAR COMMANDS
  -- ===================================================================

  DarkmistsAlias.add([[^sb(?:\s+(\w+))?$]], function()
    local cmd = matches[2]

    if cmd == "show" then
      StatusBar.showAll()
      return
    end

    if cmd == "hide" then
      StatusBar.hideAll()
      return
    end

    if cmd == "toggle" then
      StatusBar.toggle()
      return
    end

    if cmd == "update" then
      StatusBar.update()
      cecho("\n"..dm_muted.."[sb] "..dm_good.."updated\n")
      return
    end

    if cmd == "recreate" then
      StatusBar.recreate()
      return
    end

    if cmd == "info" then
      cecho("\n"..dm_header_color.."Status Bars:\n")

      cecho(string.format("  "..dm_text.."HP Gauge:    "..dm_muted.."%s\n", tostring(StatusBar.hpGauge ~= nil)))
      cecho(string.format("  "..dm_text.."MN Gauge:    "..dm_muted.."%s\n", tostring(StatusBar.mnGauge ~= nil)))
      cecho(string.format("  "..dm_text.."MV Gauge:    "..dm_muted.."%s\n", tostring(StatusBar.mvGauge ~= nil)))
      cecho(string.format("  "..dm_text.."XP Gauge:    "..dm_muted.."%s\n", tostring(StatusBar.xpGauge ~= nil)))
      cecho(string.format("  "..dm_text.."Enemy Gauge: "..dm_muted.."%s\n", tostring(StatusBar.enemyGauge ~= nil)))
      cecho(string.format("  "..dm_text.."Border:      "..dm_muted.."%spx\n", StatusBar.currentBorderHeight or "?"))

      if dmapi.player and dmapi.player.vitals then
        cecho("\n"..dm_header_color.."Vitals:\n")
        cecho(string.format(
          "  "..dm_text.."HP: "..dm_good.."%d"..dm_text.."/"..dm_good.."%d\n",
          dmapi.player.vitals.hp or 0,
          dmapi.player.vitals.hpMax or 0
        ))
        cecho(string.format(
          "  "..dm_text.."MN: "..dm_good.."%d"..dm_text.."/"..dm_good.."%d\n",
          dmapi.player.vitals.mn or 0,
          dmapi.player.vitals.mnMax or 0
        ))
        cecho(string.format(
          "  "..dm_text.."MV: "..dm_good.."%d"..dm_text.."/"..dm_good.."%d\n",
          dmapi.player.vitals.mv or 0,
          dmapi.player.vitals.mvMax or 0
        ))
      end

      if dmapi.player and dmapi.player.combat then
        cecho("\n"..dm_header_color.."Combat:\n")
        cecho(string.format(
          "  "..dm_text.."In Combat: "..dm_muted.."%s\n",
          tostring(dmapi.player.combat.active or false)
        ))
        if dmapi.player.combat.target then
          cecho("  "..dm_text.."Target: "..dm_bad .. tostring(dmapi.player.combat.target) .. "\n")
        end
      end

      return
    end

    -- default / help
    cecho("\n"..dm_header_color.."Status Bar Commands:\n")
    cecho("  "..dm_text.."sb show      "..dm_muted.."- show all bars\n")
    cecho("  "..dm_text.."sb hide      "..dm_muted.."- hide all bars\n")
    cecho("  "..dm_text.."sb toggle    "..dm_muted.."- toggle visibility\n")
    cecho("  "..dm_text.."sb update    "..dm_muted.."- force refresh\n")
    cecho("  "..dm_text.."sb recreate  "..dm_muted.."- rebuild UI\n")
    cecho("  "..dm_text.."sb info      "..dm_muted.."- debug information\n")
  end)

  -- ============================================================================
  -- ITEM TRACKER Command Aliases
  -- ============================================================================

  do
    -- Main help command
    DarkmistsAlias.add(string.format("^%s$", ItemTracker.settings.alias), function()
      local alias = ItemTracker.settings.alias
      
      cecho("\n"..dm_header_color.."Item Tracker Commands:\n")
      cecho(dm_muted.."Clickable item identification & lookup system\n\n")

      cecho(dm_text.."Usage:\n")
      cecho(string.format("  %s%s %s<item name or partial>\n\n", dm_header_color, alias, dm_text))

      cecho(dm_text.."Examples:\n")
      cecho(string.format("  %s%s bracelet%s                – search for items containing 'bracelet'\n", dm_header_color, alias, dm_text))
      cecho(string.format("  %s%s an oversized lumber axe%s – exact name lookup\n\n", dm_header_color, alias, dm_text))

      cecho(dm_text.."Area search:\n")
      cecho(string.format("  %s%s area %s<area name or partial>\n\n", dm_header_color, alias, dm_text))

      cecho(dm_text.."In-game interaction:\n")
      cecho("  "..dm_header_color.."• Click an item name"..dm_text.."       – show tooltip near your cursor\n")
      cecho("  "..dm_header_color.."• Shift + Click"..dm_text.."            – print full item details to chat\n")
      cecho("  "..dm_header_color.."• Click anywhere else"..dm_text.."      – close the tooltip\n\n")

      cecho(dm_text.."Detection rules:\n")
      cecho("  "..dm_muted.."• Only matches item names at the END of a line\n")
      cecho("  "..dm_muted.."• Longest names are matched first\n")
      cecho("  "..dm_muted.."• Prevents false matches (e.g. 'egg' in 'leggings')\n\n")

      cecho(dm_text.."Notes:\n")
      cecho("  "..dm_muted.."• Duplicate item names are supported and shown together\n")
      cecho("  "..dm_muted.."• Tooltip size auto-adjusts to item details\n")
      cecho("  "..dm_muted.."• Tooltip avoids covering status bars at bottom\n")
      cecho("  "..dm_muted.."• Colors and layout can be customized in ItemTracker.settings\n\n")
    end)

    -- Area search command
    DarkmistsAlias.add("^" .. ItemTracker.settings.alias .. "\\s+area\\s+(.*)$", function()
      local query = matches[2]
      local results = ItemTracker.listByArea(query)

      if not results or #results == 0 then
        cecho(dm_bad.."[ID] No items found for area: " .. query .. "\n")
        return
      end

      local limit = 100
      local shown = math.min(#results, limit)
      cecho(string.format(
        "\n"..dm_warn.."[ID] Items in area matching '%s' (%d):"..dm_text.."\n",
        query,
        #results
      ))

      for i = 1, shown do
        local item = results[i]
        cecho(string.format("   "..dm_text.."%d) ", i))
        local areaTag = item.area and ("[" .. item.area .. "] ") or ""
        cechoLink(
          dm_muted .. areaTag .. dm_text ..
          ItemTracker.settings.itemLinkColor .. item.name .. dm_text.."\n",
          ItemTracker.getHandler(item.name),
          "Click: tooltip | Shift+Click: full identify",
          true
        )
      end

      if #results > limit then
        cecho(dm_warn.."Refine your search."..dm_text.."\n")
      end
    end)

    -- Item search command
    DarkmistsAlias.add(string.format("^%s\\s+(.+)$", ItemTracker.settings.alias), function()
      local query = matches[2]

      -- Prevent collision with area subcommand
      if query:lower():match("^area%s+") then
        return
      end

      local results = ItemTracker.find(query)

      if not results or #results == 0 then
        cecho(dm_bad.."[ID] No items found for: " .. query .. "\n")
        return
      end

      -- Single match: show immediately
      if #results == 1 then
        ItemTracker.show(results[1])
        return
      end

      -- Multiple matches: show clickable list
      local limit = 50
      local shown = math.min(#results, limit)
      cecho(dm_warn.."[ID] Multiple matches:"..dm_text.."\n")
      for i = 1, shown do
        local item = results[i]
        cecho(string.format("   "..dm_text.."%d) ", i))
        cechoLink(
          ItemTracker.settings.itemLinkColor .. item.name .. dm_text.."\n",
          ItemTracker.getHandler(item.name),
          "Click: tooltip | Shift+Click: full identify",
          true
        )
      end
      cecho(dm_warn.."Refine your search."..dm_text.."\n")
    end)
  end

  -- =============================================================================
  -- WALK COMMAND
  -- =============================================================================
  local function renderWalkList(filter)
    local c = dm_text

    DMLogger.notify("WALK","Destinations by Area:")

    local grouped = MapDestinations.getGroupedFiltered(filter)
    if not next(grouped) then
      cecho("\n  "..dm_muted.."(none)")
      return
    end

    local areaNames = {}
    for areaName in pairs(grouped) do
      table.insert(areaNames, areaName)
    end
    table.sort(areaNames)

    for _, areaName in ipairs(areaNames) do
      for _, entry in ipairs(grouped[areaName]) do
        local roomName = getRoomName(entry.room) or "UNKNOWN"
        local destinationName = DMUtil.cap(entry.name, 24)
        local namePadding = string.rep(" ", math.max(0, 24 - #destinationName))

        cecho(string.format(
          "\n%s[%s%-16s%s] %s",
          dm_warn,
          c,
          DMUtil.cap(areaName, 16),
          dm_warn,
          c
        ))

        cechoLink(
          ("%s<u>%s</u>"):format(c, destinationName),
          function()
            expandAlias(("walk %s"):format(entry.name))
          end,
          ("Click: walk %s"):format(entry.name),
          true
        )

        cecho(string.format(
          "%s%s → %s[%s%5d%s]%s%-27s",
          namePadding,
          dm_muted,
          dm_muted,
          c,
          entry.room,
          dm_muted,
          c,
          DMUtil.cap(roomName,27)
        ))
      end
    end
  end

  DarkmistsAlias.add("^walk(?:\\s+(.*))?$", function()
    local c = dm_text
    local arg = matches[2] and matches[2]:trim() or ""

    -- HELP (compact)
    if arg == "" then
      local function line(cmd, desc)
        return string.format("  %s\n    %s\n", cmd, desc)
      end

      local out = dm_header_color .. "Walk Module:\n\n"
        .. dm_muted .. "Speedwalk between known rooms using the map speedwalk system. \nDestinations must be discovered and routes clear.\n\n"
        .. dm_header_color .. "Walk Commands:\n"
        .. line(c .. "walk <name>", dm_muted .. "Navigate to a saved destination")
        .. line(c .. "walk list <filter: optional>", dm_muted .. "Show saved destinations (optional filter)")
        .. line(c .. "walk add <name> <roomid: optional>", dm_muted .. "Add persistent destination (max 24 chars, room optional)")
        .. line(c .. "walk rem <name>", dm_muted .. "Remove a saved destination")
        .. line(c .. "walk area <name>", dm_muted .. "Navigate to first room in matching area")
        .. line(c .. "walk stop", dm_muted .. "Cancel an active walk")

      cecho(out)
      return
    end

    if arg == "stop" then
      MapDestinations.stop()
      DMLogger.notify("WALK", dm_bad.."Walking Stopped!")
      return
    end

    -- LIST (grouped by area)
    local listFilter = arg:match("^list%s+(%S+)$")
    if arg == "list" or listFilter then
      renderWalkList(listFilter)
      return
    end

    -- ADD
    do
      local name = arg:match("^add%s+([%w_]+)$")
      if name then
        local ok, a, b, cRoomName = MapDestinations.addDestination(name)

        if not ok then
          if a == "NO_CURRENT_ROOM" then
            DMLogger.notify("WALK", dm_bad.."No Current Room found on Map")
          elseif a == "INVALID_NAME" then
            DMLogger.notify("WALK", dm_bad.."Invalid destination name")
          elseif a == "NAME_TOO_LONG" then
            DMLogger.notify("WALK", ("%sDestination names must be %d characters or fewer"):format(dm_bad, b))
          end
          return
        end

        local destName, roomId = a, b

        DMLogger.notify("WALK",
          ("Added destination: %s%s%s → %s[%s%d%s] %s%s")
            :format(c, destName, dm_good, dm_muted, c, roomId, dm_muted, c, cRoomName)
        )

        return
      end
      
      local name, room = arg:match("^add%s+([%w_]+)%s+(%S+)$")
      if name and room then
        local ok, a, b, roomName = MapDestinations.addDestination(name, room)

        if not ok then
          if a == "INVALID_NAME" then
            DMLogger.notify("WALK", dm_bad.."Invalid destination name")
          elseif a == "NAME_TOO_LONG" then
            DMLogger.notify("WALK", ("%sDestination names must be %d characters or fewer"):format(dm_bad, b))
          elseif a == "INVALID_ROOM" then
            DMLogger.notify("WALK", dm_bad.."Invalid room id")
          elseif a == "ROOM_MISSING" then
            DMLogger.notify("WALK",
              ("%sRoom does not exist: %s%d"):format(dm_bad, c, b)
            )
          end
          return
        end

        local destName, roomId = a, b

        DMLogger.notify("WALK",
          ("Added destination: %s%s%s → %s[%s%d%s] %s%s")
            :format(c, destName, dm_good, dm_muted, c, roomId, dm_muted, c, roomName)
        )

        return
      end
    end

    -- REMOVE
    local rem = arg:match("^rem%s+([%w_]+)$")
    if rem then
      local ok, code, data = MapDestinations.remove(rem)

      if not ok then
        if code == "NOT_FOUND" then
          DMLogger.notify("WALK",
            ("%sNo destination named %s%s"):format(dm_bad, c, data)
          )
        end
      else
        DMLogger.notify("WALK",
          ("%sRemoved destination %s%s"):format(dm_warn, c, data)
        )
      end
      return
    end

    -- AREA SEARCH (accepts spaces, quotes, case-insensitive)
    do
      local areaSearch = arg:match("^area%s+(.+)$")
      if areaSearch then
        -- trim whitespace
        areaSearch = areaSearch:gsub("^%s*(.-)%s*$", "%1")
        -- strip surrounding quotes if present
        areaSearch = areaSearch:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        local ok, code, data = MapDestinations.navigateToArea(areaSearch)

        if not ok then
          if code == "ALREADY_IN_AREA" then
            DMLogger.notify("WALK",
              ("%sYou are already in %s%s"):format(dm_warn, c, data)
            )
          elseif code == "AREA_AMBIGUOUS" then
            DMLogger.notify("WALK", dm_warn .. "Ambiguous area — did you mean:")
            local names = {}
            for name in (data or ""):gmatch("[^,]+") do
              names[#names + 1] = name:match("^%s*(.-)%s*$")
            end
            cecho("  ")
            for i, name in ipairs(names) do
              if i > 1 then cecho(dm_muted .. ", ") end
              cechoLink(
                c .. "<u>" .. name .. "</u>",
                function() expandAlias("walk area " .. name) end,
                "Click: walk area " .. name,
                true
              )
            end
            cecho("\n")
          elseif code == "AREA_NOT_FOUND" then
            DMLogger.notify("WALK",
              ("%sNo area matching %s%s"):format(dm_bad, c, data)
            )
          elseif code == "AREA_EMPTY" then
            DMLogger.notify("WALK",
              ("%sArea has no indexed rooms: %s%s"):format(dm_bad, c, data)
            )
          elseif code == "INVALID_SEARCH" then
            DMLogger.notify("WALK", dm_bad.."Invalid area search.")
          elseif code == "NO_AREAS" then
            DMLogger.notify("WALK", dm_bad.."Area table unavailable.")
          elseif code == "NO_CURRENT_ROOM" then
            DMLogger.notify("WALK", dm_bad.."Current room unknown!")
          elseif code == "NO_PATH" then
            DMLogger.notify("WALK",("%sNo known path to area %s%s"):format(dm_bad, c, data))
          end
          return
        end

        DMLogger.notify("WALK",
          ("%sWalking to area %s%s %s[%s%d%s]")
            :format(dm_header_color, c, data, dm_muted, c, code, dm_muted)
        )
        return
      end
    end

    -- NAVIGATE TO SAVED DESTINATION
    local ok, a, b = MapDestinations.navigate(arg)

    if not ok then
      if a == "NOT_FOUND" then
        DMLogger.notify("WALK",
          ("%sNo destination named %s%s"):format(dm_bad, c, b)
        )
      elseif a == "INVALID_NAME" then
        DMLogger.notify("WALK", dm_bad.."Invalid name given!")
      elseif a == "NO_CURRENT_ROOM" then
        DMLogger.notify("WALK", dm_bad.."Current room unknown!")
      elseif a == "ALREADY_THERE" then
        DMLogger.notify("WALK",
          ("%sYou are already at %s%s"):format(dm_bad, c, b)
        )
      elseif a == "ROOM_MISSING" then
        DMLogger.notify("WALK",
          ("%sDestination room no longer exists for %s%s"):format(dm_bad, c, b)
        )
      elseif a == "NO_PATH" then
        DMLogger.notify("WALK",
          ("%sNo known path to %s%s"):format(dm_bad, c, b)
        )
      end
      return
    end

    DMLogger.notify("WALK",
      ("%sGenerating path to %s%s %s[%s%d%s] %s%s")
        :format(dm_header_color, c, arg, dm_muted, c, a, dm_muted, c, b)
    )
  end)

  -- =============================================================================
  -- SPAM PREVENTION COMMANDS
  -- =============================================================================
  DarkmistsAlias.add("^dmc\\s+spam$", function()
    local entry = DarkMistsMeta.helpIndex.spam
    dm_header(entry.title)
    cecho(dm_muted .. (entry.info or "No additional information available.") .. "\n")
  end)

  DarkmistsAlias.add("^dmc\\s+spam\\s+threshold\\s+(\\d+)$", function()
    local n = tonumber(matches[2])
    if not n or n < 1 then
      DMLogger.notify("SpamPrevention", dm_bad .. "Threshold must be a positive integer.")
      return
    end
    SpamPrevention.threshold = n
    DMLogger.notify("SpamPrevention", string.format(
      "%sThreshold set to %s%d",
      dm_muted,
      dm_text,
      n
    ))
  end)

  DarkmistsAlias.add("^dmc\\s+spam\\s+fallback\\s+(.+)$", function()
    local arg = matches[2]
    if arg == "clear" or arg == "none" then
      SpamPrevention.fallbackCommand = nil
      DMLogger.notify("SpamPrevention", dm_muted .. "Fallback command cleared.")
    else
      SpamPrevention.fallbackCommand = arg
      DMLogger.notify("SpamPrevention", string.format("%sFallback set to: %s%s", dm_muted, dm_good, arg))
    end
  end)

  DarkmistsAlias.add("^dmc\\s+spam\\s+(on|off|status)$", function()
    local cmd = matches[2]

    if cmd == "on" then
      SpamPrevention.enabled = true
      DMLogger.notify("SpamPrevention", dm_good .. "Enabled")
    elseif cmd == "off" then
      SpamPrevention.enabled = false
      DMLogger.notify("SpamPrevention", dm_bad .. "Disabled")
    else
      DMLogger.notify("SpamPrevention", string.format(
        "%sEnabled: %s%s%s  Threshold: %s%d%s  Fallback: %s%s",
        dm_muted,
        SpamPrevention.enabled and dm_good or dm_bad,
        tostring(SpamPrevention.enabled),
        dm_muted, dm_text,
        SpamPrevention.threshold,
        dm_muted, dm_text,
        SpamPrevention.fallbackCommand or "(none)"
      ))
    end
  end)

  -- =============================================================================
  -- ENCHANTER ASSIST (ES) COMMAND
  -- =============================================================================
  DarkmistsAlias.add("^es(?:\\s+(.*))?$", function()
    local c = dm_text
    local arg = matches[2] and matches[2]:trim() or ""

    -- HELP (compact)
    if arg == "" or arg == "help" then
      cecho(
        dm_header_color.."EnchanterAssist Module:\n\n"..
        dm_muted.."Automation helper for enchantment workflow management.\n"..
                  "Controls resting, part counts, and execution flow.\n\n"..
        dm_header_color.."EA Module Commands:\n"..
        "  "..c.."es auto    "..dm_muted.."Toggle automatic running mode.\n"..
        "  "..c.."es <1-5>   "..dm_muted.."Set part count (1–5), save configuration, and run.\n"..
        "  "..c.."es run     "..dm_muted.."Execute a single enchantment cycle.\n"..
        "  "..c.."es stop    "..dm_muted.."Stop after current attempt (or immediately if idle).\n"..
        "  "..c.."es stats   "..dm_muted.."Display session statistics.\n"..
        "  "..c.."es missing "..dm_muted.."Display missing material statistics.\n"..
        "  "..c.."es reset   "..dm_muted.."Reset session statistics.\n\n"..
        dm_header_color.."Configuration Commands:\n"..
        "  "..c.."es set container <name>         "..dm_muted.."Set container holding enchantment items.\n"..
        "  "..c.."es set sleeper <name>           "..dm_muted.."Set sleeper target.\n"..
        "  "..c.."es set sleepmode <sleep|potion> "..dm_muted.."Choose restoration behavior type.\n"..
        "  "..c.."es set potion <item>            "..dm_muted.."Set item used for quaffing.\n"..
        "  "..c.."es set order <seq|rand>         "..dm_muted.."Set trial selection order mode.\n"..
        "  "..c.."es sound                        "..dm_muted.."Toggle formula discovery sound\n\n"..
        dm_header_color.."Control:\n"..
        "  "..c.."es enable / es disable          "..dm_muted.."Enable or disable EnchanterAssist entirely.\n"
      )
      return
    end
  end)

  DarkmistsAlias.add("^es run$", function() EnchanterAssist.run() end)

  DarkmistsAlias.add("^es stop$", function() EnchanterAssist.hardStop() end)

  DarkmistsAlias.add("^es auto$", function()
    EnchanterAssist.autoRun = not EnchanterAssist.autoRun
    DMLogger.notify(EnchanterAssist.color.."EnchanterAssist","AutoRun: " .. tostring(EnchanterAssist.autoRun))
  end)

  DarkmistsAlias.add("^es 1$", function() EnchanterAssist.partCount = 1 EnchanterAssist._comboIndices = nil EnchanterAssist.save() EnchanterAssist.run() end)
  DarkmistsAlias.add("^es 2$", function() EnchanterAssist.partCount = 2 EnchanterAssist._comboIndices = nil EnchanterAssist.save() EnchanterAssist.run() end)
  DarkmistsAlias.add("^es 3$", function() EnchanterAssist.partCount = 3 EnchanterAssist._comboIndices = nil EnchanterAssist.save() EnchanterAssist.run() end)
  DarkmistsAlias.add("^es 4$", function() EnchanterAssist.partCount = 4 EnchanterAssist._comboIndices = nil EnchanterAssist.save() EnchanterAssist.run() end)
  DarkmistsAlias.add("^es 5$", function() EnchanterAssist.partCount = 5 EnchanterAssist._comboIndices = nil EnchanterAssist.save() EnchanterAssist.run() end)

  DarkmistsAlias.add("^es reset$", EnchanterAssist.reset)

  DarkmistsAlias.add("^es stats$", EnchanterAssist.stats)

  DarkmistsAlias.add("^es missing$", EnchanterAssist.statsMissing)

  -- ============================================================================
  -- CONFIG COMMANDS
  -- ============================================================================

  -- es set container <name>
  DarkmistsAlias.add("^es set container (.+)$", function()
    EnchanterAssist.container = matches[2]
    EnchanterAssist.save()
    DMLogger.notify(EnchanterAssist.color.."EnchanterAssist","Container set to: " .. EnchanterAssist.container)
  end)

  -- es set sleeper <name>
  DarkmistsAlias.add("^es set sleeper (.+)$", function()
    EnchanterAssist.sleeper = matches[2]
    EnchanterAssist.save()
    DMLogger.notify(EnchanterAssist.color.."EnchanterAssist","Sleeper set to: " .. EnchanterAssist.sleeper)
  end)

  -- es set sleepmode <sleep|potion>
  DarkmistsAlias.add("^es set sleepmode (sleep|potion)$", function()
    if matches[2] == "sleep" then
      EnchanterAssist.sleepType = 1
    else
      EnchanterAssist.sleepType = 0
    end
    EnchanterAssist.save()
    DMLogger.notify(EnchanterAssist.color.."EnchanterAssist","Sleep mode set to: " .. matches[2])
  end)

  -- es set potion <item>
  DarkmistsAlias.add("^es set potion (.+)$", function()
    EnchanterAssist.drainItem = matches[2]
    EnchanterAssist.save()
    DMLogger.notify(EnchanterAssist.color.."EnchanterAssist","Potion item set to: " .. EnchanterAssist.drainItem)
  end)

  -- es set order <seq|rand> (also supports deterministic/random)
  DarkmistsAlias.add("^es set order (seq|det|deterministic|rand|random)$", function()
    local mode = matches[2]
    EnchanterAssist.deterministicOrder =
      (mode == "seq" or mode == "det" or mode == "deterministic")
    EnchanterAssist._comboIndices = nil
    EnchanterAssist.save()
    DMLogger.notify(
      EnchanterAssist.color.."EnchanterAssist",
      "Order mode set to: " .. (EnchanterAssist.deterministicOrder and "seq" or "rand")
    )
  end)

  -- es enable / disable
  DarkmistsAlias.add("^es (enable|disable)$", function()
    if matches[2] == "enable" then
      EnchanterAssist.enabled = true
    else
      EnchanterAssist.enabled = false
    end
    DMLogger.notify(EnchanterAssist.color.."EnchanterAssist","Status: " .. tostring(EnchanterAssist.enabled))
  end)

  DarkmistsAlias.add("^es sound$", function()
    EnchanterAssist.playSoundOnDiscover =
      not EnchanterAssist.playSoundOnDiscover
    EnchanterAssist.save()
    DMLogger.notify(
      EnchanterAssist.color.."EnchanterAssist",
      "Play sound on discover: " ..
        tostring(EnchanterAssist.playSoundOnDiscover)
    )
  end)

end
