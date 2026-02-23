-- =============================================================================
-- darkmists.lua
-- -----------------------------------------------------------------------------
-- Global glue file for Dark Mists automation.
--
-- Responsibilities:
--   • Central line dispatcher
--
-- Design philosophy:
--   - Dumb dispatcher, smart subsystems
--   - Persistence via append-only Lua files
--   - Explicit > clever
-- =============================================================================
local saveFilePath = getMudletHomeDir() .. "/darkmists_global_settings.lua"
local itemViewerPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/item-viewer.html"
local dmapiDocPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/dmapi.html"
local mapDatPath = getMudletHomeDir() .. "/DarkMistsCompanion/map.dat"

Darkmists = {}
Darkmists.NAME = "Dark Mists Companion"
Darkmists.VERSION = "1.2.0"

Darkmists.DefaultSettings = {
  -- should we use light mode?
  lightMode = false,
  -- what % of the screen width should the main window take up
  mainWindowPanelWidth = 70,
  -- what % of the screen height should be reserve for the borders
  borders = {top = 10, bottom = 0, left = 0, right = 30},
  -- Font Size for additional Information Windows (Chat History, Who List, Affects)
  fontSize = 11,
  -- Font Face for additional Information Windows (Chat History, Who List, Affects)
  fontName = "Lucida Console",
  -- Colors for Status Bars (these are expressed in RGBA format which allows a wider variety of colors)
  statusBarColors = {
    hp = { bar = "128,0,0,255", backdrop = "32,0,0,255" },
    mn = { bar = "0,0,128,255", backdrop = "0,0,32,255" },
    mv = { bar = "128,128,0,255", backdrop = "32,32,0,255" },
    enemy = { bar = "128,0,0,255", backdrop = "32,0,0,255" },
    xp = { bar = "128,64,0,255", backdrop = "32,16,0,255" }
  },
  -- Font Color used on Status Bars (expressed in RGB format)
  statusBarFontColor = "255,255,255",
  -- Maximum Percentage of Screen Height to use for Status Bars
  statusBarTotalHeightPercent = 10,
  -- Put Status Bars in an Adjustable Container instead?
  -- EXPERIMENTAL / FUTURE USAGE - DOES NOT WORK PROPERLY YET
  statusBarsMoveable = false,
  -- How often Affects Window is Updated
  affectsWindowUpdateIntervalSeconds = 2,
  -- How many characters to cut off Affect Name At
  affectsWindowAffectNameLength = 20,
  -- How many characters to cut off Affect Mod At
  affectsWindowAffectModLength = 16,
  -- Clickable Item Link Color (lua showColors(3) to see allowable colors)
  itemTrackerLinkColorDarkMode = "pale_goldenrod",
  -- Clickable Item Link Color (lua showColors(3) to see allowable colors)
  itemTrackerLinkColorLightMode = "dark_slate_blue",
  -- Delete Original Affect Lines when typing Score / Affect
  affectsWindowDeleteOriginalLines = false,
  -- Delete Original Who Lines when typing Who
  whoWindowDeleteOriginalLines = false,
  -- Stat Roller Leniancy (0 = Roll must be Max, 1 = Roll can be 1 lower than Max, etc)
  statRollerLeniency = 1
}
Darkmists.GlobalSettings = {}

-- =============================================================================
-- GLOBAL LINE DISPATCHER
-- =============================================================================

Darkmists.OnNewLine = function()
  -- Stat parsing (HP/mana/etc)
  if StatRoller and StatRoller.on_line then
    StatRoller.on_line(line)
  end

  if ItemTracker and ItemTracker.renderLineWithLinks then
    ItemTracker.renderLineWithLinks(line)
  end

  if dmapi and dmapi.core and dmapi.core.LineTrigger then
    dmapi.core.LineTrigger(line)
  end
  
end

-- =============================================================================
-- UI / HELPER STUFF
-- =============================================================================

Darkmists.LoadMapDat = function()
  Darkmists.Log("Darkmists Core",("Loading Map from: %s"):format(mapDatPath))
  loadMap(mapDatPath)
end

Darkmists.OpenItemViewer = function()
  itemViewerPath = itemViewerPath:gsub("\\", "/")
  openUrl("file:///" .. itemViewerPath)
end

Darkmists.OpenDMAPIDocs = function()
  -- normalize for Windows
  dmapiDocPath = dmapiDocPath:gsub("\\", "/")

  openUrl("file:///" .. dmapiDocPath)
end

Darkmists.OpenSettingsFile = function()
  -- normalize for Windows
  saveFilePath = saveFilePath:gsub("\\", "/")

  openUrl("file:///" .. saveFilePath)
  Darkmists.Log("Darkmists Core","Settings File Opened. After Editing, you must use LOAD SETTINGS!")
end

Darkmists.OpenWebsite = function()
  openUrl("https://darkmists.org")
end

Darkmists.getDefaultAdjLabelstyle = function()
  if Darkmists.GlobalSettings.lightMode then
    return [[
        background-color: #EEEEEE;
        border: 2px solid #111111;
    ]]
  else
    return [[
        background-color: #111111;
        border: 2px solid #666666;
    ]]
  end
end

Darkmists.getDefaultTextColor = function()
  if Darkmists.GlobalSettings.lightMode then
    return "black"
  else
    return "white"
  end
end

Darkmists.getDefaultXPosition = function()
  if Darkmists.GlobalSettings.panelsOnLeft then
    return "0%"
  else
    return tostring(100 - Darkmists.GlobalSettings.borders.right) .. "%"
  end
end

Darkmists.getDefaultBackgroundColor = function()
  if Darkmists.GlobalSettings.lightMode then
    return "white"
  else
    return "black"
  end
end

Darkmists.getDefaultTextColorTag = function()
  return ("<%s>"):format(Darkmists.getDefaultTextColor())
end

Darkmists.Log = function(pluginName,msg)
  local output = "\n<dim_gray>[<%s>%s<dim_gray>] <green>%s"
  output = output:format(Darkmists.getDefaultTextColor(),pluginName,msg)
  cecho(output)
end

Darkmists.LogDebug = function(pluginName,msg)
  local output = "\n[%s] %s"
  output = output:format(pluginName,msg)
  debugc(output)
end

Darkmists.SaveSettings = function()
  local settings = Darkmists.GlobalSettings
---@diagnostic disable-next-line: undefined-field
  table.save(saveFilePath,settings)
  Darkmists.Log("Darkmists Core",("Settings Saved To: %s!"):format(saveFilePath))
end

Darkmists.LoadSettings = function()
---@diagnostic disable-next-line: undefined-field
  if io.exists(saveFilePath) then
    local settings = {}
    ---@diagnostic disable-next-line: undefined-field
    table.load(saveFilePath,settings)
    DMUtil.deep_copy_into(Darkmists.GlobalSettings,settings)
    Darkmists.Log("Darkmists Core",("Settings Loaded From: %s!"):format(saveFilePath))
    Darkmists.Log("Darkmists Core","You may need to Reload UI for changes to take effect!")
  else
    Darkmists.Log("Darkmists Core","No Pre-Existing Settings File Found!")
  end
end

Darkmists.ApplyDefaultSettings = function()
  DMUtil.deep_copy_into(Darkmists.GlobalSettings,Darkmists.DefaultSettings)
  Darkmists.Log("Darkmists Core","Default Settings Applied!")
end

Darkmists.SetWindowBorderPercent = function(region,percent)
  local mainWidth, mainHeight = getMainWindowSize()
  if region == "top" or region == "bottom" then
    local scaleHeight = ((percent / 100.0) * mainHeight)
    if region == "top" then
      Darkmists.GlobalSettings.borders.top = percent
      setBorderTop(scaleHeight)
    elseif region == "bottom" then
      Darkmists.GlobalSettings.borders.bottom = percent
      setBorderBottom(scaleHeight)
    end
  elseif region == "left" or region == "right" then
    local scaleWidth = ((percent / 100.0) * mainWidth)
    if region == "left" then
      Darkmists.GlobalSettings.borders.left = percent
      setBorderLeft(scaleWidth)
    elseif region == "right" then
      Darkmists.GlobalSettings.borders.right = percent
      setBorderRight(scaleWidth)
    end
  end
  Darkmists.LogDebug("Darkmists Core","Window Borders Adjusted")
end

Darkmists.Init = function()
  Darkmists.Log("Darkmists Core",("Loaded Darkmists Core v%s"):format(Darkmists.VERSION))
  Darkmists.ApplyDefaultSettings()
  Darkmists.LoadSettings()
  for k, v in pairs(Darkmists.GlobalSettings.borders) do
    Darkmists.SetWindowBorderPercent(k,v)
  end
end

-- =============================================================================
-- LOAD ALL THE STUFF
-- =============================================================================

-- DMAPI first
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/util.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/dmapi.lua" )

-- NOW Call Init
Darkmists.Init()

-- Utility Scripts that use DMAPI
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/itemtracker.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/statroller.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapdestinations.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/skillups.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/clickables.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapcolor.lua" )

-- UI Scripts
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/statusbars.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/whowindow.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/chathistory.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/affectswindow.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/mapwindow.lua" )

-- Meta Help / Command
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/dm_meta.lua" )

echo("\nAll Scripts Loaded!\n")