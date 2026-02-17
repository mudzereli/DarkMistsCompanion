-- ===================================================================
-- Skill Ups Tracker - Simple skill improvement logger
-- ===================================================================
if SkillUps and SkillUps.eventHandler then
  killAnonymousEventHandler(SkillUps.eventHandler)
  Darkmists.Log("SkillUps",("Killed Anonymous Event Handler #%d"):format(SkillUps.eventHandler))
end

SkillUps = {
  config = {
    maxSkillUps = 20,  -- Keep last 20 skill ups
  },
  history = {},
  eventHandler = nil
}

-- ===================================================================
-- TRACKING FUNCTION
-- ===================================================================

function SkillUps.addSkillUp(skillName)
  local timestamp = os.date("%H:%M:%S")
  
  -- Add to front of history
  table.insert(SkillUps.history, 1, {
    skill = skillName,
    timestamp = timestamp,
    time = os.time()
  })
  
  -- Keep only the last maxSkillUps
  while #SkillUps.history > SkillUps.config.maxSkillUps do
    table.remove(SkillUps.history)
  end
  
  local c = Darkmists.getDefaultTextColorTag()
  Darkmists.Log("SkillUps",string.format("%s%s <dim_gray>improved at %s%s!", 
    c, skillName, 
    c, timestamp))
end

-- ===================================================================
-- DISPLAY FUNCTION
-- ===================================================================

function SkillUps.display()
  local c = Darkmists.getDefaultTextColorTag()
  if #SkillUps.history == 0 then
    Darkmists.Log("SkillUps","<red>No skill ups recorded yet!")
    return
  end
  
  cecho("\n<ansi_cyan>═══════════════════════════════════════════════════")
  cecho(("\n%sLast <ansi_cyan>%d %sSkill Improvements:"):format(c,#SkillUps.history,c))
  cecho("\n<ansi_cyan>═══════════════════════════════════════════════════\n")
  
  for i, skillup in ipairs(SkillUps.history) do
    local timeAgo = os.time() - skillup.time
    local timeAgoStr
    
    if timeAgo < 60 then
      timeAgoStr = string.format("%ds ago", timeAgo)
    elseif timeAgo < 3600 then
      timeAgoStr = string.format("%dm ago", math.floor(timeAgo / 60))
    else
      timeAgoStr = string.format("%dh %dm ago", 
        math.floor(timeAgo / 3600), 
        math.floor((timeAgo % 3600) / 60))
    end
    
    cecho(string.format(
      "<dim_gray>[%s%s<dim_gray>] <green>%-30s <dark_khaki>(%s)\n",
      c,skillup.timestamp,
      skillup.skill,
      timeAgoStr
    ))
  end
  
  cecho("<ansi_cyan>═══════════════════════════════════════════════════\n")
end

function SkillUps.reset()
  SkillUps.history = {}
  Darkmists.Log("SkillUps","<red>Skill improvement history reset.")
end

-- ===================================================================
-- EVENT HANDLER
-- ===================================================================

SkillUps.eventHandler = registerAnonymousEventHandler(
  "dmapi.player.skill.improved",
  function(_, data)
    SkillUps.addSkillUp(data.skill)
  end
)

-- ===================================================================
-- ALIAS
-- ===================================================================
tempAlias([[^skillups?$]], function()
  local c = Darkmists.getDefaultTextColorTag()
  cecho([[
    <ansi_cyan>SkillUps Module:
        <dim_gray>The SkillUps module tracks recent skill improvements as they occur.
        Each time a skill increases, a notification is displayed and the
        improvement is recorded in the tracker history. Skill ups can be
        viewed at any time using ']]..c..[[skillups list<dim_gray>', and
        are visually highlighted within the practice screen for quick
        reference.

    <ansi_cyan>SkillUps Commands:
      ]]..c..[[skillups list
        <dim_gray>List all recent skill increases.

      ]]..c..[[skillups reset
        <dim_gray>Clear the skill increase history.
    ]])
  end)

tempAlias([[^skillups? list$]], function()
  SkillUps.display()
end)

tempAlias([[^skillups? reset$]], function()
  SkillUps.reset()
end)

-- ===================================================================
-- INIT
-- ===================================================================

Darkmists.Log("SkillUps",("<forest_green>Tracker initialized. Type '%sskillups<forest_green>' to view history."):format(Darkmists.getDefaultTextColorTag()))