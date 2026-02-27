-- =============================================================================
-- darkmists.lua
-- -----------------------------------------------------------------------------
-- Global glue file for Dark Mists automation.
--
-- Responsibilities:
--   • Bootstrapping / load order orchestration
--   • Global settings management
--   • Central line dispatcher
--   • High-level utility entry points
--
-- Design philosophy:
--   - Dumb dispatcher, smart subsystems
--   - Persistence via append-only Lua files
--   - Explicit > clever
-- =============================================================================

-- Load foundational utilities first (no dependencies)
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/util.lua" )

local saveFilePath = getMudletHomeDir() .. "/darkmists_global_settings.lua"
local itemViewerPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/item-viewer.html"
local dmapiDocPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/dmapi.html"
local mapDatPath = getMudletHomeDir() .. "/DarkMistsCompanion/map.dat"
local eaConverterPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/ea-save-converter.html"

Darkmists = {}
Darkmists.NAME = "DarkMistsCompanion"
Darkmists.VERSION = "1.3.6"
Darkmists.GITHUB_URL = "https://github.com/mudzereli/DarkMistsCompanion/releases/latest/download/DarkMistsCompanion.mpackage"
Darkmists.IS_DEV_BUILD = true

Darkmists.DefaultSettings = {
  -- Use light mode UI theme?
  lightMode = false,
  -- Percentage of screen width allocated to the main window
  mainWindowPanelWidth = 70,
  -- Percentage of screen space reserved for each border region
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
  -- Place status bars inside an adjustable container
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
  -- Delete original Affect lines when running Score/Affect commands
  affectsWindowDeleteOriginalLines = false,
  -- Delete original Who lines when running Who command
  whoWindowDeleteOriginalLines = false,
  -- Stat Roller Leniancy (0 = Roll must be Max, 1 = Roll can be 1 lower than Max, etc)
  statRollerLeniency = 1
}
Darkmists.GlobalSettings = {}

-- =============================================================================
-- LOCAL HELPER FUNCTIONS
-- =============================================================================

local function ifLight(light, dark)
  return Darkmists.GlobalSettings.lightMode and light or dark
end

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

function Darkmists.LoadMapDat()
  Darkmists.Log("Darkmists Core",("Loading Map from: %s"):format(mapDatPath))
  loadMap(mapDatPath)
end

function Darkmists.OpenEAConverter()
  DMUtil.openLocalFile(eaConverterPath)
end

function Darkmists.OpenItemViewer()
  DMUtil.openLocalFile(itemViewerPath)
end

function Darkmists.OpenDMAPIDocs()
  DMUtil.openLocalFile(dmapiDocPath)
end

function Darkmists.OpenSettingsFile()
  DMUtil.openLocalFile(saveFilePath)
  Darkmists.Log("Darkmists Core","Settings File Opened. After Editing, you must use LOAD SETTINGS!")
end

Darkmists.OpenWebsite = function()
  openUrl("https://darkmists.org")
end

Darkmists.UpdateFromGitHub = function()
  if Darkmists.IS_DEV_BUILD then
    Darkmists.Log("Darkmists Core", "<red>Can not update DEV BUILD from GitHub!")
    return
  end
  
  Darkmists.Log("Darkmists Core", "Updating Dark Mists Companion from GitHub...")

  if table.contains(getPackages(), Darkmists.NAME) then
    uninstallPackage(Darkmists.NAME)

    tempTimer(2, function()
      installPackage(Darkmists.GITHUB_URL)
    end)
  else
    installPackage(Darkmists.GITHUB_URL)
  end
end

Darkmists.getDefaultAdjLabelstyle = function()
  return ifLight(
    [[background-color: #EEEEEE; border: 2px solid #111111;]],
    [[background-color: #111111; border: 2px solid #666666;]]
  )
end

Darkmists.getDefaultTextColor = function()
  return ifLight("black", "white")
end

Darkmists.getDefaultBackgroundColor = function()
  return ifLight("white", "black")
end

Darkmists.getDefaultXPosition = function()
  return tostring(100 - Darkmists.GlobalSettings.borders.right) .. "%"
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

Darkmists.SetWindowBorderPercent = function(region, percent)
  local mainWidth, mainHeight = getMainWindowSize()
  -- Determine whether we're working with height or width
  local isVertical = (region == "top" or region == "bottom")
  local baseSize = isVertical and mainHeight or mainWidth
  local scaledSize = (percent / 100) * baseSize
  -- Persist the percent value
  Darkmists.GlobalSettings.borders[region] = percent
  -- Apply the border
  if region == "top" then
    setBorderTop(scaledSize)
  elseif region == "bottom" then
    setBorderBottom(scaledSize)
  elseif region == "left" then
    setBorderLeft(scaledSize)
  elseif region == "right" then
    setBorderRight(scaledSize)
  end
  Darkmists.LogDebug("Darkmists Core", "Window Borders Adjusted")
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
-- MODULE LOAD ORDER
-- =============================================================================

-- DMAPI first
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/dmapi.lua" )

-- NOW Call Init
Darkmists.Init()

-- Utility Scripts that use DMAPI
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/itemtracker.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/statroller.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapdestinations.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/enchanterassist.lua" )
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