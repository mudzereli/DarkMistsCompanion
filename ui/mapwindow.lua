MiniMapContainer =
  Adjustable.Container:new({
    name = "MiniMapContainer",

    x = "70%",
    y = "0%",
    width = "30%",
    height = "66%",

    titleText = "Mini Map",
    titleTxtColor = "white",
    padding = 10,
    adjLabelstyle = [[
      background-color: #111111;
      border: 2px solid #666666;
    ]],
    
    lockStyle = "border",
    locked = false,
    autoSave = true,
    autoLoad = true,
  })

MiniMap =
  Geyser.Mapper:new({
    name = "MiniMap",
    x = 0, y = 0,
    width = "100%", height = "100%"
  }, MiniMapContainer)

  tempTimer(2,function()
    MiniMapContainer:show()
    MiniMapContainer:raiseAll()
  end)