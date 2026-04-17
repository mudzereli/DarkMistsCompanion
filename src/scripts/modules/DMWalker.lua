-- =============================================================================
-- MAP DESTINATIONS (PERSISTENT SERVICE MODULE)
-- =============================================================================
-- Purpose:
--   • Maintain name → roomID mappings
--   • Handle persistence (load + rewrite)
--   • Provide navigation API for callers (no UI logic)
--
-- Design:
--   • add() is side-effect free (used by load replay)
--   • addAndSave() persists changes
--   • All functions return status instead of printing
-- =============================================================================

MapDestinations = {
  list = {},
  path = getMudletHomeDir() .. "/mapdestinations_state.lua",
  areaWalkTarget = nil,
  walkTargetRoom = nil,
  MAX_NAME_LEN = 24,
  _isLoading = false,
  _loadNormalized = false,
  _isWalking = false,
  _navigationBlockCount = 0,
  _navigationBlockTilStop = 1,
}

local function normalizeDestinationName(name)
  if not name then
    return nil
  end

  return tostring(name):lower()
end

local function truncateDestinationName(name)
  if #name <= MapDestinations.MAX_NAME_LEN then
    return name, false
  end

  return name:sub(1, MapDestinations.MAX_NAME_LEN), true
end

local function nextTruncatedDuplicateName(baseName)
  local n = 2

  while true do
    local suffix = ("_%d"):format(n)
    local stemLen = math.max(1, MapDestinations.MAX_NAME_LEN - #suffix)
    local candidate = baseName:sub(1, stemLen) .. suffix

    if not MapDestinations.list[candidate] then
      return candidate
    end

    n = n + 1
  end
end

function MapDestinations.clearAreaWalkTarget()
  MapDestinations.areaWalkTarget = nil
end

function MapDestinations.clearWalkTargetRoom()
  MapDestinations.walkTargetRoom = nil
end

function MapDestinations.setWalkTargetRoom(roomId)
  MapDestinations.walkTargetRoom = tonumber(roomId)
end

function MapDestinations.setAreaWalkTarget(areaId, areaName)
  MapDestinations.areaWalkTarget = {
    areaId = areaId,
    areaName = areaName
  }
end

function MapDestinations.stopCurrentSpeedwalk()
  return MapDestinations.stop()
end

function MapDestinations.checkAreaArrival()
  local target = MapDestinations.areaWalkTarget
  if not target then
    return
  end

  local currentRoom = getPlayerRoom()
  if not currentRoom then
    return
  end

  local currentAreaId = getRoomArea(currentRoom)
  if currentAreaId and currentAreaId == target.areaId then
    DMLogger.notify("WALK", ("<green>Arrived in area <white>%s<green>, stopping walk."):format(target.areaName or tostring(target.areaId)))
    MapDestinations.clearAreaWalkTarget()
    MapDestinations.stopCurrentSpeedwalk()
  end
end

-- For direct room walks, clear walking state once destination is reached.
function MapDestinations.checkWalkCompletion()
  if not MapDestinations._isWalking then
    return
  end

  local targetRoom = MapDestinations.walkTargetRoom
  if not targetRoom then
    return
  end

  local currentRoom = getPlayerRoom()
  if not currentRoom then
    return
  end

  if currentRoom == targetRoom then
    MapDestinations._isWalking = false
    MapDestinations._navigationBlockCount = 0
    MapDestinations.clearWalkTargetRoom()
  end
end

-- Handle navigation blocks during walk
local function handleNavigationBlocked()
  if not MapDestinations._isWalking then
    MapDestinations._navigationBlockCount = 0
    return
  end

  raiseEvent("onMoveFail")
  MapDestinations._navigationBlockCount = MapDestinations._navigationBlockCount + 1
  if MapDestinations._navigationBlockCount >= MapDestinations._navigationBlockTilStop then
    DMLogger.notify("WALK", "<red>Navigation blocked multiple times, stopping walk.") 
    MapDestinations.stop()
    MapDestinations._navigationBlockCount = 0
  end
end

-- Load persistent destinations from disk.
-- Resets in-memory state before replaying saved add() calls.
-- Creates a stub file if none exists.
function MapDestinations.load()
  MapDestinations.list = {}
  MapDestinations._isLoading = true
  MapDestinations._loadNormalized = false
  MapDestinations._isWalking = false
  MapDestinations.walkTargetRoom = nil

  local f = io.open(MapDestinations.path, "r")
  if not f then
    local nf = io.open(MapDestinations.path, "w")
    if nf then
      nf:write([[
-- Persistent map destinations
-- Example:
-- MapDestinations.add("arkham", 1485)
]])
      nf:close()
    end
    MapDestinations._isLoading = false
    return
  end
  f:close()

  pcall(dofile, MapDestinations.path)
  MapDestinations._isLoading = false

  if MapDestinations._loadNormalized then
    MapDestinations.rewrite()
  end

  -- Register event handlers
  DarkmistsEvents.add("MapDestinations.walkCompletionCheck", "dmapi.world.prompt", MapDestinations.checkWalkCompletion)
  DarkmistsEvents.add("MapDestinations.areaArrivalCheck", "dmapi.world.prompt", MapDestinations.checkAreaArrival)
  DarkmistsEvents.add("MapDestinations.navigationBlocked", "dmapi.player.navigation.blocked", handleNavigationBlocked)
end

-- Rewrite full destination file from current in-memory state.
-- This is the authoritative persistence mechanism.
function MapDestinations.rewrite()
  local f = io.open(MapDestinations.path, "w")
  if not f then
    return false, "WRITE_FAILED"
  end

  f:write([[
-- Persistent map destinations
-- Auto-generated. Do not edit while Mudlet is running.
]])

  for name, room in pairs(MapDestinations.list) do
    f:write(string.format(
      '\nMapDestinations.add("%s", %d)',
      name, room
    ))
  end

  f:close()
  return true
end

-- Add or overwrite a destination (no persistence side effects).
-- Used by load replay and internal mutation.
function MapDestinations.add(name, room)
  name = normalizeDestinationName(name)
  room = tonumber(room)

  if not name or not room then
    return false
  end

  if MapDestinations._isLoading then
    local truncatedName, wasTruncated = truncateDestinationName(name)
    local finalName = truncatedName

    if wasTruncated and MapDestinations.list[truncatedName] then
      finalName = nextTruncatedDuplicateName(truncatedName)
    end

    if finalName ~= name then
      MapDestinations._loadNormalized = true
    end

    MapDestinations.list[finalName] = room
    return true
  end

  MapDestinations.list[name] = room
  return true
end

-- Returns:
--   true, "REMOVED", name on success
--   false, errorMessage, name on failure
function MapDestinations.remove(name)
  name = name:lower()

  if not MapDestinations.list[name] then
    return false, "NOT_FOUND", name
  end

  MapDestinations.list[name] = nil
  MapDestinations.rewrite()
  return true, "REMOVED", name
end

-- Stop current walk (delegates to Mudlet map alias).
function MapDestinations.stop()
  MapDestinations.clearAreaWalkTarget()
  MapDestinations.clearWalkTargetRoom()
  MapDestinations._isWalking = false
  MapDestinations._navigationBlockCount = 0
  expandAlias("map stop")
  return true
end

-- Return roomId for destination name, or nil if not found.
function MapDestinations.get(name)
  if not name then return nil end
  return MapDestinations.list[name:lower()]
end

-- Navigate to a saved destination by name.
-- Returns:
--   true, roomId, roomName
--   false, errorCode, optionalData (destination name)
function MapDestinations.navigate(name)
  if not name then
    return false, "INVALID_NAME"
  end

  name = name:lower()

  local dest = MapDestinations.list[name]
  if not dest then
    return false, "NOT_FOUND", name
  end

  local current = getPlayerRoom()
  if not current then
    return false, "NO_CURRENT_ROOM"
  end

  if dest == current then
    return false, "ALREADY_THERE", name
  end

  local roomName = getRoomName(dest)
  if not roomName then
    return false, "ROOM_MISSING", name
  end

  local ok = getPath(current, dest)
  if not ok or not speedWalkDir or #speedWalkDir == 0 then
    return false, "NO_PATH", name
  end

  MapDestinations.clearAreaWalkTarget()
  MapDestinations.setWalkTargetRoom(dest)
  MapDestinations._isWalking = true
  gotoRoom(dest)
  return true, dest, roomName
end

-- Navigate to first room of an area matching search string.
-- If player is already inside the matched area, stop walking.
-- Returns:
--   true, roomId, areaName on navigation
--   false, errorCode, data on failure
--   false, "ALREADY_IN_AREA", areaName if already there
function MapDestinations.navigateToArea(search)
  if not search or search == "" then
    return false, "INVALID_SEARCH"
  end

  search = search:lower()

  local areaTable = getAreaTable()
  if not areaTable then
    return false, "NO_AREAS"
  end

  local currentRoom = getPlayerRoom()
  if not currentRoom then
    return false, "NO_CURRENT_ROOM"
  end

  local currentAreaId = currentRoom and getRoomArea(currentRoom)

  -- Collect matches, separating exact from partial so "glyndane" doesn't
  -- accidentally resolve to "Glyndane Library" instead of "Glyndane".
  local exactMatch     = nil
  local partialMatches = {}

  for areaName, areaId in pairs(areaTable) do
    local lower = areaName:lower()
    if lower == search then
      exactMatch = { areaName = areaName, areaId = areaId }
    elseif lower:find(search, 1, true) then
      partialMatches[#partialMatches + 1] = { areaName = areaName, areaId = areaId }
    end
  end

  -- Exact match beats all partials; single partial is fine; multiple = ambiguous.
  local chosen
  if exactMatch then
    chosen = exactMatch
  elseif #partialMatches == 1 then
    chosen = partialMatches[1]
  elseif #partialMatches > 1 then
    table.sort(partialMatches, function(a, b) return a.areaName < b.areaName end)
    local names = {}
    for _, m in ipairs(partialMatches) do names[#names + 1] = m.areaName end
    return false, "AREA_AMBIGUOUS", table.concat(names, ", ")
  end

  if not chosen then
    return false, "AREA_NOT_FOUND", search
  end

  local areaName = chosen.areaName
  local areaId   = chosen.areaId

  -- Already in this area?
  if currentAreaId and currentAreaId == areaId then
    MapDestinations.stop()
    return false, "ALREADY_IN_AREA", areaName
  end

  local rooms = getAreaRooms(areaId)
  if not rooms then
    return false, "AREA_EMPTY", areaName
  end

  local candidates = {}
  local seen = {}

  if rooms[0] then
    candidates[#candidates + 1] = rooms[0]
    seen[rooms[0]] = true
  end

  for _, roomId in pairs(rooms) do
    if not seen[roomId] then
      candidates[#candidates + 1] = roomId
      seen[roomId] = true
    end
  end

  local targetRoom = nil
  for _, roomId in ipairs(candidates) do
    local ok = getPath(currentRoom, roomId)
    if ok and speedWalkDir and #speedWalkDir > 0 then
      targetRoom = roomId
      break
    end
  end

  if not targetRoom then
    return false, "NO_PATH", areaName
  end

  MapDestinations.setAreaWalkTarget(areaId, areaName)
  MapDestinations.setWalkTargetRoom(targetRoom)
  MapDestinations._isWalking = true
  gotoRoom(targetRoom)
  return true, targetRoom, areaName
end

-- Public mutation API: add destination and persist immediately.
function MapDestinations.addAndSave(name, room)
  local ok = MapDestinations.add(name, room)
  if not ok then
    return false, "INVALID_INPUT"
  end

  MapDestinations.rewrite()
  return true
end

-- Returns destinations grouped by area name.
-- Result format:
--   {
--     ["Area Name"] = {
--        { name = "dest", room = 1234 },
--        ...
--     }
--   }
function MapDestinations.getDestinationsGroupedByArea()
  local areas = {}

  for name, room in pairs(MapDestinations.list) do
    local areaId   = getRoomArea(room)
    local areaName = areaId and getRoomAreaName(areaId) or "Unknown Area"

    areas[areaName] = areas[areaName] or {}
    table.insert(areas[areaName], {
      name = name,
      room = room
    })
  end

  -- sort each area's destinations alphabetically
  for _, list in pairs(areas) do
    table.sort(list, function(a, b)
      return a.name < b.name
    end)
  end

  return areas
end

-- Presentation helper:
-- Returns grouped destinations optionally filtered by
-- destination name, room name, or area name.
function MapDestinations.getGroupedFiltered(filter)
  local grouped = MapDestinations.getDestinationsGroupedByArea()

  if not filter or filter == "" then
    return grouped
  end

  filter = filter:lower()
  local result = {}

  for areaName, entries in pairs(grouped) do
    for _, entry in ipairs(entries) do
      local roomName = getRoomName(entry.room) or "UNKNOWN"

      if roomName:lower():find(filter, 1, true)
      or areaName:lower():find(filter, 1, true)
      or entry.name:lower():find(filter, 1, true)
      then
        result[areaName] = result[areaName] or {}
        table.insert(result[areaName], entry)
      end
    end
  end

  return result
end

-- Adds destination by name and optional roomId.
-- If roomId is nil, current mapped room is used.
-- Validates name and room existence before persisting.
function MapDestinations.addDestination(name, roomId)
  name = normalizeDestinationName(name)
  if not name then
    return false, "INVALID_NAME"
  end

  if #name > MapDestinations.MAX_NAME_LEN then
    return false, "NAME_TOO_LONG", MapDestinations.MAX_NAME_LEN
  end

  -- If no roomId provided, use current room
  if not roomId then
    roomId = map and map.currentRoom
    if not roomId then
      return false, "NO_CURRENT_ROOM"
    end
  else
    roomId = tonumber(roomId)
    if not roomId then
      return false, "INVALID_ROOM"
    end
  end

  local roomName = getRoomName(roomId)
  if not roomName then
    return false, "ROOM_MISSING", roomId
  end

  local ok = MapDestinations.addAndSave(name, roomId)
  if not ok then
    return false, "INVALID_INPUT"
  end

  return true, name, roomId, roomName
end
