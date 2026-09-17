-- =============================================================================
-- DarkMistsStartup
-- -----------------------------------------------------------------------------
-- Startup orchestration boundary. The implementation remains in DarkMistsCore
-- until each phase can be moved without changing persisted settings behavior.
-- =============================================================================
DarkmistsStartup = {}

DarkmistsStartup.phase = "idle"
DarkmistsStartup.generation = 0
DarkmistsStartup.onlineSession = 0
DarkmistsStartup.initialRefreshSent = false
DarkmistsStartup.mapPromptScheduled = false
DarkmistsStartup.mapPromptToken = 0

function DarkmistsStartup.setPhase(phase)
  DarkmistsStartup.phase = phase
end

function DarkmistsStartup.invalidate()
  DarkmistsStartup.generation = DarkmistsStartup.generation + 1
  DarkmistsStartup.mapPromptToken = DarkmistsStartup.mapPromptToken + 1
  DarkmistsStartup.mapPromptScheduled = false
  DarkmistsStartup.phase = "shutting-down"
end

function DarkmistsStartup.resetOnlineSession()
  DarkmistsStartup.onlineSession = DarkmistsStartup.onlineSession + 1
  DarkmistsStartup.initialRefreshSent = false
  DarkmistsStartup.mapPromptToken = DarkmistsStartup.mapPromptToken + 1
  DarkmistsStartup.mapPromptScheduled = false
end

function DarkmistsStartup.cancelMapPromptSchedule()
  DarkmistsStartup.mapPromptToken = DarkmistsStartup.mapPromptToken + 1
  DarkmistsStartup.mapPromptScheduled = false
end

function DarkmistsStartup.reconcileOnlineState(reason)
  if reason == "world-enter" then
    DarkmistsStartup.resetOnlineSession()
  elseif reason == "world-exit" then
    DarkmistsStartup.resetOnlineSession()
    return false
  end

  if not dmapi or not dmapi.player or not dmapi.player.online then
    return false
  end

  local settings = Darkmists.GlobalSettings
  if not settings or not settings.hasSeenUIIntroMessage then
    return false
  end

  local session = DarkmistsStartup.onlineSession
  if not DarkmistsStartup.initialRefreshSent
      and dmapi.core and dmapi.core.refresh then
    DarkmistsStartup.initialRefreshSent = true
    tempTimer(0, function()
      if session ~= DarkmistsStartup.onlineSession then return end
      if not dmapi.player.online then return end
      if not Darkmists.GlobalSettings.hasSeenUIIntroMessage then return end
      dmapi.core.refresh()
    end)
  end

  local canPromptForMap = Darkmists.UI_LOADED
    and not settings.minimalMode
    and not settings.hasSeenMapPrompt
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
    if promptToken ~= DarkmistsStartup.mapPromptToken then return end
    DarkmistsStartup.mapPromptScheduled = false
    if session ~= DarkmistsStartup.onlineSession then return end

    local currentSettings = Darkmists.GlobalSettings
    local stillEligible = dmapi.player.online
      and currentSettings
      and currentSettings.hasSeenUIIntroMessage
      and Darkmists.UI_LOADED
      and not currentSettings.minimalMode
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
  DarkmistsStartup.setPhase("dmapi")
  dmapi.init()

  local hadSettings = Darkmists.LoadSettings()
  DarkmistsStartup.setPhase("settings-loaded")

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

  DarkmistsStartup.setPhase("settings-ready")
  return versionChanged
end

function DarkmistsStartup.initializeModules()
  DarkmistsStartup.setPhase("modules")

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

  if type(exists) == "function"
      and exists("baseui", "alias") == 1
      and type(expandAlias) == "function" then
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

  -- Keep first-run onboarding passive until the user clicks the Button Bar
  -- callout; startup should not create a modal before DMC is explicitly started.
  DarkmistsTheme.checkBackgroundContrast()
end

function DarkmistsStartup.initializeUI()
  DarkmistsStartup.setPhase("ui")

  if not Darkmists.GlobalSettings.minimalMode then
    Darkmists.LoadUIScripts()
    tempTimer(0.4, function()
      Darkmists.RefreshUILayout({ syncStatusBar = true })
    end)
  end
end

function DarkmistsStartup.finalize(notifyMessage)
  DarkMistsMeta.init()
  DarkmistsStartup.setPhase("ready")
  Darkmists.reconcileOnlineState("startup")

  if notifyMessage then
    notifyMessage((DarkmistsTheme.mutedTag .. "Loaded Darkmists Core " .. DarkmistsTheme.infoTag .. "v%s<r>"):format(Darkmists.VERSION))
  end
end

function DarkmistsStartup.start()
  if type(Darkmists.runStartup) ~= "function" then
    return false
  end

  DarkmistsStartup.generation = DarkmistsStartup.generation + 1
  DarkmistsStartup.phase = "starting"
  local result = Darkmists.runStartup()
  DarkmistsStartup.phase = "ready"
  return result
end

return DarkmistsStartup
