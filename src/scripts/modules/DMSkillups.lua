-- ===================================================================
-- Skill Ups Tracker - Simple skill improvement logger
-- ===================================================================
SkillUps = {
  config = {
    maxSkillUps = 50,  -- Keep last 50 skill ups
  },
  history = {},
  -- No need for eventHandler tracking; managed by EventManager
}

-- Display constants — centralised so formatting changes propagate to window sizing
local SEPARATOR = "═══════════════════════════════════════════════════"
local SEP_LEN   = (utf8 and utf8.len and utf8.len(SEPARATOR)) or #SEPARATOR
local HEADER_LINES = 4  -- sep + title+reset + sep + blank (leading blank is absorbed by empty console)

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
  
  -- Clickable notification — clicking the skill name opens the full list
  cecho(string.format("\n%s[%sSkillUps%s] ", DarkmistsTheme.mutedTag, DarkmistsTheme.textTag, DarkmistsTheme.mutedTag))
  cechoLink(string.format("<u>%s</u>", skillName), "SkillUps.showAlert()", "Click to view skill improvement history", true)
  cecho(string.format(" %simproved at %s%s!<reset>", DarkmistsTheme.mutedTag, DarkmistsTheme.textTag, timestamp))
end

-- ===================================================================
-- DISPLAY FUNCTION
-- ===================================================================

function SkillUps.display(win)
  -- win: optional window name (e.g. alert panel body). Renders to main console if nil.
  local function echo(fmt, ...)
    local msg = fmt:format(...)
    if win then cecho(win, msg) else cecho(msg) end
  end

  if #SkillUps.history == 0 then
    if win then
      echo("%sNo skill ups recorded yet!", DarkmistsTheme.warnTag)
    else
      DMLogger.notify("SkillUps", DarkmistsTheme.warnTag .. "No skill ups recorded yet!")
    end
    return
  end

  echo("\n%s" .. SEPARATOR, DarkmistsTheme.cyanTag)
  echo("\n%sLast %s%d %sSkill Improvements:", DarkmistsTheme.textTag, DarkmistsTheme.highlightTag, #SkillUps.history, DarkmistsTheme.textTag)
  if win then
    cechoLink(win, "    <red><u>[Reset]</u><reset>", [[SkillUps.reset(); DMAlertWindow.Hide()]], "Reset skill improvement history", true)
  end
  echo("\n%s" .. SEPARATOR .. "\n", DarkmistsTheme.cyanTag)

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

    echo("%s[%s%s%s] %s%-30s %s(%s)\n",
      DarkmistsTheme.mutedTag,
      DarkmistsTheme.textTag, skillup.timestamp,
      DarkmistsTheme.mutedTag,
      DarkmistsTheme.goodTag,
      skillup.skill,
      DarkmistsTheme.highlightTag,
      timeAgoStr)
  end

  echo("%s" .. SEPARATOR, DarkmistsTheme.cyanTag)
end

function SkillUps.showAlert()
  if #SkillUps.history == 0 then
    DMLogger.notify("SkillUps", DarkmistsTheme.warnTag .. "No skill ups recorded yet!")
    return
  end

  -- Derive window size from alert window's actual font and chrome dimensions
  local charW, charH = calcFontSize(DMAlertWindow.getBodyFontSize())
  if not charW then charW = 8 end
  if not charH then charH = 16 end
  local totalLines  = HEADER_LINES + #SkillUps.history
  -- Match DMAlertWindow's wrapAt formula: floor((w - borderSize*2) / charW) - 2 >= SEP_LEN
  -- So w >= (SEP_LEN + 2) * charW + borderSize*2
  local estWidth   = math.max(400, (SEP_LEN + 2) * charW + DMAlertWindow.getBorderPx())
  local estHeight   = math.min(520, totalLines * charH + DMAlertWindow.getChromeHeight())

  DMAlertWindow.Show("Skill Improvements", function(win)
    SkillUps.display(win)
  end, { width = estWidth, height = estHeight, scrollable = true })
end

function SkillUps.reset()
  SkillUps.history = {}
  DMLogger.notify("SkillUps",string.format("%sSkill improvement history reset.", DarkmistsTheme.warnTag))
end


function SkillUps.RegisterHandlers()
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
    SkillUps.showAlert()
  end)

  DarkmistsAlias.add([[^skillups? reset$]], function()
    SkillUps.reset()
  end)
end

-- ===================================================================
-- INIT
-- ===================================================================

function SkillUps.init()
  SkillUps.RegisterHandlers()
  DMLogger.log("SkillUps",string.format("%sTracker initialized. Type '%sskillups%s' to view history.", DarkmistsTheme.goodTag, DarkmistsTheme.textTag, DarkmistsTheme.goodTag))
end