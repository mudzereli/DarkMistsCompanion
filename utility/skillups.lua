-- ===================================================================
-- Skill Ups Tracker - Simple skill improvement logger
-- ===================================================================

SkillUps = SkillUps or {}

SkillUps.config = {
  maxSkillUps = 20,  -- Keep last 20 skill ups
}

SkillUps.history = {}

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
  
  cecho(string.format("\n<green>[SKILLUP] <"..Darkmists.getDefaultTextColor()..">%s <dim_gray>improved at <"..Darkmists.getDefaultTextColor()..">%s", 
    skillName, timestamp))
end

-- ===================================================================
-- DISPLAY FUNCTION
-- ===================================================================

function SkillUps.display()
  if #SkillUps.history == 0 then
    cecho("\n<yellow>No skill ups recorded yet!")
    return
  end
  
  cecho("\n<cyan>═══════════════════════════════════════════════════")
  cecho("\n<"..Darkmists.getDefaultTextColor()..">Last <cyan>" .. #SkillUps.history .. " <"..Darkmists.getDefaultTextColor()..">Skill Improvements:")
  cecho("\n<cyan>═══════════════════════════════════════════════════\n")
  
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
      "<dim_gray>[<"..Darkmists.getDefaultTextColor()..">%s<dim_gray>] <green>%-30s <yellow>(%s)\n",
      skillup.timestamp,
      skillup.skill,
      timeAgoStr
    ))
  end
  
  cecho("<cyan>═══════════════════════════════════════════════════\n")
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

tempAlias([[^skillups$]], function()
  SkillUps.display()
end)

-- ===================================================================
-- INIT
-- ===================================================================

cecho("\n<dim_gray>[<"..Darkmists.getDefaultTextColor()..">SkillUps<dim_gray>] <green>Tracker initialized. Type '<"..Darkmists.getDefaultTextColor()..">skillups<green>' to view history.")