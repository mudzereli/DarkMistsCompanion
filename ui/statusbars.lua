-- ===================================================================
-- ElvUI-Style Status Bar for Dark Mists using Geyser and dmapi
-- ===================================================================
-- Features:
-- - HP/MN/MV bars with enemy HP overlay
-- - XP progress bar (auto-hides at level 51)
-- - Auto-shows on login, hides on disconnect
-- - Persistent border height across reconnects
-- ===================================================================

StatusBar = StatusBar or {}

-- ===================================================================
-- CONFIGURATION
-- ===================================================================
StatusBar.config = {
  colors = Darkmists.GlobalSettings.statusBarColors,
  barHeight = Darkmists.GlobalSettings.statusBarVitalsHeight,
  xpBarHeight = Darkmists.GlobalSettings.statusBarXPHeight,
  fontColor = Darkmists.GlobalSettings.statusBarFontColor,
  barSpacing = 0,
  bottomOffset = 4,
  sideSpacing = 0,
  enabled = true,
  maxLevel = 51,  -- Level at which XP bar hides
  totalWidth = Darkmists.GlobalSettings.mainWindowPanelWidth  -- Percentage of screen width (leaves right 30% clear)
}

StatusBar.currentBorderHeight = 0  -- Persistent border height

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
  return dmapi.player.level and dmapi.player.level < StatusBar.config.maxLevel
end

-- Calculate Y position for main vitals bars based on XP bar visibility
local function calculateBarY()
  local cfg = StatusBar.config
  local baseY = -cfg.bottomOffset - cfg.barHeight
  
  if shouldShowXP() then
    return baseY - cfg.xpBarHeight - cfg.barSpacing
  end
  return baseY
end

-- Calculate total UI height for bottom border
local function calculateTotalHeight(includeEnemy)
  local cfg = StatusBar.config
  local height = cfg.barHeight + cfg.bottomOffset

  -- XP bar: ONLY count it if it is actually visible
  if StatusBar.xpGauge and not StatusBar.xpGauge.hidden then
    height = height + cfg.xpBarHeight + cfg.barSpacing
  end

  -- Enemy bar: ONLY count it if it is actually visible
  if includeEnemy and StatusBar.enemyGauge and not StatusBar.enemyGauge.hidden then
    height = height + cfg.barHeight + cfg.barSpacing
  end

  return height
end

-- Set bottom border and track current height
function StatusBar.setBorder(height)
  if type(height) == "number" then
    StatusBar.currentBorderHeight = height
    setBorderBottom(height)
  end
end

-- Ensure gauge max value is never 0 (Geyser requirement)
local function safeMax(value)
  return (value and value > 0) and value or 1
end

local function getBaseX()
  if Darkmists.GlobalSettings.panelsOnLeft then
    return 100 - StatusBar.config.totalWidth
  end
  return 0
end

-- ===================================================================
-- CLEANUP
-- ===================================================================
function StatusBar.cleanup()
  -- Destroy all gauges
  for _, name in ipairs({"hpGauge", "mnGauge", "mvGauge", "enemyGauge", "xpGauge"}) do
    if StatusBar[name] then
      StatusBar[name]:hide()
      StatusBar[name] = nil
    end
  end
  
  -- Kill all event handlers
  for _, name in ipairs({"vitalUpdateHandler", "levelUpHandler", "levelHandler", "xpGainHandler",
                         "promptHandler", "mobStateHandler", "combatEndHandler", "loginHandler",
                         "disconnectHandler", "sysDisconnectHandler"}) do
    if StatusBar[name] then
      killAnonymousEventHandler(StatusBar[name])
      StatusBar[name] = nil
    end
  end
  
  StatusBar.setBorder(0)
end

StatusBar.cleanup()  -- Clean up any existing instance

-- ===================================================================
-- GAUGE CREATION
-- ===================================================================
function StatusBar.create()
  Darkmists.Log("StatusBars","Creating interface...")

  local baseX = getBaseX()

  local cfg = StatusBar.config
  local barY = calculateBarY()
  
  -- Calculate widths within the 70% constraint
  local totalWidth = cfg.totalWidth
  local barWidthPct = math.floor((totalWidth - (cfg.sideSpacing * 2)) / 3)
  
  -- Create HP/MN/MV gauges (3 bars side-by-side, left-aligned)
  local vitalGauges = {
    { name = "hpGauge", label = "StatusBar_HP", x = baseX, width = barWidthPct, color = cfg.colors.hp },
    { name = "mnGauge", label = "StatusBar_MN", x = baseX + barWidthPct + cfg.sideSpacing, width = barWidthPct, color = cfg.colors.mn },
    { name = "mvGauge", label = "StatusBar_MV", x = baseX + (barWidthPct * 2) + (cfg.sideSpacing * 2), width = totalWidth - (barWidthPct * 2) - (cfg.sideSpacing * 2), color = cfg.colors.mv }
  }
  
  for _, def in ipairs(vitalGauges) do
    StatusBar[def.name] = Geyser.Gauge:new({
      name = def.label,
      x = tostring(def.x) .. "%",
      y = tostring(barY) .. "px",
      width = tostring(def.width) .. "%",
      height = tostring(cfg.barHeight) .. "px"
    })
    local frontStyle, backStyle = createBarStyle(def.color)
    StatusBar[def.name].front:setStyleSheet(frontStyle)
    StatusBar[def.name].back:setStyleSheet(backStyle)
    StatusBar[def.name]:hide()
  end
  
  -- Create XP gauge (bottom bar, 70% width, left-aligned)
  StatusBar.xpGauge = Geyser.Gauge:new({
    name = "StatusBar_XP",
    x = tostring(getBaseX()) .. "%",
    y = tostring(-cfg.bottomOffset - cfg.xpBarHeight) .. "px",
    width = tostring(totalWidth) .. "%",
    height = tostring(cfg.xpBarHeight) .. "px"
  })
  local xpFront, xpBack = createBarStyle(cfg.colors.xp)
  StatusBar.xpGauge.front:setStyleSheet(xpFront)
  StatusBar.xpGauge.back:setStyleSheet(xpBack)
  StatusBar.xpGauge:hide()
  
  -- Create enemy gauge (above vitals, 70% width, left-aligned)
  StatusBar.enemyGauge = Geyser.Gauge:new({
    name = "StatusBar_Enemy",
    x = tostring(getBaseX()) .. "%",
    y = tostring(barY - cfg.barHeight - cfg.barSpacing) .. "px",
    width = tostring(totalWidth) .. "%",
    height = tostring(cfg.barHeight) .. "px"
  })
  local enemyFront, enemyBack = createBarStyle(cfg.colors.enemy)
  StatusBar.enemyGauge.front:setStyleSheet(enemyFront)
  StatusBar.enemyGauge.back:setStyleSheet(enemyBack)
  StatusBar.enemyGauge:hide()
  
  StatusBar.setBorder(0)
  StatusBar.update()
  StatusBar.updateXP()
  
  Darkmists.Log("StatusBars","Created successfully (hidden until login)")
end

-- ===================================================================
-- UPDATE FUNCTIONS
-- ===================================================================

-- Update HP/MN/MV bars with current values
function StatusBar.update()
  if not dmapi.player.vitals then return end
  
  local vitals = {
    { gauge = StatusBar.hpGauge, current = dmapi.player.vitals.hp or 0, max = safeMax(dmapi.player.vitals.hpMax) },
    { gauge = StatusBar.mnGauge, current = dmapi.player.vitals.mn or 0, max = safeMax(dmapi.player.vitals.mnMax) },
    { gauge = StatusBar.mvGauge, current = dmapi.player.vitals.mv or 0, max = safeMax(dmapi.player.vitals.mvMax) }
  }
  
  for _, v in ipairs(vitals) do
    if v.gauge then
      v.gauge:setValue(v.current, v.max, 
        string.format("<center><span style='font-size: 11pt; color: rgb(%s); font-weight: bold;'>%d/%d</span></center>",
                      StatusBar.config.fontColor,v.current, v.max))
    end
  end
  
  -- Auto-show bars when vitals are initialized and gauges exist
  if StatusBar.hpGauge and StatusBar.hpGauge.hidden and safeMax(dmapi.player.vitals.hpMax) > 1 then
    StatusBar.showAll()
  end
end

-- Update XP bar with progress to next level
function StatusBar.updateXP()
  if not StatusBar.xpGauge or not dmapi.player.experience then return end
  
  local xpTnl = tonumber(dmapi.player.experience.tnl) or 1000
  
  -- Track max TNL for this level to show progress bar filling up
  if not StatusBar.lastTnl or StatusBar.lastTnl < xpTnl then
    StatusBar.maxTnl = xpTnl
  end
  StatusBar.lastTnl = xpTnl
  
  -- Invert TNL so bar fills as you gain XP (instead of emptying)
  local xpCurrent = (StatusBar.maxTnl or xpTnl) - xpTnl
  local xpMax = math.max(StatusBar.maxTnl or xpTnl, 1)  -- Ensure never 0
  local xpPct = math.floor((xpCurrent / xpMax) * 100)
  
  StatusBar.xpGauge:setValue(xpCurrent, xpMax,
    string.format("<center><span style='font-size: 8pt; color: rgb(%s); font-weight: bold;'>%d XP to level (%d%%)</span></center>",
                  StatusBar.config.fontColor,xpTnl, xpPct))
end

-- Update enemy HP bar during combat
function StatusBar.updateEnemy(enemyData)
  if not StatusBar.enemyGauge then return end
  
  local targetName = enemyData.target or "Enemy"
  if #targetName > 40 then
    targetName = targetName:sub(1, 37) .. "..."
  end
  
  local hpPct = enemyData.hpPct or 100
  StatusBar.enemyGauge:setValue(hpPct, 100,
    string.format("<center><span style='font-size: 11pt; color: rgb(%s); font-weight: bold;'>%s - %d%%</span></center>",
                  StatusBar.config.fontColor,targetName, hpPct))
  
  if StatusBar.enemyGauge.hidden then
    StatusBar.enemyGauge:show()
  end
  
  StatusBar.setBorder(calculateTotalHeight(true))
end

-- ===================================================================
-- VISIBILITY CONTROL
-- ===================================================================

-- Show all bars (except enemy) and set border
function StatusBar.showAll()
  if not StatusBar.config.enabled then return end
  if not StatusBar.hpGauge then return end
  
  StatusBar.hpGauge:show()
  StatusBar.mnGauge:show()
  StatusBar.mvGauge:show()
  
  -- Only show XP bar if below max level
  if shouldShowXP() then
    StatusBar.xpGauge:show()
  else
    StatusBar.xpGauge:hide()
  end
  
  StatusBar.setBorder(calculateTotalHeight(false))
  Darkmists.Log("StatusBars","Bars shown")
end

-- Hide all bars and reset border
function StatusBar.hideAll()
  for _, gauge in ipairs({StatusBar.hpGauge, StatusBar.mnGauge, StatusBar.mvGauge, 
                          StatusBar.xpGauge, StatusBar.enemyGauge}) do
    if gauge then gauge:hide() end
  end
  
  StatusBar.setBorder(0)
  Darkmists.Log("StatusBars","Bars hidden")
end

-- Hide enemy bar and adjust border
function StatusBar.hideEnemy()
  if StatusBar.enemyGauge and not StatusBar.enemyGauge.hidden then
    StatusBar.enemyGauge:hide()
    StatusBar.setBorder(calculateTotalHeight(false))
  end
end

-- Toggle visibility of all bars
function StatusBar.toggle()
  if StatusBar.hpGauge then
    if StatusBar.hpGauge.hidden then
      StatusBar.showAll()
    else
      StatusBar.hideAll()
    end
  end
end

-- Reposition bars (called when XP bar visibility changes)
function StatusBar.repositionBars()
  local cfg = StatusBar.config
  local baseX = getBaseX()
  local barY = calculateBarY()

  -- Calculate widths within the 70% constraint
  local totalWidth = cfg.totalWidth
  local barWidthPct = math.floor((totalWidth - (cfg.sideSpacing * 2)) / 3)
  
  local hpWidth = barWidthPct
  local mnWidth = barWidthPct
  local mvWidth = totalWidth - (barWidthPct * 2) - (cfg.sideSpacing * 2)

  -- Move & resize HP bar
  if StatusBar.hpGauge then
    StatusBar.hpGauge:resize(tostring(hpWidth) .. "%", tostring(cfg.barHeight) .. "px")
    StatusBar.hpGauge:move(tostring(baseX) .. "%", tostring(barY) .. "px")
  end

  -- Move & resize Mana bar
  if StatusBar.mnGauge then
    StatusBar.mnGauge:resize(tostring(mnWidth) .. "%", tostring(cfg.barHeight) .. "px")
    StatusBar.mnGauge:move(
      tostring(baseX + hpWidth + cfg.sideSpacing) .. "%",
      tostring(barY) .. "px"
    )
  end

  -- Move & resize Moves bar
  if StatusBar.mvGauge then
    StatusBar.mvGauge:resize(tostring(mvWidth) .. "%", tostring(cfg.barHeight) .. "px")
    StatusBar.mvGauge:move(
      tostring(baseX + hpWidth + mnWidth + (cfg.sideSpacing * 2)) .. "%",
      tostring(barY) .. "px"
    )
  end

  -- Move enemy bar
  if StatusBar.enemyGauge then
    StatusBar.enemyGauge:move(
      tostring(baseX) .. "%",
      tostring(barY - cfg.barHeight - cfg.barSpacing) .. "px"
    )
  end
end


-- ===================================================================
-- EVENT HANDLERS
-- ===================================================================
function StatusBar.registerEvents()
  -- Update vitals bars when HP/MN/MV change
  StatusBar.vitalUpdateHandler = registerAnonymousEventHandler("dmapi.player.vitals.updated", StatusBar.update)
  
  -- Reset XP tracking on level up
  StatusBar.levelUpHandler = registerAnonymousEventHandler("dmapi.player.levelup", function()
    StatusBar.update()
    StatusBar.maxTnl = nil
    StatusBar.lastTnl = nil
    StatusBar.updateXP()
  end)
  
  -- Hide XP bar when reaching max level
  StatusBar.levelHandler = registerAnonymousEventHandler("dmapi.player.level.updated", function()
    if dmapi.player.level >= StatusBar.config.maxLevel and StatusBar.xpGauge and not StatusBar.xpGauge.hidden then
      StatusBar.xpGauge:hide()
      StatusBar.repositionBars()
      StatusBar.setBorder(calculateTotalHeight(false))
      Darkmists.Log("StatusBars","<yellow>XP bar hidden (max level reached)")
    end
  end)
  
  -- Update XP bar on experience gain and prompt
  StatusBar.xpGainHandler = registerAnonymousEventHandler("dmapi.player.experience.gain", StatusBar.updateXP)
  StatusBar.promptHandler = registerAnonymousEventHandler("dmapi.world.prompt", StatusBar.updateXP)
  
  -- Show/hide enemy bar during combat
  StatusBar.mobStateHandler = registerAnonymousEventHandler("dmapi.player.combat.mobstate", 
    function(event, data) StatusBar.updateEnemy(data) end)
  StatusBar.combatEndHandler = registerAnonymousEventHandler("dmapi.player.combat.end", StatusBar.hideEnemy)
  
  -- Show bars on login and restore border height
  StatusBar.loginHandler = registerAnonymousEventHandler("dmapi.world.enter", function()
    tempTimer(0.5, function()
      Darkmists.Log("StatusBars","Login detected - showing bars...")
      StatusBar.showAll()
      if StatusBar.currentBorderHeight > 0 then
        StatusBar.setBorder(StatusBar.currentBorderHeight)
        Darkmists.Log("StatusBars","<green>Border restored: " .. StatusBar.currentBorderHeight .. "px")
      end
    end)
  end)
  
  -- Disconnect handlers
  StatusBar.disconnectHandler = registerAnonymousEventHandler("dmapi.world.exit", function()
    Darkmists.Log("StatusBars","<yellow>Disconnect detected")
  end)
  
  StatusBar.sysDisconnectHandler = registerAnonymousEventHandler("sysDisconnectionEvent", function()
    Darkmists.Log("StatusBars","<red>System disconnect - hiding bars")
    StatusBar.hideAll()
  end)
  
  Darkmists.Log("StatusBars","Event handlers registered")
end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
tempTimer(0.5, function()
  StatusBar.create()
  Darkmists.Log("StatusBars","Status Bar Loaded")
  -- Register events after slight delay to ensure Geyser gauges are fully initialized
  tempTimer(0.2, function()
    StatusBar.registerEvents()
  end)
end)