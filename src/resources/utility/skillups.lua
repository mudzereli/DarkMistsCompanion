-- ===================================================================
-- Skill Ups Tracker - Simple skill improvement logger
-- ===================================================================
SkillUps = {
  config = {
    maxSkillUps = 20,  -- Keep last 20 skill ups
  },
  history = {},
  -- No need for eventHandler tracking; managed by EventManager
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
  
  DMLogger.notify("SkillUps",string.format("%s%s %simproved at %s%s!", 
    DarkmistsTheme.textTag, skillName,
    DarkmistsTheme.mutedTag,
    DarkmistsTheme.textTag, timestamp))
end

-- ===================================================================
-- DISPLAY FUNCTION
-- ===================================================================

function SkillUps.display()
  if #SkillUps.history == 0 then
    DMLogger.notify("SkillUps",DarkmistsTheme.warnTag.."No skill ups recorded yet!")
    return
  end
  
  cecho(string.format("\n%s═══════════════════════════════════════════════════", DarkmistsTheme.cyanTag))
  cecho(string.format("\n%sLast %s%d %sSkill Improvements:", DarkmistsTheme.textTag, DarkmistsTheme.highlightTag, #SkillUps.history, DarkmistsTheme.textTag))
  cecho(string.format("\n%s═══════════════════════════════════════════════════\n", DarkmistsTheme.cyanTag))
  
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
      "%s[%s%s%s] %s%-30s %s(%s)\n",
      DarkmistsTheme.mutedTag,
      DarkmistsTheme.textTag, skillup.timestamp,
      DarkmistsTheme.mutedTag,
      DarkmistsTheme.goodTag,
      skillup.skill,
      DarkmistsTheme.highlightTag,
      timeAgoStr
    ))
  end
  
  cecho(string.format("\n%s═══════════════════════════════════════════════════", DarkmistsTheme.cyanTag))
end

function SkillUps.reset()
  SkillUps.history = {}
  DMLogger.notify("SkillUps",string.format("%sSkill improvement history reset.", DarkmistsTheme.warnTag))
end


-- ===================================================================
-- EVENT HANDLER (managed by EventManager)
-- ===================================================================

DarkmistsEvents.add(
  "SkillUpsImproved",
  "dmapi.player.skill.improved",
  function(_, data)
    SkillUps.addSkillUp(data.skill)
  end
)

-- ===================================================================
-- ALIAS
-- ===================================================================
DarkmistsAlias.add([[^skillups?$]], function()
  cecho(DarkmistsTheme.cyanTag..[[
SkillUps Module:
    ]]..DarkmistsTheme.mutedTag..[[The SkillUps module tracks recent skill improvements as they occur.
    Each time a skill increases, a notification is displayed and the
    improvement is recorded in the tracker history. Skill ups can be
    viewed at any time using ']]..DarkmistsTheme.textTag..[[skillups list]]..DarkmistsTheme.mutedTag..[[', and
    are visually highlighted within the practice screen for quick
    reference.

]]..DarkmistsTheme.cyanTag..[[SkillUps Commands:
  ]]..DarkmistsTheme.textTag..[[skillups list
    ]]..DarkmistsTheme.mutedTag..[[List all recent skill increases.

  ]]..DarkmistsTheme.textTag..[[skillups reset
    ]]..DarkmistsTheme.mutedTag..[[Clear the skill increase history.
    ]])
  end)

DarkmistsAlias.add([[^skillups? list$]], function()
  SkillUps.display()
end)

DarkmistsAlias.add([[^skillups? reset$]], function()
  SkillUps.reset()
end)

-- ===================================================================
-- INIT
-- ===================================================================

DMLogger.log("SkillUps",string.format("%sTracker initialized. Type '%sskillups%s' to view history.", DarkmistsTheme.goodTag, DarkmistsTheme.textTag, DarkmistsTheme.goodTag))