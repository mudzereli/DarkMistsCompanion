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
}

-- Load persistent destinations from disk.
-- Resets in-memory state before replaying saved add() calls.
-- Creates a stub file if none exists.
function MapDestinations.load()
  MapDestinations.list = {}
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
    return
  end
  f:close()
  pcall(dofile, MapDestinations.path)
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
  name = name:lower()
  MapDestinations.list[name] = tonumber(room)
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
  local currentAreaId = currentRoom and getRoomArea(currentRoom)

  for areaName, areaId in pairs(areaTable) do
    if areaName:lower():find(search, 1, true) then

      -- Already in this area?
      if currentAreaId and currentAreaId == areaId then
        MapDestinations.stop()
        return false, "ALREADY_IN_AREA", areaName
      end

      local rooms = getAreaRooms(areaId)
      local firstRoom = rooms and rooms[0]

      if not firstRoom then
        return false, "AREA_EMPTY", areaName
      end

      gotoRoom(firstRoom)
      return true, firstRoom, areaName
    end
  end

  return false, "AREA_NOT_FOUND", search
end

-- Public mutation API: add destination and persist immediately.
function MapDestinations.addAndSave(name, room)
  MapDestinations.add(name, room)
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
  name = name and name:lower()
  if not name then
    return false, "INVALID_NAME"
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

  MapDestinations.addAndSave(name, roomId)

  return true, name, roomId, roomName
end

-- Load destinations on startup
MapDestinations.load()
