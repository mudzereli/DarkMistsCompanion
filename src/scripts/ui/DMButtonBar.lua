-- =============================================================================
-- Clean Docked Button Bar (Adjustable.Container Panel)
-- =============================================================================

ButtonBar = ButtonBar or {}

ButtonBar.bg = "#000000"
ButtonBar.padding = 2
ButtonBar.topLevelMaxCharacters = 16
ButtonBar.dropDownMaxCharacters = 20   -- used for dropdown width calculations
ButtonBar.fontSize = nil
ButtonBar.fontWidth = nil
ButtonBar.fontheight = nil
ButtonBar.height = nil

function ButtonBar.configure()
  local globalFontSize = 12
  if Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings.fontSize then
    globalFontSize = Darkmists.GlobalSettings.fontSize
  end

  ButtonBar.fontSize = globalFontSize + 3
  ButtonBar.fontWidth, ButtonBar.fontheight = calcFontSize(ButtonBar.fontSize)
  ButtonBar.height = ButtonBar.fontheight * 1.5
end

-- -----------------------------------------------------------------------------
-- TEAR DOWN
-- -----------------------------------------------------------------------------
function ButtonBar.destroy()
  if ButtonBar.container and ButtonBar.container.delete then
    pcall(ButtonBar.container.delete, ButtonBar.container)
  end
  ButtonBar.container = nil
  ButtonBar.nextX = nil
end

-- -----------------------------------------------------------------------------
-- CREATE BAR
-- -----------------------------------------------------------------------------
function ButtonBar:create()

  ButtonBar.configure()

  ButtonBar.destroy()

  ButtonBar.container = Adjustable.Container:new({
    name = "ButtonBar",
    x = 0, y = 0,
    width = "100%",
    height = ButtonBar.height,
    titleText = "",
    padding = ButtonBar.padding,
    locked = true,
    lockStyle = "border",
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
-- Actions are executed inline in callbacks (using pcall).

function ButtonBar:_style(btn)
  btn:setStyleSheet([[
    QLabel {
      background-color: #000000;
      color: #dddddd;
      border-right: 1px solid #222222;
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
      width = ButtonBar.fontWidth * ButtonBar.dropDownMaxCharacters,
      height = ButtonBar.height,
      layoutDir = dir,
      flyOut = true,
      message = "<left>  " .. item.label .. caret,
    })
    child:setFontSize(ButtonBar.fontSize)
    child:setStyleSheet([[
      QLabel {
        background-color: #000000;
        color: #cccccc;
        border: 1px solid #222222;
        padding-left: 6px;
      }
      QLabel::hover { background-color: #1a1a1a; }
    ]])

    if item.children then
      self:_addMenuChildren(child, item.children, depth + 1)
    else
      child:setClickCallback(function()
        tempTimer(0,function() pcall(item.action) end)
      end)
    end
  end
end

-- -----------------------------------------------------------------------------
-- BUTTON
-- -----------------------------------------------------------------------------
function ButtonBar:addButton(text, action)
  if not ButtonBar.container then return end

  local btn = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = ButtonBar.fontWidth * 20,
    height = "100%",
    message = "<center>" .. text .. "</center>",
  }, ButtonBar.container)

  btn:setFontSize(ButtonBar.fontSize)

  ButtonBar:_style(btn)

  btn:setClickCallback(function()
    tempTimer(0,function() pcall(action) end)
  end)

  ButtonBar.nextX = ButtonBar.nextX + (ButtonBar.fontWidth * 20)
end

-- -----------------------------------------------------------------------------
-- DROPDOWN
-- -----------------------------------------------------------------------------
function ButtonBar:addDropdown(text, items)
  if not ButtonBar.container then return end

  local main = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = ButtonBar.fontWidth * ButtonBar.topLevelMaxCharacters,
    height = "100%",
    message = "<center>" .. text .. " ▾</center>",
    nestable = true,
  }, ButtonBar.container)

  main:setFontSize(ButtonBar.fontSize)

  ButtonBar:_style(main)
  ButtonBar:_addMenuChildren(main, items)
  ButtonBar.nextX = ButtonBar.nextX + (ButtonBar.fontWidth * ButtonBar.topLevelMaxCharacters)
end

-- -----------------------------------------------------------------------------
-- BUILD
-- -----------------------------------------------------------------------------
function ButtonBar.build()
  ButtonBar:create()

  if not ButtonBar.container then
    return false
  end

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
          DMLogger.notify("WALK","<red>finish entering a short destination keyword then press ENTER!")
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
      {label="📊 Show Stats", action=function() expandAlias("es stats") end},
      {label="⚡ Run", action=function() expandAlias("es run") end},
      {label="♾️ Auto", action=function() expandAlias("es auto") end},
      {label="🛑 Stop", action=function() EnchanterAssist.hardStop() end},
      {label="⚠ Missing Essences", action=function() expandAlias("es missing") end},
      {label="🧹 Reset Session", action=function() expandAlias("es reset") end},
      {label="🛠 EA Tools", children={
        {label="🧪 EA Formula Viewer", action=function() Darkmists.OpenEAFormulaParser() end},
        {label="📜 Alchemy Mat List", action=function()
            DMUtil.openLocalFile(getMudletHomeDir() .. "/DarkMistsCompanion/assets/alchemy-mat-list.html")
          end},
        {label="🔄 EA Save Converter", action=function() Darkmists.OpenEAConverter() end},
      }},
      {label="❓ Enchant Assist", action=function() expandAlias("dmc help es") end}
    }},
    {label="🔎 Item Tracker", children={
      {label="🏷️ Item Tracker", action=function()
        expandAlias("dmc help dmid")
      end},
      {label="🔮 Offline Item Browser", action=function() Darkmists.OpenItemViewer() end},
      {label="❓ Item Tracker", action=function()
        expandAlias("dmc help dmid")
      end},
    }}
  })

  ButtonBar:addDropdown("⚙️ Settings", {
    {label = "🔄 Reload UI", action = function() Darkmists.PromptSafeReload() end},
    {label = "📊 Toggle UI", action = function() Darkmists.ShowUIIntroMessage(true) end},
    {label="🌞 Light Mode", action=function()
      Darkmists.GlobalSettings.lightMode = true
      DMLogger.notify("Settings","Light Mode Enabled - Reload UI for Changes to Take place")
      Darkmists.SaveSettings()
      Darkmists.PromptSafeReload()
    end},
    {label="🌚 Dark Mode", action=function()
      Darkmists.GlobalSettings.lightMode = false
      DMLogger.notify("Settings","Dark Mode Enabled - Reload UI for Changes to Take place")
      Darkmists.SaveSettings()
      Darkmists.PromptSafeReload()
    end},
    {label = "🗺️ Load Map", action = function()
        Darkmists.PromptLoadMap()
    end},
    {label = "📜 Log Console", action = function()
      pcall(DMLogger.toggle)
    end},
    {label="📊 Status Bars", children={
      {label="👁️ Show", action=function() StatusBar.enable() end},
      {label="❌ Hide", action=function() StatusBar.disable() end},
      {label="🔄 Reload", action=function() StatusBar.recreate() end},
      {label="↔️ Moveable Bar Toggle", action=function() 
        StatusBar.toggleMoveable()
      end},
    }},
    {label = "📝 Advanced", children = {
      {label = "🧼 Reset All Settings", action = function() 
        cecho(("Removing: %s (exists=%s)\n"):format(tostring(Darkmists.saveFilePath), tostring(io.exists(Darkmists.saveFilePath))))
        if io.exists(Darkmists.saveFilePath) then
          pcall(os.remove, Darkmists.saveFilePath)
          Darkmists.GlobalSettings = Darkmists.DefaultSettings
        end
        Darkmists.ResetUILayoutCache()
        Darkmists.PromptSafeReload()
      end},
      {label = "💾 Save Settings", action = function() 
        saveWindowLayout()
        Darkmists.SaveSettings()
      end},
      {label = "📤 Load Settings", action = function() 
        loadWindowLayout()
        Darkmists.LoadSettings()
        Darkmists.PromptSafeReload()
      end},
      {label="📝 Edit Settings File", action=function() Darkmists.OpenSettingsFile() end},
      {label = "📡 Updates", children = {
        {label = "🟢 Use Stable Channel", action = function()
          Darkmists.SetUpdateChannel("stable")
        end},
        {label = "🟡 Use Beta Channel", action = function()
          Darkmists.SetUpdateChannel("beta")
        end},
        {label = "📥 Update", action = function()
          Darkmists.UpdateFromGitHub()
        end},
      }},
      {label = "🔩 Dev Tools", children = {
        {label = "🎨 Re-Color Map", action = function()
          MapColors.ResetAllRooms()
          MapColors.FullUpdatePass()
          MapColors.FinalUpdatePass()
        end},
        {label = "🐞 DMAPI Debug", action = function() expandAlias("dmapi debug") end},
        {label = "📚 DMAPI Extension", action = function() Darkmists.OpenDMAPIDocs() end},
      }},
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
        DMLogger.notify("WhoWindow",("<red>Delete Original Lines: %s"):format(tostring(new_value)))
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
        DMLogger.notify("AffectsWindow",("<red>Delete Original Lines: %s"):format(tostring(new_value)))
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
        StatusBar.toggleMoveable()
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

  return true
end

function ButtonBar.rebuild()
  return ButtonBar.build()
end

function ButtonBar.init()
  local ok = ButtonBar.build()
  if ok then
    DMLogger.log(DarkmistsTheme.oliveTag.."ButtonBar","Loaded!")
  end
  return ok
end

-- Load-passive module: DarkmistsCore should call ButtonBar.init() during startup.