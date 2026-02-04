
-- =============================================================================
-- MAP DESTINATIONS (PERSISTENT)
-- =============================================================================
-- Simple name → roomID mapping for goto navigation.

MapDestinations = {
  list = {},
  path = getMudletHomeDir() .. "/mapdestinations_state.lua",
}

-- Add or overwrite a destination (runtime only)
function MapDestinations.add(name, room)
  MapDestinations.list[name] = tonumber(room)
end

-- Load persistent destinations (creates stub if missing)
function MapDestinations.load()
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

-- Rewrite full destination file (authoritative state)
function MapDestinations.rewrite()
  local f = io.open(MapDestinations.path, "w")
  if not f then
    cecho("<red>[MAP] Failed to rewrite destinations\n")
    return
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
end

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

-- Load destinations on startup
MapDestinations.load()
