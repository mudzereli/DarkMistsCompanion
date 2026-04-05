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

local saveFilePath     = getMudletHomeDir() .. "/darkmists_global_settings.lua"
local itemViewerPath   = getMudletHomeDir() .. "/DarkMistsCompanion/assets/item-viewer.html"
local dmapiDocPath     = getMudletHomeDir() .. "/DarkMistsCompanion/assets/dmapi.html"
local mapDatPath       = getMudletHomeDir() .. "/DarkMistsCompanion/assets/map.dat"
local eaConverterPath  = getMudletHomeDir() .. "/DarkMistsCompanion/assets/ea-save-converter.html"
local eaFormulaParser  = getMudletHomeDir() .. "/DarkMistsCompanion/assets/alchemy-formula-parser.html"

Darkmists = Darkmists or {}
Darkmists.NAME = "DarkMistsCompanion"
Darkmists.VERSION = "@VERSION@"
Darkmists.GITHUB_URL_STABLE = "https://github.com/mudzereli/DarkMistsCompanion/releases/latest/download/DarkMistsCompanion.mpackage"
Darkmists.GITHUB_URL_BETA = "https://github.com/mudzereli/DarkMistsCompanion/raw/refs/heads/beta/build/DarkMistsCompanion.mpackage"
Darkmists.UI_LOADED = false
Darkmists.LAYOUT_CACHE_VERSION = "@VERSION@"
Darkmists.saveFilePath = saveFilePath
Darkmists._resizePending = false

Darkmists.DefaultSettings = {
  minimalMode = true, -- start with no extra UI
  -- Use light mode UI theme?
  lightMode = false,
  -- Percentage of screen space reserved for each border region
  borders = { top = 0, bottom = 0, left = 0, right = 0 },
  -- Font Size for additional Information Windows (Chat History, Who List, Affects)
  fontSize = 11,
  -- Font Face for additional Information Windows (Chat History, Who List, Affects)
  fontName = "Lucida Console",
  -- Colors for Status Bars (these are expressed in RGBA format which allows a wider variety of colors)
  statusBarColors = {
    hp    = { bar = "128,0,0,255",   backdrop = "32,0,0,255" },
    mn    = { bar = "0,0,128,255",   backdrop = "0,0,32,255" },
    mv    = { bar = "128,128,0,255", backdrop = "32,32,0,255" },
    enemy = { bar = "128,0,0,255",   backdrop = "32,0,0,255" },
    xp    = { bar = "128,64,0,255",  backdrop = "32,16,0,255" }
  },
  -- Font Color used on Status Bars (expressed in RGB format)
  statusBarFontColor = "255,255,255",
  -- Maximum Percentage of Screen Height to use for Status Bars
  statusBarTotalHeightPercent = 10,
  -- Place status bars inside an adjustable container
  statusBarsMoveable = true,
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
  statRollerLeniency = 1,
  -- First Run Flag (for Setting up default settings)
  hasInitializedUILayout = false,
  -- First Time Intro Message?
  hasSeenUIIntroMessage = false,
  -- Whether we've prompted to load the packaged map after enabling UI
  hasSeenMapPrompt = false,
  -- Update channel for GitHub installs: "stable" or "beta"
  updateChannel = "stable",
  -- Cached UI Version (changing this will invalidate settings)
  layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION,
}

Darkmists.GlobalSettings = Darkmists.GlobalSettings or {}

-- =============================================================================
-- LOCAL HELPER FUNCTIONS
-- =============================================================================

local function ifLight(light, dark)
  return Darkmists.GlobalSettings.lightMode and light or dark
end

-- =============================================================================
-- GLOBAL LINE DISPATCHER
-- =============================================================================

function Darkmists.OnNewLine()
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
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", ("Loading Map from: %s"):format(mapDatPath))
  loadMap(mapDatPath)
  -- post-load adjustments commonly expected after loading packaged map
  tempTimer(2,function()
    disableMapInfo("Full")
    disableMapInfo("Short")
    expandAlias("find prompt")
    expandAlias("map config speedwalk_delay 0.4")
    send("look")
  end)
end

-- Prompt the user before loading the packaged map (may overwrite their current map)
function Darkmists.PromptLoadMap()
  -- Prefer showing the packaged-map prompt in the reusable alert window.
  DMAlertWindow.Show("Warning: Load Packaged Map", function(win)
    cecho(win, "\n")
    cecho(win, DarkmistsTheme.badTag .. "Loading the packaged map will overwrite your current map in Mudlet.\n\n")
    cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "Load Packaged Map" .. DarkmistsTheme.mutedTag .. "]",
      [[DMAlertWindow.Hide(); Darkmists.LoadMapDat()]],
      "Load the packaged map (may overwrite existing map)",
      true
    )
  end, { width = 560, height = 160 })

  -- mark as shown to avoid prompting repeatedly and persist
  Darkmists.GlobalSettings.hasSeenMapPrompt = true
  Darkmists.SaveSettings()
end

-- Prompt the user before performing a UI reload (safe pathway)
function Darkmists.PromptSafeReload(opts)
  opts = opts or {}
  local title = opts.title or "Reload UI"
  local body = opts.body or (
    "Reloading the UI will reset the Dark Mists interface and apply any pending layout or theme changes. If you have unsaved settings, save them first.\n\n" ..
    DarkmistsTheme.goodTag .. "Reload Now<r>" .. " to proceed, or close this panel to cancel.\n  "
  )

  DMAlertWindow.Show(title, function(win)
    cecho(win, "\n")
    cecho(win, body)
    -- Use a string that hides the panel then defers the actual reload to avoid
    -- stale C++ callback references (safe pattern used elsewhere).
    cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "Reload Now" .. DarkmistsTheme.mutedTag .. "]",
      [[DMAlertWindow.Hide(); tempTimer(0, 'Darkmists.SafeReload()')]],
      "Reload the UI (safe)", true
    )
  end, { width = opts.width or 640, height = opts.height or 200 })
end

function Darkmists.OpenEAConverter()
  DMUtil.openLocalFile(eaConverterPath)
end

function Darkmists.OpenEAFormulaParser()
  DMUtil.openLocalFile(eaFormulaParser)
end

function Darkmists.OpenItemViewer()
  DMUtil.openLocalFile(itemViewerPath)
end

function Darkmists.OpenDMAPIDocs()
  DMUtil.openLocalFile(dmapiDocPath)
end

function Darkmists.OpenSettingsFile()
  DMUtil.openLocalFile(saveFilePath)
  DMLogger.notify("Darkmists Core","Settings File Opened. After Editing, you must use LOAD SETTINGS!")
end

function Darkmists.OpenWebsite()
  openUrl("https://darkmists.org")
end

function Darkmists.getGithubUrl(channel)
  channel = channel or Darkmists.GlobalSettings.updateChannel or "stable"
  if channel == "beta" then
    -- Beta URL: expects a release/tag named "beta" or adjust to your beta release URL
    return Darkmists.GITHUB_URL_BETA
  else
    -- Stable (latest release)
    return Darkmists.GITHUB_URL_STABLE
  end
end

function Darkmists.SetUpdateChannel(channel)
  if channel ~= "stable" and channel ~= "beta" then
    Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.badTag .. (("Unknown update channel: %s"):format(tostring(channel))))
    return
  end
  Darkmists.GlobalSettings.updateChannel = channel
  Darkmists.SaveSettings()
  DMLogger.notify(DarkmistsTheme.purpleTag .. "Darkmists Core", ("Update channel set to: %s"):format(channel))
end

function Darkmists.UpdateFromGitHub(channel)
  channel = channel or Darkmists.GlobalSettings.updateChannel
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", ("Updating Dark Mists Companion from GitHub... (channel=%s)"):format(tostring(channel)))

  local url = Darkmists.getGithubUrl(channel)
  
  if table.contains(getPackages(), Darkmists.NAME) then
    uninstallPackage(Darkmists.NAME)
    tempTimer(2, function()
      installPackage(url)
    end)
  else
    installPackage(url)
  end
end

function Darkmists.getDefaultAdjLabelstyle()
  return ifLight(
    [[background-color: #EEEEEE; border: 2px solid #111111;]],
    [[background-color: #111111; border: 2px solid #666666;]]
  )
end

function Darkmists.getDefaultTextColor()
  return ifLight("black", "white")
end

function Darkmists.getDefaultBackgroundColor()
  return ifLight("white", "black")
end

function Darkmists.GetBorderPercentages()
  local px = getBorderSizes()
  local winW, winH = getMainWindowSize()

  return {
    left   = (px.left   / winW) * 100,
    right  = (px.right  / winW) * 100,
    top    = (px.top    / winH) * 100,
    bottom = (px.bottom / winH) * 100
  }
end

function Darkmists.ResetUILayoutCache()
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.badTag .. "Resetting incompatible UI layout cache...")

  local home = getMudletHomeDir()

  local targets = {
    home .. "/AdjustableContainer",
    home .. "/AdjustableTabWindow",
  }

  for _, path in ipairs(targets) do
    if io.exists(path) then
      local attr = lfs.attributes(path)
      if attr and attr.mode == "directory" then
        for file in lfs.dir(path) do
          if file ~= "." and file ~= ".." then
            os.remove(path .. "/" .. file)
          end
        end
        lfs.rmdir(path)
      else
        os.remove(path)
      end
    end
  end

  setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0);
  -- update stored layout cache version so we don't repeatedly trigger a reset
  Darkmists.GlobalSettings.layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION
  Darkmists.SaveSettings()
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.warnTag .. "UI cache cleared.")

  -- Rebuild theme and refresh layout so UI colors/styles are applied after
  -- resetting the layout cache. Use pcall to avoid hard failures during reset.
  if DarkmistsTheme and DarkmistsTheme.buildTheme then
    pcall(DarkmistsTheme.buildTheme)
  end
  pcall(Darkmists.RefreshUILayout, { syncStatusBar = true })
end

function Darkmists.ShowUIIntroMessage(force)
  -- when `force` is truthy, bypass the first-run and minimal-mode guards
  if not force and Darkmists.GlobalSettings.hasSeenUIIntroMessage then return end
  if not force and not Darkmists.GlobalSettings.minimalMode then return end
  -- slight delay so login text finishes first
  tempTimer(force and 0 or 1.5, function()
    local isMinimal = Darkmists.GlobalSettings and Darkmists.GlobalSettings.minimalMode
    local title = ("🔮 DARK MISTS COMPANION — v%s"):format(tostring(Darkmists.VERSION or "unknown"))
    DMAlertWindow.Show(title, function(win)
      cecho(win, "\n")
        if isMinimal then
          cecho(win, DarkmistsTheme.yellowTag .. " You are currently using Minimal UI Mode.\n\n")
        else
          cecho(win, DarkmistsTheme.yellowTag .. " You are currently using Full UI Mode.\n\n")
        end

        cecho(win, DarkmistsTheme.infoTag .. " Full UI provides:\n")
        cecho(win, "  " .. DarkmistsTheme.infoTag .. "• Chat History Window\n")
        cecho(win, "  " .. DarkmistsTheme.infoTag .. "• Who List Panel\n")
        cecho(win, "  " .. DarkmistsTheme.infoTag .. "• Affect & Buff Duration Tracker\n")
        cecho(win, "  " .. DarkmistsTheme.infoTag .. "• Player Status & Combat Panels\n")
        cecho(win, "  " .. DarkmistsTheme.infoTag .. "• Dockable & Customizable UI Windows\n\n")

        if isMinimal then
          cecho(win, DarkmistsTheme.infoTag .. " Command: " .. DarkmistsTheme.goodTag .. "dmc ui" .. DarkmistsTheme.infoTag .. "\n")
          cecho(win, DarkmistsTheme.mutedTag .. " (Toggle command — turns UI " .. DarkmistsTheme.goodTag .. "ON" .. DarkmistsTheme.mutedTag .. " or " .. DarkmistsTheme.badTag .. "OFF" .. DarkmistsTheme.mutedTag .. ")\n\n")
          cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "ENABLE FULL UI NOW" .. DarkmistsTheme.mutedTag .. "]",
            [[Darkmists.GlobalSettings.hasSeenUIIntroMessage = true; Darkmists.SaveSettings(); Darkmists.EnableUI()]],
            "Enable the full Dark Mists Companion UI", true)
        else
          cecho(win, DarkmistsTheme.mutedTag .. " Click to switch back to Minimal UI.\n\n")
          cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.badTag .. "DISABLE FULL UI NOW" .. DarkmistsTheme.mutedTag .. "]",
            [[Darkmists.GlobalSettings.hasSeenUIIntroMessage = true; Darkmists.SaveSettings(); Darkmists.DisableUI()]],
            "Switch to minimal UI", true)
        end
    end, { width = 640, height = 300,
      onClose = function()
        Darkmists.GlobalSettings.hasSeenUIIntroMessage = true
        Darkmists.SaveSettings()
      end
    })

    -- Persisting the "seen" flag is deferred until the user explicitly clicks
    -- the Enable/Disable action in the panel so closing the panel does NOT
    -- mark the intro as seen.

  end)
end

function Darkmists.HideUIIntroPanel()
  DMAlertWindow.Hide()
end

function Darkmists.ApplyFirstRunUILayout()
  if Darkmists.GlobalSettings.hasInitializedUILayout then return end

  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "Applying first-run UI layout...")

  -- Default dock: right 30%
  Darkmists.SetWindowBorderPercent("right", 30)

  Darkmists.GlobalSettings.hasInitializedUILayout = true
  Darkmists.SaveSettings()
end

function Darkmists.getSmartDockGeometry()
  local borders = Darkmists.GlobalSettings.borders
  local left  = borders.left  or 0
  local right = borders.right or 0

  if right >= left then
    -- Dock Right
    return {
      side  = "right",
      x     = tostring(100 - right) .. "%",
      width = tostring(right) .. "%"
    }
  else
    -- Dock Left
    return {
      side  = "left",
      x     = "0%",
      width = tostring(left) .. "%"
    }
  end
end

function Darkmists.createTabPanel(id, title, tabName)
  return Adjustable.Container:new({
    name = id,
    x = 0, y = 0,
    width = "100%", height = "100%",
    titleText = title,
    titleTxtColor = Darkmists.getDefaultTextColor(),
    padding = 8,
    adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
    lockStyle = "full",
    locked = true,
    autoSave = false,
    autoLoad = false,
  }, DMTabs[tabName .. "center"])
end

function Darkmists.Log(pluginName, msg)
  pcall(DMLogger.log, pluginName, msg)
end

function Darkmists.SaveSettings()
  Darkmists.GlobalSettings.layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION
  local settings = Darkmists.GlobalSettings
---@diagnostic disable-next-line: undefined-field
  table.save(saveFilePath, settings)
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", ("Settings Saved To: %s%s!"):format(DarkmistsTheme.infoTag, saveFilePath))
end

function Darkmists.LoadSettings()
---@diagnostic disable-next-line: undefined-field
  if io.exists(saveFilePath) then
    local settings = {}
---@diagnostic disable-next-line: undefined-field
    table.load(saveFilePath, settings)

    -- Merge settings (preserve values even if layoutCacheVersion missing)
    DMUtil.deep_copy_into(Darkmists.GlobalSettings, settings)
    Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", (DarkmistsTheme.mutedTag .. "Settings Loaded From: " .. DarkmistsTheme.infoTag .. "%s<r>"):format(saveFilePath))
    Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.mutedTag .. "You may need to Reload UI for changes to take effect!")
    -- return true indicating a settings file existed
    return true
  else
    Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.mutedTag .. "No Pre-Existing Settings File Found!")
    return false
  end
end

function Darkmists.ApplyDefaultSettings()
  DMUtil.deep_copy_into(Darkmists.GlobalSettings, Darkmists.DefaultSettings)
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.mutedTag .. "Default Settings Applied!")
end

function Darkmists.SetWindowBorderPercent(region, percent)
  local mainWidth, mainHeight = getMainWindowSize()
  -- Determine whether we're working with height or width
  local isVertical = (region == "top" or region == "bottom")
  local baseSize = isVertical and mainHeight or mainWidth
  local scaledSize = (percent / 100) * baseSize
  -- Only apply and log if the stored percent actually changed
  local prev = (Darkmists.GlobalSettings.borders and Darkmists.GlobalSettings.borders[region]) or 0
  if prev == percent then
    return
  end

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

  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "Window Borders Adjusted")
end

function Darkmists.UpdateMainWindowWrap()
  local mainWidth = getMainWindowSize()
  local borders = getBorderSizes()
  local usableWidth = math.floor(mainWidth - (borders.left or 0) - (borders.right or 0))
  local charWidth = select(1, calcFontSize("main"))

  if (not charWidth or charWidth <= 0) and Darkmists.GlobalSettings.fontSize then
    charWidth = select(1, calcFontSize(
      Darkmists.GlobalSettings.fontSize,
      Darkmists.GlobalSettings.fontName
    ))
  end

  if usableWidth > 0 and charWidth and charWidth > 0 then
    local wrapAt = math.max(20, math.floor(usableWidth / charWidth) - 2)
    setWindowWrap("main", wrapAt)
  end
end

function Darkmists.RefreshUILayout(opts)
  opts = opts or {}

  if Darkmists.GlobalSettings.minimalMode then
    Darkmists.UpdateMainWindowWrap()
    return
  end

  if opts.syncStatusBar and StatusBar and StatusBar.syncToBorders and not StatusBar._layoutLock then
    StatusBar.syncToBorders()
  end

  tempTimer(0, Darkmists.UpdateMainWindowWrap)
end

function Darkmists.RegisterEvents()
  DarkmistsEvents.add("DarkmistsWindowResize", "sysWindowResizeEvent", function()
    if Darkmists._resizePending then return end

    Darkmists._resizePending = true

    local function applyResize()
      if StatusBar and StatusBar._layoutLock then
        tempTimer(0.1, applyResize)
        return
      end

      Darkmists._resizePending = false
      Darkmists.RefreshUILayout({ syncStatusBar = true })
    end

    tempTimer(0.4, applyResize)
  end)
  
  local function RickRollASCII()
    DMAlertWindow.Show("You have become Immortalized!", function(win)
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣤⢤⣤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣶⠛⡏⠀⠀⠉⠀⠀⠉⢻⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣠⣦⣤⣄⢀⣀⡀⠀⢸⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⠀⡟⠉⠙⣿⠀⠙⠛⠛⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⡀⡇⠀⡴⠒⠒⠀⠀⢀⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣇⠈⠉⠁⠐⠆⣠⠞⠉⠀⠀⠀⠀⠀⢢⡀⠀⠀⠀⠋⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⠋⣽⠾⢷⣶⣤⡤⠖⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠈⠀⠀⠤⣎⣀⣾⡟⠄⠀⠀⠀⠀⣠⠋⣿⣦⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠠⠊⠉⢉⣭⣿⡇⠀⣟⣶⣶⡀⣠⠞⠁⢸⣿⣿⣿⣿⣿⣷⣶⣶⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⢀⣤⣶⣽⣿⣿⣿⣿⠀⢀⡇⢸⣿⠋⠁⠀⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⢀⣟⣓⣒⢴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠻⣿⣻⢨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠆⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣒⡃⠀⠿⠯⢽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⡯⠅⠀⠯⣍⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀")
        echo(win,"\n⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⣽⣿⣛⣳⣿⣿⣿⣿⢶⣭⠉⠉⠉⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀")
        echo(win,"\n⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣗⣺⣿⠶⣽⣿⣿⣿⣿⣿⠀⣀⣀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆")
        echo(win,"\n⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⣿⣭⣿⣿⣿⣿⣿⣿⣯⣁⣀⡀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇")
        echo(win,"\n⢸⣿⣿⣿⣿⡿⠿⠿⢿⣻⣿⣯⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿")
        echo(win,"\n⠀⢻⣿⣟⣥⠐⠢⠤⠤⢿⣿⣓⣿⣺⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠃")
        echo(win,"\n⠀⠘⣿⣿⣿⡆⢒⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠉⠉⠉⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠈⠙⢿⣿⣮⣽⣿⣿⣿⡶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠈⠂⠀⠈⠉⣿⣿⣿⠿⣷⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\n⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⠀⢸⠛⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀")
        echo(win,"\nNever gonna give you up...             ")
        echo(win,"\n            Never gonna let you down...")
        cechoLink(win, "\n\n" .. DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.redTag .. "Go back to DM" .. DarkmistsTheme.mutedTag .. "]",
          [[DMAlertWindow.Hide(); stopSounds(); ASCENDING = false;]],
          "Go back to DM", true)
    end, { width = 450, height = 600 })

    local soundPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/sounds/ascension.mp3"

    -- Normalize slashes (safety for Windows)
    soundPath = soundPath:gsub("\\", "/")

    playSoundFile({
      name = soundPath,
      volume = 75,
      priority = 75,
      tag = "ascension_sound"
    })

    tempTimer(8,function ()
      stopSounds()
      ASCENDING = false
    end)
  end

  ASCENDING = false
  DarkmistsEvents.add("DarkmistsImmortalButton","dmapi.world.enter",function()
    ButtonBar:addButton("🔱 Make Me Immortal", function()
      if ASCENDING then return end
      ASCENDING = true
      local t = 2.5
      local events = {
        {0,  DarkmistsTheme.goodTag,   "You step into the Circle of Ascension."},
        {t*1,  DarkmistsTheme.accentTag, "Ancient sigils flare to life beneath your feet."},
        {t*2,  DarkmistsTheme.textTag,   "A low chant echoes from unseen voices beyond the veil."},
        {t*3,  DarkmistsTheme.warnTag,   "The air grows heavy with the weight of old magic."},
        {t*4, DarkmistsTheme.infoTag,   "Starlight gathers above, spiraling toward your mortal form."},
        {t*5, DarkmistsTheme.badTag,    "The heavens tremble as the gates of eternity begin to open."},
        {t*6, DarkmistsTheme.textTag,   "A timeless voice intones: <b>'So it shall be.'"},
        {t*7, DarkmistsTheme.goodTag,   "Your soul rises beyond the bounds of flesh..."},
        {t*8, DarkmistsTheme.accentTag, "🎶 The Song of Immortality begins to play... 🎶"},
      }

      for _, ev in ipairs(events) do
        local d, tag, msg = ev[1], ev[2], ev[3]
        tempTimer(d, function()
          cecho("\n" .. tag .. msg .. "\n")
        end)
      end

      tempTimer(t*8, function()
        send("yell I am a T-t-troll!")
        RickRollASCII()
      end)

    end)
  end,true)

  -- Hook into dmapi events so we can show the packaged-map prompt after a world enter
  -- Mark a pending flag when the world enter event fires (DMAPI's reset handler will send 'score')
  DarkmistsEvents.add("Darkmists.map.prompt.pending", "dmapi.world.enter", function()
    Darkmists._pendingMapPrompt = true
  end)

-- After vitals update (score processed), if a pending prompt exists show the map prompt
  DarkmistsEvents.add("Darkmists.map.prompt.aftervitals", "dmapi.player.vitals.updated", function()
    if Darkmists._pendingMapPrompt then
      -- only show the packaged-map prompt when the full UI is loaded and enabled
      if Darkmists.UI_LOADED and not Darkmists.GlobalSettings.minimalMode and Darkmists.GlobalSettings.hasSeenUIIntroMessage then
        Darkmists._pendingMapPrompt = false
        if not Darkmists.GlobalSettings.hasSeenMapPrompt then
          tempTimer(2, function()
            if not Darkmists.GlobalSettings.hasSeenMapPrompt then
              Darkmists.PromptLoadMap()
            end
          end)
        end
      else
        -- keep pending; EnableUI() or later vitals update will handle it
        Darkmists._pendingMapPrompt = true
      end
    end
  end)

  DarkmistsEvents.add("DarkmistsPackageUninstall","sysUninstallPackage",function (_,pkgName)
    if pkgName == Darkmists.NAME then
      Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", ("Package Uninstall Detected: %s"):format(tostring(pkgName)))
      Darkmists.CleanupUI({ uninstall = true })
    end
  end)

  -- When the package is installed, perform a single, guarded resetProfile() to
  -- ensure the package has a clean runtime state. Use a short delay so the
  -- installer finishes and set a session-only guard to avoid loops.
  DarkmistsEvents.add("DarkmistsPackageInstall","sysInstallPackage",function (_,pkgName)
    if pkgName == Darkmists.NAME then
      -- Use a persisted flag because in-memory state is wiped by resetProfile().
      if Darkmists.GlobalSettings._installResetDone then return end
      Darkmists.GlobalSettings._installResetDone = true
      Darkmists.SaveSettings()
      tempTimer(1, function()
        Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", ("%sPackage Install Detected: %s — performing safe reset"):format(DarkmistsTheme.warnTag, tostring(pkgName)))
        pcall(resetProfile)
      end)
    end
  end)
end

function Darkmists.SafeReload()
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", DarkmistsTheme.badTag .. "Resetting Profile. UI Reload Incoming....")

  Darkmists.CleanupUI()

  clearWindow()
  resetProfile()
end


function Darkmists.CleanupUI(opts)
  opts = opts or {}
  if DarkmistsAlias and DarkmistsAlias.clearAll then pcall(DarkmistsAlias.clearAll) end
  if DarkmistsEvents and DarkmistsEvents.clearAll then pcall(DarkmistsEvents.clearAll) end

  if DMTabs and DMTabs.destroy then pcall(DMTabs.destroy) end
  if DarkMistsMiniMap and DarkMistsMiniMap.destroy then pcall(DarkMistsMiniMap.destroy) end
  if ButtonBar and ButtonBar.destroy then pcall(ButtonBar.destroy) end
  if StatusBar and StatusBar.cleanup then pcall(StatusBar.cleanup) end
  if DMAlertWindow and DMAlertWindow.Hide then pcall(DMAlertWindow.Hide) end
  if StatRoller and StatRoller.destroy then pcall(StatRoller.destroy) end
  if AffectsWindow and AffectsWindow.destroy then pcall(AffectsWindow.destroy) end

  if opts.uninstall then
    Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "Resetting window borders to default...")
    Darkmists.ResetUILayoutCache()
    tempTimer(0.5, function()
      setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0)
    end)
  end
end

function Darkmists.LoadUIScripts()
  if Darkmists.UI_LOADED then return end
  DMLogger.show()

  DMTabFrame.init()
  StatusBar.init()
  WhoWindow.init()
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/chathistory.lua")
  AffectsWindow.init()
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/scorepanel.lua")
  DarkMistsMiniMap.init()
  MapColors.init()
  
  -- Initialize optional UI modules that need runtime context (e.g., connection state)
  if DarkMistsMiniMap and DarkMistsMiniMap.Init then
    pcall(DarkMistsMiniMap.Init)
  end

  Darkmists.UI_LOADED = true
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "UI Scripts Loaded")
end

function Darkmists.EnableUI()
  if not Darkmists.GlobalSettings.minimalMode then return end
  -- closing any alert panels (same behavior as X)
  DMAlertWindow.Hide()

  Darkmists.GlobalSettings.minimalMode = false
  Darkmists.SaveSettings()

  -- Load UI if not already loaded
  Darkmists.ApplyFirstRunUILayout()
  Darkmists.LoadUIScripts()

  -- Apply borders
  Darkmists.RefreshUILayout({ syncStatusBar = true })

  -- Defer the packaged-map prompt: if DMAPI is available, set pending and
  -- let the DMAPI vitals handler show it after score; otherwise fall back
  -- to a simple delayed prompt so manual enables still get prompted.
  if dmapi then
    Darkmists._pendingMapPrompt = true
  else
    tempTimer(0.8, function()
      if not Darkmists.GlobalSettings.hasSeenMapPrompt then
        Darkmists.PromptLoadMap()
      end
    end)
  end

  tempTimer(1, function() DMLogger.hide() end)
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "UI Enabled")
end

function Darkmists.DisableUI()
  Darkmists.GlobalSettings.minimalMode = true
  Darkmists.SaveSettings()

  if DarkMistsMiniMap and DarkMistsMiniMap.container then
    DarkMistsMiniMap.container:hide()
    DarkMistsMiniMap.container:delete()
    DarkMistsMiniMap.container = nil
  end

  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "Switching to Minimal UI...")
  Darkmists.SafeReload()
end

function Darkmists.Init()
  DMLogger.create()
  DMLogger.show()
  DMLogger.log(DarkmistsTheme.purpleTag .. "Darkmists Core", (DarkmistsTheme.mutedTag .. "Initializing Darkmists Core " .. DarkmistsTheme.infoTag .. "v%s<r>"):format(Darkmists.VERSION))
  dmapi.init()
  local hadSettings = Darkmists.LoadSettings()
  -- If we previously persisted the one-shot install-reset guard, clear it now
  -- so future installs will be able to trigger the guarded reset again.
  if Darkmists.GlobalSettings._installResetDone then
    Darkmists.GlobalSettings._installResetDone = nil
    Darkmists.SaveSettings()
    Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core", "Cleared one-time install reset guard from settings.")
  end
  DarkmistsTheme.buildTheme()
  Darkmists.RegisterEvents()
  -- Version-based settings policy:
  -- If a saved settings file existed and its stored layout version matches the
  -- current package version, keep the user's settings. Otherwise (no saved
  -- settings, or a mismatched version), remove the saved file, apply defaults
  -- and persist defaults so the package starts clean for the new version.
  if hadSettings and Darkmists.GlobalSettings.layoutCacheVersion == Darkmists.LAYOUT_CACHE_VERSION then
    -- same version: keep loaded settings
  else
    -- version mismatch or no settings: remove any existing saved file and reset
    if io.exists(saveFilePath) then
      pcall(os.remove, saveFilePath)
    end
    Darkmists.ApplyDefaultSettings()
    Darkmists.GlobalSettings.layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION
    Darkmists.SaveSettings()
    -- Reset UI layout cache to avoid stale UI artifacts from previous versions
    Darkmists.ResetUILayoutCache()
  end

  if Darkmists.GlobalSettings.minimalMode then
    setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0)
  else
    tempTimer(0, Darkmists.UpdateMainWindowWrap)
  end

  Darkmists.ShowUIIntroMessage()
  -- checkBackgroundContrast is called here so it queues after the intro alert,
  -- never inside buildTheme() which may be called multiple times
  DarkmistsTheme.checkBackgroundContrast()

  -- Utility Scripts that use DMAPI
  ItemTracker.init()
  StatRoller.init()
  MapDestinations.load()
  EnchanterAssist.init()
  SkillUps.init()
  DMClickables.init()
  ButtonBar.init()

  -- UI Scripts
  if not Darkmists.GlobalSettings.minimalMode then
    Darkmists.LoadUIScripts()
    tempTimer(0.4, function()
      Darkmists.RefreshUILayout({ syncStatusBar = true })
    end)
  end

  -- Meta Help / Command
  DarkMistsMeta.init()

  tempTimer(1, function() DMLogger.hide() end)
  DMLogger.notify(DarkmistsTheme.purpleTag .. "Darkmists Core", (DarkmistsTheme.mutedTag .. "Loaded Darkmists Core " .. DarkmistsTheme.infoTag .. "v%s<r>"):format(Darkmists.VERSION))
end

-- =============================================================================
-- MODULE LOAD ORDER
-- =============================================================================
tempTimer(1, function() Darkmists.Init() end)