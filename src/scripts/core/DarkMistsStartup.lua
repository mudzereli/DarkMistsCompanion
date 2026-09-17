-- =============================================================================
-- DarkMistsStartup
-- -----------------------------------------------------------------------------
-- Startup orchestration boundary. The implementation remains in DarkMistsCore
-- until each phase can be moved without changing persisted settings behavior.
-- =============================================================================
DarkmistsStartup = {}

-- Phases are a debugging breadcrumb: nothing branches on them yet, so these
-- constants exist to keep the valid set in one place and to make a typo visible
-- instead of silently recording a phase that does not exist.
DarkmistsStartup.PHASE_IDLE            = "idle"
DarkmistsStartup.PHASE_STARTING        = "starting"
DarkmistsStartup.PHASE_DMAPI           = "dmapi"
DarkmistsStartup.PHASE_SETTINGS_LOADED = "settings-loaded"
DarkmistsStartup.PHASE_SETTINGS_READY  = "settings-ready"
DarkmistsStartup.PHASE_MODULES         = "modules"
DarkmistsStartup.PHASE_UI              = "ui"
DarkmistsStartup.PHASE_READY           = "ready"
DarkmistsStartup.PHASE_SHUTTING_DOWN   = "shutting-down"

DarkmistsStartup.phase = DarkmistsStartup.PHASE_IDLE
DarkmistsStartup.generation = 0
DarkmistsStartup.onlineSession = 0
DarkmistsStartup.initialRefreshSent = false
DarkmistsStartup.mapPromptScheduled = false
DarkmistsStartup.mapPromptToken = 0

local function invalidateMapPromptSchedule()
  DarkmistsStartup.mapPromptToken = DarkmistsStartup.mapPromptToken + 1
  DarkmistsStartup.mapPromptScheduled = false
end

function DarkmistsStartup.setPhase(phase)
  DarkmistsStartup.phase = phase
end

function DarkmistsStartup.invalidate()
  DarkmistsStartup.generation = DarkmistsStartup.generation + 1
  invalidateMapPromptSchedule()
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_SHUTTING_DOWN)
end

function DarkmistsStartup.resetOnlineSession()
  DarkmistsStartup.onlineSession = DarkmistsStartup.onlineSession + 1
  DarkmistsStartup.initialRefreshSent = false
  invalidateMapPromptSchedule()
end

function DarkmistsStartup.cancelMapPromptSchedule()
  invalidateMapPromptSchedule()
end

function DarkmistsStartup.reconcileOnlineState(reason)
  if reason == "world-enter" then
    DarkmistsStartup.resetOnlineSession()
  elseif reason == "world-exit" then
    DarkmistsStartup.resetOnlineSession()
    return false
  end

  if not dmapi.player.online then
    return false
  end

  local settings = Darkmists.GlobalSettings
  if not settings.hasSeenUIIntroMessage then
    return false
  end

  local session = DarkmistsStartup.onlineSession
  local generation = DarkmistsStartup.generation
  if not DarkmistsStartup.initialRefreshSent then
    DarkmistsStartup.initialRefreshSent = true
    tempTimer(0, function()
      if generation ~= DarkmistsStartup.generation then return end
      if session ~= DarkmistsStartup.onlineSession then return end
      if not dmapi.player.online then return end
      if not Darkmists.GlobalSettings.hasSeenUIIntroMessage then return end
      dmapi.core.refresh()
    end)
  end

  -- DarkmistsSetup owns the map prompt while its sequence is in flight, so it
  -- must not be scheduled a second time here. The refresh block above has
  -- already run, which is what delivers the first score after the UI choice.
  if DarkmistsSetup.ownsMapPrompt() then
    return true
  end

  -- Offered in both UI modes: the bundled map is a Mudlet map, independent of
  -- DMC's own panels.
  local canPromptForMap = not settings.hasSeenMapPrompt
  if (reason == "startup" or reason == "setup-complete" or reason == "ui-enabled")
      and canPromptForMap then
    Darkmists._pendingMapPrompt = true
  end

  if not Darkmists._pendingMapPrompt or not canPromptForMap
      or DarkmistsStartup.mapPromptScheduled then
    return true
  end

  DarkmistsStartup.mapPromptScheduled = true
  DarkmistsStartup.mapPromptToken = DarkmistsStartup.mapPromptToken + 1
  local promptToken = DarkmistsStartup.mapPromptToken
  tempTimer(2, function()
    if generation ~= DarkmistsStartup.generation then return end
    if promptToken ~= DarkmistsStartup.mapPromptToken then return end
    DarkmistsStartup.mapPromptScheduled = false
    if session ~= DarkmistsStartup.onlineSession then return end

    local currentSettings = Darkmists.GlobalSettings
    local stillEligible = dmapi.player.online
      and currentSettings.hasSeenUIIntroMessage
      and not currentSettings.hasSeenMapPrompt
    if not stillEligible then
      Darkmists._pendingMapPrompt = true
      return
    end

    Darkmists._pendingMapPrompt = false
    Darkmists.PromptLoadMap()
  end)
  return true
end

function DarkmistsStartup.prepare(settingsPath)
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_DMAPI)
  dmapi.init()

  local hadSettings = Darkmists.LoadSettings()
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_SETTINGS_LOADED)

  local savedLayoutVersion = Darkmists.GlobalSettings.layoutCacheVersion
  local versionChanged = hadSettings
    and savedLayoutVersion ~= Darkmists.LAYOUT_CACHE_VERSION

  -- Apply a queued theme only during startup, before rebuilding the theme.
  if Darkmists.GlobalSettings.pendingThemeMode ~= nil then
    Darkmists.GlobalSettings.lightMode = Darkmists.GlobalSettings.pendingThemeMode
    Darkmists.GlobalSettings.pendingThemeMode = nil
    Darkmists.SaveSettings()
  end

  DarkmistsTheme.buildTheme()
  Darkmists.RegisterEvents()

  -- Preserve the existing layout-version policy and storage behavior.
  if not (hadSettings and savedLayoutVersion == Darkmists.LAYOUT_CACHE_VERSION) then
    if io.exists(settingsPath) then pcall(os.remove, settingsPath) end
    Darkmists.ApplyDefaultSettings()
    Darkmists.GlobalSettings.layoutCacheVersion = Darkmists.LAYOUT_CACHE_VERSION
    Darkmists.SaveSettings()
    Darkmists.ResetUILayoutCache()
  end

  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_SETTINGS_READY)
  return versionChanged
end

function DarkmistsStartup.initializeModules()
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_MODULES)

  ItemTracker.init()
  StatRoller.init()
  MapDestinations.load()
  EnchanterAssist.init()
  SkillUps.init()
  DMClickables.init()
  ButtonBar.init()
  SessionTime.init()
  MakeArmor.init()
  DamageMessages.init()
  DMSounds.init()
  SpamPrevention.init()
  CMudWrapper.load()

  -- BaseUI is an optional third-party package, so keep the feature detection.
  if exists("baseui", "alias") == 1 then
    Darkmists.Log("Darkmists Core", "BaseUI alias found; hiding BaseUI")
    expandAlias("baseui hide")
  else
    Darkmists.Log("Darkmists Core", "BaseUI alias not present; skipping BaseUI hide")
  end
end

function DarkmistsStartup.configureRuntime()
  if Darkmists.GlobalSettings.minimalMode then
    setBorderTop(0); setBorderBottom(0); setBorderLeft(0); setBorderRight(0)
  else
    tempTimer(0, Darkmists.UpdateMainWindowWrap)
  end

  -- First-run contrast is owned by DarkmistsSetup, which runs it after the map
  -- prompt. Returning users have no sequence, so queue it here instead;
  -- finalize() or the map prompt's onClose drains it.
  if Darkmists.GlobalSettings.hasSeenUIIntroMessage then
    Darkmists._contrastCheckPending = true
  end
end

function DarkmistsStartup.initializeUI()
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_UI)

  if not Darkmists.GlobalSettings.minimalMode then
    Darkmists.LoadUIScripts()
    tempTimer(0.4, function()
      Darkmists.RefreshUILayout({ syncStatusBar = true })
    end)
  end
end

function DarkmistsStartup.finalize(notifyMessage)
  DarkMistsMeta.init()
  Darkmists.reconcileOnlineState("startup")

  -- Drain the queued contrast notice unless the map prompt is going to appear
  -- first; a scheduled map prompt drains it from its onClose handler.
  if not DarkmistsStartup.mapPromptScheduled then
    tempTimer(0, Darkmists.RunPendingContrastCheck)
  end

  if notifyMessage then
    notifyMessage((DarkmistsTheme.mutedTag .. "Loaded Darkmists Core " .. DarkmistsTheme.infoTag .. "v%s<r>"):format(Darkmists.VERSION))
  end

  -- Last thing startup does, so the phase only reads ready once the refresh
  -- reconciliation and the contrast drain are both queued.
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_READY)
end

function DarkmistsStartup.start()
  DarkmistsStartup.generation = DarkmistsStartup.generation + 1
  DarkmistsStartup.setPhase(DarkmistsStartup.PHASE_STARTING)
  return Darkmists.runStartup()
end

return DarkmistsStartup
