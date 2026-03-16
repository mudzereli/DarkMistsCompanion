DarkMistsMiniMap = DarkMistsMiniMap or {}

-- Geometry snapshot at load time (intentional: matches original behavior)
local dock = Darkmists.getSmartDockGeometry()

-- -------------------------------------------------------------------
-- UI Creation
-- -------------------------------------------------------------------
function DarkMistsMiniMap.create()
  if DarkMistsMiniMap.container then return end

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

function DarkMistsMiniMap.destroy()
  if DarkMistsMiniMap.container then
    DarkMistsMiniMap.container:hide()
    DarkMistsMiniMap.container:delete()
    DarkMistsMiniMap.container = nil
  end
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
  Darkmists.Log("MiniMapContainer","Registering Events with EventHandlerManager")
  DarkmistsEvents.add("MiniMapMousePress", "sysMapWindowMousePressEvent", DarkMistsMiniMap.update)
  DarkmistsEvents.add("MiniMapPrompt", "dmapi.world.prompt", DarkMistsMiniMap.update)
  Darkmists.Log("MiniMapContainer","Events Registered!")
end

-- -------------------------------------------------------------------
-- Initialization
-- -------------------------------------------------------------------

tempTimer(0.5, function()
  DarkMistsMiniMap.create()
  DarkMistsMiniMap.registerEvents()
  Darkmists.Log("MiniMapContainer","MiniMap Created!")
  tempTimer(0, function()
    DarkMistsMiniMap.update()
    DarkMistsMiniMap.container:show()
    DarkMistsMiniMap.container:raiseAll()
  end)
end)