-- =============================================================================
-- DMWalkAlert
-- -----------------------------------------------------------------------------
-- Renders the saved map destinations in a movable DMAlertWindow.
-- =============================================================================
DMWalkAlert = {}

local DESTINATION_MAX_LENGTH = 24

local function sortedAreaNames(grouped)
  local names = {}
  for areaName in pairs(grouped) do
    names[#names + 1] = areaName
  end
  table.sort(names)
  return names
end

local function collectEntries(grouped)
  local areas = sortedAreaNames(grouped)
  local entries = {}
  local lineCount = 2
  local maxLineLength = 34

  for _, areaName in ipairs(areas) do
    local areaEntries = grouped[areaName]
    lineCount = lineCount + 1
    maxLineLength = math.max(maxLineLength, #areaName + 4)

    for _, entry in ipairs(areaEntries) do
      local roomName = getRoomName(entry.room) or "UNKNOWN"
      local destinationName = DMUtil.cap(entry.name, DESTINATION_MAX_LENGTH)
      local displayRoomName = DMUtil.cap(roomName, 27)
      local lineLength = #destinationName + #displayRoomName + 5

      entries[#entries + 1] = {
        areaName = areaName,
        destinationName = destinationName,
        name = entry.name,
        room = entry.room,
        roomName = displayRoomName,
      }
      lineCount = lineCount + 1
      maxLineLength = math.max(maxLineLength, lineLength)
    end
  end

  return areas, entries, lineCount, maxLineLength
end

local function renderEmpty(win, filter)
  cecho(win, "\n  " .. DarkmistsTheme.mutedTag .. "(none)")
  if filter and filter ~= "" then
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

function DMWalkAlert.show(filter)
  local grouped = MapDestinations.getGroupedFiltered(filter)
  local _, _, lineCount, maxLineLength = collectEntries(grouped)
  local charW, charH = calcFontSize(DMAlertWindow.getBodyFontSize())

  if not charW then charW = 8 end
  if not charH then charH = 16 end

  local estimatedWidth = math.max(520, math.min(900,
    (maxLineLength + 4) * charW + DMAlertWindow.getBorderPx()))
  local estimatedHeight = math.min(600,
    math.max(220, lineCount * charH + DMAlertWindow.getChromeHeight()))

  DMAlertWindow.Show("Walk Destinations", function(win)
    renderDestinations(win, grouped, filter)
  end, {
    width = estimatedWidth,
    height = estimatedHeight,
    scrollable = true,
  })
end

return DMWalkAlert
