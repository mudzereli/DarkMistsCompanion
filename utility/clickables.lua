DMClickables = DMClickables or {}
DMClickables.settings = {
    lastCommand = ""
}

function DMClickables.ClickablePractices(line)
    -- Ignore prompts
    if line:sub(1,1) == "<" then return end

    local cmd = command:lower()
    -- Only during practice / skill commands
    if not (cmd and (
        cmd:match("^prac")
    or cmd:match("^sk")
    or cmd:match("^sp")
    or cmd:match("^$")
    )) then return end

    if cmd:match("^prac")
        or cmd:match("^sk")
        or cmd:match("^sp") then

        DMClickables.settings.lastCommand = cmd
    end

    local raw = line

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
    local txtColor = Darkmists.getDefaultTextColorTag()

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
    elseif (not DMClickables.settings.lastCommand:match("^prac")) then
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
    if SkillUps and SkillUps.history then
        for i, v in ipairs(SkillUps.history) do
        if v.skill == skill:match("^%s*(.-)%s*$") then
            c = "<dark_khaki>"
        end
        end
    end
    
    cechoLink(
        string.format("%s%-19s", c, skillDisplay),
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