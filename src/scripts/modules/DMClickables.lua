DMClickables = {}
DMClickables.settings = {
    lastSkillCommand = ""
}

function DMClickables.ClickablePractices()
    local raw = getCurrentLine()

    -- ignore empty lines
    if not raw or raw == "" then return end

    -- ignore prompty stuff, and also trigger a command reset
    if raw:sub(1,1) == "<" then 
        DMClickables.settings.lastSkillCommand = ""
        return 
    end

    -- only trigger off certain commands
    if not command then return end
    local cmd = command:lower()
    local match_prac_skill_spell = cmd:match("^prac")
        or cmd:match("^sk")
        or cmd:match("^sp")

    if match_prac_skill_spell then
        DMClickables.settings.lastSkillCommand = cmd
    end

    -- if we just pressed enter but had a previous command then we should keep going
    if not (match_prac_skill_spell or cmd:match("^$")) then 
        return 
    end

    -- capture optional "Level NN:" prefix
    local levelPrefix = raw:match("^(%s*Level%s+%d+:%s*)")

    -- strip it only for parsing
    if levelPrefix then
    raw = raw:gsub("^%s*Level%s+%d+:%s*", "")
    end

    -- strip continuation indentation
    raw = raw:gsub("^%s+", "")

    local found = false
    local output = {}
    local txtColor = "<r>"
    
    -- collect skills first - UPDATED to include dash
    for skill, pct in raw:gmatch("([%a%-][%a%s'%-]-)%s+(%d+)%%") do
    found = true
    table.insert(output, { skill = skill, pct = pct, suffix = "%" })
    end

    for skill, pct in raw:gmatch("([%a%-][%a%s'%-]-)%s+(%d+) mana") do
    found = true
    table.insert(output, { skill = skill, pct = pct, suffix = " mana" })
    end

    for skill, pct in raw:gmatch("([%a%-][%a%s'%-]-)%s+n/a") do
    found = true
    table.insert(output, { skill = skill, pct = " n/a", suffix = "" })
    end

    if not found then return end

    replaceLine("")

    if levelPrefix then
        cecho(txtColor .. levelPrefix)
    elseif DMClickables.settings.lastSkillCommand:match("(.*)list$")
      or (not DMClickables.settings.lastSkillCommand:match("^prac")) then
        cecho(txtColor.."          ")
    end

    for _, entry in ipairs(output) do
    local skill = entry.skill
    local pct   = entry.pct
    local skillDisplay = skill
    if #skillDisplay > 19 then
        skillDisplay = skillDisplay:sub(1,19)
    end
    
    local c = "<steel_blue>"
    local trimmed = skill:match("^%s*(.-)%s*$")

    if SkillUps and SkillUps.history then
        for _, v in ipairs(SkillUps.history) do
            if v.skill == trimmed then
                c = "<dark_khaki>"
                break
            end
        end
    end
    
    cechoLink(
        string.format("%s%-20s", c, skillDisplay),
        function()
        if holdingModifiers(mudlet.keymodifier.Shift) then
            send("prac " .. skill)
            send("practice")
        else
            send("help " .. skill)
        end
        end,
        "Click: help " .. skill .. "\nShift+Click: practice " .. skill,
        true
    )
    
    -- Color code the percentage
    local color = txtColor
    if pct ~= " n/a" and entry.suffix == "%" then
        local numPct = tonumber(pct)
        if numPct == 100 then
        color = "<dark_green>"
        elseif numPct >= 90 then
        color = "<dark_khaki>"
        elseif numPct >= 50 then
        color = "<coral>"
        else
        color = "<red>"
        end
    end
    
    cecho(string.format("%s%3s%s  ", color, pct, entry.suffix))
    end
end

DMClickables.auctions = {
  active = false,
  linesLeft = 0,
}

function DMClickables.RenderAuctionPager(raw)
  if not raw then return false end
  if not raw:find("auction list", 1, true) then return false end

  local prefix, content = raw:match("^(.-)%[(.-)%]%s*$")
  if not content or not content:match("^%s*Page%s+%d+/%d+") then return false end

  prefix = (prefix or ""):gsub("%s+$", "")

  replaceLine("")
  if prefix ~= "" then
    cecho("<r>" .. prefix .. " ")
  end
  cecho("<r>[ ")

  local first = true
  for segment in content:gmatch("([^|]+)") do
    local part = segment:gsub("^%s+", ""):gsub("%s+$", "")

    if not first then
      cecho("<r> | ")
    end
    first = false

    local label, cmd = part:match("^(prev):%s*(auction list %d+)$")
    if not cmd then
      label, cmd = part:match("^(next):%s*(auction list %d+)$")
    end

    if cmd then
      cecho("<r>" .. label .. ": ")
      cechoLink(
        string.format("<forest_green><u>%s</u>", cmd),
        function()
          send(cmd)
        end,
        string.format("Click: %s", cmd),
        true
      )
    else
      cecho("<r>" .. part)
    end
  end

  cecho("<r> ]\n")
  return true
end

function DMClickables.ClickableAuctions()
  if not DMClickables then return end

  local state = DMClickables.auctions
  local raw = getCurrentLine()
  if not raw or raw == "" then return end

  if DMClickables.RenderAuctionPager(raw) then
    return
  end

  if raw:match("^Item ID%s+Name%s+Buyout%s+Time Left%s+Current Bid") then
    state.active = true
    state.linesLeft = 21
    return
  end

  if not state.active then return end
  if state.linesLeft <= 0 then
    state.active = false
    return
  end

  state.linesLeft = state.linesLeft - 1

  if raw:match("^%-%-%-%-%-.*") then
    return
  end

  local id, name, buyout, timeLeft, bid, suffix = raw:match(
    "^%s*([a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9])%s+(.-)%s%s+(%d+)%s+([0-9dhm%s]-)%s%s+(%d*)%s*(.*)$"
  )
  if not name then return end

  replaceLine("")

  name = name:gsub("^%s+", "")
  name = name:gsub("%s+$", "")
  timeLeft = timeLeft:gsub("%s+$", "")
  if #name >= 28 then
    name = name:sub(1, 28)
  end

  local bidNum = tonumber(bid) or 0

  cechoLink(
    string.format("<forest_green><u>%7s</u>", id),
    function()
      send("auc browse " .. id)
    end,
    string.format("Click: auc browse %s", id),
    true
  )
  cecho("<r>  ")
  cechoLink(
    string.format("<r>%-28s", name),
    function()
      send("auc browse " .. id)
    end,
    string.format("Click: auc browse %s", id),
    true
  )
  cecho("<r>  ")

  cechoLink(
    string.format("<dark_khaki>%7s", buyout),
    function()
      send("auc buyout " .. id)
      send("auc list")
    end,
    string.format("Click: auc buyout %s", id),
    true
  )
  cecho("<r>  ")

  cecho("<r>" .. ("%11s"):format(timeLeft))
  cecho("<r>  ")

  cechoLink(
    string.format("<dark_khaki>%11s", bid),
    function()
      send(("auc bid %s %s"):format(id, bidNum + 1))
      send("auc list")
    end,
    string.format("Click: auc bid %s %d", id, bidNum + 1),
    true
  )

  if suffix and suffix ~= "" then
    cecho(("<forest_green>%s"):format(suffix))
  end
  cecho("\n")
end

DMClickables.quests = {
  active = false,
  linesLeft = 0,
}

function DMClickables.ClickableQuests()
  local raw = getCurrentLine()
  if not raw or raw == "" then return end

  local state = DMClickables.quests

  -- Header line activates the state machine
  if raw:match("^Quest%s+Title%s+Summary") then
    state.active = true
    state.linesLeft = 30
    return
  end

  if not state.active then return end
  if state.linesLeft <= 0 then
    state.active = false
    return
  end
  state.linesLeft = state.linesLeft - 1

  -- Quest line: number + description
  local questNum, rest = raw:match("^%s*(%d+)%s%s+(.+)$")
  if not questNum then return end

  local txtColor = "<r>"
  replaceLine("")
  cechoLink(
    string.format("<forest_green>%12s%s  %s\n", "<u>"..questNum.."</u>", txtColor, rest),
    function()
      if holdingModifiers(mudlet.keymodifier.Shift) then
        send("quest drop " .. questNum)
        send("quest current")
      else
        send("quest read " .. questNum)
      end
    end,
    string.format("Click: quest read %s | Shift+Click: quest drop %s", questNum, questNum),
    true
  )
end

DMClickables.essence = {
  active = false,
  cap = 225
}

function DMClickables.ClickableEssences()

  local raw = getCurrentLine()

  if not raw or raw == "" then return end

  -- START BLOCK
  if raw:match("^Your stored essences %(cap:%s*(%d+) per material%):$") then
    local cap = raw:match("%(cap:%s*(%d+)")
    if cap then
      DMClickables.essence.cap = tonumber(cap)
    end
    DMClickables.essence.active = true
    return
  end

  -- END BLOCK
  if DMClickables.essence.active and raw:match("^Total:%s+%d+ essences stored across") then
    DMClickables.essence.active = false
    return
  end

  -- ignore everything outside block
  if not DMClickables.essence.active then return end

  -- skip pager
  if raw:match("^%[Hit Return to continue%]") then return end

    -- if line doesn't contain essence pairs, block was interrupted
  if not raw:match("([%a]+)%s+(%d+)") then
    DMClickables.essence.active = false
    return
  end
  
  local output = {}
  local cap = DMClickables.essence.cap

  for mat, num in raw:gmatch("([%a]+)%s+(%d+)") do
    local n = tonumber(num)
    local pct = n / cap
    local color = "<red>"

    if pct >= 1 then
      color = "<dark_green>"
    elseif pct >= .9 then
      color = "<green>"
    elseif pct >= .75 then
      color = "<dark_khaki>"
    elseif pct >= .5 then
      color = "<coral>"
    end

    table.insert(output,
      string.format("<steel_blue>%-15s %s%3d<reset>", mat, color, n)
    )
  end

  if #output == 0 then return end

  replaceLine("")
  cecho("   " .. table.concat(output, "      "))
end

DMClickables.vault = {
  active = false,
}

function DMClickables.ClickableVaultNumbers()
  local raw = getCurrentLine()
  if not raw or raw == "" then return end

  -- Header activates vault capture
  if raw:find("^=== VAULT") then
    DMClickables.vault.active = true
    return
  end

  if not DMClickables.vault.active then return end

  -- Extract [number] from vault listing lines
  -- Format: [+ ]    [12345] item name
  local num = raw:match("^%s*%+?%s*%[([%d]+)%]")
  if not num then return end

  local s, e = raw:find("%[" .. num .. "%]")
  if not s then return end

  selectCurrentLine()

  if selectSection(s, e - s - 1) then
    setLink(function()
      send(("get %s vault"):format(num))
    end, string.format("Click: get %s vault", num))
    setFgColor(0, 100, 0)
    setUnderline(true)
  end
  resetFormat()
  moveCursorEnd()
end

function DMClickables.init()
  DarkmistsEvents.add("DMClickables.AuctionPromptReset", "dmapi.world.prompt", function()
    DMClickables.auctions.active = false
    DMClickables.auctions.linesLeft = 0
  end)

  DarkmistsEvents.add("DMClickables.QuestPromptReset", "dmapi.world.prompt", function()
    DMClickables.quests.active = false
    DMClickables.quests.linesLeft = 0
  end)

  DarkmistsEvents.add("DMClickables.VaultPromptReset", "dmapi.world.prompt", function()
    DMClickables.vault.active = false
  end)

  DarkmistsEvents.add("DMClickables.Auctions", "dmapi.core.line", function()
    DMClickables.ClickableAuctions()
  end)

  DarkmistsEvents.add("DMClickables.Practices", "dmapi.core.line", function()
    DMClickables.ClickablePractices()
  end)

  DarkmistsEvents.add("DMClickables.Essences", "dmapi.core.line", function()
    DMClickables.ClickableEssences()
  end)

  DarkmistsEvents.add("DMClickables.Quests", "dmapi.core.line", function()
    DMClickables.ClickableQuests()
  end)

  DarkmistsEvents.add("DMClickables.VaultNumbers", "dmapi.core.line", function()
    DMClickables.ClickableVaultNumbers()
  end)
end