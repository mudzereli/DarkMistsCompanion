-- ===================================================================
-- ElvUI-Style Status Bar for Dark Mists using Geyser and dmapi
-- ===================================================================
-- Features:
-- - HP/MN/MV bars with enemy HP overlay
-- - XP progress bar (auto-hides at level 51)
-- - Auto-shows on login, hides on disconnect
-- - Persistent attached or floating layout across reconnects
-- ===================================================================
StatusBar = StatusBar or {}

-- ===================================================================
-- CONFIGURATION
-- ===================================================================
-- Config is populated in StatusBar.init() so GlobalSettings is guaranteed
-- to be loaded. A stub is kept here so pre-init guards (isEnabled) are safe.
StatusBar.config = {}

-- ===================================================================
-- UTILITY FUNCTIONS
-- ===================================================================

-- Generate CSS stylesheet for Geyser gauge (front and back)
local function createBarStyle(colorConfig)
  local function parseRGBA(rgba)
    local r, g, b, a = rgba:match("(%d+),(%d+),(%d+),(%d+)")
    return { r = tonumber(r), g = tonumber(g), b = tonumber(b), a = tonumber(a) }
  end

  local barColor = parseRGBA(colorConfig.bar)
  local backdropColor = parseRGBA(colorConfig.backdrop)
  local template = "background-color: rgba(%d, %d, %d, %d); border: 1px solid rgba(0, 0, 0, 220); border-radius: 0px; margin: 0px; padding: 0px;"

  return string.format(template, barColor.r, barColor.g, barColor.b, barColor.a),
         string.format(template, backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a)
end

-- Check if XP bar should be visible (below max level)
local function shouldShowXP()
  return dmapi.player.level
     and dmapi.player.level < StatusBar.config.maxLevel
     and dmapi.player.online
end

-- Determine if enemy bar should be visible
local function shouldShowEnemy()
  return dmapi.player.combat
     and dmapi.player.combat.active
     and dmapi.player.online
end

local function getStatusSummary()
  local status = (dmapi.player and dmapi.player.status) or {}

  local goodClr  = cecho2hecho(DarkmistsTheme.goodTag)
  local warnClr  = cecho2hecho(DarkmistsTheme.warnTag)
  local badClr   = cecho2hecho(DarkmistsTheme.badTag)
  local labelClr = cecho2hecho(DarkmistsTheme.textTag)

  local function span(color, text)
    return ("<span style='color: %s;'>%s</span>"):format(color, text)
  end

  local postureColor = (status.sleeping or status.resting) and warnClr or goodClr
  local posture = status.sleeping and "Sleeping"
    or status.resting and "Resting"
    or "Awake"

  local hungerMap = {
    [-1] = { "Full",             goodClr },
    [0]  = { "Not Hungry",       goodClr },
    [1]  = { "Hungry",           warnClr },
    [2]  = { "Famished",         warnClr },
    [3]  = { "Starving",         badClr  },
    [4]  = { "Starvation",       badClr  },
  }
  local thirstMap = {
    [0] = { "Not Thirsty",       goodClr },
    [1] = { "Thirsty",           warnClr },
    [2] = { "Parched",           warnClr },
    [3] = { "Dehydrating",       badClr  },
    [4] = { "Dying of Thirst",   badClr  },
  }

  local hEntry = hungerMap[status.hungry]  or { "Hunger ?", labelClr }
  local tEntry = thirstMap[status.thirsty] or { "Thirst ?", labelClr }
  local sep    = span(labelClr, "  •  ")

  local parts = {
    span(labelClr, "State: ")  .. span(postureColor, posture),
    span(labelClr, "Hunger: ") .. span(hEntry[2], hEntry[1]),
    span(labelClr, "Thirst: ") .. span(tEntry[2], tEntry[1]),
  }
  if status.stunned then
    parts[#parts + 1] = span(badClr, "Stunned")
  end

  return table.concat(parts, sep)
end

local function setEnemyGaugeDisplayMode(mode)
  if not StatusBar.enemyGauge then return end
  if StatusBar._enemyGaugeDisplayMode == mode then return end

  if mode == "status" then
    local isLightMode = Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings.lightMode
    local neutralColors = isLightMode and {
      bar = "255,255,255,45",
      backdrop = "240,240,240,25"
    } or {
      bar = "0,0,0,55",
      backdrop = "0,0,0,30"
    }
    local front, back = createBarStyle(neutralColors)
    StatusBar.enemyGauge.front:setStyleSheet(front)
    StatusBar.enemyGauge.back:setStyleSheet(back)
  else
    local front, back = createBarStyle(StatusBar.config.colors.enemy)
    StatusBar.enemyGauge.front:setStyleSheet(front)
    StatusBar.enemyGauge.back:setStyleSheet(back)
  end

  StatusBar._enemyGaugeDisplayMode = mode
end

-- Ensure gauge max value is never 0 (Geyser requirement)
local function safeMax(value)
  return (value and value > 0) and value or 1
end

-- Vitals must be valid and meaningful before showing bars
local function shouldShowVitals()
  return dmapi.player
     and dmapi.player.vitals
     and dmapi.player.online
     and safeMax(dmapi.player.vitals.hpMax) > 1
end

local function isEnabled()
  return StatusBar.config and StatusBar.config.enabled
end

-- One-shot handler that waits for the first valid vitals packet
local function registerFirstVitalsHandler()
  DarkmistsEvents.add(
    "StatusBarFirstVitalsHandler",
    "dmapi.player.vitals.updated",
    function()
      if not isEnabled() then return end
      Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Vitals received — showing bars")
      StatusBar.showAll()  -- state transition: hidden → visible
      StatusBar.reflow()
    end,
    true
  )
end

-- ===================================================================
-- CLEANUP
-- ===================================================================
function StatusBar.cleanup()
  StatusBar._recreateToken = (StatusBar._recreateToken or 0) + 1

  -- Destroy all gauges
  for _, name in ipairs({"hpGauge", "mnGauge", "mvGauge", "enemyGauge", "xpGauge"}) do
    local gauge = StatusBar[name]
    if gauge then
      gauge:hide()
      StatusBar[name] = nil -- clear reference for GC
    end
  end

  if StatusBar.container then
    if not StatusBar._skipSave then
      local saved, saveError = pcall(function() StatusBar.container:save() end)
      if not saved then
        Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars",
          "<yellow>Unable to save status-bar layout: " .. tostring(saveError))
      end
    end
    StatusBar.container:hide()
    StatusBar.container:delete()
    StatusBar.container = nil
  end

  StatusBar._skipSave = nil

  -- Reset display-mode guard so the freshly-created gauge always gets styled.
  StatusBar._enemyGaugeDisplayMode = nil
  StatusBar.lastTnl = nil
  StatusBar.maxTnl = nil
end

StatusBar.cleanup()  -- ensure reload safety

-- ===================================================================
-- GAUGE CREATION
-- ===================================================================
function StatusBar.create()
  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Creating interface...")

  local cfg = StatusBar.config

  -- Create HP/MN/MV gauges (3 bars side-by-side, left-aligned)
  local vitalGauges = {
    { name = "hpGauge", label = "StatusBar_HP", x = 0,     width = 33.33, color = cfg.colors.hp },
    { name = "mnGauge", label = "StatusBar_MN", x = 33.33, width = 33.33, color = cfg.colors.mn },
    { name = "mvGauge", label = "StatusBar_MV", x = 66.66, width = 33.33, color = cfg.colors.mv }
  }

  local borders = Darkmists.GetBorderPercentages()
  local left   = borders.left
  local right  = borders.right

  local constraints = {
    name   = "StatusBarContainer",
    x      = left .. "%",
    y      = (100 - cfg.containerHeightPct) .. "%",
    width  = (100 - left - right) .. "%",
    height = cfg.containerHeightPct .. "%",
  }

  constraints.titleText = "Status Bars"
  constraints.titleTxtColor = Darkmists.getDefaultTextColor()
  constraints.padding = 10
  constraints.adjLabelstyle = Darkmists.getDefaultAdjLabelstyle()
  constraints.lockStyle = "standard"
  constraints.locked = true
  constraints.autoSave = true
  constraints.autoLoad = true
  StatusBar.container = Adjustable.Container:new(constraints)

  StatusBar.container:show()

  -- Gauge Factory
  local function newGauge(def)
    local gauge = Geyser.Gauge:new({
      name = def.label,
      x = def.x,
      y = def.y,
      width = def.width,
      height = def.height
    }, StatusBar.container)

    local front, back = createBarStyle(def.color)
    gauge.front:setStyleSheet(front)
    gauge.back:setStyleSheet(back)

    if def.hidden then gauge:hide() end
    StatusBar[def.key] = gauge
  end

  -- All 3 Vitals (use existing table)
  for _, def in ipairs(vitalGauges) do
    newGauge({
      key = def.name,
      label = def.label,
      x = tostring(def.x) .. "%",
      y = "40%",
      width = tostring(def.width) .. "%",
      height = "40%",
      color = def.color
    })
  end

  -- XP Gauge
  newGauge({
    key = "xpGauge",
    label = "StatusBar_XP",
    x = "0%", y = "80%",
    width = "100%", height = "20%",
    color = cfg.colors.xp
  })

  -- Enemy Gauge
  newGauge({
    key = "enemyGauge",
    label = "StatusBar_Enemy",
    x = "0%", y = "0%",
    width = "100%", height = "40%",
    color = cfg.colors.enemy,
    hidden = true
  })

  StatusBar.hideAll()
  StatusBar.update()
  StatusBar.updateXP()
  StatusBar.reflow()

  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Created successfully (hidden until login)")
end

-- ===================================================================
-- UPDATE FUNCTIONS
-- ===================================================================

-- Update HP/MN/MV bars with current values
function StatusBar.update()
  if not isEnabled() then return end
  local vitals = dmapi.player.vitals
  if not vitals then return end

  local function setVital(gauge, cur, max, pct, regen)
    if not gauge then return end

    -- regen indicator formatting
    local adir = regen and regen ~= 0
      and (regen > 0 and (" (+"..regen..")") or (" ("..regen..")"))
      or ""

    local text = vitals.estimated
      and ("%d%%%s"):format(pct or 100, adir)
      or ("%d/%d%s"):format(cur or 0, safeMax(max), adir)

    gauge:setValue(cur or 0, safeMax(max),
      ("<center><span style='font-size: 11pt; color: rgb(%s); font-weight: bold;'>%s</span></center>")
        :format(StatusBar.config.fontColor, text))
  end

  setVital(StatusBar.hpGauge, vitals.hp, vitals.hpMax, vitals.hpPct, vitals.hpRegen)
  setVital(StatusBar.mnGauge, vitals.mn, vitals.mnMax, vitals.mnPct, vitals.mnRegen)
  setVital(StatusBar.mvGauge, vitals.mv, vitals.mvMax, vitals.mvPct, vitals.mvRegen)

  -- first valid vitals packet reveals bars
  if StatusBar.hpGauge and StatusBar.hpGauge.hidden and safeMax(vitals.hpMax) > 1 then
    StatusBar.showAll()
    StatusBar.reflow()
  end
end

-- Update XP bar with progress to next level
function StatusBar.updateXP()
  if not isEnabled() then return end
  if not StatusBar.xpGauge or not dmapi.player.experience then return end
  if not shouldShowXP() then
    StatusBar.xpGauge:hide()
    StatusBar.reflow()
  end

  local xpTnl = tonumber(dmapi.player.experience.tnl) or 1000

  -- track highest TNL seen to invert bar direction
  if not StatusBar.lastTnl or StatusBar.lastTnl < xpTnl then
    StatusBar.maxTnl = xpTnl
  end
  StatusBar.lastTnl = xpTnl

  local xpCurrent = (StatusBar.maxTnl or xpTnl) - xpTnl
  local xpMax = math.max(StatusBar.maxTnl or xpTnl, 1)
  local xpPct = math.floor((xpCurrent / xpMax) * 100)

  StatusBar.xpGauge:setValue(xpCurrent, xpMax,
    ("<center><span style='font-size: 8pt; color: rgb(%s); font-weight: bold;'>%d XP to level (%d%%)</span></center>")
      :format(StatusBar.config.fontColor, xpTnl, xpPct))
end

-- Update enemy HP bar during combat
function StatusBar.updateEnemy(enemyData)
  if not isEnabled() then return end
  if not StatusBar.enemyGauge then return end

  if not shouldShowEnemy() then
    setEnemyGaugeDisplayMode("status")
    StatusBar.enemyGauge:setValue(100, 100,
      ("<center><span style='font-size: 10pt; color: rgb(%s); font-weight: bold;'>%s</span></center>")
        :format(StatusBar.config.fontColor, getStatusSummary()))

    if StatusBar.enemyGauge.hidden then
      StatusBar.enemyGauge:show()
      StatusBar.reflow()
    end
    return
  end

  local targetName = (enemyData and enemyData.target)
    or dmapi.player.combat.target
    or "Enemy"
  if #targetName > 40 then
    targetName = targetName:sub(1, 37) .. "..."
  end

  local hpPct = (enemyData and enemyData.hpPct)
    or dmapi.player.combat.targetHpPct
    or 100

  setEnemyGaugeDisplayMode("enemy")
  StatusBar.enemyGauge:setValue(hpPct, 100,
    ("<center><span style='font-size: 11pt; color: rgb(%s); font-weight: bold;'>%s - %d%%</span></center>")
      :format(StatusBar.config.fontColor, targetName, hpPct))

  if StatusBar.enemyGauge.hidden then
    StatusBar.enemyGauge:show()
    StatusBar.reflow()
  end
end

function StatusBar.recreate()
  StatusBar.cleanup()
  local recreateToken = StatusBar._recreateToken
  tempTimer(0, function()
    if StatusBar._recreateToken ~= recreateToken then return end
    StatusBar.create()
    StatusBar.registerEvents()
    StatusBar.showAll()
  end)
  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Status Bars Recreated")
end

-- Refresh attached horizontal geometry after the main window changes size.
function StatusBar.syncToBorders()
  if not StatusBar.container then return end

  local attached = StatusBar.container.attached
  if attached == "top" or attached == "bottom" then
    local borders = Darkmists.GetBorderPercentages()
    local left = borders.left or 0
    local right = borders.right or 0
    StatusBar.container:move(left .. "%", nil)
    StatusBar.container:resize((100 - left - right) .. "%", nil)
  end

  StatusBar.reflow()
  StatusBar.update()
  StatusBar.updateXP()
end

function StatusBar.reflow()
  if not StatusBar.container then return end
  if not isEnabled() then
    return
  end

  local showEnemy = StatusBar.enemyGauge and not StatusBar.enemyGauge.hidden
  local showXP = StatusBar.xpGauge and not StatusBar.xpGauge.hidden and shouldShowXP()

  -- Unit weights (enemy=2, vitals=2, xp=1)
  local enemyUnits = showEnemy and 2 or 0
  local vitalUnits = shouldShowVitals() and 2 or 0
  local xpUnits = showXP and 1 or 0

  local totalUnits = enemyUnits + vitalUnits + xpUnits
  if totalUnits == 0 then
    return
  end

  local enemyHeight = (enemyUnits / totalUnits) * 100
  local vitalHeight = (vitalUnits / totalUnits) * 100
  local xpHeight = (xpUnits / totalUnits) * 100

  local yOffset = 0

  if showEnemy then
    StatusBar.enemyGauge:show()
    StatusBar.enemyGauge:move("0%", yOffset .. "%")
    StatusBar.enemyGauge:resize("100%", enemyHeight .. "%")
    yOffset = yOffset + enemyHeight
  elseif StatusBar.enemyGauge then
    StatusBar.enemyGauge:hide()
  end

  for _, gauge in ipairs({StatusBar.hpGauge, StatusBar.mnGauge, StatusBar.mvGauge}) do
    if gauge then
      gauge:move(gauge.x, yOffset .. "%")
      gauge:resize(gauge.width, vitalHeight .. "%")
    end
  end

  yOffset = yOffset + vitalHeight

  if showXP then
    StatusBar.xpGauge:show()
    StatusBar.xpGauge:move("0%", yOffset .. "%")
    StatusBar.xpGauge:resize("100%", xpHeight .. "%")
  elseif StatusBar.xpGauge then
    StatusBar.xpGauge:hide()
  end

end

-- ===================================================================
-- VISIBILITY CONTROL
-- ===================================================================
function StatusBar.showAll()
  if not isEnabled() then
    StatusBar.hideAll()
    return
  end
  if not shouldShowVitals() then return end

  if StatusBar.container then
    StatusBar.container:attachToBorder("bottom")
    StatusBar.applyAttachedHeight()
    local saved, saveError = pcall(function() StatusBar.container:save() end)
    if not saved then
      Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars",
        "<yellow>Unable to save attached status-bar layout: " .. tostring(saveError))
    end
  end

  StatusBar.reflow()

  if StatusBar.container then
    StatusBar.container:show()
  end

  for _, gauge in ipairs({
    StatusBar.hpGauge,
    StatusBar.mnGauge,
    StatusBar.mvGauge
  }) do
    if gauge then gauge:show() end
  end

  StatusBar.update()
  StatusBar.updateXP()
  StatusBar.updateEnemy()
  StatusBar.reflow()
  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Bars shown")
end

function StatusBar.hideAll()
  StatusBar.reflow()
  if StatusBar.hpGauge then StatusBar.hpGauge:hide() end
  if StatusBar.mnGauge then StatusBar.mnGauge:hide() end
  if StatusBar.mvGauge then StatusBar.mvGauge:hide() end
  StatusBar.hideEnemy()
  StatusBar.updateXP()

  if StatusBar.container then
    StatusBar.container:detach()
    StatusBar.container:hide()
  end

  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Bars hidden")
end

function StatusBar.hideEnemy()
  StatusBar.updateEnemy()
end

function StatusBar.toggle()
  if StatusBar.config then
    if StatusBar.config.enabled then
      StatusBar.disable()
    else
      StatusBar.enable()
    end
  end
end

function StatusBar.setTotalHeightPercent(value)
  value = math.max(1, math.min(40, math.floor(tonumber(value) or 10)))
  StatusBar.config.containerHeightPct = value
  Darkmists.GlobalSettings.statusBarTotalHeightPercent = value
  Darkmists.SaveSettings()

  if StatusBar.container then
    local attached = StatusBar.container.attached
    if attached == "top" or attached == "bottom" then
      StatusBar.applyAttachedHeight()
      StatusBar.syncToBorders()
    else
      StatusBar.reflow()
    end
  end
end

function StatusBar.applyAttachedHeight()
  if not StatusBar.container then return end

  local attached = StatusBar.container.attached
  if attached ~= "top" and attached ~= "bottom" then return end

  local value = StatusBar.config.containerHeightPct
  local y = attached == "bottom" and ("-" .. value .. "%") or "0%"

  local previousLayoutLock = StatusBar._layoutLock
  StatusBar._layoutLock = true
  StatusBar.container:detach()
  StatusBar.container:move(nil, y)
  StatusBar.container:resize(nil, value .. "%")
  StatusBar.container:attachToBorder(attached)
  Darkmists.SetWindowBorderPercent(attached, value, true)
  StatusBar._layoutLock = previousLayoutLock
end

function StatusBar.enable()
  StatusBar.config.enabled = true
  Darkmists.GlobalSettings.statusBarsEnabled = true
  Darkmists.SaveSettings()

  -- If never initialized (e.g. disabled at startup), create everything now
  if not StatusBar.container then
    StatusBar.create()
    StatusBar.registerEvents()
  end

  StatusBar.showAll()
  StatusBar.reflow()

  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars", "<green>Status bars enabled")
end

function StatusBar.disable()
  StatusBar.config.enabled = false
  Darkmists.GlobalSettings.statusBarsEnabled = false
  Darkmists.SaveSettings()

  StatusBar.hideAll()

  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars", "<red>Status bars disabled")
end

-- ===================================================================
-- EVENT HANDLERS
-- ===================================================================
function StatusBar.registerEvents()
  DarkmistsEvents.add("StatusBarVitalsUpdated", "dmapi.player.vitals.updated", StatusBar.update)

  DarkmistsEvents.add("StatusBarLevelUp", "dmapi.player.levelup", function()
    StatusBar.update()
    StatusBar.maxTnl = nil
    StatusBar.lastTnl = nil
    StatusBar.updateXP()
    StatusBar.reflow()
  end)

  DarkmistsEvents.add("StatusBarLevelUpdated", "dmapi.player.level.updated", function()
    local showXP = shouldShowXP()
    if (not showXP) and StatusBar.xpGauge and (not StatusBar.xpGauge.hidden) then
      StatusBar.xpGauge:hide()
      StatusBar.reflow()
      Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","<yellow>XP bar hidden (max level reached)")
    elseif showXP and StatusBar.xpGauge and StatusBar.xpGauge.hidden then
      StatusBar.xpGauge:show()
      StatusBar.reflow()
      Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","<yellow>XP bar shown (max level not reached)")
    end
  end)

  DarkmistsEvents.add("StatusBarExperienceGain", "dmapi.player.experience.gain", StatusBar.updateXP)
  DarkmistsEvents.add("StatusBarPrompt", "dmapi.world.prompt", StatusBar.updateXP)

  DarkmistsEvents.add("StatusBarCombatMobstate", "dmapi.player.combat.mobstate", function(_, data)
    StatusBar.updateEnemy(data)
  end)

  DarkmistsEvents.add("StatusBarCombatEnd", "dmapi.player.combat.end", StatusBar.hideEnemy)

  DarkmistsEvents.add("StatusBarHungerUpdate", "dmapi.player.hunger.update", StatusBar.updateEnemy)
  DarkmistsEvents.add("StatusBarThirstUpdate", "dmapi.player.thirst.update", StatusBar.updateEnemy)
  DarkmistsEvents.add("StatusBarSleepEnter", "dmapi.player.sleep.enter", StatusBar.updateEnemy)
  DarkmistsEvents.add("StatusBarSleepExit", "dmapi.player.sleep.exit", StatusBar.updateEnemy)
  DarkmistsEvents.add("StatusBarSleepBlocked", "dmapi.player.sleep.blocked", StatusBar.updateEnemy)
  DarkmistsEvents.add("StatusBarRestEnter", "dmapi.player.rest.enter", StatusBar.updateEnemy)
  DarkmistsEvents.add("StatusBarRestExit", "dmapi.player.rest.exit", StatusBar.updateEnemy)

  DarkmistsEvents.add("StatusBarWorldExit", "dmapi.world.exit", function()
    StatusBar.hideAll()
    Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","<yellow>Disconnect detected")
  end)

  DarkmistsEvents.add("StatusBarDisconnection", "sysDisconnectionEvent", function()
    StatusBar.hideAll()
    Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","<red>System disconnect - hiding bars")
  end)

  DarkmistsEvents.add("StatusBarWorldEnter", "dmapi.world.enter", function()
    Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","World entered — awaiting vitals")
    registerFirstVitalsHandler() -- reset oneshot lifecycle on reconnect
  end)

  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Events Registered!")
end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
function StatusBar.init()
  -- Rebuild config from live GlobalSettings on every init (reload-safe).
  StatusBar.config = {
    colors = Darkmists.GlobalSettings.statusBarColors,
    containerHeightPct = Darkmists.GlobalSettings.statusBarTotalHeightPercent,
    fontColor = Darkmists.GlobalSettings.statusBarFontColor,
    enabled = Darkmists.GlobalSettings.statusBarsEnabled ~= false, -- default true if nil
    maxLevel = 51,
  }

  if not isEnabled() then
    Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Status Bars disabled in config")
    return
  end

  StatusBar.create()
  StatusBar.registerEvents()

  if shouldShowVitals() then
    StatusBar.showAll()
  end

  Darkmists.Log(DarkmistsTheme.redTag.. "StatusBars","Status Bar Loaded (UI Ready)")
end