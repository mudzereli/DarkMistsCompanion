DARKMISTS_MINIMAP_EVENT_HANDLERS = DARKMISTS_MINIMAP_EVENT_HANDLERS or {}

DarkMistsMiniMap = {}
DarkMistsMiniMap.container = nil
DarkMistsMiniMap.header = nil
DarkMistsMiniMap.minimap = nil

DarkMistsMiniMap.create = function()
  -- create main container
  DarkMistsMiniMap.container = Adjustable.Container:new({
    name = "MiniMapContainer",

    x = Darkmists.getDefaultXPosition(),
    width = tostring(100 - Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
    y = "0%",
    height = "40%",

    titleText = "Mini Map",
    titleTxtColor = Darkmists.getDefaultTextColor(),
    padding = 10,
    adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
    
    lockStyle = "border",
    locked = false,
    autoSave = true,
    autoLoad = true,
  })

  -- create header inside of container
  do
    DarkMistsMiniMap.header = Geyser.Label:new({
      name = "MiniMapHeader",
      x = "0%", y = "0%",
      width = "100%", height = "10%"
    }, DarkMistsMiniMap.container)
    -- apply stylesheet to header
    DarkMistsMiniMap.header:setStyleSheet([[
      padding: 0px;
      margin: 0px;
      font-weight: 900;
      qproperty-alignment: AlignCenter;
    ]])
    DarkMistsMiniMap.header:setFont(Darkmists.GlobalSettings.fontName)
    DarkMistsMiniMap.header:setFontSize(Darkmists.GlobalSettings.fontSize)
  end

  -- create minimap container inside
  DarkMistsMiniMap.minimap = Geyser.Mapper:new({
      name = "MiniMap",
      x = "0%", y = "10%",
      width = "100%", height = "90%"
    }, DarkMistsMiniMap.container)

  Darkmists.Log("MiniMapContainer","Container Created!")
end

DarkMistsMiniMap.update = function()
  local room = {
    name = nil,
    id = nil,
    area = nil
  }
  -- try to use map selection first
  local s = getMapSelection()
  if s then
    room.id = s.center
    if room.id then
      room.name = getRoomName(room.id)
    end
    if room.name then
      room.area = getRoomAreaName(getRoomArea(room.id))
    end
  end
  -- if that doesn't work, try to use current room
  if not (room.name and room.id and room.area) then
    -- try to use current room info
    if map.currentRoom then
      room.name = map.currentName
      room.id = map.currentRoom
      room.area = getRoomAreaName(map.currentArea)
    end
  end
  -- if anything doesn't work, set it to unknown
  if not (room.name) then
    room.name = "unknown"
  end
  if not (room.id) then
    room.id = "?"
  end
  if not (room.area) then
    room.area = "unknown"
  end
  -- emulate mapper display and show it
  local disp = "%s / %s (%s)"
  disp = disp:format(room.name,tostring(room.id),room.area)
  DarkMistsMiniMap.header:clear()
  DarkMistsMiniMap.header:echo(disp)
end

DarkMistsMiniMap.registerEvents = function()
  -- kill old event handlers
  for _, v in ipairs(DARKMISTS_MINIMAP_EVENT_HANDLERS) do
    killAnonymousEventHandler(v)
    Darkmists.Log("MiniMapContainer",("Killing Event Handler #%d"):format(v))
  end
  DARKMISTS_MINIMAP_EVENT_HANDLERS = {}

  -- update on map window mouse press event
  table.insert(DARKMISTS_MINIMAP_EVENT_HANDLERS,
    registerAnonymousEventHandler("sysMapWindowMousePressEvent",
      function() DarkMistsMiniMap.update() end))

  -- update on room exit updated
  table.insert(DARKMISTS_MINIMAP_EVENT_HANDLERS,
    registerAnonymousEventHandler("dmapi.world.prompt",
      function() DarkMistsMiniMap.update() end))
  Darkmists.Log("MiniMapContainer","Events Registered!")
end

tempTimer(1,function()
  DarkMistsMiniMap.create()
  DarkMistsMiniMap.registerEvents()
  DarkMistsMiniMap.update()
  DarkMistsMiniMap.container:show()
  DarkMistsMiniMap.container:raiseAll()
  Darkmists.Log("MiniMapContainer","MiniMap Created!")
end)