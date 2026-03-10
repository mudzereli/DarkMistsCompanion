local isLight = Darkmists.GlobalSettings.lightMode
local dock = Darkmists.getSmartDockGeometry()

local inactiveStyle = isLight and [[
  QLabel {
    background-color: rgb(245,245,250);
    border: 1px solid rgb(220,220,235);
    margin-left: 1px;
    margin-right: 1px;
    padding: 6px;
    qproperty-alignment: 'AlignCenter';
  }
  QLabel:hover {
    background-color: rgb(235,225,255);
    border: 1px solid rgb(200,180,255);
  }
]]
or [[
  QLabel {
    background-color: rgba(255,255,255,5%);
    margin-left: 1px;
    margin-right: 1px;
    padding: 6px;
    qproperty-alignment: 'AlignCenter';
  }
  QLabel:hover {
    background-color: rgba(180,160,255,28%);
  }
]]

local activeStyle = isLight and [[
  QLabel {
    background-color: rgb(170,140,255);
    color: white;
    border-top: 3px solid rgb(48, 51, 107);   /* Dark Mists deep purple */
    margin-left: 1px;
    margin-right: 1px;
    padding: 6px;
    font-weight: bold;
    qproperty-alignment: 'AlignCenter';
  }
]]
or [[
  QLabel {
    background-color: rgb(48, 51, 107);   /* Dark Mists deep purple */
    color: white;
    border-top: 3px solid rgb(170,140,255);
    margin-left: 1px;
    margin-right: 1px;
    padding: 6px;
    font-weight: bold;
    qproperty-alignment: 'AlignCenter';
  }
]]

DMTabFrame = Adjustable.Container:new({
  name = "DMTabFrame",

  x = dock.x,
  y = "50%",
  width  = dock.width,
  height = "50%",

  titleText = "",
  lockStyle = "border",
  titleTxtColor = Darkmists.getDefaultTextColor(),
  adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
  --padding = 4,
  attached = "right",
  autoSave = true,
  autoLoad = true,
  raiseOnClick = true
})

DMTabs = Adjustable.TabWindow:new({
  x = 0, y = 0,
  width = "100%", height = "100%",

  tabs = {"Chat","Affects","Who","Player"},

  color1 = Darkmists.getDefaultTextColor(),
  color2 = Darkmists.getDefaultTextColor(),
  tabTxtColor = Darkmists.getDefaultTextColor(),

  inactiveTabStyle = inactiveStyle,
  activeTabStyle   = activeStyle,
  --tabBarHeight = "7%",
  footerStyle = [[
    background-color: ]] .. Darkmists.getDefaultBackgroundColor() .. [[;
  ]],
  centerStyle = [[
    background-color: ]] .. Darkmists.getDefaultBackgroundColor() .. [[;
    border-radius: 0px;
  ]]
}, DMTabFrame)

function DMTabs:queueLayoutSave()
  if not self.__layoutSaveQueued then
    self.__layoutSaveQueued = true
    tempTimer(0.8, function()
      if DMTabs then DMTabs:save() end
      if DMTabs then DMTabs.__layoutSaveQueued = nil end
    end)
  end
end

registerAnonymousEventHandler("sysProfileSaveStarted", function()
  DMTabs:queueLayoutSave()
end)

tempTimer(120, function()
  if DMTabs then DMTabs:save() end
end, true)

DMTabs:load()