-- =============================================================================
-- darkmists.lua
-- -----------------------------------------------------------------------------
-- Global glue file for Dark Mists automation.
--
-- == EXECUTION MODEL ==========================================================
--
-- 1. Script loads (package install / Mudlet startup)
--    • Runs top-level code immediately: sets constants, Darkmists.DefaultSettings
--    • Queues tempTimer(1, Darkmists.Init)  — everything else is deferred
--
-- 2. Darkmists.Init() fires at t=1s and delegates to DarkmistsStartup
--    • DMLogger.create — hidden logging infrastructure
--    • prepare() — initializes DMAPI, loads settings, builds the theme, and
--      registers core events
--       - sysWindowResizeEvent
--       - dmapi.world.enter → sets _pendingMapPrompt = true
--       - dmapi.player.vitals.updated → may call PromptLoadMap()
--       - sysUninstallPackage
--    • prepare() version check:
--       - If saved version matches LAYOUT_CACHE_VERSION → keep settings
--       - If mismatch or no file → delete save, apply defaults, reset UI cache,
--         and schedule tempTimer(1, resetProfile)
--    • configureRuntime() — applies borders and theme contrast checks
--    • initializeModules() — starts utility modules and optional BaseUI hiding
--    • initializeUI() — loads the full UI when not in minimal mode
--    • finalize() — initializes metadata and reconciles an already-online session
--
-- 3. Login sequence (user connects, auto-login)
--    • MUD sends welcome message → dmapi.world.enter fired
--       - dmapi handler: after setup, sends "", "", "score"
--       - Darkmists handler: sets _pendingMapPrompt = true
--    • "score" response parsed → dmapi.player.vitals.updated fired
--       - If _pendingMapPrompt, UI_LOADED, !minimalMode, hasSeenUIIntroMessage
--         → tempTimer(2, PromptLoadMap) → shows the bundled-map choice alert
--       - Load choice → LoadMapDat() → loadMap() + 2s timer → send("look")
--       - Keep / Ask Later / close leave the current map untouched
--
-- 4. Event-driven thereafter
--    • sysWindowResizeEvent → debounced RefreshUILayout
--    • sysUninstallPackage → CleanupUI({uninstall=true})
--    • User commands (dmapi, dmc ui, etc.) dispatched via aliases
--
-- == KEY TIMING DEPENDENCIES ==================================================
--
-- • dmapi.init() MUST run before Darkmists.RegisterEvents() because Darkmists'
--   handlers listen to dmapi.* events. Order is correct currently.
-- • Utility modules (ItemTracker, StatRoller, etc.) init AFTER events registered,
--   so their first on_line call may miss the first few lines of output.
-- • ShowUIIntroMessage opens only after an explicit Button Bar action.
--
-- == VERSION / SAVE RESET BEHAVIOR ============================================
--
-- • Darkmists.LAYOUT_CACHE_VERSION = "1.5.1" must be bumped on layout-breaking
--   changes to force old saved settings/Ui cache to be wiped.
-- • On version mismatch: save file deleted → defaults applied → saved with new
--   version → ResetUILayoutCache() resets container layouts + TabWindow state
--   → tempTimer(1, resetProfile) reloads the profile.
-- • ⚠ resetProfile() mid-game disconnects the user. This path is intended for
--   version upgrades only, not routine reconnects.
--
-- == DESIGN PHILOSOPHY ========================================================
--   - Dumb dispatcher, smart subsystems
--   - Persistence via append-only Lua files
--   - Explicit > clever
-- =============================================================================

local saveFilePath      = getMudletHomeDir() .. "/darkmists_global_settings.lua"
local itemViewerPath    = getMudletHomeDir() .. "/DarkMistsCompanion/assets/item-viewer.html"
local dmapiDocPath      = getMudletHomeDir() .. "/DarkMistsCompanion/assets/dmapi.html"
local mapDatPath        = getMudletHomeDir() .. "/DarkMistsCompanion/assets/map.dat"
local eaConverterPath   = getMudletHomeDir() .. "/DarkMistsCompanion/assets/ea-save-converter.html"
local eaFormulaParser   = getMudletHomeDir() .. "/DarkMistsCompanion/assets/alchemy-formula-parser.html"
local lineFormatterPath = getMudletHomeDir() .. "/DarkMistsCompanion/assets/line-formatter.html"

Darkmists = {}
Darkmists.NAME = "DarkMistsCompanion"
Darkmists.VERSION = "@VERSION@"
Darkmists.GITHUB_URL_STABLE = "https://github.com/mudzereli/DarkMistsCompanion/releases/latest/download/DarkMistsCompanion.mpackage"
Darkmists.GITHUB_URL_BETA = "https://github.com/mudzereli/DarkMistsCompanion/raw/refs/heads/beta/build/DarkMistsCompanion.mpackage"
Darkmists.UI_LOADED = false
Darkmists.LAYOUT_CACHE_VERSION = "1.5.1" -- bump this when making layout-breaking changes to force a cache reset
Darkmists.saveFilePath = saveFilePath
Darkmists._resizePending = false

Darkmists.DefaultSettings = {
  minimalMode = true, -- start with no extra UI
  -- Use light mode UI theme?
  lightMode = false,
  -- Percentage of screen space reserved for each border region
  borders = { top = 0, bottom = 0, left = 0, right = 0 },
  -- Font Size for additional Information Windows (Chat History, Who List, Affects)
  fontSize = math.ceil(getFontSize()*0.75),--11,
  -- Font Size for the DMTabFrame tab labels (px)
  tabFontSize = DMConstants.TAB_FONT_DEFAULT_PX,
  -- Font Face for additional Information Windows (Chat History, Who List, Affects)
  fontName = getFont(),
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
  -- How often Affects Window is Updated
  affectsWindowUpdateIntervalSeconds = 2,
  -- How many characters to cut off Affect Name At
  affectsWindowAffectNameLength = 20,
  -- How many characters to cut off Affect Mod At
  affectsWindowAffectModLength = 16,
  -- Spam prevention threshold before fallback/deny triggers
  spamThreshold = 24,
  -- Spam prevention settings
  spamEnabled = true,
  spamMinLength = 3,
  -- Optional fallback command sent when spam threshold is reached
  spamFallbackCommand = "save",
  -- Clickable Item Link Color (lua showColors(3) to see allowable colors)
  itemTrackerLinkColorDarkMode = "PaleGoldenrod",
  -- Clickable Item Link Color (lua showColors(3) to see allowable colors)
  itemTrackerLinkColorLightMode = "DarkSlateBlue",
  -- Delete original Affect lines when running Score/Affect commands
  affectsWindowDeleteOriginalLines = false,
  -- Delete original Who lines when running Who command
  whoWindowDeleteOriginalLines = false,
  -- Chat and skill history limits
  chatHistoryMaxMessages = 100,
  skillUpsMaxEntries = 50,
  skillUpsDisplayMode = "main",
  -- Stat Roller Leniency (0 = Roll must be Max, 1 = Roll can be 1 lower than Max, etc)
  statRollerLeniency = 1,
  statRollerCalibrationLines = 20,
  statRollerShowDetails = true,
  statRollerSparklineWidth = 16,
  -- First Run Flag (for Setting up default settings)
  hasInitializedUILayout = false,
  -- First Time Intro Message?
  hasSeenUIIntroMessage = false,
  -- Whether we've prompted to load the packaged map after enabling UI
  hasSeenMapPrompt = false,
  -- Update channel for GitHub installs: "stable" or "beta"
  updateChannel = "stable",
  -- Damage Message Color (any Mudlet color name; use lua showColors() to list options)
  damageMessageColor = "red",
  -- Damage Message Mode: "avg", "range", or "both"
  damageMessageMode = "avg",
  -- Damage Message Enabled: whether inline damage estimates are shown (persisted)
  damageMessageEnabled = true,
  -- DMSounds ambience is opt-in and uses the full volume range
  dmsoundsEnabled = false,
  dmsoundsVolume = 100,
  -- MakeArmor defaults
  makearmorSleeper = "bedroll",
  makearmorContainer = "bag",
  makearmorDefaultMinimumTotal = 15,
  -- Cached UI Version (changing this will invalidate settings)
  layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION,
}

Darkmists.GlobalSettings = {}

-- =============================================================================
-- LOCAL HELPER FUNCTIONS
-- =============================================================================

local function ifLight(light, dark)
  return Darkmists.GlobalSettings.lightMode and light or dark
end

-- Shorthand — avoids repeating "Darkmists Core" prefix on every log line
local TAG = "Darkmists Core"
-- DarkmistsTheme loads in managers/ (before core/), and buildNeutralTheme() runs
-- at file load, so the tag fields always exist by the time this is called.
local function tag()  return DarkmistsTheme.purpleTag .. TAG end
local function log(msg)   Darkmists.Log(tag(), msg) end
local function notify(msg) DMLogger.notify(tag(), msg) end

-- =============================================================================
-- GLOBAL LINE DISPATCHER
-- =============================================================================

function Darkmists.OnNewLine()
  -- StatRoller, ItemTracker, and dmapi each define these handlers
  -- unconditionally, and all load before any MUD line can arrive.
  StatRoller.on_line(line)
  ItemTracker.renderLineWithLinks(line)
  dmapi.core.LineTrigger(line)
end

-- =============================================================================
-- UI / HELPER STUFF
-- =============================================================================

function Darkmists.LoadMapDat()
  log(("Loading Map from: %s"):format(mapDatPath))
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

-- @param onComplete optional; called once with true when the map was installed,
--        false when it was kept or the panel was dismissed.
function Darkmists.PromptLoadMap(onComplete)
  DarkmistsStartup.cancelMapPromptSchedule()

  -- Latched before the panel hides: DMAlertWindow.Hide() runs onClose, and a
  -- deliberate choice must not also be reported as a dismissal.
  local resolved = false
  local function resolveMapPrompt(installed)
    if resolved then return end
    resolved = true
    -- Every exit - install, keep, or dismissing the panel - counts as the player
    -- answering, so the prompt is never re-offered automatically. SETTINGS ->
    -- "Load Map" remains the deliberate way back.
    Darkmists.GlobalSettings.hasSeenMapPrompt = true
    Darkmists.SaveSettings()
    if onComplete then onComplete(installed) end
  end

  local function chooseLoadMap()
    resolveMapPrompt(true)
    DMAlertWindow.Hide()
    tempTimer(0, Darkmists.LoadMapDat)
  end

  local function chooseKeepMap()
    resolveMapPrompt(false)
    DMAlertWindow.Hide()
  end

  local _, mapCharHeight = calcFontSize(DMAlertWindow.getBodyFontSize())
  local mapPromptHeight = math.min(360, math.max(220,
    10 * (mapCharHeight or 16) + DMAlertWindow.getChromeHeight()))

  DMAlertWindow.Show("Install Dark Mists Map?", function(win)
    cecho(win, "\n")
    cecho(win, DarkmistsTheme.infoTag .. "Would you like to install the bundled Dark Mists world map?\n")
    cecho(win, DarkmistsTheme.infoTag .. "It covers most of the game's rooms and areas.\n")
    cecho(win, DarkmistsTheme.warnTag .. "Installing it will replace your current Mudlet map.\n\n")
    cecho(win, DarkmistsTheme.mutedTag .. "Choose how to continue:\n\n")
    cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "Yes, install map" .. DarkmistsTheme.mutedTag .. "]",
      chooseLoadMap,
      "Install the bundled Dark Mists map and replace the current map", true)
    cecho(win, "\n")
    cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.infoTag .. "No, keep current map" .. DarkmistsTheme.mutedTag .. "]",
      chooseKeepMap,
      "Keep the current Mudlet map and do not load the bundled map", true)
  end, {
    height = mapPromptHeight,
    onClose = function()
      -- Dismissed with the X (or torn down by a reload): treat as "keep".
      resolveMapPrompt(false)
      -- Menu-invoked prompts have no sequence to hand off to, so drain any
      -- contrast check that startup queued for a returning user.
      if not onComplete then
        Darkmists.RunPendingContrastCheck()
      end
    end,
  })
end

-- Prompt the user before performing a UI reload (safe pathway)
function Darkmists.PromptSafeReload(opts)
  opts = opts or {}
  Darkmists._reloadConfirmed = false
  local title = opts.title or "Reload UI"
  local body = opts.body or (
    DarkmistsTheme.textTag .. "Reloading the UI will reset the Dark Mists interface and apply any pending layout or theme changes. If you have unsaved settings, save them first.\n\n" ..
    DarkmistsTheme.goodTag .. "Reload Now" .. DarkmistsTheme.textTag .. " to proceed, or close this panel to cancel.\n  "
  )

  DMAlertWindow.Show(title, function(win)
    cecho(win, "\n")
    cecho(win, body)
    -- Use a string that hides the panel then defers the actual reload to avoid
    -- stale C++ callback references (safe pattern used elsewhere).
    cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "Reload Now" .. DarkmistsTheme.mutedTag .. "]",
      [[Darkmists._reloadConfirmed = true; DMAlertWindow.Hide(); tempTimer(0, 'Darkmists.SafeReload()')]],
      "Reload the UI (safe)", true
    )
  end, {
    width = opts.width or 640,
    height = opts.height or 200,
    -- Cancelling the prompt (closing it without reloading) discards any
    -- queued theme switch so it isn't applied on the next startup.
    onClose = function()
      if not Darkmists._reloadConfirmed then
        Darkmists.cancelPendingTheme()
      end
    end,
  })
end

-- Discard a queued theme change (used when a reload prompt is cancelled).
function Darkmists.cancelPendingTheme()
  if Darkmists.GlobalSettings.pendingThemeMode ~= nil then
    Darkmists.GlobalSettings.pendingThemeMode = nil
    Darkmists.SaveSettings()
    DMLogger.notify("Settings", "Theme change cancelled")
  end
end

local function openAsset(path) DMUtil.openLocalFile(path) end
Darkmists.OpenEAConverter    = function() openAsset(eaConverterPath) end
Darkmists.OpenEAFormulaParser = function() openAsset(eaFormulaParser) end
Darkmists.OpenItemViewer     = function() openAsset(itemViewerPath) end
Darkmists.OpenDMAPIDocs      = function() openAsset(dmapiDocPath) end
Darkmists.OpenLineFormatter  = function() openAsset(lineFormatterPath) end

function Darkmists.OpenSettingsFile()
  DMUtil.openLocalFile(saveFilePath)
  notify("Settings File Opened. After Editing, you must use LOAD SETTINGS!")
end

function Darkmists.OpenWebsite()
  openUrl("https://darkmists.org")
end

function Darkmists.OpenWiki()
  openUrl("https://wiki.darkmists.org/en/mudlet")
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
    log(DarkmistsTheme.badTag .. (("Unknown update channel: %s"):format(tostring(channel))))
    return
  end
  Darkmists.GlobalSettings.updateChannel = channel
  Darkmists.SaveSettings()
  notify(("Update channel set to: %s"):format(channel))
end

function Darkmists.UpdateFromGitHub(channel)
  channel = channel or Darkmists.GlobalSettings.updateChannel
  log(("Updating Dark Mists Companion from GitHub... (channel=%s)"):format(tostring(channel)))

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
  log(DarkmistsTheme.badTag .. "Resetting incompatible UI layout cache...")

  if Adjustable and Adjustable.Container and Adjustable.Container.doAll then
    pcall(function()
      Adjustable.Container:doAll(function(container)
        if container.deleteSaveFile then
          container:deleteSaveFile()
        end
      end)
    end)
  end

  if DMTabs and DMTabs.resetSaveFile then
    pcall(DMTabs.resetSaveFile, DMTabs)
  elseif Adjustable and Adjustable.TabWindow and Adjustable.TabWindow.resetSaveFile then
    pcall(Adjustable.TabWindow.resetSaveFile, Adjustable.TabWindow)
  end

  setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0);
  -- update stored layout cache version so we don't repeatedly trigger a reset
  Darkmists.GlobalSettings.layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION
  Darkmists.SaveSettings()
  log(DarkmistsTheme.warnTag .. "UI cache cleared.")

  -- Rebuild theme and refresh layout so UI colors/styles are applied after
  -- resetting the layout cache. Use pcall to avoid hard failures during reset.
  pcall(DarkmistsTheme.buildTheme)
  pcall(Darkmists.RefreshUILayout, { syncStatusBar = true })
end

function Darkmists.ShowUIIntroMessage(force, onChosen, onDismissed)
  -- when `force` is truthy, bypass the first-run and minimal-mode guards
  if not force and Darkmists.GlobalSettings.hasSeenUIIntroMessage then return end
  if not force and not Darkmists.GlobalSettings.minimalMode then return end
  -- Latched before the panel hides: DMAlertWindow.Hide() runs onClose, and a
  -- deliberate choice must not also be reported as a dismissal.
  local chosen = false
  local function commitChoice(mode)
    if chosen then return end
    chosen = true
    DMAlertWindow.Hide()
    -- Deferred: the mode actions that follow may reload the profile, and the
    -- next sequence step builds a new alert panel - so let this click return
    -- before anything else runs.
    if onChosen then
      tempTimer(0, function() onChosen(mode) end)
    end
  end
  -- slight delay so login text finishes first
  tempTimer(force and 0 or 1.5, function()
    local isMinimal = Darkmists.GlobalSettings.minimalMode
    local isFirstRun = not Darkmists.GlobalSettings.hasSeenUIIntroMessage
    local _, introCharHeight = calcFontSize(DMAlertWindow.getBodyFontSize())
    local introHeight = math.min(520, math.max(300,
      21 * (introCharHeight or 16) + DMAlertWindow.getChromeHeight()))
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

        if isFirstRun then
          cecho(win, DarkmistsTheme.infoTag .. " Choose how Dark Mists Companion should start:\n")
          cecho(win, DarkmistsTheme.mutedTag .. " Minimal UI keeps the main interface uncluttered. Full UI adds dockable panels and status windows.\n\n")
          cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.infoTag .. "USE MINIMAL UI" .. DarkmistsTheme.mutedTag .. "]",
            function() commitChoice("minimal"); Darkmists.MarkUIIntroSeen() end,
            "Keep the lightweight Minimal UI", true)
          cecho(win, "\n")
          cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "ENABLE FULL UI NOW" .. DarkmistsTheme.mutedTag .. "]",
            function() commitChoice("full"); Darkmists.EnableUI(); Darkmists.MarkUIIntroSeen() end,
            "Enable the full Dark Mists Companion UI", true)
        elseif isMinimal then
          cecho(win, DarkmistsTheme.infoTag .. " Command: " .. DarkmistsTheme.goodTag .. "dmc ui" .. DarkmistsTheme.infoTag .. "\n")
          cecho(win, DarkmistsTheme.mutedTag .. " (Toggle command — turns UI " .. DarkmistsTheme.goodTag .. "ON" .. DarkmistsTheme.mutedTag .. " or " .. DarkmistsTheme.badTag .. "OFF" .. DarkmistsTheme.mutedTag .. ")\n\n")
          cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.goodTag .. "ENABLE FULL UI NOW" .. DarkmistsTheme.mutedTag .. "]",
            function() commitChoice("full"); Darkmists.EnableUI(); Darkmists.MarkUIIntroSeen() end,
            "Enable the full Dark Mists Companion UI", true)
        else
          cecho(win, DarkmistsTheme.mutedTag .. " Click to switch back to Minimal UI.\n\n")
          cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.badTag .. "DISABLE FULL UI NOW" .. DarkmistsTheme.mutedTag .. "]",
            function() commitChoice("minimal"); Darkmists.MarkUIIntroSeen(); Darkmists.DisableUI() end,
            "Switch to minimal UI", true)
        end

        cecho(win, "\n\n" .. DarkmistsTheme.infoTag .. "Getting Started:\n")
        cechoLink(win, DarkmistsTheme.mutedTag .. "<u>[" .. DarkmistsTheme.accentTag .. "DarkMists Companion Wiki" .. DarkmistsTheme.mutedTag .. "]",
          function() Darkmists.OpenWiki() end,
          "Open the Dark Mists Mudlet Wiki", true)
        cecho(win, "\n\n" .. DarkmistsTheme.mutedTag .. "In Mudlet, type:\n")
        cecho(win, "  " .. DarkmistsTheme.goodTag .. "dmc help" .. DarkmistsTheme.mutedTag .. "     for in-game help\n")
        cecho(win, "  " .. DarkmistsTheme.goodTag .. "dmc settings" .. DarkmistsTheme.mutedTag .. " for the settings panel\n")
    end, {
      height = introHeight,
      onClose = function()
        if not chosen and onDismissed then onDismissed() end
      end,
    })

  end)
end

function Darkmists.MarkUIIntroSeen()
  if not Darkmists.GlobalSettings.hasSeenUIIntroMessage then
    Darkmists.GlobalSettings.hasSeenUIIntroMessage = true
    Darkmists.SaveSettings()

    if ButtonBar and ButtonBar.rebuild then
      tempTimer(0, function() ButtonBar.rebuild() end)
    end

    -- Also sends the first score refresh once the player is online, which is
    -- why it happens here rather than as a separate sequence step.
    Darkmists.reconcileOnlineState("setup-complete")
  end
end

function Darkmists.reconcileOnlineState(reason)
  return DarkmistsStartup.reconcileOnlineState(reason)
end

function Darkmists.RunPendingContrastCheck()
  if not Darkmists._contrastCheckPending then return end
  Darkmists._contrastCheckPending = false

  DarkmistsTheme.checkBackgroundContrast()
end

function Darkmists.ApplyFirstRunUILayout()
  if Darkmists.GlobalSettings.hasInitializedUILayout then return end

  log("Applying first-run UI layout...")

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
    -- This panel is locked "full" both docked and undocked, so the padding is
    -- ignored in normal use and the frame around a pulled-out tab comes from
    -- the tab window's own container (see applyFloatFrame in
    -- GeyserAdjustableTabWindow, and the DMConstants.TAB_FLOAT_* constants).
    -- It only matters if the panel is unlocked by hand, where keeping it at
    -- least half the title bar height stops the header overlapping that bar.
    padding = 14,
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
  log(("Settings Saved To: %s%s!"):format(DarkmistsTheme.infoTag, saveFilePath))
end

function Darkmists.LoadSettings()
---@diagnostic disable-next-line: undefined-field
  if io.exists(saveFilePath) then
    local settings = {}
---@diagnostic disable-next-line: undefined-field
    table.load(saveFilePath, settings)
    -- Fill missing font settings from Mudlet without overwriting user values.
    settings.fontName = settings.fontName or Darkmists.DefaultSettings.fontName
    settings.fontSize = settings.fontSize or Darkmists.DefaultSettings.fontSize

    -- Merge settings (preserve values even if layoutCacheVersion missing)
    DMUtil.deep_copy_into(Darkmists.GlobalSettings, settings)
    log((DarkmistsTheme.mutedTag .. "Settings Loaded From: " .. DarkmistsTheme.infoTag .. "%s<r>"):format(saveFilePath))
    log(DarkmistsTheme.mutedTag .. "You may need to Reload UI for changes to take effect!")
    -- return true indicating a settings file existed
    return true
  else
    log(DarkmistsTheme.mutedTag .. "No Pre-Existing Settings File Found!")
    return false
  end
end

function Darkmists.ApplyDefaultSettings()
  DMUtil.deep_copy_into(Darkmists.GlobalSettings, Darkmists.DefaultSettings)
  log(DarkmistsTheme.mutedTag .. "Default Settings Applied!")
end

function Darkmists.SetWindowBorderPercent(region, percent, force)
  local mainWidth, mainHeight = getMainWindowSize()
  -- Determine whether we're working with height or width
  local isVertical = (region == "top" or region == "bottom")
  local baseSize = isVertical and mainHeight or mainWidth
  local scaledSize = (percent / 100) * baseSize
  -- Only apply and log if the stored percent actually changed
  local prev = (Darkmists.GlobalSettings.borders and Darkmists.GlobalSettings.borders[region]) or 0
  if prev == percent and not force then
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

  log("Window Borders Adjusted")
end

function Darkmists.UpdateMainWindowWrap()
  local mainWidth = getMainWindowSize()
  local borders = getBorderSizes()
  local usableWidth = math.floor(mainWidth - (borders.left or 0) - (borders.right or 0))
  local charWidth = select(1, calcFontSize("main"))
  if (not charWidth or charWidth <= 0) and Darkmists.GlobalSettings.fontSize then
    charWidth = select(1, calcFontSize(Darkmists.GlobalSettings.fontSize, Darkmists.GlobalSettings.fontName))
  end
  if usableWidth > 0 and charWidth and charWidth > 0 then
    setWindowWrap("main", math.max(20, math.floor(usableWidth / charWidth) - 2))
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
  
  -- (RickRoll easter egg removed — see git history for the ASCENSION block)

  -- Hook into dmapi events so we can show the packaged-map prompt after a world enter
  -- Mark a pending flag when the world enter event fires (DMAPI's reset handler will send 'score')
  DarkmistsEvents.add("Darkmists.map.prompt.pending", "dmapi.world.enter", function()
    Darkmists._pendingMapPrompt = true
  end)

  DarkmistsEvents.add("Darkmists.online.reset", "dmapi.world.exit", function()
    DarkmistsStartup.resetOnlineSession()
  end)

-- After vitals update (score processed), if a pending prompt exists show the map prompt
  DarkmistsEvents.add("Darkmists.map.prompt.aftervitals", "dmapi.player.vitals.updated", function()
    Darkmists.reconcileOnlineState("vitals")
  end)

  DarkmistsEvents.add("DarkmistsPackageUninstall","sysUninstallPackage",function (_,pkgName)
    if pkgName == Darkmists.NAME then
      log(("Package Uninstall Detected: %s"):format(tostring(pkgName)))
      Darkmists.CleanupUI({ uninstall = true })
    end
  end)

end

function Darkmists.SafeReload()
  log(DarkmistsTheme.badTag .. "Resetting Profile. UI Reload Incoming....")

  Darkmists.CleanupUI()

  clearWindow()
  resetProfile()
end


function Darkmists.CleanupUI(opts)
  opts = opts or {}
  DarkmistsStartup.invalidate()

  if opts.uninstall and StatusBar then
    StatusBar._skipSave = true
    Darkmists.ResetUILayoutCache()
  end

  if DMSounds and DMSounds.cleanup then pcall(DMSounds.cleanup) end
  if DarkmistsAlias and DarkmistsAlias.clearAll then pcall(DarkmistsAlias.clearAll) end
  if DarkmistsEvents and DarkmistsEvents.clearAll then pcall(DarkmistsEvents.clearAll) end
  if DarkmistsTrigger and DarkmistsTrigger.clearAll then pcall(DarkmistsTrigger.clearAll) end
  if DarkmistsTimer and DarkmistsTimer.clearAll then pcall(DarkmistsTimer.clearAll) end

  if DMAlertWindow and DMAlertWindow.Hide then pcall(DMAlertWindow.Hide) end
  if DMAlertWindow and DMAlertWindow.destroy then pcall(DMAlertWindow.destroy) end
  if DMSettingsPanel and DMSettingsPanel.destroy then pcall(DMSettingsPanel.destroy) end
  if DMSettings and DMSettings.clear then pcall(DMSettings.clear) end
  if AffectsWindow and AffectsWindow.destroy then pcall(AffectsWindow.destroy) end
  if ChatHistory and ChatHistory.destroy then pcall(ChatHistory.destroy) end
  if WhoWindow and WhoWindow.destroy then pcall(WhoWindow.destroy) end
  if WalkDestinations and WalkDestinations.destroy then pcall(WalkDestinations.destroy) end
  if ScorePanel and ScorePanel.destroy then pcall(ScorePanel.destroy) end
  if DarkMistsMiniMap and DarkMistsMiniMap.destroy then pcall(DarkMistsMiniMap.destroy) end
  if ButtonBar and ButtonBar.destroy then pcall(ButtonBar.destroy) end
  if StatusBar and StatusBar.cleanup then pcall(StatusBar.cleanup) end
  if StatRoller and StatRoller.destroy then pcall(StatRoller.destroy) end
  if DMTabs and DMTabs.destroy then pcall(DMTabs.destroy) end

  if opts.uninstall then
    log("Resetting window borders to default...")
  end
end

function Darkmists.LoadUIScripts()
  if Darkmists.UI_LOADED then return end
  DMTabFrame.init()
  StatusBar.init()
  WhoWindow.init()
  ChatHistory.init()
  AffectsWindow.init()
  ScorePanel.init()
  DarkMistsMiniMap.init()
  MapColors.init()
  DMSettingsPanel.init()
  Darkmists.UI_LOADED = true
  -- Ordering matters: this must stay last and after UI_LOADED is set. The walk
  -- window's canUseDock() gates on Darkmists.UI_LOADED, and a restored float
  -- needs its panel rebuilt here or the window comes back empty.
  WalkDestinations.init()
  log("UI Scripts Loaded")
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

  log("UI Enabled")
end

function Darkmists.DisableUI()
  Darkmists.GlobalSettings.minimalMode = true
  Darkmists.SaveSettings()

  if DarkMistsMiniMap and DarkMistsMiniMap.container then
    DarkMistsMiniMap.container:hide()
    DarkMistsMiniMap.container:delete()
    DarkMistsMiniMap.container = nil
  end

  log("Switching to Minimal UI...")
  Darkmists.SafeReload()
end

function Darkmists.Init()
  return DarkmistsStartup.start()
end

function Darkmists.runStartup()
  DMLogger.create()
  log((DarkmistsTheme.mutedTag .. "Initializing Darkmists Core " .. DarkmistsTheme.infoTag .. "v%s<r>"):format(Darkmists.VERSION))
  local versionChanged = DarkmistsStartup.prepare(saveFilePath)

  if versionChanged then
    tempTimer(1, function()
      notify(DarkmistsTheme.warnTag .. "Package version change detected — performing safe reset")
      pcall(resetProfile)
    end)
  end

  DarkmistsStartup.configureRuntime()
  DarkmistsStartup.initializeModules()
  DarkmistsStartup.initializeUI()
  DarkmistsStartup.finalize(notify)
end

-- =============================================================================
-- MODULE LOAD ORDER
-- =============================================================================
tempTimer(1, function() Darkmists.Init() end)