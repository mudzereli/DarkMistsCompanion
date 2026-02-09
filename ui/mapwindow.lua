MiniMapContainer =
  Adjustable.Container:new({
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
Darkmists.Log("MiniMapContainer","Container Created!")

MiniMap =
  Geyser.Mapper:new({
    name = "MiniMap",
    x = 0, y = 0,
    width = "100%", height = "100%"
  }, MiniMapContainer)

  tempTimer(1,function()
    Darkmists.Log("MiniMapContainer","MiniMap Created!")
    MiniMapContainer:show()
    MiniMapContainer:raiseAll()
  end)