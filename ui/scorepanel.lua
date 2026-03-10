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

local Theme = {}
if Darkmists.GlobalSettings.lightMode then
  Theme.section  = "<midnight_blue>"
  Theme.label    = "<dim_gray>"
  Theme.value    = "<black>"
  Theme.accent   = "<royal_blue>"
  Theme.good     = "<sea_green>"
  Theme.warn     = "<dark_orange>"
  Theme.bad      = "<firebrick>"
  Theme.divider  = "<slate_gray>"
else
  Theme.section  = "<light_steel_blue>"
  Theme.label    = "<dim_gray>"
  Theme.value    = "<white>"
  Theme.accent   = "<deep_sky_blue>"
  Theme.good     = "<medium_spring_green>"
  Theme.warn     = "<orange>"
  Theme.bad      = "<ansi_red>"
  Theme.divider  = "<dark_slate_gray>"
end

local function getDividerWidth()
  local w,_ = getUserWindowSize("ScorePanelConsole")
  local charW,_ = calcFontSize(AffectsWindow.config.fontSize)
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
    ("\n%s━━%s%s<reset>\n"):format(Theme.divider, Theme.section..cleanTitle, Theme.divider..right))
end

local function diffColor(base, mod)
  if mod > base then return Theme.good
  elseif mod < base then return Theme.bad
  else return Theme.value end
end

--ScorePanel = {}
ScorePanel = ScorePanel or {}

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
  ScorePanel.console:setFontSize(AffectsWindow.config.fontSize)
  ScorePanel.console:setFont(AffectsWindow.config.fontName)
  ScorePanel.window:show()
  ScorePanel.window:raiseAll()
  Darkmists.Log("ScorePanel","Score Panel Created")
end

ScorePanel.registerEvents = function()
  if SCOREPANEL_PROMPT_HANDLER then 
    killAnonymousEventHandler(SCOREPANEL_PROMPT_HANDLER) 
    Darkmists.Log("ScorePanel","Killed Old Event Handlers")
  end
  SCOREPANEL_PROMPT_HANDLER = registerAnonymousEventHandler(
    "dmapi.world.prompt",
    function() ScorePanel.refresh() end)
  Darkmists.Log("ScorePanel","Events Registered")
end

ScorePanel.refresh = function()
  local con = "ScorePanelConsole"
  ScorePanel.console:clear()

  local P = dmapi.player
  local W = dmapi.world
  local M = map

  local h = P.status.hungry
  local t = P.status.thirsty

  section("Character")
  line("%sLevel %s%d  %sAge %s%dy %s(%dh%s)\n",
    Theme.label, Theme.value, P.level,
    Theme.label, Theme.value, P.age.years,
    Theme.label, P.age.hours, Theme.label)

  section("Attributes")
  local A = P.stats.attributes
  -- Base stats
  line(
    "%sBase     %sSTR %-2d  INT %-2d  WIS %-2d  DEX %-2d  CON %-2d\n",
    Theme.label, Theme.value,
    A.str.base, A.int.base, A.wis.base, A.dex.base, A.con.base
  )
  -- Modified Stats
  line(
    "%sModified %sSTR %s%-2d%s  INT %s%-2d%s  WIS %s%-2d%s  DEX %s%-2d%s  CON %s%-2d\n",
    Theme.label, Theme.value,
    diffColor(A.str.base,A.str.mod), A.str.mod, Theme.value,
    diffColor(A.int.base,A.int.mod), A.int.mod, Theme.value,
    diffColor(A.wis.base,A.wis.mod), A.wis.mod, Theme.value,
    diffColor(A.dex.base,A.dex.mod), A.dex.mod, Theme.value,
    diffColor(A.con.base,A.con.mod), A.con.mod
  )

  section("Vitals")
  line("%sHP %s%-7s %s(+%d)  %sMN %s%-7s %s(+%d)  %sMV %s%-7s %s(+%d)\n",
    Theme.bad,   Theme.value, P.vitals.hp.."/"..P.vitals.hpMax, Theme.label, P.vitals.hpRegen or 0,
    Theme.accent,Theme.value, P.vitals.mn.."/"..P.vitals.mnMax, Theme.label, P.vitals.mnRegen or 0,
    Theme.warn,  Theme.value, P.vitals.mv.."/"..P.vitals.mvMax, Theme.label, P.vitals.mvRegen or 0
  )

  section("Condition")
  line("<dim_gray>Hunger <white>%s %s   <dim_gray>Thirst <white>%s %s\n",
    StatusIcons.hunger.icon[h], StatusIcons.hunger.text[h],
    StatusIcons.thirst.icon[t], StatusIcons.thirst.text[t])
    
  section("Wealth")
  local goldColor   = Darkmists.GlobalSettings.lightMode and "<goldenrod>" or "<gold>"
  local silverColor = Darkmists.GlobalSettings.lightMode and "<slate_gray>" or "<light_slate_gray>"
  line("%sOn Hand  %s%6dg  %s%6ds\n",
    Theme.label,
    goldColor,   P.currency.gold,
    silverColor, P.currency.silver
  )
  line("%sBank     %s%6dg  %s%6ds  %s(House %s%dg%s)\n",
    Theme.label,
    goldColor,   P.bank.gold,
    silverColor, P.bank.silver,
    Theme.label, goldColor, P.bank.house, Theme.label
  )

  section("Location")
  line("%s%s\n", Theme.section, M.currentName or "?")
  line("%sRoom %s%s  %sExits %s%s\n",
    Theme.label, Theme.value, tostring(M.currentRoom) or "?",
    Theme.label, Theme.value, table.concat(W.room.exits," "))

  local status = "<white>Ready"
  if P.combat.active then status = "<red>In Combat"
  elseif P.status.sleeping then status = "<yellow>Sleeping"
  elseif P.status.resting then status = "<yellow>Resting" end

  section("Status")
  local statusColor = Theme.good
  local statusText  = "Ready"

  if P.combat.active then
    statusColor = Theme.bad
    statusText  = "In Combat"
  elseif P.status.sleeping then
    statusColor = Theme.warn
    statusText  = "Sleeping"
  elseif P.status.resting then
    statusColor = Theme.warn
    statusText  = "Resting"
  end
  cecho(con, statusColor .. statusText .. "\n")

  if P.combat.active then
    section("Combat")
    line("<dim_gray>Target <white>%s\n", P.combat.target or "?")
    line("<dim_gray>Health <white>%d%%\n", P.combat.targetHpPct)
  end
end

ScorePanel.create()
ScorePanel.registerEvents()