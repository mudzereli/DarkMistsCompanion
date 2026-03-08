DMTabs = Adjustable.TabWindow:new({
  name = "DMTabs",

  x = Darkmists.getDefaultXPosition(),
  width  = tostring(100 - Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
  y = "50%",
  height = "50%",

  tabs = {"Chat","Affects","Who","Player"},

  color1 = Darkmists.getDefaultBackgroundColor(),
  color2 = Darkmists.getDefaultBackgroundColor(),
  tabTxtColor = Darkmists.getDefaultTextColor(),

  -- INACTIVE TABS
  inactiveTabStyle = [[
    QLabel {
      background-color: rgba(255,255,255,5%);
      margin-left: 1px;
      margin-right: 1px;
      padding: 6px;
      qproperty-alignment: 'AlignCenter';
    }
    QLabel:hover {
      background-color: rgba(180,160,255,12%);
    }
  ]],

  -- ACTIVE TAB (Dark Mists purple accent)
  activeTabStyle = [[
    QLabel {
      background-color: rgba(180,160,255,20%);
      border-top: 2px solid rgb(170,140,255);
      margin-left: 1px;
      margin-right: 1px;
      padding: 6px;
      font-weight: bold;
      qproperty-alignment: 'AlignCenter';
    }
  ]],
})