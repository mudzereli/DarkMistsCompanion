local isLight = Darkmists.GlobalSettings.lightMode

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

DMTabs = Adjustable.TabWindow:new({
  name = "DMTabs",

  x = Darkmists.getDefaultXPosition(),
  width  = tostring(100 - Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
  y = "50%",
  height = "50%",

  tabs = {"Chat","Affects","Who","Player"},

  color1 = Darkmists.getDefaultTextColor(),
  color2 = Darkmists.getDefaultTextColor(),
  tabTxtColor = Darkmists.getDefaultTextColor(),

  inactiveTabStyle = inactiveStyle,
  activeTabStyle   = activeStyle,
  footerStyle = [[
    background-color: ]] .. Darkmists.getDefaultBackgroundColor() .. [[;
  ]],
  centerStyle = [[
    background-color: ]] .. Darkmists.getDefaultBackgroundColor() .. [[;
    border-radius: 6px;
    margin: 4px;
  ]]
})