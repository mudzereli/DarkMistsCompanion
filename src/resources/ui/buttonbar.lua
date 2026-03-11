-- =============================================================================
-- Clean Docked Button Bar (Adjustable.Container Panel)
-- =============================================================================

ButtonBar = ButtonBar or {}

ButtonBar.height = "25px"
ButtonBar.bg = "#000000"

-- -----------------------------------------------------------------------------
-- DELETE OLD BAR PROPERLY
-- -----------------------------------------------------------------------------
function ButtonBar:reset()
  if ButtonBar.container then
    ButtonBar.container:delete()
    ButtonBar.container = nil
  end
  ButtonBar.nextX = 0
end

-- -----------------------------------------------------------------------------
-- CREATE BAR
-- -----------------------------------------------------------------------------
function ButtonBar:create()

  if not Geyser or not Adjustable then
    echo("Geyser not ready yet.\n")
    return
  end

  if ButtonBar.container then
    ButtonBar.container:delete()
    ButtonBar.container = nil
  end

  ButtonBar.container = Adjustable.Container:new({
    name = "ButtonBar",
    x = 0, y = 0,
    width = "100%",
    height = ButtonBar.height,
    titleText = "",
    padding = 0,
    locked = true,
    lockStyle = "full",
    autoSave = false,
    autoLoad = false,
    adjLabelstyle = [[
      background-color: ]] .. ButtonBar.bg .. [[;
      border-bottom: 2px solid #444444;
    ]]
  })

  ButtonBar.container:attachToBorder("top")
  ButtonBar.nextX = 0
end

-- -----------------------------------------------------------------------------
-- HELPERS
-- -----------------------------------------------------------------------------
function ButtonBar:_run(action)
  if type(action) == "function" then action()
  elseif type(action) == "string" then send(action) end
end

function ButtonBar:_style(btn)
  btn:setStyleSheet([[
    QLabel {
      background-color: #000000;
      color: #dddddd;
      border-right: 1px solid #222222;
      font-size: 9pt;
    }
    QLabel::hover { background-color: #111111; }
  ]])
end

-- -----------------------------------------------------------------------------
-- RECURSIVE MENU BUILDER
-- -----------------------------------------------------------------------------
function ButtonBar:_addMenuChildren(parent, items, depth)

  depth = depth or 1

  for _, item in ipairs(items) do

    -- Direction logic
    local dir
    if depth == 1 then
      dir = "BV"   -- first level drops DOWN
    else
      dir = "RV"   -- deeper levels go RIGHT
    end

    local caret = item.children and "   ▸" or ""

    local child = parent:addChild({
      width = 180,
      height = 24,
      layoutDir = dir,
      flyOut = true,
      message = "<left>  " .. item.label .. caret,
    })

    child:setStyleSheet([[
      QLabel {
        background-color: #000000;
        color: #cccccc;
        border: 1px solid #222222;
        padding-left: 6px;
        font-size: 9pt;
      }
      QLabel::hover { background-color: #1a1a1a; }
    ]])

    if item.children then
      self:_addMenuChildren(child, item.children, depth + 1)
    else
      child:setClickCallback(function()
        ButtonBar:_run(item.action)
      end)
    end
  end
end

-- -----------------------------------------------------------------------------
-- BUTTON
-- -----------------------------------------------------------------------------
function ButtonBar:addButton(text, action)
  local btn = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = 120,
    height = "100%",
    message = "<center>" .. text .. "</center>",
  }, ButtonBar.container)

  ButtonBar:_style(btn)

  btn:setClickCallback(function()
    ButtonBar:_run(action)
  end)

  ButtonBar.nextX = ButtonBar.nextX + 120
end

-- -----------------------------------------------------------------------------
-- DROPDOWN
-- -----------------------------------------------------------------------------
function ButtonBar:addDropdown(text, items)
  local main = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = 150,
    height = "100%",
    message = "<center>" .. text .. " ▾</center>",
    nestable = true,
  }, ButtonBar.container)

  ButtonBar:_style(main)
  ButtonBar:_addMenuChildren(main, items)
  ButtonBar.nextX = ButtonBar.nextX + 150
end

-- -----------------------------------------------------------------------------
-- BUILD
-- -----------------------------------------------------------------------------
ButtonBar:create()

ButtonBar:addButton("🐲 Website", function() Darkmists.OpenWebsite() end)

ButtonBar:addDropdown("🧰 Modules", {
  -- Skillup Module
  {label="🎓 Skillups", children={
    {label="📜 Skillups", action=function() SkillUps.display() end},
    {label="🔄 Reset Skillups", action=function() SkillUps.reset() end},
    {label="❓ Skillups", action=function() expandAlias("dmc help skillups") end},
  }},
  -- Walk Module
  {label="👣 Walk", children={
    {label="📜 Destinations", action=function() expandAlias("walk list") end},
    {label="📍 Add Current Room", action=function()
        Darkmists.Log("WALK","<red>finish entering a short destination keyword then press ENTER!")
        clearCmdLine()
        appendCmdLine("walk add ")
        end},
    {label="🛑 Stop Walking", action=function() expandAlias("walk stop") end},
    {label="🧭 Zones", action=function() MapColors.AuditCurrentArea() end},
    {label="❓ Walk", action=function() expandAlias("dmc help walk") end},
  }},
  -- Enchant Assist Module
  {label="🧪 Enchant Assist", children={
    {label="⚗️ Trials", children={
      {label="❶ ES Try 1", action=function() expandAlias("es 1") end},
      {label="❷ ES Try 2", action=function() expandAlias("es 2") end},
      {label="❸ ES Try 3", action=function() expandAlias("es 3") end},
      {label="❹ ES Try 4", action=function() expandAlias("es 4") end},
      {label="❺ ES Try 5", action=function() expandAlias("es 5") end},
    }},
    {label="⚡ Run", action=function() expandAlias("es run") end},
    {label="♾️ Auto", action=function() expandAlias("es auto") end},
    {label="📊 Stats", action=function() expandAlias("es stats") end},
    {label="⚠ Missing", action=function() expandAlias("es missing") end},
    {label="🧹 Reset", action=function() expandAlias("es reset") end},
    {label="🛠 EA Tools", children={
      {label="🧪 EA Formula Viewer", action=function() Darkmists.OpenEAFormulaParser() end},
      {label="🔄 EA Save Converter", action=function() Darkmists.OpenEAConverter() end},
    }},
    {label="❓ Enchant Assist", action=function() expandAlias("dmc help es") end}
  }},
  {label="🔎 Item Tracker", children={
    {label="🏷️ Item Tracker", action=function()
      expandAlias("dmc help dmid")
    end},
    {label="🔮 Offline Item Browser", action=function() Darkmists.OpenItemViewer() end},
  }}
})

ButtonBar:addDropdown("🛠 Tools", {
  {label="🔮 Offline Item Browser", action=function() Darkmists.OpenItemViewer() end},
  {label="🔄 EA Save Converter", action=function() Darkmists.OpenEAConverter() end},
  {label="🧪 EA Formula Viewer", action=function() Darkmists.OpenEAFormulaParser() end},
  {label="🎨 Re-Color Map", action=function() 
    MapColors.ResetAllRooms()
    MapColors.FullUpdatePass()
    MapColors.FinalUpdatePass()
  end},
  {label="🐞 DMAPI Debug", action=function() expandAlias("dmapi debug") end},
  {label="📚 DMAPI Extension", action=function() Darkmists.OpenDMAPIDocs() end},
  {label="🗺️ Load Map", action=function() 
    Darkmists.LoadMapDat()
    tempTimer(2,function()
      disableMapInfo("Full")
      disableMapInfo("Short")
      expandAlias("find prompt")
      expandAlias("map config speedwalk_delay 0.4")
      send("look")
    end)
  end},
  {label="📡 Update From Github", action=function() Darkmists.UpdateFromGitHub() end},
})

ButtonBar:addDropdown("⚙️ Settings", {
    {label = "🔄 Reload UI", action = Darkmists.SafeReload},
    {label="🌞 Light Mode", action=function()
      Darkmists.GlobalSettings.lightMode = true
      Darkmists.Log("Settings","Light Mode Enabled - Reload UI for Changes to Take place")
      Darkmists.SaveSettings()
      Darkmists.SafeReload()
    end},
    {label="🌚 Dark Mode", action=function()
      Darkmists.GlobalSettings.lightMode = false
      Darkmists.Log("Settings","Dark Mode Enabled - Reload UI for Changes to Take place")
      Darkmists.SaveSettings()
      Darkmists.SafeReload()
    end},
    {label = "🧼 Reset All Settings", action = function() 
      saveWindowLayout()
      Darkmists.ResetUILayoutCache()
    end},
    {label = "💾 Save Settings", action = function() 
      saveWindowLayout()
      Darkmists.SaveSettings()
    end},
    {label = "📥 Load Settings", action = function() 
      loadWindowLayout()
      Darkmists.LoadSettings()
      Darkmists.SafeReload()
    end},
    {label = "📝 Advanced", children = {
      {label="📝 Edit Settings File", action=function() Darkmists.OpenSettingsFile() end}
    }}
    --[[
    {label="💬 Chat History", children={
      {label="👁️ Show", action=function() ChatHistory.window:show() end},
      {label="❌ Hide", action=function() ChatHistory.window:hide() end},
    }},
    {label="👥 Who List", children={
      {label="👁️ Show", action=function() WhoWindow.window:show() end},
      {label="❌ Hide", action=function() WhoWindow.window:hide() end},
      {label="✂️ Delete Original Lines", action=function() 
        local new_value = not WhoWindow.config.deleteOriginalLines
        WhoWindow.config.deleteOriginalLines = new_value
        Darkmists.GlobalSettings.whoWindowDeleteOriginalLines = new_value
        Darkmists.Log("WhoWindow",("<red>Delete Original Lines: %s"):format(tostring(new_value)))
        Darkmists.SaveSettings()
      end},
    }},
    {label="✨ Affects List", children={
      {label="👁️ Show", action=function() AffectsWindow.window:show() end},
      {label="❌ Hide", action=function() AffectsWindow.window:hide() end},
      {label="✂️ Delete Original Lines", action=function() 
        local new_value = not AffectsWindow.config.deleteOriginalLines
        AffectsWindow.config.deleteOriginalLines = new_value
        Darkmists.GlobalSettings.affectsWindowDeleteOriginalLines = new_value
        Darkmists.Log("AffectsWindow",("<red>Delete Original Lines: %s"):format(tostring(new_value)))
        Darkmists.SaveSettings()
      end},
    }},
    {label="🗺️ Map Window", children={
      {label="👁️ Show", action=function() DarkMistsMiniMap.container:show() end},
      {label="❌ Hide", action=function() DarkMistsMiniMap.container:hide() end},
    }},
    {label="📊 Status Bars", children={
      {label="👁️ Show", action=function() StatusBar.config.enabled = true StatusBar.showAll() end},
      {label="❌ Hide", action=function() StatusBar.config.enabled = false StatusBar.hideAll() end},
      {label="🔄 Reload", action=function() StatusBar.recreate() end},
      {label="↔️ Moveable Bar Toggle", action=function() 
        local s = Darkmists.GlobalSettings
        local m = s.statusBarsMoveable
        s.statusBarsMoveable = not m
        StatusBar.config.moveable = s.statusBarsMoveable
        StatusBar.recreate() 
      end},
    }},
    {label="🖼️ Borders", children = {
      {label = "Top", children = {
        {label = "Border Top: 0%", action = function() Darkmists.SetWindowBorderPercent("top",0) Darkmists.SaveSettings() end},
        {label = "Border Top: 10%", action = function() Darkmists.SetWindowBorderPercent("top",10) Darkmists.SaveSettings() end},
        {label = "Border Top: 20%", action = function() Darkmists.SetWindowBorderPercent("top",20) Darkmists.SaveSettings() end},
        {label = "Border Top: 30%", action = function() Darkmists.SetWindowBorderPercent("top",30) Darkmists.SaveSettings() end},
      }},
      {label = "Bottom", children = {
        {label = "Border Bottom: 0%", action = function() Darkmists.SetWindowBorderPercent("bottom",0) Darkmists.SaveSettings() end},
        {label = "Border Bottom: 10%", action = function() Darkmists.SetWindowBorderPercent("bottom",10) Darkmists.SaveSettings() end},
        {label = "Border Bottom: 20%", action = function() Darkmists.SetWindowBorderPercent("bottom",20) Darkmists.SaveSettings() end},
        {label = "Border Bottom: 30%", action = function() Darkmists.SetWindowBorderPercent("bottom",30) Darkmists.SaveSettings() end},
      }},
      {label = "Left", children = {
        {label = "Border Left: 0%", action = function() Darkmists.SetWindowBorderPercent("left",0) Darkmists.SaveSettings() end},
        {label = "Border Left: 10%", action = function() Darkmists.SetWindowBorderPercent("left",10) Darkmists.SaveSettings() end},
        {label = "Border Left: 20%", action = function() Darkmists.SetWindowBorderPercent("left",20) Darkmists.SaveSettings() end},
        {label = "Border Left: 30%", action = function() Darkmists.SetWindowBorderPercent("left",30) Darkmists.SaveSettings() end},
      }},
      {label = "Right", children = {
        {label = "Border Right: 0%", action = function() Darkmists.SetWindowBorderPercent("right",0) Darkmists.SaveSettings() end},
        {label = "Border Right: 10%", action = function() Darkmists.SetWindowBorderPercent("right",10) Darkmists.SaveSettings() end},
        {label = "Border Right: 20%", action = function() Darkmists.SetWindowBorderPercent("right",20) Darkmists.SaveSettings() end},
        {label = "Border Right: 30%", action = function() Darkmists.SetWindowBorderPercent("right",30) Darkmists.SaveSettings() end},
      }},
    }},
    ]]--
  })

ButtonBar:addDropdown("❓ Help", {

  {label="❔ General", action=function()
    expandAlias("dmc help")
  end},

  {label="🧭 World", children={
    {label="🗺️ Area Maps", action=function()
      expandAlias("dmc help map")
    end},
    {label="🚩 Map Markers", action=function()
      expandAlias("dmc help walk")
    end},
  }},

  {label="👤 Character", children={
    {label="🎲 Stat Roller", action=function()
      expandAlias("dmc help statroll")
    end},
    {label="📈 Skillup Tracking", action=function()
      expandAlias("dmc help skillups")
    end},
    {label="🧪 Enchant Assist", action=function()
      expandAlias("dmc help es")
    end},
  }},

  {label="☰ Interface", children={
    {label="📊 Status Bars", action=function()
      expandAlias("dmc help sb")
    end},
    {label="💬 Chat History", action=function()
      expandAlias("dmc help ch")
    end},
    {label="👥 Who List", action=function()
      expandAlias("dmc help who")
    end},
    {label="✨ Affects List", action=function()
      expandAlias("dmc help affects")
    end},
    {label="🏷️ Item Tracker", action=function()
      expandAlias("dmc help dmid")
    end},
  }},

})

Darkmists.Log("ButtonBar","Loaded!")