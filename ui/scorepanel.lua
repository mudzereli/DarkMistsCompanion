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
local DIVIDER_WIDTH = 48  -- adjust to taste

local function line(fmt, ...)
  cecho("ScorePanelConsole", fmt:format(...))
end

local function section(title)
  local cleanTitle = " "..title.." "
  local remaining = DIVIDER_WIDTH - #cleanTitle
  if remaining < 0 then remaining = 0 end
  local right = string.rep("━", remaining)
  cecho("ScorePanelConsole",
    ("\n<slate_gray>━━%s%s<reset>\n"):format(cleanTitle, right))
end

--ScorePanel = {}
ScorePanel = ScorePanel or {}

ScorePanel.create = function()
  if ScorePanel.window then return end
  
  ScorePanel.window = Darkmists.createTabPanel("ScorePanel","Player Status","Player")

  ScorePanel.console = Geyser.MiniConsole:new({
    name   = "ScorePanelConsole",
    x      = 0,
    y      = 0,
    width  = "100%",
    height = "100%",
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
  line("<dim_gray>Level <white>%d  <dim_gray>Age <white>%dy <dim_gray>(<white>%dh<dim_gray>)\n",
    P.level, P.age.years, P.age.hours)

  section("Vitals")
  line("<red>%d/%d  <blue>%d/%d  <yellow>%d/%d\n",
    P.vitals.hp, P.vitals.hpMax,
    P.vitals.mn, P.vitals.mnMax,
    P.vitals.mv, P.vitals.mvMax)

  section("Condition")
  line("<white>%s %s   %s %s\n",
    StatusIcons.hunger.icon[h], StatusIcons.hunger.text[h],
    StatusIcons.thirst.icon[t], StatusIcons.thirst.text[t])

  section("Wealth")
  line("<dim_gray>On Hand  <yellow>%6dg  <slate_gray>%6ds\n",
    P.currency.gold, P.currency.silver)
  line("<dim_gray>Bank     <yellow>%6dg  <slate_gray>%6ds  <dim_gray>(House <yellow>%dg<dim_gray>)\n",
    P.bank.gold, P.bank.silver, P.bank.house)

  section("Location")
  line("<white>%s\n", M.currentName or "?")
  line("<dim_gray>Room <white>%s  <dim_gray>Exits <white>%s\n",
    tostring(M.currentRoom) or "?",
    table.concat(W.room.exits," "))

  local status = "<white>Ready"
  if P.combat.active then status = "<red>In Combat"
  elseif P.status.sleeping then status = "<yellow>Sleeping"
  elseif P.status.resting then status = "<yellow>Resting" end

  section("Status")
  cecho(con, status.."\n")

  if P.combat.active then
    section("Combat")
    line("<dim_gray>Target <white>%s\n", P.combat.target or "?")
    line("<dim_gray>Health <white>%d%%\n", P.combat.targetHpPct)
  end
end

ScorePanel.create()
ScorePanel.registerEvents()