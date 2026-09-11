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
      width = 190,
      toolTip = "Filter destinations by name, room, or area; press Enter to apply",
      onSubmit = function(text)
        WalkDestinations.setFilter(text)
      end,
    },
    buttons = {
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

function WalkDestinations.setFilter(filter)
  WalkDestinations.activeFilter = normalizeFilter(filter)
  if WalkDestinations.controls and WalkDestinations.controls.filter then
    local input = WalkDestinations.controls.filter
    input:clear()
    if WalkDestinations.activeFilter ~= "" then
      input:append(WalkDestinations.activeFilter)
    end
  end
  return WalkDestinations.refresh()
end

function WalkDestinations.open(filter)
  filter = normalizeFilter(filter)

  if not canUseDock() then
    return DMWalkAlert.show(filter)
  end

  if not WalkDestinations.create() then
    return DMWalkAlert.show(filter)
  end

  WalkDestinations.setFilter(filter)
  if DMTabFrame.setTabVisible then
    DMTabFrame.setTabVisible("Destinations", true)
  end
  DMTabs:deactivateTab()
  DMTabs:activateTab("Destinations")
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

  WalkDestinations.window = nil
  WalkDestinations.header = nil
  WalkDestinations.controls = nil
  WalkDestinations.console = nil
  WalkDestinations.activeFilter = ""
end

return WalkDestinations
