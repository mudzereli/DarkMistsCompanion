DARKMISTS_MINIMAP_EVENT_HANDLERS = DARKMISTS_MINIMAP_EVENT_HANDLERS or {}

DarkMistsMiniMap = DarkMistsMiniMap or {}
DarkMistsMiniMap.container = nil
DarkMistsMiniMap.header = nil
DarkMistsMiniMap.minimap = nil

-- Geometry snapshot at load time (intentional: matches original behavior)
local dock = Darkmists.getSmartDockGeometry()

-- -------------------------------------------------------------------
-- UI Creation
-- -------------------------------------------------------------------
function DarkMistsMiniMap.create()
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

  Darkmists.Log("MiniMapContainer","Container Created!")
end

-- -------------------------------------------------------------------
-- Update Display
-- -------------------------------------------------------------------
function DarkMistsMiniMap.update()
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
  -- Remove existing handlers owned by this module
  for _, handlerId in ipairs(DARKMISTS_MINIMAP_EVENT_HANDLERS) do
    killAnonymousEventHandler(handlerId)
    Darkmists.Log("MiniMapContainer", ("Killing Event Handler #%d"):format(handlerId))
  end
  DARKMISTS_MINIMAP_EVENT_HANDLERS = {}

  -- Register new handlers
  table.insert(DARKMISTS_MINIMAP_EVENT_HANDLERS,
    registerAnonymousEventHandler("sysMapWindowMousePressEvent", DarkMistsMiniMap.update))

  table.insert(DARKMISTS_MINIMAP_EVENT_HANDLERS,
    registerAnonymousEventHandler("dmapi.world.prompt", DarkMistsMiniMap.update))

  Darkmists.Log("MiniMapContainer","Events Registered!")
end

-- -------------------------------------------------------------------
-- Initialization
-- -------------------------------------------------------------------
tempTimer(1, function()
  DarkMistsMiniMap.create()
  DarkMistsMiniMap.registerEvents()
  DarkMistsMiniMap.update()
  DarkMistsMiniMap.container:show()
  DarkMistsMiniMap.container:raiseAll()
  Darkmists.Log("MiniMapContainer","MiniMap Created!")
end)