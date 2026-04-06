local StatusIcons = {
  hunger = {
    icon = {[-1]="🍽️",[0]="😊",[1]="🍕",[2]="🍗",[3]="💀",[4]="☠️"},
    text = {[-1]="Full",[0]="Satisfied",[1]="Hungry",[2]="Famished",[3]="Starving",[4]="Dying"}
  },
  thirst = {
    icon = {[0]="😊",[1]="💧",[2]="💦",[3]="🌊",[4]="☠️"},
    text = {[0]="Satisfied",[1]="Thirsty",[2]="Parched",[3]="Dehydrating",[4]="Dying"}
  }
}

ScorePanel = {}
ScorePanel.config = {
  fontSize = 10,
  fontName = "Consolas",
}

-- Theme-aware tags
local sectionTag  = "<sky_blue>"
local label    = "<dim_gray>"
local value    = "<white>"
local accent   = "<cyan>"
local good     = "<green>"
local warn     = "<yellow>"
local bad      = "<red>"
local divider  = "<silver>"
local goldTag  = "<gold>"
local silverTag = "<silver>"
local textTag  = "<ansi_white>"

function ScorePanel.applyTheme()
  local theme = rawget(_G, "DarkmistsTheme") or {}
  local settings = (Darkmists and Darkmists.GlobalSettings) or {}

  ScorePanel.config.fontSize = settings.fontSize or ScorePanel.config.fontSize or 10
  ScorePanel.config.fontName = settings.fontName or ScorePanel.config.fontName or "Consolas"

  sectionTag = theme.skyTag or sectionTag
  label = theme.mutedTag or label
  value = theme.textTag or value
  accent = theme.accentTag or accent
  good = theme.goodTag or good
  warn = theme.warnTag or warn
  bad = theme.badTag or bad
  divider = theme.silverTag or divider
  goldTag = theme.goldTag or goldTag
  silverTag = theme.silverTag or silverTag
  textTag = theme.textTag or textTag
end

local function getDividerWidth()
  local w = select(1, getUserWindowSize("ScorePanelConsole")) or 80
  local fontSize = ScorePanel.config.fontSize or 10
  local charW = select(1, calcFontSize(fontSize)) or 1
  if charW < 1 then charW = 1 end
  return math.floor(w / charW) - 4
end

local function line(fmt, ...)
  cecho("ScorePanelConsole", fmt:format(...))
end

local function section(title)
  local width = getDividerWidth()
  local cleanTitle = " "..title.." "
  local remaining = width - #cleanTitle
  if remaining < 0 then remaining = 0 end
  local right = string.rep("━", remaining)

  cecho("ScorePanelConsole",
    ("\n%s━━%s%s%s\n"):format(divider, sectionTag..cleanTitle, divider..right, textTag))
end

local function diffColor(base, mod)
  if mod > base then return good
  elseif mod < base then return bad
  else return value end
end

-- Always reset UI references on load so create() runs fresh against the new
-- DMTabs containers. ScorePanel holds no persistent data, so this is safe.
ScorePanel.window  = nil
ScorePanel.console = nil

ScorePanel.create = function()
  if ScorePanel.window then return end
  
  ScorePanel.window = Darkmists.createTabPanel("ScorePanel","Player Status","Player")

  ScorePanel.console = Geyser.MiniConsole:new({
    name   = "ScorePanelConsole",
    x      = "1%",
    y      = "1%",
    width  = "98%",
    height = "98%",
    color = Darkmists.getDefaultBackgroundColor()
  }, ScorePanel.window)
  ScorePanel.console:setFontSize(ScorePanel.config.fontSize)
  ScorePanel.console:setFont(ScorePanel.config.fontName)
  --ScorePanel.console:enableAutoWrap()
  ScorePanel.console:enableScrollBar()
  ScorePanel.window:show()
  ScorePanel.window:raiseAll()
  Darkmists.Log("ScorePanel","Score Panel Created")
end

ScorePanel.destroy = function()
  if ScorePanel.console then
    pcall(function()
      if ScorePanel.console.hide then ScorePanel.console:hide() end
      if ScorePanel.console.delete then ScorePanel.console:delete() end
    end)
    ScorePanel.console = nil
  end

  if ScorePanel.window then
    pcall(function()
      if ScorePanel.window.hide then ScorePanel.window:hide() end
      if ScorePanel.window.delete then ScorePanel.window:delete() end
    end)
    ScorePanel.window = nil
  end
end

ScorePanel.registerEvents = function()
  DarkmistsEvents.add("ScorePanelPromptHandler", "dmapi.world.prompt", ScorePanel.refresh)
  Darkmists.Log("ScorePanel","Events Registered")
end

ScorePanel.refresh = function()
  if not ScorePanel.console then return end

  local con = "ScorePanelConsole"
  ScorePanel.console:clear()

  local P = dmapi.player
  local W = dmapi.world
  local M = map

  -- Ensure we have numeric indices for lookups; coerce possible string values
  -- to numbers and default to 0 (satisfied).
  local h = tonumber(P.status.hungry) or 0
  local t = tonumber(P.status.thirsty) or 0

  -- Resolve icon/text with simple fallbacks to the '0' (satisfied) entry
  local hungerIcon = StatusIcons.hunger.icon[h] or StatusIcons.hunger.icon[0] or ""
  local hungerText = StatusIcons.hunger.text[h] or StatusIcons.hunger.text[0] or "Unknown"
  local thirstIcon = StatusIcons.thirst.icon[t] or StatusIcons.thirst.icon[0] or ""
  local thirstText = StatusIcons.thirst.text[t] or StatusIcons.thirst.text[0] or "Unknown"

  section("Character")
  line("%sLevel %s%d  %sAge %s%dy %s(%dh%s)\n",
    label, value, P.level,
    label, value, P.age.years,
    label, P.age.hours, label)

  section("Attributes")
  local A = P.stats.attributes
  -- Base stats
  line(
    "%sBase     %sSTR %-2d  INT %-2d  WIS %-2d  DEX %-2d  CON %-2d\n",
    label, value,
    A.str.base, A.int.base, A.wis.base, A.dex.base, A.con.base
  )
  -- Modified Stats
  line(
    "%sModified %sSTR %s%-2d%s  INT %s%-2d%s  WIS %s%-2d%s  DEX %s%-2d%s  CON %s%-2d\n",
    label, value,
    diffColor(A.str.base,A.str.mod), A.str.mod, value,
    diffColor(A.int.base,A.int.mod), A.int.mod, value,
    diffColor(A.wis.base,A.wis.mod), A.wis.mod, value,
    diffColor(A.dex.base,A.dex.mod), A.dex.mod, value,
    diffColor(A.con.base,A.con.mod), A.con.mod
  )

  section("Vitals")
  line("%sHP %s%-7s %s(+%d)  %sMN %s%-7s %s(+%d)  %sMV %s%-7s %s(+%d)\n",
    bad,   value, P.vitals.hp.."/"..P.vitals.hpMax, label, P.vitals.hpRegen or 0,
    accent,value, P.vitals.mn.."/"..P.vitals.mnMax, label, P.vitals.mnRegen or 0,
    warn,  value, P.vitals.mv.."/"..P.vitals.mvMax, label, P.vitals.mvRegen or 0
  )

  section("Condition")
  -- Ensure format string has one placeholder per argument (8 total)
  line("%sHunger %s%s %s   %sThirst %s%s %s\n",
    label, value, hungerIcon, hungerText,
    label, value, thirstIcon, thirstText)
    
  section("Wealth")
  local goldColor   = goldTag
  local silverColor = silverTag
  line("%sOn Hand  %s%6dg  %s%6ds\n",
    label,
    goldColor,   P.currency.gold,
    silverColor, P.currency.silver
  )
  line("%sBank     %s%6dg  %s%6ds  %s(House %s%dg%s)\n",
    label,
    goldColor,   P.bank.gold,
    silverColor, P.bank.silver,
    label, goldColor, P.bank.house, label
  )

  section("Location")
  line("%s%s\n", sectionTag, M.currentName or "?")
  line("%sRoom %s%s  %sExits %s%s\n",
    label, value, tostring(M.currentRoom) or "?",
    label, value, table.concat(W.room.exits," "))

  section("Status")
  local statusColor = good
  local statusText  = "Ready"

  if P.combat.active then
    statusColor = bad
    statusText  = "In Combat"
  elseif P.status.sleeping then
    statusColor = warn
    statusText  = "Sleeping"
  elseif P.status.resting then
    statusColor = warn
    statusText  = "Resting"
  end
  cecho(con, statusColor .. statusText .. "\n")

  if P.combat.active then
    section("Combat")
    line("%sTarget %s%s\n", label, value, P.combat.target or "?")
    line("%sHealth %s%d%%\n", label, value, P.combat.targetHpPct)
  end
end

function ScorePanel.init()
  ScorePanel.applyTheme()
  ScorePanel.create()
  ScorePanel.registerEvents()
  ScorePanel.refresh()
end