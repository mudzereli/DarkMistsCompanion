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
  Darkmists.Log("Darkmists Core", ("Loading Map from: %s"):format(mapDatPath))
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
  local helperPath = getMudletHomeDir() .. "/DarkMistsCompanion/ui/framework/DMAlertWindow.lua"
  if not DMAlertWindow and io.exists(helperPath) then
    dofile(helperPath)
  end

  if DMAlertWindow and DMAlertWindow.Show then
    DMAlertWindow.Show("Warning: Load Packaged Map", function(win)
      cecho(win, "\n")
      cecho(win, "<red>Loading the packaged map will overwrite your current map in Mudlet.\n\n")
      cechoLink(win, "<dim_gray><u>[<green>Load Packaged Map<dim_gray>]",
        [[DMAlertWindow.Hide(); Darkmists.LoadMapDat()]],
        "Load the packaged map (may overwrite existing map)",
        true
      )
    end, { width = 560, height = 160 })
  else
    -- Fallback to original cecho block if helper unavailable
    cecho("\n\n")
    cecho("<orange>╔════════════════════════════════════════════════════════════╗\n")
    cecho("<orange>║<red>      Warning: loading the packaged map will overwrite      <orange>║\n")
    cecho("<orange>║<red>                your current map in Mudlet.                 <orange>║\n")
    cecho("<orange>║                    ")
    cechoLink("<dim_gray><u>[<green>Load Packaged Map<dim_gray>]",
      [[Darkmists.LoadMapDat()]],
      "Load the packaged map (may overwrite existing map)",
      true
    )
    cecho("                     <orange>║\n")
    cecho("<orange>╚════════════════════════════════════════════════════════════╝\n")
  end

  -- mark as shown to avoid prompting repeatedly and persist
  Darkmists.GlobalSettings.hasSeenMapPrompt = true
  Darkmists.SaveSettings()
end

-- Prompt the user before performing a UI reload (safe pathway)
function Darkmists.PromptSafeReload(opts)
  opts = opts or {}
  local helperPath = getMudletHomeDir() .. "/DarkMistsCompanion/ui/framework/DMAlertWindow.lua"
  if not DMAlertWindow and io.exists(helperPath) then
    dofile(helperPath)
  end

  local title = opts.title or "Reload UI"
  local body = opts.body or ([[
Reloading the UI will reset the Dark Mists interface and apply any pending layout or theme changes. If you have unsaved settings, save them first.

Click <green>Reload Now<r> to proceed, or close this panel to cancel.
  ]])

  if DMAlertWindow and DMAlertWindow.Show then
    DMAlertWindow.Show(title, function(win)
      cecho(win, "\n")
      cecho(win, body)
      cecho("\n\n")
      -- Use a string that hides the panel then defers the actual reload to avoid
      -- stale C++ callback references (safe pattern used elsewhere).
      cechoLink(win, "<dim_gray><u>[<green>Reload Now<dim_gray>]",
        [[DMAlertWindow.Hide(); tempTimer(0, 'Darkmists.SafeReload()')]],
        "Reload the UI (safe)", true
      )
    end, { width = opts.width or 640, height = opts.height or 200 })
  else
    -- Fallback to plain text / cecho with safe scheduling
    cecho("\n\n")
    cecho("<orange>╔════════════════════════════════════════╗\n")
    cecho("<orange>║<cadet_blue>         Reload Dark Mists UI?          <orange>║\n")
    cecho("<orange>║                                        ║\n")
    cecho("<orange>║              ")
    cechoLink("<dim_gray><u>[<green>Reload Now<dim_gray>]", [[tempTimer(0, 'Darkmists.SafeReload()')]], "Reload the UI", true)
    cecho("              <orange>║\n")
    cecho("<orange>╚════════════════════════════════════════╝\n")
    cecho("\n\n")
  end
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
  Darkmists.Log("Darkmists Core","Settings File Opened. After Editing, you must use LOAD SETTINGS!")
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
    Darkmists.Log("Darkmists Core", ("<red>Unknown update channel: %s"):format(tostring(channel)))
    return
  end
  Darkmists.GlobalSettings.updateChannel = channel
  Darkmists.SaveSettings()
  Darkmists.Log("Darkmists Core", ("Update channel set to: %s"):format(channel))
end

function Darkmists.UpdateFromGitHub(channel)
  channel = channel or Darkmists.GlobalSettings.updateChannel
  Darkmists.Log("Darkmists Core", ("Updating Dark Mists Companion from GitHub... (channel=%s)"):format(tostring(channel)))

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

function Darkmists.getDefaultTextColorTag()
  return ("<%s>"):format(Darkmists.getDefaultTextColor())
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
  Darkmists.Log("Darkmists Core","<red>Resetting incompatible UI layout cache...")

  local home = getMudletHomeDir()

  local targets = {
    home .. "/darkmists_global_settings.lua",
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
  Darkmists.Log("Darkmists Core","<orange>UI cache cleared.")
end

function Darkmists.ShowUIIntroMessage()
  if Darkmists.GlobalSettings.hasSeenUIIntroMessage then return end
  if not Darkmists.GlobalSettings.minimalMode then return end
  -- slight delay so login text finishes first
  tempTimer(1.5, function()
    -- lazily load framework helper if not already present (works in minimal mode)
    local helperPath = getMudletHomeDir() .. "/DarkMistsCompanion/ui/framework/DMAlertWindow.lua"
    if not DMAlertWindow and io.exists(helperPath) then
      dofile(helperPath)
    end

    if DMAlertWindow and DMAlertWindow.Show then
      DMAlertWindow.Show(("🔮 WELCOME TO DARK MISTS COMPANION — v%s"):format(tostring(Darkmists.VERSION or "unknown")), function(win)
        cecho(win, "\n")
        cecho(win, "<ansi_yellow> You are currently using Minimal UI Mode.\n\n")
        cecho(win, "<steel_blue> Enable the Full Interface to access:\n")
        cecho(win, "  <steel_blue>• Chat History Window\n")
        cecho(win, "  <steel_blue>• Who List Panel\n")
        cecho(win, "  <steel_blue>• Affect & Buff Duration Tracker\n")
        cecho(win, "  <steel_blue>• Player Status & Combat Panels\n")
        cecho(win, "  <steel_blue>• Dockable & Customizable UI Windows\n\n")
        cecho(win, "<steel_blue> Command: <green>dmc ui<steel_blue>\n")
        cecho(win, "<dim_gray> (Toggle command — turns UI <green>ON<dim_gray> or <red>OFF<dim_gray>)\n\n")
        cechoLink(win, "<dim_gray><u>[<green>ENABLE FULL UI NOW<dim_gray>]", [[Darkmists.EnableUI()]], "Enable the full Dark Mists Companion UI", true)
      end, { width = 640, height = 300 })
    else
      -- Fallback to original cecho block when helper unavailable
      cecho("\n")
      cecho("<gold>╔════════════════════════════════════════════════════════════╗\n")
      cecho(("<gold>║<cadet_blue> 🔮 WELCOME TO DARK MISTS COMPANION        %16s <gold>║\n"):format("v"..tostring(Darkmists.VERSION or "unknown")))
      cecho("<gold>╠════════════════════════════════════════════════════════════╣\n")
      cecho("<gold>║<ansi_yellow> You are currently using Minimal UI Mode.                   <gold>║\n")
      cecho("<gold>║                                                            ║\n")
      cecho("<gold>║<steel_blue> Enable the Full Interface to access:                       <gold>║\n")
      cecho("<gold>║   <steel_blue>• Chat History Window                                    <gold>║\n")
      cecho("<gold>║   <steel_blue>• Who List Panel                                         <gold>║\n")
      cecho("<gold>║   <steel_blue>• Affect & Buff Duration Tracker                         <gold>║\n")
      cecho("<gold>║   <steel_blue>• Player Status & Combat Panels                          <gold>║\n")
      cecho("<gold>║   <steel_blue>• Dockable & Customizable UI Windows                     <gold>║\n")
      cecho("<gold>║                                                            ║\n")
      cecho("<gold>╠════════════════════════════════════════════════════════════╣\n")
      cecho("<gold>║<steel_blue> Command: <green>dmc ui<steel_blue>                                            <gold>║\n")
      cecho("<gold>║<dim_gray> (Toggle command — turns UI <green>ON<dim_gray> or <red>OFF<dim_gray>)                      <gold>║\n")
      cecho("<gold>║                                                            ║\n")
      cecho("<gold>║ ")
      cechoLink("<dim_gray><u>[<green>ENABLE FULL UI NOW<dim_gray>]",
        [[Darkmists.EnableUI()]],
        "Enable the full Dark Mists Companion UI",
        true
      )
      cecho("                                       <gold>║\n")
      cecho("<gold>╚════════════════════════════════════════════════════════════╝\n\n")
    end

    -- persist that we've shown it once (user can close with X)
    Darkmists.GlobalSettings.hasSeenUIIntroMessage = true
    Darkmists.SaveSettings()

  end)
end

function Darkmists.HideUIIntroPanel()
  if DMAlertWindow and DMAlertWindow.Hide then
    pcall(DMAlertWindow.Hide)
    return
  end
  if not Darkmists.UIIntroPanel then return end
  local p = Darkmists.UIIntroPanel
  hideWindow(p.body)
  hideWindow(p.header)
  hideWindow(p.close)
  hideWindow(p.border)
end

function Darkmists.ApplyFirstRunUILayout()
  if Darkmists.GlobalSettings.hasInitializedUILayout then return end

  Darkmists.Log("Darkmists Core", "Applying first-run UI layout...")

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
  local output = "\n<dim_gray>[<%s>%s<dim_gray>] <slate_gray>%s"
  cecho(output:format(Darkmists.getDefaultTextColor(), pluginName, msg))
end

function Darkmists.LogDebug(pluginName, msg)
  debugc(("\n[%s] %s"):format(pluginName, msg))
end

function Darkmists.SaveSettings()
  Darkmists.GlobalSettings.layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION
  local settings = Darkmists.GlobalSettings
---@diagnostic disable-next-line: undefined-field
  table.save(saveFilePath, settings)
  Darkmists.Log("Darkmists Core", ("Settings Saved To: %s!"):format(saveFilePath))
end

function Darkmists.LoadSettings()
---@diagnostic disable-next-line: undefined-field
  if io.exists(saveFilePath) then
    local settings = {}
---@diagnostic disable-next-line: undefined-field
    table.load(saveFilePath, settings)

    -- Detect legacy settings BEFORE merging
    if settings.layoutCacheVersion == nil then
      Darkmists.Log("<medium_sea_green>Darkmists Core", "<red>Legacy settings detected (no layout version)")
      tempTimer(0,function ()
        Darkmists.ResetUILayoutCache()
        Darkmists.SafeReload()
      end)
      return
    end
    
    DMUtil.deep_copy_into(Darkmists.GlobalSettings, settings)
    Darkmists.Log("<medium_sea_green>Darkmists Core", ("<slate_gray>Settings Loaded From: <steel_blue>%s<r>"):format(saveFilePath))
    Darkmists.Log("<medium_sea_green>Darkmists Core","<slate_gray>You may need to Reload UI for changes to take effect!")
  else
    Darkmists.Log("<medium_sea_green>Darkmists Core","<slate_gray>No Pre-Existing Settings File Found!")
  end
end

function Darkmists.ApplyDefaultSettings()
  DMUtil.deep_copy_into(Darkmists.GlobalSettings, Darkmists.DefaultSettings)
  Darkmists.Log("<medium_sea_green>Darkmists Core","<slate_gray>Default Settings Applied!")
end

function Darkmists.SetWindowBorderPercent(region, percent)
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
    end

    tempTimer(0.4, applyResize)
  end)

  DarkmistsEvents.add("DarkmistsPackageUninstall","sysUninstallPackage",function (_,pkgName)
    if pkgName == Darkmists.NAME then
      Darkmists.Log("Darkmists Core", ("Package Uninstall Detected: %s"):format(tostring(pkgName)))
      Darkmists.CleanupUI({ uninstall = true })
    end
  end)
end

function Darkmists.SafeReload()
  Darkmists.Log("Darkmists Core","<red>Resetting Profile. UI Reload Incoming....")

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
  
  if opts.uninstall then
    Darkmists.Log("Darkmists Core", "Resetting window borders to default...")
    Darkmists.ResetUILayoutCache()
    tempTimer(0.5, function()
      setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0)
    end)
  end
end

function Darkmists.Init()
  Darkmists.Log("<medium_sea_green>Darkmists Core", ("<slate_gray>Loaded Darkmists Core <steel_blue>v%s<r>"):format(Darkmists.VERSION))
  Darkmists.ApplyDefaultSettings()
  Darkmists.LoadSettings()
  DarkmistsTheme.buildTheme()
  Darkmists.RegisterEvents()
  
  -- Layout cache compatibility check
  if Darkmists.GlobalSettings.layoutCacheVersion ~= Darkmists.LAYOUT_CACHE_VERSION then
      tempTimer(0,function ()
        Darkmists.ResetUILayoutCache()
        Darkmists.SafeReload()
      end)
    return
  end

  if Darkmists.GlobalSettings.minimalMode then
    setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0)
  else
    tempTimer(0, Darkmists.UpdateMainWindowWrap)
  end

  Darkmists.ShowUIIntroMessage()
end

function Darkmists.LoadUIScripts()
  if Darkmists.UI_LOADED then return end

  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/framework/GeyserAdjustableTabWindow.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/framework/DMTabFrame.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/statusbars.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/whowindow.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/chathistory.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/affectswindow.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/scorepanel.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/mapwindow.lua")
  dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapcolor.lua")
  Darkmists.UI_LOADED = true
  Darkmists.Log("Darkmists Core", "UI Scripts Loaded")
end

function Darkmists.EnableUI()
  if not Darkmists.GlobalSettings.minimalMode then return end
  -- closing any alert panels (same behavior as X)
  if DMAlertWindow and DMAlertWindow.Hide then pcall(DMAlertWindow.Hide) end

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

  Darkmists.Log("Darkmists Core", "UI Enabled")
end

function Darkmists.DisableUI()
  Darkmists.GlobalSettings.minimalMode = true
  Darkmists.SaveSettings()

  if DarkMistsMiniMap and DarkMistsMiniMap.container then
    DarkMistsMiniMap.container:hide()
    DarkMistsMiniMap.container:delete()
    DarkMistsMiniMap.container = nil
  end

  Darkmists.Log("Darkmists Core", "Switching to Minimal UI...")
  Darkmists.SafeReload()
end

-- =============================================================================
-- MODULE LOAD ORDER
-- =============================================================================
Darkmists.Init()

-- Utility Scripts that use DMAPI
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/itemtracker.lua")
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/statroller.lua")
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/mapdestinations.lua")
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/enchanterassist.lua")
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/skillups.lua")
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/utility/clickables.lua")
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/ui/buttonbar.lua")

-- UI Scripts
if not Darkmists.GlobalSettings.minimalMode then
  Darkmists.LoadUIScripts()
  tempTimer(0.4, function()
    Darkmists.RefreshUILayout({ syncStatusBar = true })
  end)
end

-- Meta Help / Command
dofile(getMudletHomeDir() .. "/DarkMistsCompanion/core/DarkMistsMeta.lua")

Darkmists.Log("Darkmists Core", "All Scripts Loaded!")