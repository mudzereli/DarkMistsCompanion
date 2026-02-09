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
    StatusBar.cleanup()
    tempTimer(0.5, function()
      StatusBar.create()
      StatusBar.registerEvents()
    end)
    cecho("\n<dim_grey>[sb] <dark_khaki>recreated\n")
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
  local arg = matches[2] and matches[2]:trim() or ""

  -- HELP
  if arg == "" then
    cecho([[
<ansi_cyan>Walk Commands:
  ]]..DarkmistsMeta.colors.default..[[walk <name>
    <dim_gray>Navigate to a saved destination

  ]]..DarkmistsMeta.colors.default..[[walk list
    <dim_gray>Show all saved destinations

  ]]..DarkmistsMeta.colors.default..[[walk add <name> <roomid>
    <dim_gray>Add a persistent destination

  ]]..DarkmistsMeta.colors.default..[[walk rem <name>
    <dim_gray>Remove a destination (persistent)

  ]]..DarkmistsMeta.colors.default..[[walk area <name>
    <dim_gray>Navigate to the first room of a matching area
]])
    return
  end

  -- LIST (grouped by area)
  if arg == "list" then
    cecho("\n<ansi_cyan>[MAP] Destinations by Area:\n")

    if not next(MapDestinations.list) then
      cecho("  <dim_gray>(none)\n")
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
          "<dark_khaki>[%-16s] "..DarkmistsMeta.colors.default.."%-16s <dim_gray>→ room "..DarkmistsMeta.colors.default.."%d\n",
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
        "\n<green>[MAP] Added destination "..DarkmistsMeta.colors.default.."%s<green> → room "..DarkmistsMeta.colors.default.."%s\n",
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
        cecho("\n<red>[MAP] No destination named "..DarkmistsMeta.colors.default .. rem .. "\n")
        return
      end
      MapDestinations.list[rem] = nil
      MapDestinations.rewrite()
      cecho("\n<dark_khaki>[MAP] Removed destination "..DarkmistsMeta.colors.default .. rem .. "\n")
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
          cecho(("\n<green>[MAP] Found area "..DarkmistsMeta.colors.default.."%s\n"):format(name))
          local rooms = getAreaRooms(id)
          local firstRoom = rooms and rooms[0]
          if firstRoom then
            gotoRoom(firstRoom)
          else
            cecho("<dark_khaki>[MAP] Area has no rooms indexed\n")
          end
          return
        end
      end

      cecho("\n<red>[MAP] No area matching "..DarkmistsMeta.colors.default .. areaSearch .. "\n")
      return
    end
  end

  -- NAVIGATE TO SAVED DESTINATION
  local dest = MapDestinations.list[arg:lower()]
  if not dest then
    cecho("\n<red>[MAP] Unknown destination. Type "..DarkmistsMeta.colors.default.."walk<red> for help.\n")
    return
  end

  local current = getPlayerRoom()
  if not current then
    cecho("<red>[MAP] Current room unknown\n")
    return
  end

  cecho(("<ansi_cyan>[MAP] Generating Path: "..DarkmistsMeta.colors.default.."%s<dim_gray> (room %d)\n")
    :format(arg, dest))

  local ok = getPath(current, dest)
  if not ok or not speedWalkDir or #speedWalkDir == 0 then
    cecho("<dark_khaki>[MAP] No known path for that destination\n")
    return
  end

  gotoRoom(dest)
end)