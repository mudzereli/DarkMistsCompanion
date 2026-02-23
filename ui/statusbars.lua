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
  containerHeightPct = Darkmists.GlobalSettings.statusBarTotalHeightPercent,
  fontColor = Darkmists.GlobalSettings.statusBarFontColor,
  moveable = Darkmists.GlobalSettings.statusBarsMoveable,
  enabled = true,
  maxLevel = 51,  -- Level at which XP bar hides
}

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
  return dmapi.player.level and dmapi.player.level < StatusBar.config.maxLevel and dmapi.player.online
end

local function shouldShowEnemy()
  return dmapi.player.combat and dmapi.player.combat.active and dmapi.player.online
end

-- Ensure gauge max value is never 0 (Geyser requirement)
local function safeMax(value)
  return (value and value > 0) and value or 1
end

local function shouldShowVitals()
  return dmapi.player
     and dmapi.player.vitals
     and dmapi.player.online
     and safeMax(dmapi.player.vitals.hpMax) > 1
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
  
  if StatusBar.container then
    StatusBar.container:hide()
    StatusBar.container:delete()
    StatusBar.container = nil
  end
  Darkmists.SetWindowBorderPercent("bottom",0)
end

StatusBar.cleanup()  -- Clean up any existing instance

-- ===================================================================
-- GAUGE CREATION
-- ===================================================================
function StatusBar.create()
  Darkmists.Log("StatusBars","Creating interface...")

  local cfg = StatusBar.config
  
  -- Create HP/MN/MV gauges (3 bars side-by-side, left-aligned)
  local vitalGauges = {
    { name = "hpGauge", label = "StatusBar_HP", x = 0,     width = 33.33, color = cfg.colors.hp },
    { name = "mnGauge", label = "StatusBar_MN", x = 33.33, width = 33.33, color = cfg.colors.mn },
    { name = "mvGauge", label = "StatusBar_MV", x = 66.66, width = 33.33, color = cfg.colors.mv }
  }
  
  local constraints = {
      name = "StatusBarContainer",
      x = Darkmists.GlobalSettings.borders.left .. "%",
      y = (100 - StatusBar.config.containerHeightPct) .. "%",
      width = (100 - Darkmists.GlobalSettings.borders.left - Darkmists.GlobalSettings.borders.right) .. "%",
      height = StatusBar.config.containerHeightPct .. "%",
    }
    
  if StatusBar.config.moveable then
    constraints.titleText = "Status Bars"
    constraints.titleTxtColor = Darkmists.getDefaultTextColor()
    constraints.padding = 10
    constraints.adjLabelstyle = Darkmists.getDefaultAdjLabelstyle()
    constraints.lockStyle = "border"
    constraints.locked = false
    constraints.autoSave = true
    constraints.autoLoad = true
    StatusBar.container = Adjustable.Container:new(constraints)
  else
    StatusBar.container = Geyser.Container:new(constraints)
  end
  StatusBar.container:show()

  -- Gauge Factory
  local function newGauge(def)
    local g = Geyser.Gauge:new({
        name = def.label,
        x = def.x,
        y = def.y,
        width = def.width,
        height = def.height
      }, StatusBar.container)

    local front, back = createBarStyle(def.color)
    g.front:setStyleSheet(front)
    g.back:setStyleSheet(back)

    if def.hidden then g:hide() end
    StatusBar[def.key] = g
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
  newGauge ({
    key = "xpGauge",
    label = "StatusBar_XP",
    x = "0%", y = "80%",
    width = "100%", height = "20%",
    color = cfg.colors.xp
  })
  -- Enemy Gauge
  newGauge ({
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
  
  Darkmists.Log("StatusBars","Created successfully (hidden until login)")
end

-- ===================================================================
-- UPDATE FUNCTIONS
-- ===================================================================

-- Update HP/MN/MV bars with current values
function StatusBar.update()
  local vit = dmapi.player.vitals
  if not vit then return end

  local function setVital(gauge, cur, max, pct, regen)
    if not gauge then return end

    local adir = regen and regen ~= 0 and
      (regen > 0 and (" (+"..regen..")") or (" ("..regen..")")) or ""

    local text
    if vit.estimated then
      text = ("%d%%%s"):format(pct or 100, adir)
    else
      text = ("%d/%d%s"):format(cur or 0, safeMax(max), adir)
    end

    gauge:setValue(cur or 0, safeMax(max),
      ("<center><span style='font-size: 11pt; color: rgb(%s); font-weight: bold;'>%s</span></center>")
        :format(StatusBar.config.fontColor, text))
  end

  setVital(StatusBar.hpGauge, vit.hp, vit.hpMax, vit.hpPct, vit.hpRegen)
  setVital(StatusBar.mnGauge, vit.mn, vit.mnMax, vit.mnPct, vit.mnRegen)
  setVital(StatusBar.mvGauge, vit.mv, vit.mvMax, vit.mvPct, vit.mvRegen)

  if StatusBar.hpGauge and StatusBar.hpGauge.hidden and safeMax(vit.hpMax) > 1 then
    StatusBar.showAll()
    StatusBar.reflow()
  end
end

-- Update XP bar with progress to next level
function StatusBar.updateXP()
  if not StatusBar.xpGauge or not dmapi.player.experience then return end
  if not shouldShowXP() then
    StatusBar.xpGauge:hide()
    StatusBar.reflow()
  end
  
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
    StatusBar.reflow()
  end
end

function StatusBar.recreate()
    StatusBar.cleanup()
    tempTimer(0.5, function()
      StatusBar.create()
      StatusBar.registerEvents()
      StatusBar.showAll()
    end)
    Darkmists.Log("StatusBars","Status Bars Recreated")
end

function StatusBar.reflow()
  if not StatusBar.container then return end

  local cfg = StatusBar.config
  local container = StatusBar.container

  local showEnemy = StatusBar.enemyGauge and not StatusBar.enemyGauge.hidden
  local showXP = StatusBar.xpGauge and not StatusBar.xpGauge.hidden and shouldShowXP()

  -- Unit weights (enemy=2, vitals=2, xp=1)
  local enemyUnits = showEnemy and 2 or 0
  local showVitals = shouldShowVitals()
  local vitalUnits = showVitals and 2 or 0
  local xpUnits = showXP and 1 or 0

  local totalUnits = enemyUnits + vitalUnits + xpUnits
  if totalUnits == 0 then 
    Darkmists.SetWindowBorderPercent("bottom", 0)
    return
  end

  -- Calculate proportional heights
  local enemyHeight = (enemyUnits / totalUnits) * 100
  local vitalHeight = (vitalUnits / totalUnits) * 100
  local xpHeight = (xpUnits / totalUnits) * 100

  -------------------------------------------------
  -- Resize container & border (ONLY if not moveable)
  -------------------------------------------------
  if not cfg.moveable then
    local baseHeight = cfg.containerHeightPct
    local newHeight = baseHeight * (totalUnits / 5) -- 5 = max units (2+2+1)

    local newY = 100 - newHeight
    container:move(nil, newY .. "%")
    container:resize(nil, newHeight .. "%")

    Darkmists.SetWindowBorderPercent("bottom", newHeight)
  end

  -------------------------------------------------
  -- Stack gauges
  -------------------------------------------------
  local yOffset = 0

  -- Enemy (top)
  if showEnemy then
    StatusBar.enemyGauge:show()
    StatusBar.enemyGauge:move("0%", yOffset .. "%")
    StatusBar.enemyGauge:resize("100%", enemyHeight .. "%")
    yOffset = yOffset + enemyHeight
  elseif StatusBar.enemyGauge then
    StatusBar.enemyGauge:hide()
  end

  -- Vitals (HP/MN/MV always visible)
  for _, gauge in ipairs({StatusBar.hpGauge, StatusBar.mnGauge, StatusBar.mvGauge}) do
    if gauge then
      gauge:move(gauge.x, yOffset .. "%")
      gauge:resize(gauge.width, vitalHeight .. "%")
    end
  end
  yOffset = yOffset + vitalHeight

  -- XP (bottom)
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

-- Show all bars (except enemy) and set border
function StatusBar.showAll()
  StatusBar.container:show()
  StatusBar.update()
  StatusBar.updateXP()
  StatusBar.reflow()
  Darkmists.Log("StatusBars","Bars shown")
end

-- Hide all bars and reset border
function StatusBar.hideAll()
  StatusBar.container:hide()
  StatusBar.reflow()
  Darkmists.Log("StatusBars","Bars hidden")
end

-- Hide enemy bar and adjust border
function StatusBar.hideEnemy()
  if shouldShowEnemy() then return end
  if StatusBar.enemyGauge and not StatusBar.enemyGauge.hidden then
    StatusBar.enemyGauge:hide()
    StatusBar.reflow()
  end
end

-- Toggle visibility of all bars
function StatusBar.toggle()
  if StatusBar.container then
    if StatusBar.container.hidden then
      StatusBar.showAll()
    else
      StatusBar.hideAll()
    end
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
    StatusBar.reflow()
  end)
  
  -- Hide XP bar when reaching max level
  StatusBar.levelHandler = registerAnonymousEventHandler("dmapi.player.level.updated", function()
    local showXP = shouldShowXP()
    if (not showXP) and StatusBar.xpGauge and (not StatusBar.xpGauge.hidden) then
      StatusBar.xpGauge:hide()
      StatusBar.reflow()
      Darkmists.Log("StatusBars","<yellow>XP bar hidden (max level reached)")
    elseif (showXP) and StatusBar.xpGauge and StatusBar.xpGauge.hidden then
      StatusBar.xpGauge:show()
      StatusBar.reflow()
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
      StatusBar.reflow()
    end)
  end)
  
  -- Disconnect handlers
  StatusBar.disconnectHandler = registerAnonymousEventHandler("dmapi.world.exit", function()
    StatusBar.hideAll()
    Darkmists.Log("StatusBars","<yellow>Disconnect detected")
  end)
  
  StatusBar.sysDisconnectHandler = registerAnonymousEventHandler("sysDisconnectionEvent", function()
    StatusBar.hideAll()
    Darkmists.Log("StatusBars","<red>System disconnect - hiding bars")
  end)
  
  Darkmists.Log("StatusBars","Event handlers registered")
end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
tempTimer(0.5, function()
  StatusBar.create()
  StatusBar.registerEvents()
  Darkmists.Log("StatusBars","Status Bar Loaded")
end)