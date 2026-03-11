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

DarkmistsMeta = DarkmistsMeta or {}

DarkmistsMeta.meta = {
  name    = Darkmists.NAME,
  version = Darkmists.VERSION,
}

DarkmistsMeta.colors = {
  default = Darkmists.getDefaultTextColorTag(),
  header = "<ansi_cyan>",
  link = "<cornflower_blue>"
}

DarkmistsMeta.helpIndex = {
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
    command = ItemTracker.settings.alias,
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
}

local helpSections = {
  {
    title = "Meta",
    keys  = { "dmc" },
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
}

-- =============================================================================
-- OUTPUT HELPERS (local to this file)
-- =============================================================================

-- Section header
local function dm_header(title)
  cecho("\n"..DarkmistsMeta.colors.header.."[" .. title .. "]"..DarkmistsMeta.colors.default.."\n")
end

local function dm_link(label, command)
  cechoLink(
    string.format(DarkmistsMeta.colors.link.."%-10s", label),
    function() expandAlias(command) end,
    "Click to run: " .. command,
    true
  )
end

-- ===================================================================
-- UI MODE COMMANDS
-- ===================================================================

DarkmistsAlias.add([[^dmc\s+ui(?:\s+(on|off))?$]], function()
  local state = matches[2]

  -- Explicit ON
  if state == "on" then
    if not Darkmists.GlobalSettings.minimalMode then
      cecho("\n<dim_gray>[UI] "..DarkmistsMeta.colors.default.."Already in <green>FULL UI<dim_gray> mode.\n")
      return
    end

    cecho("\n<dim_gray>[UI] "..DarkmistsMeta.colors.default.."Enabling <green>FULL UI<dim_gray> mode...\n")
    Darkmists.EnableUI()
    return
  end

  -- Explicit OFF
  if state == "off" then
    if Darkmists.GlobalSettings.minimalMode then
      cecho("\n<dim_gray>[UI] "..DarkmistsMeta.colors.default.."Already in <yellow>MINIMAL UI<dim_gray> mode.\n")
      return
    end

    cecho("\n<dim_gray>[UI] "..DarkmistsMeta.colors.default.."Switching to <yellow>MINIMAL UI<dim_gray> mode...\n")
    Darkmists.DisableUI()
    return
  end

  -- Toggle
  if Darkmists.GlobalSettings.minimalMode then
    cecho("\n<dim_gray>[UI] "..DarkmistsMeta.colors.default.."Enabling <green>FULL UI<dim_gray> mode...\n")
    Darkmists.EnableUI()
  else
    cecho("\n<dim_gray>[UI] "..DarkmistsMeta.colors.default.."Switching to <yellow>MINIMAL UI<dim_gray> mode...\n")
    Darkmists.DisableUI()
  end
end)

-- =============================================================================
-- dm help
-- =============================================================================

DarkmistsAlias.add("^dmc help (.*)$", function()
  local key   = matches[2]
  local entry = DarkmistsMeta.helpIndex[key]

  if not entry then
    cecho("\n<red>[DM] Unknown help topic: "..DarkmistsMeta.colors.default .. key .. "\n")
    return
  end

  -- If the feature has a real command, just run it
  if entry.command then
    expandAlias(entry.command)
    return
  end

  -- Otherwise, show informational help
  dm_header(entry.title)
  cecho("<dim_gray>" .. (entry.info or "No additional information available.") .. "\n")
end)

DarkmistsAlias.add("^dmc(?:\\s+help)?$", function()
  dm_header(DarkmistsMeta.meta.name)

  cecho(string.format(
    "<dim_gray>Version: "..DarkmistsMeta.colors.default.."%s\n\n",
    DarkmistsMeta.meta.version
  ))

  for _, section in ipairs(helpSections) do
    cecho(DarkmistsMeta.colors.header .. section.title .. ":\n")

    for _, key in ipairs(section.keys) do
      local info = DarkmistsMeta.helpIndex[key]
      if info then
        local cmd = (key == "dmc") and "dmc help" or ("dmc help " .. key)
        dm_link(("  <u>%s [%s]</u>"):format(info.title,key), cmd)
        cecho("\n<dim_gray>    " .. info.desc .. "\n")
      end
    end

    cecho("\n")
  end

  cecho("<dim_gray>Click a feature or type <dim_gray>dmc help <feature>\n")
end)

-- ===================================================================
-- CHAT HISTORY (CH) COMMANDS
-- ===================================================================

DarkmistsAlias.add([[^ch(?:\s+(\w+))?$]], function()
  local cmd = matches[2]

  if cmd == "refresh" then
    ChatHistory.refresh()
    cecho("\n<dim_gray>["..DarkmistsMeta.colors.default.."ChatHistory<dim_gray>] <green>Refreshed")
  else
    cecho("\n<ansi_cyan>Chat History Commands:\n")
    cecho(DarkmistsMeta.colors.default.."ch refresh<dim_gray> – Refresh window\n")
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
    cecho("\n<dim_grey>[sb] <green>updated\n")
    return
  end

  if cmd == "recreate" then
    StatusBar.recreate()
    return
  end

  if cmd == "info" then
    cecho("\n<ansi_cyan>Status Bars:\n")

    cecho(string.format("  "..DarkmistsMeta.colors.default.."HP Gauge:    <dim_grey>%s\n", tostring(StatusBar.hpGauge ~= nil)))
    cecho(string.format("  "..DarkmistsMeta.colors.default.."MN Gauge:    <dim_grey>%s\n", tostring(StatusBar.mnGauge ~= nil)))
    cecho(string.format("  "..DarkmistsMeta.colors.default.."MV Gauge:    <dim_grey>%s\n", tostring(StatusBar.mvGauge ~= nil)))
    cecho(string.format("  "..DarkmistsMeta.colors.default.."XP Gauge:    <dim_grey>%s\n", tostring(StatusBar.xpGauge ~= nil)))
    cecho(string.format("  "..DarkmistsMeta.colors.default.."Enemy Gauge: <dim_grey>%s\n", tostring(StatusBar.enemyGauge ~= nil)))
    cecho(string.format("  "..DarkmistsMeta.colors.default.."Border:      <dim_grey>%spx\n", StatusBar.currentBorderHeight or "?"))

    if dmapi.player and dmapi.player.vitals then
      cecho("\n<ansi_cyan>Vitals:\n")
      cecho(string.format(
        "  "..DarkmistsMeta.colors.default.."HP: <green>%d"..DarkmistsMeta.colors.default.."/<green>%d\n",
        dmapi.player.vitals.hp or 0,
        dmapi.player.vitals.hpMax or 0
      ))
      cecho(string.format(
        "  "..DarkmistsMeta.colors.default.."MN: <green>%d"..DarkmistsMeta.colors.default.."/<green>%d\n",
        dmapi.player.vitals.mn or 0,
        dmapi.player.vitals.mnMax or 0
      ))
      cecho(string.format(
        "  "..DarkmistsMeta.colors.default.."MV: <green>%d"..DarkmistsMeta.colors.default.."/<green>%d\n",
        dmapi.player.vitals.mv or 0,
        dmapi.player.vitals.mvMax or 0
      ))
    end

    if dmapi.player and dmapi.player.combat then
      cecho("\n<ansi_cyan>Combat:\n")
      cecho(string.format(
        "  "..DarkmistsMeta.colors.default.."In Combat: <dim_grey>%s\n",
        tostring(dmapi.player.combat.active or false)
      ))
      if dmapi.player.combat.target then
        cecho("  "..DarkmistsMeta.colors.default.."Target: <red>" .. tostring(dmapi.player.combat.target) .. "\n")
      end
    end

    return
  end

  -- default / help
  cecho("\n<ansi_cyan>Status Bar Commands:\n")
  cecho("  "..DarkmistsMeta.colors.default.."sb show      <dim_grey>- show all bars\n")
  cecho("  "..DarkmistsMeta.colors.default.."sb hide      <dim_grey>- hide all bars\n")
  cecho("  "..DarkmistsMeta.colors.default.."sb toggle    <dim_grey>- toggle visibility\n")
  cecho("  "..DarkmistsMeta.colors.default.."sb update    <dim_grey>- force refresh\n")
  cecho("  "..DarkmistsMeta.colors.default.."sb recreate  <dim_grey>- rebuild UI\n")
  cecho("  "..DarkmistsMeta.colors.default.."sb info      <dim_grey>- debug information\n")
end)

-- ============================================================================
-- ITEM TRACKER Command Aliases
-- ============================================================================

do
  -- Main help command
  DarkmistsAlias.add(string.format("^%s$", ItemTracker.settings.alias), function()
    local alias = ItemTracker.settings.alias
    
    cecho("\n<ansi_cyan>Item Tracker Commands:\n")
    cecho("<dim_grey>Clickable item identification & lookup system\n\n")

    cecho(DarkmistsMeta.colors.default.."Usage:\n")
    cecho(string.format("  <ansi_cyan>%s "..DarkmistsMeta.colors.default.."<item name or partial>\n\n", alias))

    cecho(DarkmistsMeta.colors.default.."Examples:\n")
    cecho(string.format("  <ansi_cyan>%s bracelet"..DarkmistsMeta.colors.default.."                – search for items containing 'bracelet'\n", alias))
    cecho(string.format("  <ansi_cyan>%s an oversized lumber axe"..DarkmistsMeta.colors.default.." – exact name lookup\n\n", alias))

    cecho(DarkmistsMeta.colors.default.."Area search:\n")
    cecho(string.format("  <ansi_cyan>%s area "..DarkmistsMeta.colors.default.."<area name or partial>\n\n", alias))

    cecho(DarkmistsMeta.colors.default.."In-game interaction:\n")
    cecho("  <ansi_cyan>• Click an item name"..DarkmistsMeta.colors.default.."       – show tooltip near your cursor\n")
    cecho("  <ansi_cyan>• Shift + Click"..DarkmistsMeta.colors.default.."            – print full item details to chat\n")
    cecho("  <ansi_cyan>• Click anywhere else"..DarkmistsMeta.colors.default.."      – close the tooltip\n\n")

    cecho(DarkmistsMeta.colors.default.."Detection rules:\n")
    cecho("  <dim_grey>• Only matches item names at the END of a line\n")
    cecho("  <dim_grey>• Longest names are matched first\n")
    cecho("  <dim_grey>• Prevents false matches (e.g. 'egg' in 'leggings')\n\n")

    cecho(DarkmistsMeta.colors.default.."Notes:\n")
    cecho("  <dim_grey>• Duplicate item names are supported and shown together\n")
    cecho("  <dim_grey>• Tooltip size auto-adjusts to item details\n")
    cecho("  <dim_grey>• Tooltip avoids covering status bars at bottom\n")
    cecho("  <dim_grey>• Colors and layout can be customized in ItemTracker.settings\n\n")
  end)

  -- Area search command
  DarkmistsAlias.add("^" .. ItemTracker.settings.alias .. "\\s+area\\s+(.*)$", function()
    local query = matches[2]
    local results = ItemTracker.listByArea(query)

    if not results or #results == 0 then
      cecho("<red>[ID] No items found for area: " .. query .. "\n")
      return
    end

    cecho(string.format(
      "\n<light_goldenrod>[ID] Items in area matching '%s' (%d):"..DarkmistsMeta.colors.default.."\n",
      query,
      #results
    ))

    for i, item in ipairs(results) do
      cecho(string.format("   "..DarkmistsMeta.colors.default.."%d) ", i))
      local areaTag = item.area and ("[" .. item.area .. "] ") or ""
      cechoLink(
        "<dim_grey>" .. areaTag .. DarkmistsMeta.colors.default ..
        ItemTracker.settings.itemLinkColor .. item.name .. DarkmistsMeta.colors.default.."\n",
        function() ItemTracker.handleClick(item.name) end,
        "Click: tooltip | Shift+Click: full identify",
        true
      )
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
      cecho("<red>[ID] No items found for: " .. query .. "\n")
      return
    end

    -- Single match: show immediately
    if #results == 1 then
      ItemTracker.show(results[1])
      return
    end

    -- Multiple matches: show clickable list
    cecho("<light_goldenrod>[ID] Multiple matches:"..DarkmistsMeta.colors.default.."\n")
    for i, item in ipairs(results) do
      cecho(string.format("   "..DarkmistsMeta.colors.default.."%d) ", i))
      cechoLink(
        ItemTracker.settings.itemLinkColor .. item.name .. DarkmistsMeta.colors.default.."\n",
        function() ItemTracker.handleClick(item.name) end,
        "Click: tooltip | Shift+Click: full identify",
        true
      )
    end
    cecho("<light_goldenrod>Refine your search."..DarkmistsMeta.colors.default.."\n")
  end)
end

-- =============================================================================
-- WALK COMMAND
-- =============================================================================
local function renderWalkList(filter)
  local c = DarkmistsMeta.colors.default

  Darkmists.Log("WALK","Destinations by Area:")

  local grouped = MapDestinations.getGroupedFiltered(filter)
  if not next(grouped) then
    cecho("\n  <dim_gray>(none)")
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

      cechoLink(string.format(
        "\n<dark_khaki>[%s%-16s<dark_khaki>] %s%-23s <dim_gray>→ <dim_gray>[%s%5d<dim_gray>] %s%-32s",
        c,
        DMUtil.cap(areaName, 16),
        c,
        ("<u>%s</u>"):format(DMUtil.cap(entry.name, 16)),
        c,
        entry.room,
        c,
        DMUtil.cap(roomName,32)
      ),
      function()
        expandAlias(("walk %s"):format(entry.name))
      end,
      ("Click: walk %s"):format(entry.name),
      true)
    end
  end
end

DarkmistsAlias.add("^walk(?:\\s+(.*))?$", function()
  local c = DarkmistsMeta.colors.default
  local arg = matches[2] and matches[2]:trim() or ""

  -- HELP
  if arg == "" then
    cecho([[
<ansi_cyan>Walk Module:
    <dim_gray>The Walk module enables speedwalking between two known rooms 
    using the default map speedwalk system. Both the starting room and 
    destination must already be discovered, and the route must be clear. Paths 
    that require traversing mazes are not supported.

<ansi_cyan>Walk Commands:
  ]]..c..[[walk <name>
    <dim_gray>Navigate to a saved destination

  ]]..c..[[walk list <filter: optional>
    <dim_gray>Show all saved destinations. A filter argument can
    be supplied to further refine the results.

  ]]..c..[[walk add <name> <roomid: optional>
    <dim_gray>Add a persistent destination. If room id is omitted
    then the current room is used (if known).

  ]]..c..[[walk rem <name>
    <dim_gray>Permanently remove a destination.

  ]]..c..[[walk area <name>
    <dim_gray>Navigate to the first room of a matching area.

  ]]..c..[[walk stop
    <dim_gray>Cancel a walk that is currently in progress.
]])
    return
  end

  if arg == "stop" then
    MapDestinations.stop()
    Darkmists.Log("WALK","<red>Walking Stopped!")
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
          Darkmists.Log("WALK","<red>No Current Room found on Map")
        elseif a == "INVALID_NAME" then
          Darkmists.Log("WALK","<red>Invalid destination name")
        end
        return
      end

      local destName, roomId = a, b

      Darkmists.Log("WALK",
        ("Added destination: %s%s<green> → <dim_gray>[%s%d<dim_gray>] %s%s")
          :format(c, destName, c, roomId, c, cRoomName)
      )

      return
    end
    
    local name, room = arg:match("^add%s+([%w_]+)%s+(%S+)$")
    if name and room then
      local ok, a, b, roomName = MapDestinations.addDestination(name, room)

      if not ok then
        if a == "INVALID_NAME" then
          Darkmists.Log("WALK","<red>Invalid destination name")
        elseif a == "INVALID_ROOM" then
          Darkmists.Log("WALK","<red>Invalid room id")
        elseif a == "ROOM_MISSING" then
          Darkmists.Log("WALK",
            ("<red>Room does not exist: <white>%s%d"):format(c, b)
          )
        end
        return
      end

      local destName, roomId = a, b

      Darkmists.Log("WALK",
        ("Added destination: %s%s<green> → <dim_gray>[%s%d<dim_gray>] %s%s")
          :format(c, destName, c, roomId, c, roomName)
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
        Darkmists.Log("WALK",
          ("<red>No destination named %s%s"):format(c, data)
        )
      end
    else
      Darkmists.Log("WALK",
        ("<dark_khaki>Removed destination %s%s"):format(c, data)
      )
    end
    return
  end

  -- AREA SEARCH (accepts underscores, case-insensitive)
  do
    local areaSearch = arg:match("^area%s+([%w_]+)$")
    if areaSearch then
      local ok, code, data = MapDestinations.navigateToArea(areaSearch)

      if not ok then
        if code == "ALREADY_IN_AREA" then
          Darkmists.Log("WALK",
            ("<dark_khaki>You are already in %s%s"):format(c, data)
          )
        elseif code == "AREA_NOT_FOUND" then
          Darkmists.Log("WALK",
            ("<red>No area matching %s%s"):format(c, data)
          )
        elseif code == "AREA_EMPTY" then
          Darkmists.Log("WALK",
            ("<red>Area has no indexed rooms: %s%s"):format(c, data)
          )
        elseif code == "INVALID_SEARCH" then
          Darkmists.Log("WALK","<red>Invalid area search.")
        elseif code == "NO_AREAS" then
          Darkmists.Log("WALK","<red>Area table unavailable.")
        elseif code == "NO_CURRENT_ROOM" then
          Darkmists.Log("WALK","<red>Current room unknown!")
        elseif code == "NO_PATH" then
          Darkmists.Log("WALK",("<red>No known path to area %s%s"):format(c, data))
        end
        return
      end

      Darkmists.Log("WALK",
        ("<ansi_cyan>Walking to area %s%s <dim_gray>[%s%d<dim_gray>]")
          :format(c, data, c, code)
      )
      return
    end
  end

  -- NAVIGATE TO SAVED DESTINATION
  local ok, a, b = MapDestinations.navigate(arg)

  if not ok then
    if a == "NOT_FOUND" then
      Darkmists.Log("WALK",
        ("<red>No destination named %s%s"):format(c, b)
      )
    elseif a == "INVALID_NAME" then
      Darkmists.Log("WALK","<red>Invalid name given!")
    elseif a == "NO_CURRENT_ROOM" then
      Darkmists.Log("WALK","<red>Current room unknown!")
    elseif a == "ALREADY_THERE" then
      Darkmists.Log("WALK",
        ("<red>You are already at %s%s"):format(c, b)
      )
    elseif a == "ROOM_MISSING" then
      Darkmists.Log("WALK",
        ("<red>Destination room no longer exists for %s%s"):format(c, b)
      )
    elseif a == "NO_PATH" then
      Darkmists.Log("WALK",
        ("<red>No known path to %s%s"):format(c, b)
      )
    end
    return
  end

  Darkmists.Log("WALK",
    ("<ansi_cyan>Generating path to %s%s <dim_gray>[%s%d<dim_gray>] %s%s")
      :format(c, arg, c, a, c, b)
  )
end)

-- =============================================================================
-- ENCHANTER ASSIST (ES) COMMAND
-- =============================================================================
DarkmistsAlias.add("^es(?:\\s+(.*))?$", function()
  local c = DarkmistsMeta.colors.default
  local arg = matches[2] and matches[2]:trim() or ""

  -- HELP
  if arg == "" or arg == "help" then
    cecho([[
<ansi_cyan>EnchanterAssist Module:
    <dim_gray>Automation helper for enchantment workflow management.
    Controls resting, part counts, and execution flow.

<ansi_cyan>EA Module Commands:
  ]]..c..[[es run
    <dim_gray>Execute a single enchantment cycle.

  ]]..c..[[es auto
    <dim_gray>Toggle automatic running mode.

  ]]..c..[[es 1-5
    <dim_gray>Set enchantment part count (1–5),
    save configuration, and immediately run.

  ]]..c..[[es stats
    <dim_gray>Display current session statistics.

  ]]..c..[[es missing
    <dim_gray>Display missing material statistics.

  ]]..c..[[es reset
    <dim_gray>Reset session statistics.

<ansi_cyan>Configuration Commands:
  ]]..c..[[es set container <name>
    <dim_gray>Set container holding enchantment items.

  ]]..c..[[es set sleeper <name>
    <dim_gray>Set sleeper target.

  ]]..c..[[es set sleepmode <sleep|potion>
    <dim_gray>Choose restoration behavior type.

  ]]..c..[[es set potion <item>
    <dim_gray>Set item used for quaffing.

  ]]..c..[[es sound
    <dim_gray>Toggle formula discovery sound

<ansi_cyan>Control:
  ]]..c..[[es enable
  ]]..c..[[es disable
    <dim_gray>Enable or disable EnchanterAssist entirely.
]])
    return
  end
end)

DarkmistsAlias.add("^es run$", function() EnchanterAssist.run() end)

DarkmistsAlias.add("^es auto$", function()
  EnchanterAssist.autoRun = not EnchanterAssist.autoRun
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","AutoRun: " .. tostring(EnchanterAssist.autoRun))
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
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Container set to: " .. EnchanterAssist.container)
end)

-- es set sleeper <name>
DarkmistsAlias.add("^es set sleeper (.+)$", function()
  EnchanterAssist.sleeper = matches[2]
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Sleeper set to: " .. EnchanterAssist.sleeper)
end)

-- es set sleepmode <sleep|potion>
DarkmistsAlias.add("^es set sleepmode (sleep|potion)$", function()
  if matches[2] == "sleep" then
    EnchanterAssist.sleepType = 1
  else
    EnchanterAssist.sleepType = 0
  end
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Sleep mode set to: " .. matches[2])
end)

-- es set potion <item>
DarkmistsAlias.add("^es set potion (.+)$", function()
  EnchanterAssist.drainItem = matches[2]
  EnchanterAssist.save()
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Potion item set to: " .. EnchanterAssist.drainItem)
end)

-- es enable / disable
DarkmistsAlias.add("^es (enable|disable)$", function()
  if matches[2] == "enable" then
    EnchanterAssist.enabled = true
  else
    EnchanterAssist.enabled = false
  end
  Darkmists.Log(EnchanterAssist.color.."EnchanterAssist","Status: " .. tostring(EnchanterAssist.enabled))
end)

DarkmistsAlias.add("^es sound$", function()
  EnchanterAssist.playSoundOnDiscover =
    not EnchanterAssist.playSoundOnDiscover
  EnchanterAssist.save()
  Darkmists.Log(
    EnchanterAssist.color.."EnchanterAssist",
    "Play sound on discover: " ..
      tostring(EnchanterAssist.playSoundOnDiscover)
  )
end)