--================================--
-- Button Bar
--================================--

-- Manages the top toolbar (buttons & dropdowns) used by the UI.
-- Uses Geyser Labels and the Adjustable container to place controls.
-- Designed to be reload-safe: callers destroy/recreate this module
-- during reloads so the implementation keeps minimal persistent state.
-- `ButtonBar.nextX` tracks the horizontal offset used while laying out
-- top-level controls left-to-right.
ButtonBar = {}

ButtonBar.bg = "#000000"
ButtonBar.padding = 2
ButtonBar.topLevelMaxCharacters = 16
ButtonBar.dropDownMaxCharacters = 20
ButtonBar.buttonMaxCharacters = 20
ButtonBar.timeMaxCharacters = 11
ButtonBar.fontSize = nil
ButtonBar.fontWidth = nil
ButtonBar.fontHeight = nil
ButtonBar.height = nil
ButtonBar.timeLabel = nil

-- Qt-style CSS used by Geyser `QLabel` instances. Keep separate
-- styles for top-level buttons (compact, horizontal) and menu
-- labels (padded, bordered) so hover and spacing can differ.
ButtonBar.buttonStyleSheet = [[
  QLabel {
    background-color: #000000;
    color: #dddddd;
    border-right: 1px solid #222222;
  }
  QLabel::hover { background-color: #111111; }
]]

ButtonBar.menuStyleSheet = [[
  QLabel {
    background-color: #000000;
    color: #cccccc;
    border: 1px solid #222222;
    padding-left: 6px;
  }
  QLabel::hover { background-color: #1a1a1a; }
]]

-- Resolve font sizing and compute measured font metrics used by layout.
-- Falls back to a sensible default, and keeps calculations idempotent
-- so reloads produce the same dimensions.
function ButtonBar.configure()
  local globalFontSize = 12
  if Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings.fontSize then
    globalFontSize = Darkmists.GlobalSettings.fontSize
  end

  ButtonBar.fontSize = globalFontSize + 3
  ButtonBar.fontWidth, ButtonBar.fontHeight = calcFontSize(ButtonBar.fontSize)
  ButtonBar.height = ButtonBar.fontHeight * 1.5
end

--================================--
-- Lifecycle
--================================--
-- Safely destroy the existing container during reloads.
-- Use `pcall` to avoid runtime errors if the container was already
-- partially torn down by a previous reload; leave no lingering refs.
function ButtonBar.destroy()
  local container = ButtonBar.container
  if container and container.delete then
    pcall(container.delete, container)
  end
  -- Time display label is a child of the container and gets torn down
  -- with the container; clear our handle to avoid stale references.
  ButtonBar.container = nil
  ButtonBar.nextX = nil
  ButtonBar.timeLabel = nil
end

--================================--
-- Initialization
--================================--
-- Create and attach the Adjustable container used as the bar.
-- The bar is locked and not persisted (`autoSave=false`) because
-- layout is programmatically managed; callers may choose to persist
-- elsewhere. `attachToBorder('top')` pins the bar to the top edge.
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

--================================--
-- Geometry and Callbacks
--================================--

function ButtonBar:_buttonWidth()
  return ButtonBar.fontWidth * ButtonBar.buttonMaxCharacters
end

function ButtonBar:_dropdownWidth()
  return ButtonBar.fontWidth * ButtonBar.topLevelMaxCharacters
end

function ButtonBar:_menuWidth()
  return ButtonBar.fontWidth * ButtonBar.dropDownMaxCharacters
end

-- Update the right-aligned session time display label.
-- Called externally by SessionTime on each tick.
-- Silently no-ops if the label hasn't been created yet (e.g., minimal mode).
function ButtonBar.setTimeDisplay(text)
  if not ButtonBar.timeLabel then return end
  ButtonBar.timeLabel:echo("<center>" .. (text or "") .. "</center>")
end

-- Execute a menu/button action in a protected call.
-- Actions are arbitrary functions; isolating failures prevents a broken
-- action from taking down the UI. Errors are routed to `DMLogger`.
function ButtonBar:_runAction(action)
  if type(action) ~= "function" then
    return false
  end

  -- Keep failures local to the originating action.
  local ok, err = pcall(action)
  if not ok and DMLogger and DMLogger.notify then
    DMLogger.notify("ButtonBar", "<red>Action failed: " .. tostring(err))
  end
  return ok
end

function ButtonBar:_style(btn, isMenu)
  btn:setStyleSheet(isMenu and ButtonBar.menuStyleSheet or ButtonBar.buttonStyleSheet)
end

-- Produce the formatted label for a menu entry. Adds a small caret
-- for entries that contain children so the user sees it's a submenu.
function ButtonBar:_menuLabel(item)
  local caret = item.children and "   ▸" or ""
  return "<left>  " .. tostring(item.label or "") .. caret
end

--================================--
-- Menu Tree Building
--================================--
-- -----------------------------------------------------------------------------
function ButtonBar:_addMenuChildren(parent, items, depth)
  depth = depth or 1

  if type(items) ~= "table" then
    return
  end

  -- Recursively build children. The `layoutDir` choice is important:
  --  - "BV" keeps the first-level menu vertical so top-level items stack
  --    cleanly under the parent.
  --  - "RV" is used for deeper levels to avoid overlapping flyouts.
  -- Click callbacks are deferred via `tempTimer(0, ...)` so the menu
  -- UI can close/settle before the action runs (avoids focus/order races).
  for _, item in ipairs(items) do
    local dir = depth == 1 and "BV" or "RV"

    local child = parent:addChild({
      width = ButtonBar:_menuWidth(),
      height = ButtonBar.height,
      layoutDir = dir,
      flyOut = true,
      message = ButtonBar:_menuLabel(item),
    })
    child:setFontSize(ButtonBar.fontSize)
    ButtonBar:_style(child, true)

    if item.children then
      self:_addMenuChildren(child, item.children, depth + 1)
    else
      child:setClickCallback(function()
        tempTimer(0, function()
          ButtonBar:_runAction(item.action)
        end)
      end)
    end
  end
end

--================================--
-- Top-Level Buttons
--================================--
-- Create a compact top-level clickable button.
-- Buttons are simple `Geyser.Label` elements; `ButtonBar.nextX` is
-- incremented to place subsequent controls to the right.
function ButtonBar:addButton(text, action)
  if not ButtonBar.container then return end

  local btn = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = ButtonBar:_buttonWidth(),
    height = "100%",
    message = "<center>" .. text .. "</center>",
  }, ButtonBar.container)

  btn:setFontSize(ButtonBar.fontSize)

  ButtonBar:_style(btn, false)

  btn:setClickCallback(function()
    tempTimer(0, function()
      ButtonBar:_runAction(action)
    end)
  end)

  ButtonBar.nextX = ButtonBar.nextX + ButtonBar:_buttonWidth()
end

--================================--
-- Top-Level Dropdowns
--================================--
-- Create a nestable dropdown header which will host a flyout menu.
-- `nestable=true` allows the label to spawn child menus built by
-- `_addMenuChildren` using the descriptor table supplied in `items`.
function ButtonBar:addDropdown(text, items)
  if not ButtonBar.container then return end

  local main = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = ButtonBar:_dropdownWidth(),
    height = "100%",
    message = "<center>" .. text .. " ▾</center>",
    nestable = true,
  }, ButtonBar.container)

  main:setFontSize(ButtonBar.fontSize)

  ButtonBar:_style(main, false)
  ButtonBar:_addMenuChildren(main, items)
  ButtonBar.nextX = ButtonBar.nextX + ButtonBar:_dropdownWidth()
end

--================================--
-- Menu Data
--================================--
-- Menu descriptor tables. Each entry is a table with `label` and
-- either `action` (a function) or `children` (an array of entries).
-- Actions frequently call `expandAlias` to route commands into Mudlet.
local MODULE_MENU = {
  {label = "🎓 Skillups", children = {
    {label = "📜 Skillups", action = function() SkillUps.showAlert() end},
    {label = "🔄 Reset Skillups", action = function() SkillUps.reset() end},
    {label = "❓ Skillups", action = function() expandAlias("dmc help skillups") end},
  }},

  {label = "👣 Walk", children = {
    {label = "📜 Destinations", action = function() expandAlias("walk list") end},
    {label = "📍 Add Current Room", action = function()
      -- Leave the destination token editable; only the command prefix is fixed.
      DMLogger.notify("WALK", "<red>finish entering a short destination keyword then press ENTER!")
      clearCmdLine()
      appendCmdLine("walk add ")
    end},
    {label = "🛑 Stop Walking", action = function() expandAlias("walk stop") end},
    {label = "🧭 Zones", action = function() MapColors.AuditCurrentArea() end},
    {label = "❓ Walk", action = function() expandAlias("dmc help walk") end},
  }},

  {label = "🔎 Item Tracker", children = {
    {label = "🔮 Offline Item Browser", action = function() Darkmists.OpenItemViewer() end},
    {label = "❓ Item Tracker", action = function()
      expandAlias("dmc help dmid")
    end},
  }},

  {label = "🧪 Enchant Assist", children = {
    {label = "⚗️ Trials", children = {
      {label = "❶ ES Try 1", action = function() expandAlias("es 1") end},
      {label = "❷ ES Try 2", action = function() expandAlias("es 2") end},
      {label = "❸ ES Try 3", action = function() expandAlias("es 3") end},
      {label = "❹ ES Try 4", action = function() expandAlias("es 4") end},
      {label = "❺ ES Try 5", action = function() expandAlias("es 5") end},
      {label = "⚡ Run", action = function() expandAlias("es run") end},
      {label = "♾️ Auto", action = function() expandAlias("es auto") end},
      {label = "🛑 Stop", action = function() EnchanterAssist.hardStop() end},
    }},
    {label = "📊 Show Stats", action = function() expandAlias("es stats") end},
    {label = "⚠ Missing Essences", action = function() expandAlias("es missing") end},
    {label = "🧹 Reset Session", action = function() expandAlias("es reset") end},
    {label = "🛠 EA Tools", children = {
      {label = "🧪 EA Formula Viewer", action = function() Darkmists.OpenEAFormulaParser() end},
      {label = "📜 Alchemy Mat List", action = function()
        DMUtil.openLocalFile(getMudletHomeDir() .. "/DarkMistsCompanion/assets/alchemy-mat-list.html")
      end},
      {label = "🔄 EA Save Converter", action = function() Darkmists.OpenEAConverter() end},
    }},
    {label = "❓ Enchant Assist", action = function() expandAlias("dmc help es") end}
  }},
  {label = "📐 Line Formatter", action = function() Darkmists.OpenLineFormatter() end},
}

-- Settings menu: mutates `Darkmists.GlobalSettings` and may prompt a
-- UI reload. Keep actions minimal; destructive operations request
-- user confirmation via other helpers when necessary.
local SETTINGS_MENU = {
  {label = "🔄 Reload UI", action = function() Darkmists.PromptSafeReload() end},
  {label = "📊 Toggle UI", action = function() Darkmists.ShowUIIntroMessage(true) end},

  {label = "🌞 Light Mode", action = function()
    -- Defer the switch: queue it and apply only on the next UI reload/startup,
    -- so nothing re-themes before the user confirms.
    Darkmists.GlobalSettings.pendingThemeMode = true
    DMLogger.notify("Settings", "Light Mode queued - Reload UI to apply")
    Darkmists.SaveSettings()
    Darkmists.PromptSafeReload()
  end},

  {label = "🌚 Dark Mode", action = function()
    Darkmists.GlobalSettings.pendingThemeMode = false
    DMLogger.notify("Settings", "Dark Mode queued - Reload UI to apply")
    Darkmists.SaveSettings()
    Darkmists.PromptSafeReload()
  end},

  {label = "🗺️ Load Map", action = function()
    Darkmists.PromptLoadMap()
  end},

  {label = "📊 Status Bars", children = {
    {label = "👁️ Show", action = function() StatusBar.enable() end},
    {label = "❌ Hide", action = function() StatusBar.disable() end},
    {label = "🔄 Reload", action = function() StatusBar.recreate() end},
    --{label = "↔️ Moveable Bar Toggle", action = function()
    --  StatusBar.toggleMoveable()
    --end},
  }},

  {label = "📝 Advanced", children = {
    {label = "📜 Log Console", action = function()
      pcall(DMLogger.toggle)
    end},
    {label = "🧼 Reset All Settings", action = function()
      -- Remove persisted state before reloading defaults.
      cecho(("Removing: %s (exists=%s)\n"):format(tostring(Darkmists.saveFilePath), tostring(io.exists(Darkmists.saveFilePath))))
      if io.exists(Darkmists.saveFilePath) then
        pcall(os.remove, Darkmists.saveFilePath)
        Darkmists.GlobalSettings = Darkmists.DefaultSettings
      end
      Darkmists.ResetUILayoutCache()
      Darkmists.PromptSafeReload()
    end},
    --{label = "💾 Save Settings", action = function()
    --  -- Layout must be captured before settings are written.
    --  saveWindowLayout()
    --  Darkmists.SaveSettings()
    --end},
    --{label = "📤 Load Settings", action = function()
    --  -- Restore layout before rehydrating UI state.
    --  loadWindowLayout()
    --  Darkmists.LoadSettings()
    --  Darkmists.PromptSafeReload()
    --end},
    --{label = "📝 Edit Settings File", action = function() Darkmists.OpenSettingsFile() end},
    --{label = "📡 Updates", children = {
    --  {label = "🟢 Use Stable Channel", action = function()
    --    Darkmists.SetUpdateChannel("stable")
    --  end},
    --  {label = "🟡 Use Beta Channel", action = function()
    --    Darkmists.SetUpdateChannel("beta")
    --  end},
    --  {label = "📥 Update", action = function()
    --    Darkmists.UpdateFromGitHub()
    --  end},
    --}},
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
}

-- Help menu entries should correspond to keys in `DarkMistsMeta.helpIndex`.
-- They call `expandAlias("dmc help <topic>")` to render help in-client.
local HELP_MENU = {
  {label = "❔ General", children = {
    {label = "📘 Main Help", action = function() expandAlias("dmc help") end},
    {label = "🌞 UI Mode", action = function() expandAlias("dmc help ui") end},
    {label = "📝 Info Box", action = function() expandAlias("dmc help infobox") end},
    {label = "💥 Damage Messages", action = function() expandAlias("dmc help showdmg") end},
    {label = "🚫 Spam Prevention", action = function() expandAlias("dmc help spam") end},
  }},

  {label = "🧭 World", children = {
    {label = "🗺️ Area Maps", action = function()
      expandAlias("dmc help map")
    end},
    {label = "🚩 Map Markers", action = function()
      expandAlias("dmc help walk")
    end},
  }},

  {label = "👤 Character", children = {
    {label = "🎲 Stat Roller", action = function()
      expandAlias("dmc help statroll")
    end},
    {label = "📈 Skillup Tracking", action = function()
      expandAlias("dmc help skillups")
    end},
    {label = "🧪 Enchant Assist", action = function()
      expandAlias("dmc help es")
    end},
  }},

  {label = "☰ Interface", children = {
    {label = "📊 Status Bars", action = function()
      expandAlias("dmc help sb")
    end},
    {label = "💬 Chat History", action = function()
      expandAlias("dmc help ch")
    end},
    {label = "👥 Who List", action = function()
      expandAlias("dmc help who")
    end},
    {label = "✨ Affects List", action = function()
      expandAlias("dmc help affects")
    end},
    {label = "🏷️ Item Tracker", action = function()
      expandAlias("dmc help dmid")
    end},
  }},

  {label = "📜 Scripting", children = {
    {label = "⌨️ CMud Wrapper", action = function()
      expandAlias("dmc help cmud")
    end},
  }},
}

-- -----------------------------------------------------------------------------
-- BUILD
-- -----------------------------------------------------------------------------
-- Build the bar and populate top-level controls. Returns `true` on
-- success. This is intentionally idempotent: callers may call `build`
-- again after a reload to re-create UI state.
function ButtonBar.build()
  ButtonBar:create()

  if not ButtonBar.container then
    return false
  end

  ButtonBar:addButton("🐲 Website", function() Darkmists.OpenWebsite() end)
  ButtonBar:addDropdown("🧰 Modules", MODULE_MENU)
  ButtonBar:addDropdown("⚙️ Settings", SETTINGS_MENU)
  ButtonBar:addDropdown("❓ Help", HELP_MENU)

  -- Session time display, positioned after the last menu item so it
  -- sits at the end of the main window area (not under the map).
  ButtonBar.nextX = ButtonBar.nextX + ButtonBar.padding * 2
  ButtonBar.timeLabel = Geyser.Label:new({
    x = ButtonBar.nextX,
    y = 0,
    width = ButtonBar.fontWidth * ButtonBar.timeMaxCharacters,
    height = "100%",
    message = "",
  }, ButtonBar.container)
  ButtonBar.timeLabel:setFontSize(ButtonBar.fontSize)
  ButtonBar.timeLabel:setStyleSheet([[
    QLabel {
      background-color: #000000;
      color: #999999;
    }
  ]])
  ButtonBar.timeLabel:setToolTip("Session timer")

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