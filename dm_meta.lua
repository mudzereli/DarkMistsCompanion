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
    desc = "Central help hub for the Dark Mists Mudlet package.",
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
    keys  = { "ch", "sb", "dmid", "who", "affects" },
  },
  {
    title = "Travel & Map",
    keys  = { "map", "walk" },
  },
  {
    title = "Character",
    keys  = { "skillups", "statroll" },
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

-- =============================================================================
-- dm help
-- =============================================================================

tempAlias("^dmc help (.*)$", function()
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

tempAlias("^dmc(?:\\s+help)?$", function()
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
        dm_link(("  %s [%s]"):format(info.title,key), cmd)
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

tempAlias([[^ch(?:\s+(\w+))?$]], function()
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

tempAlias([[^sb(?:\s+(\w+))?$]], function()
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

-- Main help command
tempAlias(string.format("^%s$", ItemTracker.settings.alias), function()
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
tempAlias("^" .. ItemTracker.settings.alias .. "\\s+area\\s+(.*)$", function()
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
tempAlias(string.format("^%s\\s+(.+)$", ItemTracker.settings.alias), function()
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

-- =============================================================================
-- walk COMMAND
-- =============================================================================
tempAlias("^walk(?:\\s+(.*))?$", function()
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
    expandAlias("map stop")
    Darkmists.Log("WALK","<red>Walking Stopped!")
    return
  end

  -- LIST (grouped by area)
  local listFilter = arg:match("^list%s+(%S+)$")
  if arg == "list" or listFilter then
    Darkmists.Log("WALK","Destinations by Area:")
    if not next(MapDestinations.list) then
      cecho("\n  <dim_gray>(none)")
      return
    end

    local grouped = MapDestinations.getDestinationsGroupedByArea()
    local filter = listFilter and listFilter:lower()

    local areaNames = {}

    for areaName in pairs(grouped) do
      table.insert(areaNames, areaName)
    end
    table.sort(areaNames)

    for _, areaName in ipairs(areaNames) do
      for _, entry in ipairs(grouped[areaName]) do
        local roomName = getRoomName(entry.room) or "UNKNOWN"
        local areaMatchName = getRoomAreaName(getRoomArea(entry.room)) or areaName

        local show = true
        if filter then
          local rn = roomName:lower()
          local an = areaMatchName:lower()
          local en = (entry.name):lower()
          show = (rn:find(filter, 1, true) ~= nil)
              or (an:find(filter, 1, true) ~= nil)
              or (en:find(filter, 1, true) ~= nil)
        end

        if show then
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

    return
  end

  -- ADD
  do
    local name = arg:match("^add%s+([%w_]+)$")
    if name then
      name = name:lower()
      if name then
        if map and map.currentRoom then
          local room = map.currentRoom
          local roomName = getRoomName(room)
          if not roomName then 
            roomName = "UNKNOWN"
          end
          MapDestinations.add(name, room)
          MapDestinations.rewrite()
          Darkmists.Log("WALK",("Added destination: %s%s<green> → <dim_gray>[%s%d<dim_gray>] %s%s"):format(c,name,c,room,c,roomName))
        else
          Darkmists.Log("WALK","<red>No Current Room found on Map")
        end
      end
      return
    end
    
    local name, room = arg:match("^add%s+([%w_]+)%s+(%d+)$")
    if name and room then
      name = name:lower()
      local roomName = getRoomName(room)
      if not roomName then 
        roomName = "UNKNOWN"
      end
      MapDestinations.add(name, room)
      MapDestinations.rewrite()
      Darkmists.Log("WALK",("Added destination: %s%s<green> → <dim_gray>[%s%d<dim_gray>] %s%s"):format(c,name,c,room,c,roomName))
      return
    end
  end

  -- REMOVE
  do
    local rem = arg:match("^rem%s+([%w_]+)$")
    if rem then
      rem = rem:lower()
      if not MapDestinations.list[rem] then
        Darkmists.Log("WALK",("<red>No destination named %s%s"):format(c,rem))
        return
      end
      MapDestinations.list[rem] = nil
      MapDestinations.rewrite()
      Darkmists.Log("WALK",("<dark_khaki>Removed destination %s%s"):format(c,rem))
      return
    end
  end

  -- AREA SEARCH (accepts underscores, case-insensitive)
  do
    local areaSearch = arg:match("^area%s+([%w_]+)$")
    if areaSearch then
      areaSearch = areaSearch:lower()
      
      for name, id in pairs(getAreaTable()) do
        if name:lower():find(areaSearch, 1, true) then
          Darkmists.Log("WALK",("Found area %s%s"):format(c,name))
          local rooms = getAreaRooms(id)
          local firstRoom = rooms and rooms[0]
          if firstRoom then
            gotoRoom(firstRoom)
          else
          Darkmists.Log("WALK","<red>Area has no rooms indexed.")
          end
          return
        end
      end

      Darkmists.Log("WALK",("<red>No area matching %s%s"):format(c,areaSearch))
      return
    end
  end

  -- NAVIGATE TO SAVED DESTINATION
  local dest = MapDestinations.list[arg:lower()]
  if not dest then
    Darkmists.Log("WALK",("<red>Unknown destination. Type %swalk <red>for help."):format(c))
    return
  end

  local current = getPlayerRoom()
  if not current then
    Darkmists.Log("WALK","<red>Current Room Unknown!")
    return
  end

  if dest == current then
    Darkmists.Log("WALK","<red>You are already there!")
    return
  end

  local roomName = getRoomName(dest)

  local ok = getPath(current, dest)
  if not ok or not speedWalkDir or #speedWalkDir == 0 or not dest or not roomName then
    Darkmists.Log("WALK","<red>No known path for that destination!")
    return
  end

  Darkmists.Log("WALK",("<ansi_cyan>Generating Path to %s%s <dim_gray>[%s%d<dim_gray>] %s%s"):format(c,arg,c,dest,c,roomName))
  gotoRoom(dest)
end)