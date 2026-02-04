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
  name    = "Dark Mists Mudlet Bundle",
  version = "0.9.0",   -- bump manually
}

DarkmistsMeta.helpIndex = {
  dmm = {
    title = "Dark Mists",
    desc = "Central help hub for the Dark Mists Mudlet package.",
    info  = [[
Central help hub for the Dark Mists Mudlet package.

Includes:
• Feature discovery
• Version information
• Runtime status checks
    ]],
  },

  ["goto"] = {
    title   = "Map Destinations",
    command = "goto",
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
• Used by the 'goto' command for navigation
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
    keys  = { "dmm" },
  },
  {
    title = "Travel & Map",
    keys  = { "map", "goto" },
  },
  {
    title = "Interface",
    keys  = { "ch", "sb", "dmid", "who", "affects" },
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
  cecho("\n<cyan>[" .. title .. "]<white>\n")
end

local function dm_link(label, command)
  cechoLink(
    string.format("  <cornflower_blue>%-10s", label),
    function() expandAlias(command) end,
    "Click to run: " .. command,
    true
  )
end

-- =============================================================================
-- dm help
-- =============================================================================

tempAlias("^dmm help (.*)$", function()
  local key   = matches[2]
  local entry = DarkmistsMeta.helpIndex[key]

  if not entry then
    cecho("\n<red>[DM] Unknown help topic: <white>" .. key .. "\n")
    return
  end

  -- If the feature has a real command, just run it
  if entry.command then
    expandAlias(entry.command)
    return
  end

  -- Otherwise, show informational help
  dm_header(entry.title)
  cecho("<grey>" .. (entry.info or "No additional information available.") .. "\n")
end)

tempAlias("^dmm(?:\\s+help)?$", function()
  dm_header(DarkmistsMeta.meta.name)

  cecho(string.format(
    "<grey>Version: <white>%s\n\n",
    DarkmistsMeta.meta.version
  ))

  for _, section in ipairs(helpSections) do
    cecho("<cyan>" .. section.title .. ":\n")

    for _, key in ipairs(section.keys) do
      local info = DarkmistsMeta.helpIndex[key]
      if info then
        local cmd = (key == "dmm") and "dmm help" or ("dmm help " .. key)
        dm_link(key, cmd)
        cecho(" <grey>- " .. info.desc .. "\n")
      end
    end

    cecho("\n")
  end

  cecho("<grey>Click a feature or type <white>dmm help <feature>\n")
end)

-- ===================================================================
-- CHAT HISTORY (CH) COMMANDS
-- ===================================================================

tempAlias([[^ch(?:\s+(\w+))?$]], function()
  local cmd = matches[2]

  if cmd == "refresh" then
    ChatHistory.refresh()
    cecho("\n<dim_gray>[<white>ChatHistory<dim_gray>] <green>Refreshed")
  else
    cecho("\n<dim_gray>Chat History Commands:\n")
    cecho("<white>ch refresh<dim_gray> – Refresh window\n")
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
    cecho("\n<grey>[sb] <green>updated\n")
    return
  end

  if cmd == "recreate" then
    StatusBar.cleanup()
    tempTimer(0.5, function()
      StatusBar.create()
      StatusBar.registerEvents()
    end)
    cecho("\n<grey>[sb] <yellow>recreated\n")
    return
  end

  if cmd == "info" then
    cecho("\n<cyan>Status Bars:\n")

    cecho(string.format("  <white>HP Gauge:    <grey>%s\n", tostring(StatusBar.hpGauge ~= nil)))
    cecho(string.format("  <white>MN Gauge:    <grey>%s\n", tostring(StatusBar.mnGauge ~= nil)))
    cecho(string.format("  <white>MV Gauge:    <grey>%s\n", tostring(StatusBar.mvGauge ~= nil)))
    cecho(string.format("  <white>XP Gauge:    <grey>%s\n", tostring(StatusBar.xpGauge ~= nil)))
    cecho(string.format("  <white>Enemy Gauge: <grey>%s\n", tostring(StatusBar.enemyGauge ~= nil)))
    cecho(string.format("  <white>Border:      <grey>%spx\n", StatusBar.currentBorderHeight or "?"))

    if dmapi.player and dmapi.player.vitals then
      cecho("\n<cyan>Vitals:\n")
      cecho(string.format(
        "  <white>HP: <green>%d<white>/<green>%d\n",
        dmapi.player.vitals.hp or 0,
        dmapi.player.vitals.hpMax or 0
      ))
      cecho(string.format(
        "  <white>MN: <green>%d<white>/<green>%d\n",
        dmapi.player.vitals.mn or 0,
        dmapi.player.vitals.mnMax or 0
      ))
      cecho(string.format(
        "  <white>MV: <green>%d<white>/<green>%d\n",
        dmapi.player.vitals.mv or 0,
        dmapi.player.vitals.mvMax or 0
      ))
    end

    if dmapi.player and dmapi.player.combat then
      cecho("\n<cyan>Combat:\n")
      cecho(string.format(
        "  <white>In Combat: <grey>%s\n",
        tostring(dmapi.player.combat.active or false)
      ))
      if dmapi.player.combat.target then
        cecho("  <white>Target: <red>" .. tostring(dmapi.player.combat.target) .. "\n")
      end
    end

    return
  end

  -- default / help
  cecho("\n<cyan>Status Bar Commands:\n")
  cecho("  <white>sb show      <grey>- show all bars\n")
  cecho("  <white>sb hide      <grey>- hide all bars\n")
  cecho("  <white>sb toggle    <grey>- toggle visibility\n")
  cecho("  <white>sb update    <grey>- force refresh\n")
  cecho("  <white>sb recreate  <grey>- rebuild UI\n")
  cecho("  <white>sb info      <grey>- debug information\n")
end)


-- ============================================================================
-- ITEM TRACKER Command Aliases
-- ============================================================================

-- Main help command
tempAlias(string.format("^%s$", ItemTracker.settings.alias), function()
  local alias = ItemTracker.settings.alias
  
  cecho(string.format(
    "\n<light_goldenrod>[%s v%s by %s]<white>\n",
    ItemTracker.name,
    ItemTracker.version,
    ItemTracker.author
  ))
  cecho("<grey>Clickable item identification & lookup system\n\n")

  cecho("<white>Usage:\n")
  cecho(string.format("  <cyan>%s <white><item name or partial>\n\n", alias))

  cecho("<white>Examples:\n")
  cecho(string.format("  <cyan>%s bracelet<white>                – search for items containing 'bracelet'\n", alias))
  cecho(string.format("  <cyan>%s an oversized lumber axe<white> – exact name lookup\n\n", alias))

  cecho("<white>Area search:\n")
  cecho(string.format("  <cyan>%s area <white><area name or partial>\n\n", alias))

  cecho("<white>In-game interaction:\n")
  cecho("  <cyan>• Click an item name<white>       – show tooltip near your cursor\n")
  cecho("  <cyan>• Shift + Click<white>            – print full item details to chat\n")
  cecho("  <cyan>• Click anywhere else<white>      – close the tooltip\n\n")

  cecho("<white>Detection rules:\n")
  cecho("  <grey>• Only matches item names at the END of a line\n")
  cecho("  <grey>• Longest names are matched first\n")
  cecho("  <grey>• Prevents false matches (e.g. 'egg' in 'leggings')\n\n")

  cecho("<white>Notes:\n")
  cecho("  <grey>• Duplicate item names are supported and shown together\n")
  cecho("  <grey>• Tooltip size auto-adjusts to item details\n")
  cecho("  <grey>• Tooltip avoids covering status bars at bottom\n")
  cecho("  <grey>• Colors and layout can be customized in ItemTracker.settings\n\n")
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
    "\n<light_goldenrod>[ID] Items in area matching '%s' (%d):<white>\n",
    query,
    #results
  ))

  for i, item in ipairs(results) do
    cecho(string.format("   <white>%d) ", i))
    local areaTag = item.area and ("[" .. item.area .. "] ") or ""
    cechoLink(
      "<grey>" .. areaTag .. "<white>" ..
      ItemTracker.settings.itemLinkColor .. item.name .. "<white>\n",
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
  cecho("<light_goldenrod>[ID] Multiple matches:<white>\n")
  for i, item in ipairs(results) do
    cecho(string.format("   <white>%d) ", i))
    cechoLink(
      ItemTracker.settings.itemLinkColor .. item.name .. "<white>\n",
      function() ItemTracker.handleClick(item.name) end,
      "Click: tooltip | Shift+Click: full identify",
      true
    )
  end
  cecho("<light_goldenrod>Refine your search.<white>\n")
end)

-- =============================================================================
-- goto COMMAND
-- =============================================================================
tempAlias("^goto(?:\\s+(.*))?$", function()
  local arg = matches[2] and matches[2]:trim() or ""

  -- HELP
  if arg == "" then
    cecho([[
<cyan>[MAP] goto command usage:
  <white>goto <name>
    <gray>Navigate to a saved destination

  <white>goto list
    <gray>Show all saved destinations

  <white>goto add <name> <roomid>
    <gray>Add a persistent destination

  <white>goto rem <name>
    <gray>Remove a destination (persistent)

  <white>goto area <name>
    <gray>Navigate to the first room of a matching area
]])
    return
  end

  -- LIST (grouped by area)
  if arg == "list" then
    cecho("\n<cyan>[MAP] Destinations by Area:\n")

    if not next(MapDestinations.list) then
      cecho("  <gray>(none)\n")
      return
    end

    local grouped = MapDestinations.getDestinationsGroupedByArea()
    local areaNames = {}

    for areaName in pairs(grouped) do
      table.insert(areaNames, areaName)
    end
    table.sort(areaNames)

    for _, areaName in ipairs(areaNames) do
      for _, entry in ipairs(grouped[areaName]) do
        cecho(string.format(
          "<yellow>[%-16s] <white>%-16s <gray>→ room <white>%d\n",
          DMUtil.cap(areaName, 16),
          DMUtil.cap(entry.name, 16),
          entry.room
        ))
      end
    end
    return
  end

  -- ADD
  do
    local name, room = arg:match("^add%s+([%w_]+)%s+(%d+)$")
    if name and room then
      name = name:lower()
      MapDestinations.add(name, room)
      MapDestinations.rewrite()
      cecho(string.format(
        "\n<green>[MAP] Added destination <white>%s<green> → room <white>%s\n",
        name, room
      ))
      return
    end
  end

  -- REMOVE
  do
    local rem = arg:match("^rem%s+([%w_]+)$")
    if rem then
      rem = rem:lower()
      if not MapDestinations.list[rem] then
        cecho("\n<red>[MAP] No destination named <white>" .. rem .. "\n")
        return
      end
      MapDestinations.list[rem] = nil
      MapDestinations.rewrite()
      cecho("\n<yellow>[MAP] Removed destination <white>" .. rem .. "\n")
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
          cecho(("\n<green>[MAP] Found area <white>%s\n"):format(name))
          local rooms = getAreaRooms(id)
          local firstRoom = rooms and rooms[0]
          if firstRoom then
            gotoRoom(firstRoom)
          else
            cecho("<yellow>[MAP] Area has no rooms indexed\n")
          end
          return
        end
      end

      cecho("\n<red>[MAP] No area matching <white>" .. areaSearch .. "\n")
      return
    end
  end

  -- NAVIGATE TO SAVED DESTINATION
  local dest = MapDestinations.list[arg:lower()]
  if not dest then
    cecho("\n<red>[MAP] Unknown destination. Type <white>goto<red> for help.\n")
    return
  end

  local current = getPlayerRoom()
  if not current then
    cecho("<red>[MAP] Current room unknown\n")
    return
  end

  cecho(("<cyan>[MAP] Generating Path: <white>%s<gray> (room %d)\n")
    :format(arg, dest))

  local ok = getPath(current, dest)
  if not ok or not speedWalkDir or #speedWalkDir == 0 then
    cecho("<yellow>[MAP] No known path for that destination\n")
    return
  end

  gotoRoom(dest)
end)

--- DM MUDLET PACKAGE FEATURES
---
--- This package is designed to enhance and modernize the Dark Mists
--- play experience through improved visual clarity and convenience,
--- while preserving the core text-based nature of the game.
---
--- Features focus on awareness and readability rather than automation,
--- and intentionally avoid PvP advantages or gameplay decision-making.
--- 
--- CHAT HISTORY
--- - Separate console window with communication channels
--- - Supported Channels: say, tell, gtell, yell, ooc, house talk
--- - Not Supported: brandtalk, any others
--- 
--- WHO WINDOW
--- - Contains most recent list from "who" command
--- - Conveniently see who is online without scrolling up/down
--- - Refreshes when "who" output detected
--- 
--- AFFECTS WINDOW
--- - Contains most recent list from "affects" or "score" command
--- - Updates roughly equivalent to game time. 
--- - Provides more awareness around when buffs are expired / will expire
--- 
--- STATUS BARS
--- - Monitor HP / MANA / MOVES with real-time updating bars
--- - Also includes HP bar for Current Enemy
--- - XP Bar (needs "prompt tnl" enabled to work properly)
--- - Should work with all class prompts, even Berserker, although there is no bar for Rage (yet)
--- 
--- ITEM TRACKER
--- - Brings the Website Item lookup into the game
--- - View item base stats with a click
--- - Supported: Your Equipment, Other Players, NPCs, Looting, Inventory, Containers, Shops
--- - Not Supported: Ground Items
--- 
--- FULLY INTERACTABLE COLORED MAP W/ ROUGHLY 15K ROOMS MAPPED
--- - Uses Mudlet's built in mapping system to detect your location in game
--- - Mudlet map areas that correspond with game areas
--- - Maps can be viewed even offline
--- 
--- MAP DESTINATIONS
--- - Named, persistent navigation using Mudlet pathfinding.
--- - Save room locations as keywords and walk there with a commmand
--- - For Example "goto gms" might walk you to Glyndane Market Square
--- - "goto area <area name>" is also partially supported, although entry point is not guaranteed.
--- 
--- CLICKABLE TEXT
--- - Room Directions
--- - Quest Command
--- - Practices
--- - Training
--- - Auction House
--- 
--- STAT ROLLER
--- - For Maximizing Stats during character creation
---
----- PLANS FOR FUTURE RELEASE
---
--- CHAT HISTORY
--- - Clickable Names
--- - Example, Clicking Ultharys in [OOC] to Ultharys: test would yield a prompt input of "ooc Ultharys "
--- - this makes it so that the user can continue a conversation quickly from the Chat History Window
--- 
--- WHO WINDOW
--- - Compact View
--- 
--- STATUS BARS
--- - Rage Bar for Berserkers
--- - Thirst / Hunger Indicators
--- - Gold / Silver Display
--- 
--- MAP DESTINATIONS
--- - Better "goto area" logic