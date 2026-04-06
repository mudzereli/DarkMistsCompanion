DarkMistsMiniMap = {}
DarkMistsMiniMap.dock = nil

function DarkMistsMiniMap.configure()
  if Darkmists and Darkmists.getSmartDockGeometry then
    DarkMistsMiniMap.dock = Darkmists.getSmartDockGeometry()
  else
    DarkMistsMiniMap.dock = {
      x = 0,
      width = "100%"
    }
  end
end

-- -------------------------------------------------------------------
-- UI Creation
-- -------------------------------------------------------------------
function DarkMistsMiniMap.create()
  if DarkMistsMiniMap.container then return end

  DarkMistsMiniMap.configure()
  local dock = DarkMistsMiniMap.dock or { x = 0, width = "100%" }

  DarkMistsMiniMap.container = Adjustable.Container:new({
    name = "MiniMapContainer",
    x = dock.x,
    width = dock.width,
    y = "0%",
    height = "50%",
    titleText = "Mini Map",
    titleTxtColor = Darkmists.getDefaultTextColor(),
    padding = 10,
    adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
    lockStyle = "border",
    attached = dock.side,
    locked = false,
    autoSave = true,
    autoLoad = true,
  })

  -- Header
  local header = Geyser.Label:new({
    name = "MiniMapHeader",
    x = "0%", y = "0%",
    width = "100%", height = "10%"
  }, DarkMistsMiniMap.container)

  header:setStyleSheet([[
    padding: 0px;
    margin: 0px;
    font-weight: 900;
    qproperty-alignment: AlignCenter;
  ]])
  header:setFont(Darkmists.GlobalSettings.fontName)
  header:setFontSize(Darkmists.GlobalSettings.fontSize)

  DarkMistsMiniMap.header = header -- store reference for updates

  -- Mapper
  DarkMistsMiniMap.minimap = Geyser.Mapper:new({
    name = "MiniMap",
    x = "0%", y = "10%",
    width = "100%", height = "90%"
  }, DarkMistsMiniMap.container)

  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","Container Created!")
end

function DarkMistsMiniMap.destroy()
  if DarkMistsMiniMap.container then
    DarkMistsMiniMap.container:hide()
    DarkMistsMiniMap.container:delete()
    DarkMistsMiniMap.container = nil
  end
  DarkMistsMiniMap.header = nil
  DarkMistsMiniMap.minimap = nil
end
-- -------------------------------------------------------------------
-- Update Display
-- -------------------------------------------------------------------
function DarkMistsMiniMap.update()
  if not map then return end -- defensive; should not occur if mapper data properly loaded
  if not map.configs then return end  -- defensive; should not occur if mapper data properly loaded
  local name, id, area

  -- Prefer selected room
  local selection = getMapSelection()
  if selection then
    id = selection.center
    if id then
      name = getRoomName(id)
      if name then
        -- Only resolve area if room name resolved successfully
        area = getRoomAreaName(getRoomArea(id))
      end
    end
  end

  -- Fallback to current room if any selection data missing
  if not (name and id and area) and map.currentRoom then
    name = map.currentName
    id = map.currentRoom
    area = getRoomAreaName(map.currentArea)
  end

  -- Defaults ensure stable UI even if mapper data unavailable
  name = name or "unknown"
  id = id or "?"
  area = area or "unknown"

  local disp = ("%s / %s (%s)"):format(name, tostring(id), area)

  -- Header may briefly be nil during reload race; assume exists as original did
  DarkMistsMiniMap.header:clear()
  DarkMistsMiniMap.header:echo(disp)
end

-- -------------------------------------------------------------------
-- Event Management
-- -------------------------------------------------------------------
function DarkMistsMiniMap.registerEvents()
  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","Registering Events with EventHandlerManager")
  DarkmistsEvents.add("MiniMapMousePress", "sysMapWindowMousePressEvent", DarkMistsMiniMap.update)
  DarkmistsEvents.add("MiniMapPrompt", "dmapi.world.prompt", DarkMistsMiniMap.update)
  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","Events Registered!")
end

-- -------------------------------------------------------------------
-- Initialization
-- -------------------------------------------------------------------

-- Install an override for the mapper's `sanitizeRoomName` function.
-- This replaces the original implementation with the project's preferred behavior
-- while keeping the override local to this module. If `map` is not yet present,
-- retry once shortly after load.
local function install_sanitize_override()
  local function sanitizeRoomName(roomtitle)
    if type(roomtitle) ~= "string" then
      return roomtitle
    end

    -- remove immortal VNUMs like [Room 12345] at end of room titles,
    -- which disrupts the minimap's ability to match selected rooms to mapper data.
    roomtitle = roomtitle:gsub("%s*%[[Rr][Oo][Oo][Mm]%s+%d+%]%s*$", "")

    -- original behavior (keep this)
    if not roomtitle:match("   ") then
      return roomtitle
    end

    local parts = roomtitle:split("  ")
    table.sort(parts, function(a,b) return #a < #b end)
    local longestpart = parts[#parts]

    local trimmed = utf8.match(longestpart, "[%w ]+"):trim()
    return trimmed
  end

  if map then
    map.sanitizeRoomName = sanitizeRoomName
  end
end

-- Initialize the minimap when connected (or immediately if already connected).
local function initMiniMap()
  if DarkMistsMiniMap.container then return end
  DarkMistsMiniMap.create()
  DarkMistsMiniMap.registerEvents()
  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","MiniMap Created!")
  -- update and show immediately
  DarkMistsMiniMap.update()
  install_sanitize_override()
  if DarkMistsMiniMap.container then
    -- Delay showing briefly to avoid being overridden by any auto-load
    -- or restore logic that may run immediately after creation (observed
    -- behavior during package updates). A short timer ensures the final
    -- visibility state is the visible one we expect.
    tempTimer(0.05, function()
      if DarkMistsMiniMap.container then
        DarkMistsMiniMap.container:show()
        DarkMistsMiniMap.container:raiseAll()
      end
    end)
  end
end

-- Public initializer: create now if connected, otherwise register a one-shot
-- sysConnectionEvent handler and unregister it after first successful connect.
function DarkMistsMiniMap.init()
  DarkMistsMiniMap.configure()
  local _, _, connected = getConnectionInfo()
  if connected then
    initMiniMap()
    return true
  end

  -- Register a one-shot connection handler via DarkmistsEvents so it will be
  -- automatically removed after it fires once.
  DarkmistsEvents.add("DarkMistsMiniMap.OnConnect", "sysConnectionEvent",
    function()
      local _,_,c = getConnectionInfo()
      if c then
        initMiniMap()
      end
    end,
    true
  )

  return true
end

function DarkMistsMiniMap.rebuild()
  DarkMistsMiniMap.destroy()
  return DarkMistsMiniMap.init()
end

