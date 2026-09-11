-- ============================================================================
-- Walk Destinations Window
-- ----------------------------------------------------------------------------
-- On-demand dockable destination list with the existing alert as fallback.
-- ============================================================================
WalkDestinations = {}

local DESTINATION_MAX_LENGTH = 24

WalkDestinations.window = nil
WalkDestinations.header = nil
WalkDestinations.controls = nil
WalkDestinations.console = nil
WalkDestinations.activeFilter = ""
WalkDestinations._watchedText = ""
WalkDestinations.FILTER_POLL_INTERVAL = 0.2
WalkDestinations.FILTER_TIMER_KEY = "WalkDestinations.filterWatch"

local function normalizeFilter(filter)
  return tostring(filter or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function sortedAreaNames(grouped)
  local names = {}
  for areaName in pairs(grouped) do
    names[#names + 1] = areaName
  end
  table.sort(names)
  return names
end

local function renderEmpty(win, filter)
  cecho(win, "\n  " .. DarkmistsTheme.mutedTag .. "(none)")
  if filter ~= "" then
    cecho(win, "\n\n  " .. DarkmistsTheme.mutedTag .. "No destinations match " .. DarkmistsTheme.textTag .. filter .. DarkmistsTheme.mutedTag .. ".")
  end
end

local function renderDestinations(win, grouped, filter)
  local dmText = DarkmistsTheme.textTag
  local dmMuted = DarkmistsTheme.mutedTag
  local dmInfo = DarkmistsTheme.infoTag
  local dmWarn = DarkmistsTheme.warnTag
  local dmLink = DarkmistsTheme.accentTag
  local areas = sortedAreaNames(grouped)

  cecho(win, "\n")
  if #areas == 0 then
    renderEmpty(win, filter)
    return
  end

  for areaIndex, areaName in ipairs(areas) do
    local headerGap = areaIndex == 1 and "" or "\n"
    cecho(win, headerGap .. dmWarn .. "<b>[" .. dmText .. areaName .. dmWarn .. "]</b>\n")

    for _, entry in ipairs(grouped[areaName]) do
      local roomName = getRoomName(entry.room) or "UNKNOWN"
      local destinationName = DMUtil.cap(entry.name, DESTINATION_MAX_LENGTH)
      local displayRoomName = DMUtil.cap(roomName, 27)

      cecho(win, "  ")
      cechoLink(
        win,
        string.format("%s<u>%s</u>", dmLink, destinationName),
        function()
          expandAlias("walk " .. entry.name)
        end,
        "Click to walk to " .. entry.name .. " (Room " .. entry.room .. ")",
        true
      )
      cecho(win, string.format("%s (%s%s%s)\n", dmMuted, dmInfo, displayRoomName, dmMuted))
    end
  end
end

local function dockIsVisible()
  local dock = DMTabFrame and DMTabFrame.container
  if not dock then return false end
  if dock.hidden == true then return false end

  if type(dock.isVisible) == "function" then
    local ok, visible = pcall(dock.isVisible, dock)
    if ok and visible == false then return false end
  end

  return true
end

local function canUseDock()
  if not Darkmists or not Darkmists.UI_LOADED then return false end
  if Darkmists.GlobalSettings and Darkmists.GlobalSettings.minimalMode then return false end
  if not DMTabFrame or not DMTabFrame.container or not DMTabs then return false end
  if not DMTabs["Destinationscenter"] then return false end
  return dockIsVisible()
end

function WalkDestinations.create()
  if WalkDestinations.window and WalkDestinations.console then return true end
  if not canUseDock() then return false end

  local panelColors = DarkmistsTheme.panel or {}
  local ph = DMPanelHeader.create("WalkDestinations", "Walk Destinations", "Destinations", {
    consoleColor = Darkmists.getDefaultBackgroundColor(),
    font = getFont(),
    fontSize = Darkmists.GlobalSettings.fontSize,
    age = false,
    filter = {
      width = 210,
      height = 20,
      gapLeft = 2,
      toolTip = "Filter destinations by name, room, or area (applies as you type)",
      onSubmit = function(text)
        WalkDestinations.setFilter(text)
      end,
    },
    buttons = {
      -- Sits next to the filter box: saves its text as a destination at the
      -- current room, the same as `walk add <name>`.
      { key = "add", label = "add", marginX = 1,
        color = panelColors.buttonAddColor or "#4ade80",
        tooltip = "Add the filter box text as a destination at your current room",
        onClick = function() WalkDestinations.addFromFilter() end },
      -- Next to add, and destructive like the palette's other red button.
      { key = "del", label = "del", marginX = 1,
        color = panelColors.buttonClearColor or "#ff7b6b",
        tooltip = "Remove the destination named in the filter box",
        onClick = function() WalkDestinations.removeFromFilter() end },
      -- Stretchy spacer: keeps the filter on the left, buttons anchored right.
      { key = "spacer", stretch = true },
      { key = "clear", label = "clear", marginX = 1,
        color = panelColors.buttonClearColor or "#ff7b6b",
        tooltip = "Clear destination filter",
        onClick = function() WalkDestinations.setFilter("") end },
      { key = "refresh", label = "refresh", marginX = 1, marginR = 4,
        color = panelColors.buttonRefreshColor or "#a78bfa",
        tooltip = "Refresh destinations",
        onClick = function() WalkDestinations.refresh() end },
    },
  })

  WalkDestinations.window = ph.panel
  WalkDestinations.header = ph.header
  WalkDestinations.controls = ph.controls
  WalkDestinations.console = ph.console

  WalkDestinations.console:setFont(getFont())
  WalkDestinations.console:setFontSize(Darkmists.GlobalSettings.fontSize)
  WalkDestinations.console:enableAutoWrap()
  WalkDestinations.console:enableScrollBar()

  WalkDestinations.window:show()
  WalkDestinations.window:raiseAll()
  WalkDestinations.startFilterWatch()
  Darkmists.Log("WalkDestinations", "Dockable destinations window created")
  return true
end

function WalkDestinations.refresh()
  if not WalkDestinations.console then return false end

  WalkDestinations.console:clear()
  local grouped = MapDestinations.getGroupedFiltered(WalkDestinations.activeFilter)
  renderDestinations(WalkDestinations.console.name, grouped, WalkDestinations.activeFilter)
  return true
end

-- Applies a filter programmatically (clear button, walk command, reopen) by
-- syncing the input box first, then re-rendering.
function WalkDestinations.setFilter(filter)
  filter = normalizeFilter(filter)
  WalkDestinations.activeFilter = filter
  WalkDestinations._watchedText = filter
  if WalkDestinations.controls and WalkDestinations.controls.filter then
    local input = WalkDestinations.controls.filter
    input:clear()
    if filter ~= "" then
      input:append(filter)
    end
  end
  return WalkDestinations.refresh()
end

-- "add" button: save what is typed in the filter box as a destination at the
-- current room, which is what `walk add <name>` does. The box keeps its text, so
-- the new destination is then what the filtered list shows.
function WalkDestinations.addFromFilter()
  local input = WalkDestinations.controls and WalkDestinations.controls.filter
  local name = input and normalizeFilter(input:getText()) or ""
  if name == "" then
    DMLogger.notify("WALK", DarkmistsTheme.badTag
      .. "Type a name in the filter box to add it as a destination")
    return false
  end

  local ok, a, b, c = MapDestinations.addDestination(name)
  if not ok then
    if a == "NO_CURRENT_ROOM" then
      DMLogger.notify("WALK", DarkmistsTheme.badTag .. "No Current Room found on Map")
    elseif a == "NAME_TOO_LONG" then
      DMLogger.notify("WALK", ("%sDestination names must be %d characters or fewer")
        :format(DarkmistsTheme.badTag, b))
    elseif a == "ROOM_MISSING" then
      DMLogger.notify("WALK", ("%sRoom does not exist: %s%d")
        :format(DarkmistsTheme.badTag, DarkmistsTheme.textTag, b))
    else
      DMLogger.notify("WALK", DarkmistsTheme.badTag .. "Invalid destination name")
    end
    return false
  end

  DMLogger.notify("WALK", ("Added destination: %s%s%s → %s[%s%d%s] %s%s"):format(
    DarkmistsTheme.textTag, a, DarkmistsTheme.goodTag, DarkmistsTheme.mutedTag,
    DarkmistsTheme.textTag, b, DarkmistsTheme.mutedTag, DarkmistsTheme.textTag, c))
  WalkDestinations.refresh()
  return true
end

-- "del" button: delete the destination named in the filter box, which is what
-- `walk rem <name>` does. The box keeps its text, so the list simply drops that
-- entry once the filter is re-applied.
function WalkDestinations.removeFromFilter()
  local input = WalkDestinations.controls and WalkDestinations.controls.filter
  local name = input and normalizeFilter(input:getText()) or ""
  if name == "" then
    DMLogger.notify("WALK", DarkmistsTheme.badTag
      .. "Type a name in the filter box to remove that destination")
    return false
  end

  local ok, code, removed = MapDestinations.remove(name)
  if not ok then
    if code == "NOT_FOUND" then
      DMLogger.notify("WALK", ("%sNo destination named %s%s")
        :format(DarkmistsTheme.badTag, DarkmistsTheme.textTag, removed))
    else
      DMLogger.notify("WALK", DarkmistsTheme.badTag .. "Invalid destination name")
    end
    return false
  end

  DMLogger.notify("WALK", ("%sRemoved destination %s%s")
    :format(DarkmistsTheme.warnTag, DarkmistsTheme.textTag, removed))
  WalkDestinations.refresh()
  return true
end

-- Geyser.CommandLine exposes no text-changed signal, so a lightweight repeating
-- timer polls the box and re-renders live as the player types. Created with the
-- panel and torn down in destroy(), so reloads never leak the timer.
function WalkDestinations.startFilterWatch()
  DarkmistsTimer.add(WalkDestinations.FILTER_TIMER_KEY, WalkDestinations.FILTER_POLL_INTERVAL, function()
    WalkDestinations.pollFilterInput()
  end, true)
end

function WalkDestinations.pollFilterInput()
  local input = WalkDestinations.controls and WalkDestinations.controls.filter
  if not input then
    DarkmistsTimer.remove(WalkDestinations.FILTER_TIMER_KEY)
    return
  end

  local text = input:getText() or ""
  if text == WalkDestinations._watchedText then return end

  -- Track the raw text, not the trimmed filter, so a trailing space mid-typing
  -- does not retrigger a refresh on every tick.
  WalkDestinations._watchedText = text
  local normalized = normalizeFilter(text)
  if normalized == WalkDestinations.activeFilter then return end

  WalkDestinations.activeFilter = normalized
  WalkDestinations.refresh()
end

-- Restored on load: a pulled-out Destinations tab comes back as an empty window,
-- because the panel is only ever built on demand. Rebuild it so the float has its
-- content - and render it, since create() alone does not draw the list.
function WalkDestinations.init()
  local tabs = DMTabs
  if not (tabs and tabs.Destinations and tabs.Destinations.floating) then return end
  if WalkDestinations.create() then
    WalkDestinations.setFilter(WalkDestinations.activeFilter)
  end
end

function WalkDestinations.open(filter)
  filter = normalizeFilter(filter)

  if not canUseDock() then
    return DMWalkAlert.show(filter)
  end

  -- A pulled-out Destinations tab is its own window: show that instead of going
  -- through setTabVisible, which restores (re-docks) a floating tab, and instead
  -- of activateTab, which would restyle it as the active docked tab.
  local tabs = DMTabs
  if tabs and tabs.Destinations and tabs.Destinations.floating then
    if not WalkDestinations.create() then
      return DMWalkAlert.show(filter)
    end
    WalkDestinations.setFilter(filter)

    -- showFloatingTab, not raiseAll: the float's own x button hides its window
    -- without un-floating the tab, so raising alone leaves a closed one invisible
    -- and `walk list` looking like it did nothing.
    DMTabFrame.showFloatingTab("Destinations")
    return true
  end

  if DMTabFrame.setTabVisible then
    DMTabFrame.setTabVisible("Destinations", true)
  end
  DMTabs:deactivateTab()
  DMTabs:activateTab("Destinations")

  -- Build the panel only after its tab has become visible. Creating it while
  -- the initial hidden page is still attached makes its nested layout inherit
  -- that hidden state on the first open.
  if not WalkDestinations.create() then
    return DMWalkAlert.show(filter)
  end
  WalkDestinations.setFilter(filter)
  WalkDestinations.window:show()
  WalkDestinations.window:raiseAll()
  return true
end

function WalkDestinations.destroy()
  if WalkDestinations.console and WalkDestinations.console.delete then
    pcall(WalkDestinations.console.delete, WalkDestinations.console)
  end
  if WalkDestinations.window and WalkDestinations.window.delete then
    pcall(WalkDestinations.window.delete, WalkDestinations.window)
  end

  DarkmistsTimer.remove(WalkDestinations.FILTER_TIMER_KEY)

  WalkDestinations.window = nil
  WalkDestinations.header = nil
  WalkDestinations.controls = nil
  WalkDestinations.console = nil
  WalkDestinations.activeFilter = ""
  WalkDestinations._watchedText = ""
end

return WalkDestinations
