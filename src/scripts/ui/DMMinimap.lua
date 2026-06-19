--================================--
-- Mini Map
--================================--

DarkMistsMiniMap = {}
DarkMistsMiniMap.dock = nil

--================================--
-- Configuration
--================================--

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

--================================--
-- UI Creation
--================================--

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

  -- Mutated in place during refresh; do not rebuild the label.
  DarkMistsMiniMap.header = header

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

--================================--
-- Display Update
--================================--

function DarkMistsMiniMap.update()
  if not DarkMistsMiniMap.header then return end
  if not map then return end
  if not map.configs then return end
  local selection = getMapSelection()
  local id = selection and selection.center
  local name = id and getRoomName(id)
  local area = name and getRoomAreaName(getRoomArea(id))

  -- Prefer the selected room; fall back to the live room when selection is incomplete.
  if not (name and id and area) and map.currentRoom then
    name = map.currentName
    id = map.currentRoom
    area = getRoomAreaName(map.currentArea)
  end

  name = name or "unknown"
  id = id or "?"
  area = area or "unknown"

  local disp = ("%s / %s (%s)"):format(name, tostring(id), area)

  DarkMistsMiniMap.header:clear()
  DarkMistsMiniMap.header:echo(disp)
end

--================================--
-- Event Wiring
--================================--

function DarkMistsMiniMap.registerEvents()
  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","Registering Events with EventHandlerManager")
  DarkmistsEvents.add("MiniMapMousePress", "sysMapWindowMousePressEvent", DarkMistsMiniMap.update)
  DarkmistsEvents.add("MiniMapPrompt", "dmapi.world.prompt", DarkMistsMiniMap.update)
  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","Events Registered!")
end

--================================--
-- Initialization
--================================--

-- Keep mapper-generated room titles stable so selected-room matching survives immortal suffix noise.
local function install_sanitize_override()
  local function sanitizeRoomName(roomtitle)
    if type(roomtitle) ~= "string" then
      return roomtitle
    end

    -- Strip the trailing immortal room marker before comparing names.
    roomtitle = roomtitle:gsub("%s*%[[Rr][Oo][Oo][Mm]%s+%d+%]%s*$", "")

    if not roomtitle:match("   ") then
      return roomtitle
    end

    -- Preserve the readable room fragment when the mapper pads the title into chunks.
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

-- Delay the visible show call so restore paths do not immediately hide the container again.
local function initMiniMap()
  if DarkMistsMiniMap.container then return end
  DarkMistsMiniMap.create()
  DarkMistsMiniMap.registerEvents()
  DMLogger.log(DarkmistsTheme.greenTag .. "MiniMapContainer","MiniMap Created!")
  DarkMistsMiniMap.update()
  install_sanitize_override()
  if DarkMistsMiniMap.container then
    tempTimer(0.05, function()
      if DarkMistsMiniMap.container then
        DarkMistsMiniMap.container:show()
        DarkMistsMiniMap.container:raiseAll()
      end
    end)
  end
end

-- Register a one-shot connect handler when startup runs before the session is ready.
function DarkMistsMiniMap.init()
  DarkMistsMiniMap.configure()
  local _, _, connected = getConnectionInfo()
  if not connected then
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

  initMiniMap()

  return true
end

function DarkMistsMiniMap.rebuild()
  DarkMistsMiniMap.destroy()
  return DarkMistsMiniMap.init()
end

