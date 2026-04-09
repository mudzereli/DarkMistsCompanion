-- =============================================================================
-- CMudWrapper
--
-- Persistent CMUD-like wrapper for aliases/triggers/variables
-- Save file: /scripts/saved/cmud_wrapper.lua
-- Reload-safe: kills old handles before re-installing
-- =============================================================================

if rawget(_G, "CMudWrapper") and CMudWrapper.unload then
  pcall(CMudWrapper.unload)
end

-- User-configurable options (change these as desired)
CMudWrapper = {
  commandChar = "#", -- character that prefixes CMudWrapper commands (e.g. #ALIAS)
  -- Default command separator used inside alias bodies. Common separators: ';' or '|'.
  -- Make this configurable; change at runtime with `CMudWrapper.commandSeparator = '|'`.
  commandSeparator = "|",
  savePath = getMudletHomeDir() .. "/scripts/saved/cmud_wrapper.lua",
  state = { aliases = {}, triggers = {}, vars = {}, defaults = {} },
  handles = { aliases = {}, triggers = {} },
  commandHandle = nil,
}

local function trim(s)
  return (s or ""):match("^%s*(.-)%s*$")
end

local function parseArgs(s)
  local out, i = {}, 1
  while i <= #s do
    while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
    if i > #s then break end

    if s:sub(i, i) == "{" then
      local depth, start = 1, i + 1
      i = i + 1
      while i <= #s and depth > 0 do
        local ch = s:sub(i, i)
        if ch == "{" then depth = depth + 1
        elseif ch == "}" then depth = depth - 1 end
        i = i + 1
      end
      out[#out + 1] = s:sub(start, i - 2)
    else
      local start = i
      while i <= #s and not s:sub(i, i):match("%s") do i = i + 1 end
      out[#out + 1] = s:sub(start, i - 1)
    end
  end
  return out
end

local function applyVars(text)
  for k, v in pairs(CMudWrapper.state.vars) do
    text = text:gsub("@" .. k, tostring(v))
  end
  return text
end

local function applyMatches(text, matchTable, negMap)
  if not matchTable and not negMap then return text end
  local protected = {}
  -- Protect doubled-percent sequences like %%1 and %%-(1) -> placeholder so single-pass substitution
  text = text:gsub("%%%%%-(%d+)", function(num)
    local key = "__CMW_PCT_NEG_" .. num .. "__"
    protected[key] = "%-" .. num
    return key
  end)
  text = text:gsub("%%%%(%d+)", function(num)
    local key = "__CMW_PCT_" .. num .. "__"
    protected[key] = "%" .. num
    return key
  end)

  if matchTable then
    for i = 2, #matchTable do
      text = text:gsub("%%" .. tostring(i - 1), matchTable[i] or "")
    end
  end

  if negMap then
    text = text:gsub("%%-(%d+)", function(num)
      return negMap[tonumber(num)] or ""
    end)
  end

  -- restore protected tokens to single-percent form (delayed expansion)
  for k, v in pairs(protected) do
    text = text:gsub(k, v)
  end

  return text
end

local function isPrefix(prefix, target)
  if not prefix or prefix == "" then return false end
  prefix = prefix:upper()
  target = (target or ""):upper()
  return target:sub(1, #prefix) == prefix
end

local function escapeRegex(text)
  return (tostring(text):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

function CMudWrapper.save()
  table.save(CMudWrapper.savePath, CMudWrapper.state)
end

function CMudWrapper.setVariable(name, value, default)
  if not name then return end
  name = tostring(name)
  if default then
    if default == "_nodef" then
      CMudWrapper.state.defaults[name] = nil
    else
      CMudWrapper.state.defaults[name] = default
    end
  end

  CMudWrapper.state.vars[name] = value
  CMudWrapper.save()
  cecho(("<green>[CMudWrapper] variable set: %s = %s\n"):format(name, tostring(value)))
end

function CMudWrapper.runLine(line, matchTable, negMap)
  line = trim(applyMatches(applyVars(line), matchTable, negMap))
  if line == "" then return end

  if line:sub(1, 1) == CMudWrapper.commandChar then
    CMudWrapper.exec(line)
  else
    send(line)
  end
end

function CMudWrapper.runBody(body, matchTable, negMap)
  body = applyMatches(applyVars(body or ""), matchTable, negMap)
  -- build a character class of separators: include configured plus common ones
  local configured = tostring(CMudWrapper.commandSeparator)
  local candidates = {}
  candidates[configured] = true
  candidates["|"] = true

  local chars = {}
  for s, _ in pairs(candidates) do
    -- only take first character if multi-char separator
    local ch = s:sub(1,1)
    -- escape magic characters for char class
    ch = ch:gsub("([%]%\\%^%-])","%%%1")
    chars[#chars+1] = ch
  end

  local esc = table.concat(chars)
  -- build proper pattern for char class
  local pat = "([^" .. esc .. "]+)"
  for cmd in body:gmatch(pat) do
    cmd = trim(cmd)
    if cmd ~= "" then
      CMudWrapper.runLine(cmd, matchTable, negMap)
    end
  end
end

function CMudWrapper.installAlias(name, spec)
  if CMudWrapper.handles.aliases[name] then
    pcall(killAlias, CMudWrapper.handles.aliases[name])
  end

  local function aliasHandler()
    local captured = matches or {}

    if spec.tail then
      -- support patterns where the tail capture may be in matches[1] or matches[2]
      local raw = captured[2] or captured[1] or ""
      local words = {}
      for w in raw:gmatch("%S+") do
        words[#words + 1] = w
      end

      local mt = { [1] = captured[1] }
      for i = 1, #words do mt[i + 1] = words[i] end

      local neg = {}
      for i = 1, #words do
        neg[i] = table.concat(words, " ", i)
      end
      neg[1] = raw

      CMudWrapper.runBody(spec.body, mt, neg)
    else
      CMudWrapper.runBody(spec.body, captured, nil)
    end
  end

  local ok, id_or_err = pcall(function() return tempAlias(spec.pattern, aliasHandler) end)
  if ok and id_or_err then
    CMudWrapper.handles.aliases[name] = id_or_err
  else
    cecho(("<red>[CMudWrapper] failed to register alias '%s' pattern=%s error=%s\n"):format(tostring(name), tostring(spec.pattern), tostring(id_or_err)))
  end
end

function CMudWrapper.installTrigger(name, spec)
  if CMudWrapper.handles.triggers[name] then
    pcall(killTrigger, CMudWrapper.handles.triggers[name])
  end

  CMudWrapper.handles.triggers[name] = tempRegexTrigger(spec.pattern, function()
    CMudWrapper.runBody(spec.body, matches, nil)
  end)
end

function CMudWrapper.removeAlias(name)
  if CMudWrapper.handles.aliases[name] then
    pcall(killAlias, CMudWrapper.handles.aliases[name])
    CMudWrapper.handles.aliases[name] = nil
  end
  CMudWrapper.state.aliases[name] = nil
  CMudWrapper.save()
  cecho(("<green>[CMudWrapper] alias removed: %s\n"):format(tostring(name)))
end

function CMudWrapper.removeTrigger(name)
  if CMudWrapper.handles.triggers[name] then
    pcall(killTrigger, CMudWrapper.handles.triggers[name])
    CMudWrapper.handles.triggers[name] = nil
  end
  CMudWrapper.state.triggers[name] = nil
  CMudWrapper.save()
end

function CMudWrapper.unload()
  if CMudWrapper.commandHandle then
    pcall(killAlias, CMudWrapper.commandHandle)
    CMudWrapper.commandHandle = nil
  end

  if CMudWrapper.assignHandle then
    pcall(killAlias, CMudWrapper.assignHandle)
    CMudWrapper.assignHandle = nil
  end

  for _, id in pairs(CMudWrapper.handles.aliases or {}) do
    pcall(killAlias, id)
  end
  for _, id in pairs(CMudWrapper.handles.triggers or {}) do
    pcall(killTrigger, id)
  end

  CMudWrapper.handles = { aliases = {}, triggers = {} }
end

function CMudWrapper.exec(line)
  if line:sub(1, 1) ~= CMudWrapper.commandChar then return false end

  local args = parseArgs(line:sub(2))
  local verb = (table.remove(args, 1) or "")

  if isPrefix(verb, "ALIAS") then
    -- New simplified form: #ALIAS {name} {body}
    local name = args[1]
    local body = nil
    if #args >= 2 then
      body = table.concat(args, " ", 2)
    end
    -- If no args: list aliases
    if not name then
      cecho("<cyan>[CMudWrapper] Aliases:\n")
      for k, v in pairs(CMudWrapper.state.aliases) do
        cecho(("  <white>%s<r>: %s\n"):format(k, v.body or ""))
      end
      return true
    end

    -- If only name provided, show definition
    if name and not body then
      local def = CMudWrapper.state.aliases[name]
      if def then
        cecho(("<cyan>[CMudWrapper] %s -> %s\n"):format(name, def.body or ""))
      else
        cecho(("<yellow>[CMudWrapper] alias not found: %s\n"):format(name))
      end
      return true
    end

    -- For the simplified API, build a default pattern that captures a tail
    local usesTail = true
    local pattern = "^" .. escapeRegex(name) .. "\\s*(.*)$"

    assert(name and body, "#ALIAS {name} {body}")
    -- sanitize any protected/delayed-placeholder tokens that may have been
    -- introduced by earlier substitution passes (e.g. __CMW_PCT_fireball__)
    -- map negative placeholders first: __CMW_PCT_NEG_<n>__ -> %-<n>
    body = body:gsub("__CMW_PCT_NEG_(%d+)__", function(n) return "%-" .. n end)
    -- map any remaining protected placeholders to a single positional token (%1)
    body = body:gsub("__CMW_PCT_[^_]+__", "%%1")

    CMudWrapper.state.aliases[name] = { pattern = pattern, body = body, tail = usesTail }
    CMudWrapper.installAlias(name, CMudWrapper.state.aliases[name])
    CMudWrapper.save()
    cecho(("<green>[CMudWrapper] alias saved: %s\n"):format(name))

  elseif isPrefix(verb, "UNALIAS") then
    assert(args[1], "#UNALIAS {name}")
    CMudWrapper.removeAlias(args[1])

  elseif verb == "TRIGGER" or verb == "ACTION" then
    local name, pattern, body = args[1], args[2], args[3]
    assert(name and pattern and body, "#TRIGGER {name} {pattern} {body}")
    CMudWrapper.state.triggers[name] = { pattern = pattern, body = body }
    CMudWrapper.installTrigger(name, CMudWrapper.state.triggers[name])
    CMudWrapper.save()
    cecho(("<green>[CMudWrapper] trigger saved: %s\n"):format(name))

  elseif verb == "UNTRIGGER" then
    assert(args[1], "#UNTRIGGER {name}")
    CMudWrapper.removeTrigger(args[1])

  elseif isPrefix(verb, "VARIABLE") or isPrefix(verb, "VAR") or verb:upper() == "VA" then
    local name = args[1]
    local value = args[2]

    if not name then
      cecho("<cyan>[CMudWrapper] Variables:\n")
      for k, v in pairs(CMudWrapper.state.vars) do
        cecho(("  <white>%s<r>: %s\n"):format(k, tostring(v)))
      end
      return true
    end

    if value == nil then
      local current = CMudWrapper.state.vars[name]
      if current ~= nil then
        cecho(("<cyan>[CMudWrapper] %s -> %s\n"):format(name, tostring(current)))
      else
        cecho(("<yellow>[CMudWrapper] variable not found: %s\n"):format(name))
      end
      return true
    end

    local default = args[3]
    CMudWrapper.setVariable(name, value, default)

  elseif isPrefix(verb, "UNVARIABLE") or isPrefix(verb, "UNVAR") then
    assert(args[1], "#UNVAR {name}")
    local name = args[1]
    if CMudWrapper.state.vars[name] ~= nil then
      CMudWrapper.state.vars[name] = nil
      CMudWrapper.state.defaults[name] = nil
      CMudWrapper.save()
      cecho(("<green>[CMudWrapper] variable removed: %s\n"):format(tostring(name)))
    else
      cecho(("<yellow>[CMudWrapper] variable not found: %s\n"):format(tostring(name)))
    end

  elseif verb == "SHOW" or verb == "SAY" then
    cecho(applyVars(table.concat(args, " ")) .. "\n")

  elseif verb == "SEND" then
    send(applyVars(table.concat(args, " ")))

  elseif verb == "REPEAT" then
    local n = tonumber(args[1]) or 1
    local text = table.concat(args, " ", 2)
    for _ = 1, n do
      CMudWrapper.runLine(text)
    end

  elseif verb:match("^%d+$") then
    local n = tonumber(verb) or 1
    local text = table.concat(args, " ")
    for _ = 1, n do
      CMudWrapper.runLine(text)
    end

  else
    cecho(("<yellow>[CMudWrapper] unsupported command: %s\n"):format(verb))
  end

  return true
end

function CMudWrapper.load()
  local data = {}
  pcall(table.load, CMudWrapper.savePath, data)

  CMudWrapper.state.aliases = data.aliases or {}
  CMudWrapper.state.triggers = data.triggers or {}
  CMudWrapper.state.vars = data.vars or {}
  CMudWrapper.state.defaults = data.defaults or {}

  if CMudWrapper.commandHandle then
    pcall(killAlias, CMudWrapper.commandHandle)
  end

  CMudWrapper.commandHandle = tempAlias([[^(#.+)$]], function()
    CMudWrapper.exec(matches[1] or matches[2] or "")
  end)

  -- assignment alias: allow `name = value` or `name := value` without leading #
  if CMudWrapper.assignHandle then
    pcall(killAlias, CMudWrapper.assignHandle)
    CMudWrapper.assignHandle = nil
  end

  CMudWrapper.assignHandle = tempAlias([[^\s*([\w_]+)\s*:?=\s*(.+)$]], function()
    local var = matches[2]
    local val = matches[3]
    if var then
      CMudWrapper.setVariable(var, val)
    end
  end)

  for name, spec in pairs(CMudWrapper.state.aliases) do
    CMudWrapper.installAlias(name, spec)
  end

  for name, spec in pairs(CMudWrapper.state.triggers) do
    CMudWrapper.installTrigger(name, spec)
  end
end

CMudWrapper.load()
