-- =============================================================================
-- darkmists.lua
-- -----------------------------------------------------------------------------
-- Global glue file for Dark Mists automation.
--
-- Responsibilities:
--   • Central line dispatcher
--   • Persistent map destinations + goto command
--   • Persistent post-death command system
--   • Death event hook
--
-- Design philosophy:
--   - Dumb dispatcher, smart subsystems
--   - Persistence via append-only Lua files
--   - Explicit > clever
-- =============================================================================

Darkmists = {}

Darkmists.GlobalSettings = {
  -- should we use light mode?
  lightMode = false,
  -- what % of the screen should the main window take up
  mainWindowPanelWidth = 70,
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
  -- Pixel Height for Status Bars
  statusBarVitalsHeight = 32,
  -- Pixel Height for XP Bar
  statusBarXPHeight = 16,
  -- How often Affects Window is Updated
  affectsWindowUpdateIntervalSeconds = 2,
  -- How many characters to cut off Affect Name At
  affectsWindowAffectNameLength = 24,
  -- How many characters to cut off Affect Mod At
  affectsWindowAffectModLength = 16,
  -- Clickable Item Link Color (lua showColors(3) to see allowable colors)
  itemTrackerLinkColorDarkMode = "pale_goldenrod",
  -- Clickable Item Link Color (lua showColors(3) to see allowable colors)
  itemTrackerLinkColorLightMode = "dark_slate_blue",
  -- Stat Roller Leniancy (0 = Roll must be Max, 1 = Roll can be 1 lower than Max, etc)
  statRollerLeniency = 1
}

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

Darkmists.OpenItemViewer = function()
  local base = getMudletHomeDir()
  local path = base .. "/DarkMistsCompanion/assets/item-viewer.html"

  -- normalize for Windows
  path = path:gsub("\\", "/")

  openUrl("file:///" .. path)
end

Darkmists.OpenDMAPIDocs = function()
  local base = getMudletHomeDir()
  local path = base .. "/DarkMistsCompanion/assets/dmapi.html"

  -- normalize for Windows
  path = path:gsub("\\", "/")

  openUrl("file:///" .. path)
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

-- =============================================================================
-- LOAD ALL THE STUFF
-- =============================================================================
-- DMAPI first
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/util.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/dmapi.lua" )

-- Utility Scripts that use DMAPI
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/itemtracker.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/statroller.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapdestinations.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapcolor.lua" )

-- UI Scripts
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/statusbars.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/whowindow.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/chathistory.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/affectswindow.lua" )
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/mapwindow.lua" )

-- Meta Help / Command
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/dm_meta.lua" )

local mainWidth, mainHeight = getMainWindowSize()
local scaleWidth = (1.0-(Darkmists.GlobalSettings.mainWindowPanelWidth / 100.0)) * mainWidth
setBorderRight(scaleWidth)

echo("\nAll Scripts Loaded!\n")