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
  savePath = getMudletHomeDir() .. "/cmudwrapper_data.lua",
  -- Full state shape including varmeta for per-variable enabled/disabled tracking.
  state = { aliases = {}, triggers = {}, vars = {}, defaults = {}, varmeta = {}, classes = {} },
  handles = { aliases = {}, triggers = {} },
  commandHandle = nil,
  -- Runtime-only default class. Set with `#CLASS name`, reset with `#CLASS 0`.
  defaultClass = nil,
  -- Tracks active alias/trigger names so nested bodies cannot recurse forever.
  _callStack = {},
  -- Runtime-only index of trigger definitions that reference @vars in their pattern.
  _patternDeps = {},
}

-- Convenience notify wrapper for this module.
-- Automatically prefixes messages with the module tag and appends a
-- trailing newline so callers only provide the colored message body.
function CMudWrapper.notify(msg)
  if not msg then msg = "" end
  msg = tostring(msg)
  if not msg:match("\n$") then
    msg = msg .. "\n"
  end
  local prefix = DarkmistsTheme and (DarkmistsTheme.blueTag .. "CMudWrapper") or "CMudWrapper"
  DMLogger.notify(prefix, msg)
end

--================================--
-- Command Dispatch
--================================--

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

-- Match token expansion is deliberately ordered: protect delayed literals first,
-- then expand positional references, then restore anything that was meant to stay literal.
local function expandMatchTokens(text, matchTable)
  if matchTable then
    -- %-N expands to the tail of the captured argument list starting at slot N.
    -- Wrapping multi-word results in {} keeps parseArgs from splitting the tail back apart.
    text = text:gsub("%%%-(%d+)", function(num)
      local n = tonumber(num)
      if not n or n < 1 then return "%-" .. num end
      local val
      if n == 1 then
        val = matchTable[1] or ""
      else
        local parts = {}
        for i = n + 1, #matchTable do
          parts[#parts + 1] = matchTable[i] or ""
        end
        val = table.concat(parts, " ")
      end
      return val:find(" ", 1, true) and ("{" .. val .. "}") or val
    end)

    for i = 2, #matchTable do
      local replacement = matchTable[i] or ""
      text = text:gsub("%%" .. tostring(i - 1), function()
        return replacement
      end)
    end

    -- Any positional token with no capture is removed, matching the wrapper's empty-string fallback.
    text = text:gsub("%%(%d+)", "")
  end

  return text
end

local function applyMatches(text, matchTable)
  if not matchTable then return text end
  local delayed = {}

  -- Protect literal %%1-style tokens so the first pass does not turn them into captures.
  text = text:gsub("%%%%(%d+)", function(num)
    local key = "__CMW_PCT_" .. num .. "__"
    delayed[key] = "%" .. num
    return key
  end)

  text = expandMatchTokens(text, matchTable)

  -- Restore the escaped tokens after positional expansion has finished.
  for k, v in pairs(delayed) do
    text = text:gsub(k, function()
      return v
    end)
  end

  return text
end

local function splitTopLevelCommands(text, separator)
  text = tostring(text or "")
  separator = tostring(separator or ""):sub(1, 1)
  if separator == "" then separator = "|" end

  local commands = {}
  local depth = 0
  local start = 1
  local i = 1

  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      if depth > 0 then depth = depth - 1 end
    elseif ch == separator and depth == 0 then
      commands[#commands + 1] = trim(text:sub(start, i - 1))
      start = i + 1
    end
    i = i + 1
  end

  commands[#commands + 1] = trim(text:sub(start))
  return commands
end

local function formatDisplayBody(text, opts)
  opts = opts or {}

  if opts.kind == "variable" then
    local nameColor = opts.enabled and DarkmistsTheme.goodTag or DarkmistsTheme.warnTag
    local nameDisplay = nameColor .. tostring(opts.name or "") .. DarkmistsTheme.mutedTag
    return string.format(
      "%s%s@%s » %s%s",
      tostring(opts.indent or ""),
      DarkmistsTheme.blueTag,
      nameDisplay,
      DarkmistsTheme.textTag,
      tostring(text)
    )
  end

  local commands = splitTopLevelCommands(text, CMudWrapper.commandSeparator)
  local pieces = {}

  for index, command in ipairs(commands) do
    command = tostring(command or "")
    command = command:gsub("%%%-(%d+)", function(num)
      return DarkmistsTheme.yellowTag .. "%-" .. num .. DarkmistsTheme.textTag
    end)
    command = command:gsub("%%(%d+)", function(num)
      return DarkmistsTheme.yellowTag .. "%" .. num .. DarkmistsTheme.textTag
    end)
    command = command:gsub("(@)([%a_][%w_]*)", function(at, name)
      local enabled = not (CMudWrapper.state.varmeta and CMudWrapper.state.varmeta[name] == false)
      local nameColor = enabled and DarkmistsTheme.goodTag or DarkmistsTheme.warnTag
      return DarkmistsTheme.blueTag .. at .. nameColor .. name
    end)

    pieces[#pieces + 1] = DarkmistsTheme.textTag .. command
    if index < #commands then
      pieces[#pieces + 1] = DarkmistsTheme.mutedTag .. tostring(CMudWrapper.commandSeparator)
    end
  end

  return table.concat(pieces)
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

local function escapeCmudLiteral(text)
  text = tostring(text or "")
  text = text:gsub("~", "~~")
  text = text:gsub("%%", function() return "~%" end)
  text = text:gsub("%*", "~*")
  text = text:gsub("%?", "~?")
  text = text:gsub("%^", "~^")
  text = text:gsub("%$", "~$")
  text = text:gsub("%[", "~[")
  text = text:gsub("%]", "~]")
  text = text:gsub("%{", "~{")
  text = text:gsub("%}", "~}")
  text = text:gsub("%(", "~(")
  text = text:gsub("%)", "~)")
  text = text:gsub("%|", "~|")
  text = text:gsub("%&", "~&")
  return text
end

-- Trigger definitions can use {@var} or bare @var so the variable is resolved before the pattern is compiled.
local function applyPatternVars(text, regexMode)
  text = tostring(text or "")

  local function expand(name)
    local value = CMudWrapper.state.vars[name]
    if value == nil then return "" end
    value = tostring(value)
    if regexMode then
      return escapeRegex(value)
    end
    return escapeCmudLiteral(value)
  end

  text = text:gsub("%{@([%w_]+)%}", expand)
  return text:gsub("@([%a_][%w_]*)", expand)
end

local function collectPatternVars(text)
  local deps = {}
  tostring(text or ""):gsub("%{@([%w_]+)%}", function(name)
    deps[name] = true
  end)
  tostring(text or ""):gsub("@([%a_][%w_]*)", function(name)
    deps[name] = true
  end)
  return deps
end

function CMudWrapper.refreshPatternTriggersFor(name)
  if not name or not CMudWrapper._patternDeps then return end

  local affected = {}
  for triggerName, deps in pairs(CMudWrapper._patternDeps) do
    if deps and deps[name] then
      affected[#affected + 1] = triggerName
    end
  end

  for _, triggerName in ipairs(affected) do
    local spec = CMudWrapper.state.triggers[triggerName]
    if spec then
      CMudWrapper.installTrigger(triggerName, spec)
    end
  end
end

local function exportArg(text)
  return DarkmistsTheme.mutedTag .. "{" .. DarkmistsTheme.textTag .. tostring(text or "") .. DarkmistsTheme.mutedTag .. "}"
end

local function echoExport(lines)
  if not lines or #lines == 0 then return false end
  echo("\n")
  for _, line in ipairs(lines) do
    cecho(line .. "\n")
  end
  return true
end

local function formatExportBody(text)
  return DarkmistsTheme.mutedTag .. "{" .. formatDisplayBody(tostring(text or "")) .. DarkmistsTheme.mutedTag .. "}"
end

local function buildExportAliasLines(name)
  local spec = CMudWrapper.state.aliases[name]
  if not spec then
    return nil, ("alias not found: %s"):format(tostring(name))
  end

  local classArg = spec.class and (" " .. DarkmistsTheme.textTag .. exportArg(spec.class)) or ""
  local lines = {
    DarkmistsTheme.blueTag .. "#ALIAS" .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. formatExportBody(spec.body) .. classArg,
  }
  if spec.enabled == false then
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#T-" .. DarkmistsTheme.textTag .. " " .. DarkmistsTheme.textTag .. exportArg(name)
  end
  return lines, nil
end

local function buildExportTriggerLines(name)
  local spec = CMudWrapper.state.triggers[name]
  if not spec then
    return nil, ("trigger not found: %s"):format(tostring(name))
  end

  local commandName = spec.cmud and "#TRIGGER" or "#RXTRIGGER"
  local classArg = spec.class and (" " .. DarkmistsTheme.textTag .. exportArg(spec.class)) or ""
  local lines = {
    DarkmistsTheme.blueTag .. commandName .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. DarkmistsTheme.textTag .. exportArg(spec.pattern or "") .. " "
      .. formatExportBody(spec.body) .. classArg,
  }

  if spec.enabled == false then
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#T-" .. DarkmistsTheme.textTag .. " " .. DarkmistsTheme.textTag .. exportArg(name)
  end
  return lines, nil
end

local function buildExportVariableLines(name)
  if CMudWrapper.state.vars[name] == nil then
    return nil, ("variable not found: %s"):format(tostring(name))
  end

  local value = CMudWrapper.state.vars[name]
  local default = CMudWrapper.state.defaults[name]
  local varClass = CMudWrapper.state.varmeta and CMudWrapper.state.varmeta["__class__" .. name]
  local line = DarkmistsTheme.blueTag .. "#VARIABLE" .. DarkmistsTheme.textTag .. " "
    .. DarkmistsTheme.textTag .. exportArg(name) .. " "
    .. DarkmistsTheme.textTag .. exportArg(value)
  if default ~= nil then
    line = line .. " " .. exportArg(default)
  end
  if varClass then
    -- 3-arg form: class only (no default placeholder needed)
    -- 4-arg form: default class (only when default is also set)
    line = line .. " " .. DarkmistsTheme.textTag .. exportArg(varClass)
  end

  local lines = { line }
  if CMudWrapper.state.varmeta and CMudWrapper.state.varmeta[name] == false then
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#T-" .. DarkmistsTheme.textTag .. " " .. DarkmistsTheme.textTag .. exportArg(name)
  end

  return lines, nil
end

function CMudWrapper.exportAlias(name)
  local spec = CMudWrapper.state.aliases[name]
  if not spec then
    return false, ("alias not found: %s"):format(tostring(name))
  end

  local classArg = spec.class and (" " .. DarkmistsTheme.textTag .. exportArg(spec.class)) or ""
  local lines = {
    DarkmistsTheme.blueTag .. "#ALIAS" .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. formatExportBody(spec.body) .. classArg,
  }
  if spec.enabled == false then
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#T-" .. DarkmistsTheme.textTag .. " " .. DarkmistsTheme.textTag .. exportArg(name)
  end
  return echoExport(lines), nil
end

function CMudWrapper.exportTrigger(name)
  local spec = CMudWrapper.state.triggers[name]
  if not spec then
    return false, ("trigger not found: %s"):format(tostring(name))
  end

  local commandName = spec.cmud and "#TRIGGER" or "#RXTRIGGER"
  local classArg = spec.class and (" " .. DarkmistsTheme.textTag .. exportArg(spec.class)) or ""
  local lines = {
    DarkmistsTheme.blueTag .. commandName .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. DarkmistsTheme.textTag .. exportArg(spec.pattern or "") .. " "
      .. formatExportBody(spec.body) .. classArg,
  }

  if spec.enabled == false then
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#T-" .. DarkmistsTheme.textTag .. " " .. DarkmistsTheme.textTag .. exportArg(name)
  end

  return echoExport(lines), nil
end

function CMudWrapper.exportVariable(name)
  if CMudWrapper.state.vars[name] == nil then
    return false, ("variable not found: %s"):format(tostring(name))
  end

  local value = CMudWrapper.state.vars[name]
  local default = CMudWrapper.state.defaults[name]
  local varClass = CMudWrapper.state.varmeta and CMudWrapper.state.varmeta["__class__" .. name]
  local line = DarkmistsTheme.blueTag .. "#VARIABLE" .. DarkmistsTheme.textTag .. " "
    .. DarkmistsTheme.textTag .. exportArg(name) .. " "
    .. DarkmistsTheme.textTag .. exportArg(value)
  if default ~= nil then
    line = line .. " " .. exportArg(default)
  end
  if varClass then
    line = line .. " " .. DarkmistsTheme.textTag .. exportArg(varClass)
  end

  local lines = { line }
  if CMudWrapper.state.varmeta and CMudWrapper.state.varmeta[name] == false then
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#T-" .. DarkmistsTheme.textTag .. " " .. DarkmistsTheme.textTag .. exportArg(name)
  end

  return echoExport(lines), nil
end

function CMudWrapper.exportDefinition(name, kind)
  kind = tostring(kind or ""):lower()
  if kind == "alias" then
    return CMudWrapper.exportAlias(name)
  elseif kind == "trigger" or kind == "rxtrigger" or kind == "action" or kind == "rxaction" then
    return CMudWrapper.exportTrigger(name)
  elseif kind == "variable" then
    return CMudWrapper.exportVariable(name)
  end

  local exported = false

  if CMudWrapper.state.aliases[name] then
    local ok = CMudWrapper.exportAlias(name)
    exported = exported or ok
  end
  if CMudWrapper.state.triggers[name] then
    local ok = CMudWrapper.exportTrigger(name)
    exported = exported or ok
  end
  if CMudWrapper.state.vars[name] ~= nil then
    local ok = CMudWrapper.exportVariable(name)
    exported = exported or ok
  end

  if not exported then
    return false, ("name not found: %s"):format(tostring(name))
  end

  return true, nil
end

function CMudWrapper.exportAll(classFilter)
  local lines = {}
  local wroteSection = false

  local function addSection(title)
    if wroteSection then
      lines[#lines + 1] = ""
    end
    wroteSection = true
    lines[#lines + 1] = DarkmistsTheme.infoTag .. title
  end

  local function addItem(itemLines)
    for _, line in ipairs(itemLines or {}) do
      lines[#lines + 1] = line
    end
  end

  local function matchesClass(specClass)
    if not classFilter then return true end
    return tostring(specClass or ""):lower() == classFilter:lower()
  end

  -- Emit #CLASS definitions. When filtering, only emit the relevant class.
  local classNames = {}
  for k in pairs(CMudWrapper.state.classes) do
    if not classFilter or tostring(k):lower() == classFilter:lower() then
      classNames[#classNames + 1] = k
    end
  end
  table.sort(classNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  for _, k in ipairs(classNames) do
    local cls = CMudWrapper.state.classes[k]
    local opts = {}
    if cls.enabled == false then opts[#opts + 1] = "disable" else opts[#opts + 1] = "enable" end
    if cls.hidden then opts[#opts + 1] = "hidden" end
    lines[#lines + 1] = DarkmistsTheme.blueTag .. "#CLASS" .. DarkmistsTheme.textTag .. " "
      .. exportArg(k) .. " " .. exportArg(table.concat(opts, ", "))
  end

  local aliasNames = {}
  for name in pairs(CMudWrapper.state.aliases) do
    if matchesClass((CMudWrapper.state.aliases[name] or {}).class) then
      aliasNames[#aliasNames + 1] = name
    end
  end
  table.sort(aliasNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  if #aliasNames > 0 then
    for _, name in ipairs(aliasNames) do
      addItem((buildExportAliasLines(name)))
    end
  end

  local triggerNames = {}
  for name in pairs(CMudWrapper.state.triggers) do
    if matchesClass((CMudWrapper.state.triggers[name] or {}).class) then
      triggerNames[#triggerNames + 1] = name
    end
  end
  table.sort(triggerNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  if #triggerNames > 0 then
    for _, name in ipairs(triggerNames) do
      addItem((buildExportTriggerLines(name)))
    end
  end

  local variableNames = {}
  for name in pairs(CMudWrapper.state.vars) do
    local varClass = CMudWrapper.state.varmeta and CMudWrapper.state.varmeta["__class__" .. name]
    if matchesClass(varClass) then
      variableNames[#variableNames + 1] = name
    end
  end
  table.sort(variableNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  if #variableNames > 0 then
    for _, name in ipairs(variableNames) do
      addItem((buildExportVariableLines(name)))
    end
  end

  if #lines == 0 then
    echo("\n" .. DarkmistsTheme.warnTag .. "nothing to export\n")
    return true
  end

  echo("\n")
  for _, line in ipairs(lines) do
    if line == "" then
      echo("\n")
    else
      cecho(line .. "\n")
    end
  end
  return true
end

-- ---------------------------------------------------------------------------
-- CMUD wildcard pattern translator
--
-- Translates a CMUD-style wildcard pattern into a PCRE regex string.
-- Also returns a varMapping table so &VarName captures are assigned.
--
-- Supported tokens:
--   *        any characters/space      → .*
--   ?        any single character      → .
--   %d       digits (0-9)              → \d+
--   %n       signed number             → [+-]?\d+
--   %w       alpha word (a-z)          → [a-zA-Z]+
--   %a       alphanumeric              → [a-zA-Z0-9]+
--   %s       whitespace                → \s+
--   %x       non-whitespace            → \S+
--   %p       punctuation               → [^\w\s]+
--   %t       direction command         → (?:north|south|...)
--   [range]  character class           → [range]+
--   (pat)    capture to %1..%99        → (pat)
--   {a|b|c}  alternation               → (?:a|b|c)
--   {^str}   negation / no-match       → (?!str)\S*
--   &nn      exactly nn chars          → .{nn}
--   &Name    capture into variable     → (.+?) + assigned after fire
--   ~x       literal x                 → escaped x
--   ~~       literal ~                 → ~
--   ^  $     line anchors              → ^ $
-- ---------------------------------------------------------------------------
local _cmudDirPattern = "(?:north|northeast|northwest|south|southeast|southwest" ..
  "|east|west|up|down|in|out|ne|nw|se|sw|n|s|e|w|u|d)"

-- Escape a literal string for use inside a PCRE pattern.
local function pcreEsc(s)
  return (s:gsub("([%(%)%.%+%-%*%?%[%]%^%$%{%}%|\\])", "\\%1"))
end

-- Core recursive translator. captures = list collector, captureN = {count}.
local function _cmudToRegex(pat, captures, captureN)
  local res = {}
  local i, n = 1, #pat

  -- Forward-declare for recursion inside brace handling.
  local translate

  -- Split a string by a separator at brace depth 0.
  local function splitTop(s, sep)
    local parts, d, st = {}, 0, 1
    for k = 1, #s do
      local c = s:sub(k, k)
      if     c == "{" then d = d + 1
      elseif c == "}" then d = d - 1
      elseif c == sep and d == 0 then
        parts[#parts+1] = s:sub(st, k-1); st = k + 1
      end
    end
    parts[#parts+1] = s:sub(st)
    return parts
  end

  translate = function(sub)
    return _cmudToRegex(sub, captures, captureN)
  end

  while i <= n do
    local ch = pat:sub(i, i)

    if ch == "~" then
      i = i + 1
      if i <= n then
        local nx = pat:sub(i, i)
        res[#res+1] = nx == "~" and "~" or pcreEsc(nx)
      end

    elseif ch == "%" then
      i = i + 1
      if i > n then break end
      local sp = pat:sub(i, i)
      if     sp == "d" then res[#res+1] = "\\d+"
      elseif sp == "n" then res[#res+1] = "[+-]?\\d+"
      elseif sp == "w" then res[#res+1] = "[a-zA-Z]+"
      elseif sp == "a" then res[#res+1] = "[a-zA-Z0-9]+"
      elseif sp == "s" then res[#res+1] = "\\s+"
      elseif sp == "x" then res[#res+1] = "\\S+"
      elseif sp == "p" then res[#res+1] = "[^\\w\\s]+"
      elseif sp == "t" then res[#res+1] = _cmudDirPattern
      else   res[#res+1] = pcreEsc("%" .. sp)
      end

    elseif ch == "*"  then res[#res+1] = ".*"
    elseif ch == "?"  then res[#res+1] = "."
    elseif ch == "^"  then res[#res+1] = "^"
    elseif ch == "$"  then res[#res+1] = "$"

    elseif ch == "(" then
      captureN[1] = captureN[1] + 1
      res[#res+1] = "("
    elseif ch == ")" then
      res[#res+1] = ")"

    elseif ch == "&" then
      i = i + 1
      if i > n then res[#res+1] = "\\&"; break end
      local rest = pat:sub(i)
      local nn = rest:match("^(%d+)")
      if nn then
        res[#res+1] = ".{" .. nn .. "}"
        i = i + #nn - 1
      else
        local varName = rest:match("^([%a_][%w_]*)")
        if varName then
          captureN[1] = captureN[1] + 1
          captures[#captures+1] = { idx = captureN[1], name = varName }
          res[#res+1] = "(.+?)"
          i = i + #varName - 1
        else
          res[#res+1] = "\\&"
          i = i - 1
        end
      end

    elseif ch == "[" then
      -- Pass character class verbatim until the closing ].
      local cls = { "[" }
      i = i + 1
      if i <= n and pat:sub(i,i) == "^" then cls[#cls+1] = "^"; i = i+1 end
      if i <= n and pat:sub(i,i) == "]" then cls[#cls+1] = "]"; i = i+1 end
      while i <= n and pat:sub(i,i) ~= "]" do
        cls[#cls+1] = pat:sub(i,i); i = i+1
      end
      cls[#cls+1] = "]"  -- closing bracket
      cls[#cls+1] = "+"  -- any amount as per CMUD spec
      res[#res+1] = table.concat(cls)

    elseif ch == "{" then
      -- Collect inner content up to matching }.
      local depth, j, innerChars = 1, i+1, {}
      while j <= n do
        local c = pat:sub(j, j)
        if     c == "{" then depth = depth + 1
        elseif c == "}" then
          depth = depth - 1
          if depth == 0 then break end
        end
        innerChars[#innerChars+1] = c
        j = j + 1
      end
      local inner = table.concat(innerChars)
      i = j  -- advance i to closing }

      if inner:sub(1,1) == "^" then
        -- {^val} or {^val1|val2}: negative match
        local negParts = splitTop(inner:sub(2), "|")
        local xlated = {}
        for _, p in ipairs(negParts) do xlated[#xlated+1] = translate(p) end
        if #xlated == 1 then
          res[#res+1] = "(?!" .. xlated[1] .. ")\\S*"
        else
          res[#res+1] = "(?!(?:" .. table.concat(xlated, "|") .. "))\\S*"
        end
      else
        -- {val1|val2|val3}: alternation
        local altParts = splitTop(inner, "|")
        local xlated = {}
        for _, p in ipairs(altParts) do xlated[#xlated+1] = translate(p) end
        res[#res+1] = "(?:" .. table.concat(xlated, "|") .. ")"
      end

    else
      res[#res+1] = pcreEsc(ch)
    end

    i = i + 1
  end

  return table.concat(res)
end

-- Public entry point: translate a CMUD wildcard pattern.
-- Returns: regex (string), varMapping (list of {idx, name} for &VarName tokens)
local function cmudPatternToRegex(pat)
  local captures = {}
  local captureN  = { 0 }
  local regex = _cmudToRegex(pat, captures, captureN)
  return regex, captures
end

function CMudWrapper.save()
  table.save(CMudWrapper.savePath, CMudWrapper.state)
end

function CMudWrapper.setVariable(name, value, default)
  if not name then return end
  name = tostring(name)
  if default and default ~= "" then
    if default == "_nodef" then
      CMudWrapper.state.defaults[name] = nil
    else
      CMudWrapper.state.defaults[name] = default
    end
  end

  CMudWrapper.state.vars[name] = value
  CMudWrapper.save()
  CMudWrapper.refreshPatternTriggersFor(name)
  CMudWrapper.notify(DarkmistsTheme.goodTag .. ("variable set: %s = %s"):format(name, tostring(value)))
end

-- Attempt to invoke a registered alias by name for the given command line.
-- Returns true if a matching alias was found and executed (or blocked by the
-- recursion guard), false otherwise.  Falls through to send() when false.
function CMudWrapper.tryInvokeAlias(line)
  local word = line:match("^([^%s]+)")
  if not word then return false end

  -- Fast path: single-word alias name
  local name = word
  local spec = CMudWrapper.state.aliases[name]

  -- Slow path: multi-word alias names (e.g. "dr f")
  -- Find the longest stored name that is a prefix of the typed line.
  if not spec then
    local bestLen = 0
    for k in pairs(CMudWrapper.state.aliases) do
      local klen = #k
      if klen > bestLen and k:find(" ", 1, true) then
        local after = line:sub(klen + 1, klen + 1)
        if line:sub(1, klen) == k and (after == "" or after:match("%s")) then
          name = k
          spec = CMudWrapper.state.aliases[k]
          bestLen = klen
        end
      end
    end
  end

  if not spec then return false end
  if spec.enabled == false then return false end
  if spec.class then
    local cls = CMudWrapper.state.classes and CMudWrapper.state.classes[spec.class]
    if cls and cls.enabled == false then return false end
  end

  if CMudWrapper._callStack[name] then
    CMudWrapper.notify(DarkmistsTheme.warnTag .. ("recursion blocked: alias '%s' called itself"):format(name))
    return true
  end

  local tail = trim(line:sub(#name + 1))
  local args = parseArgs(tail)
  local matchTable = { tail }
  for i = 1, #args do matchTable[i + 1] = args[i] end

  CMudWrapper._callStack[name] = true
  local ok, err = pcall(CMudWrapper.runBody, spec.body, matchTable)
  CMudWrapper._callStack[name] = nil

  if not ok then
    CMudWrapper.notify(DarkmistsTheme.badTag .. ("alias '%s' error: %s"):format(name, tostring(err)))
  end

  return true
end

function CMudWrapper.runLine(line, matchTable)
  line = trim(applyMatches(applyVars(line), matchTable))
  if line == "" then return end

  if line:sub(1, 1) == CMudWrapper.commandChar then
    CMudWrapper.exec(line)
  else
    -- Let scripted bodies chain through aliases before falling back to send().
    if CMudWrapper.tryInvokeAlias(line) then return end
    send(line)
  end
end

function CMudWrapper.runBody(body, matchTable)
  body = applyMatches(applyVars(body or ""), matchTable)

  local commands = splitTopLevelCommands(body, CMudWrapper.commandSeparator)

  -- Execute top-level commands sequentially and suspend the remainder for #WAIT.
  CMudWrapper._wait = CMudWrapper._wait or { timers = {}, triggers = {} }

  local function executeFrom(i)
    for idx = i, #commands do
      local cmd = commands[idx]
      if cmd ~= "" then
        if cmd:sub(1,1) == CMudWrapper.commandChar then
          local argstr = cmd:sub(2)
          local carg = parseArgs(argstr)
          local verb = (table.remove(carg,1) or ""):upper()
          if isPrefix(verb, "WAIT") then
            local t = tonumber(carg[1])
            if t and t > 0 then
              -- schedule timer (Mudlet tempTimer uses seconds).
              -- Use a table so the id is guaranteed to be set before
              -- the callback reads it (avoids nil-key errors).
              local ws = {}
              ws.tid = tempTimer(t / 1000, function()
                if CMudWrapper._wait and ws.tid then
                  CMudWrapper._wait.timers[ws.tid] = nil
                end
                executeFrom(idx + 1)
              end)
              if CMudWrapper._wait and ws.tid then
                CMudWrapper._wait.timers[ws.tid] = true
              end
              return
            else
              -- wait-for-line: fire on the very next MUD line then stop.
              -- `^(.*)$` matches every line, so we use a `fired` flag to
              -- guarantee exactly-once execution even if Mudlet delivers
              -- the kill asynchronously and the trigger fires again.
              local ws = { fired = false }
              ws.rid = tempRegexTrigger([[^(.*)$]], function()
                if ws.fired then return end
                ws.fired = true
                pcall(killTrigger, ws.rid)
                if CMudWrapper._wait and ws.rid then
                  CMudWrapper._wait.triggers[ws.rid] = nil
                end
                executeFrom(idx + 1)
              end)
              if CMudWrapper._wait and ws.rid then
                CMudWrapper._wait.triggers[ws.rid] = true
              end
              return
            end
          end
        end

        -- Normal execution
        CMudWrapper.runLine(cmd, matchTable)
      end
    end
  end

  -- Start execution from the first command.
  executeFrom(1)
end

function CMudWrapper.installAlias(name, spec)
  -- Disabled aliases stay defined but do not get runtime handles until re-enabled.
  if spec and spec.enabled == false then
    return
  end
  -- Skip aliases in disabled classes.
  if spec and spec.class then
    local cls = CMudWrapper.state.classes and CMudWrapper.state.classes[spec.class]
    if cls and cls.enabled == false then return end
  end
  if CMudWrapper.handles.aliases[name] then
    pcall(killAlias, CMudWrapper.handles.aliases[name])
  end

  local function aliasHandler()
    local captured = matches or {}

    -- Block self-recursion before running the body.
    if CMudWrapper._callStack[name] then
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("recursion blocked: alias '%s' called itself"):format(name))
      return
    end

    CMudWrapper._callStack[name] = true
    local ok, err = pcall(function()
      if spec.tail then
        local raw = trim(captured[2] or "")
        -- split raw into arguments using the same parser used by exec
        local args = parseArgs(raw)

        -- build matchTable so that matchTable[2] -> %1, matchTable[3] -> %2, etc.
        local matchTable = {}
        matchTable[1] = raw
        for i = 1, #args do
          matchTable[i + 1] = args[i]
        end

        CMudWrapper.runBody(spec.body, matchTable)
      else
        CMudWrapper.runBody(spec.body, captured)
      end
    end)
    CMudWrapper._callStack[name] = nil

    if not ok then
        CMudWrapper.notify(DarkmistsTheme.badTag .. ("alias '%s' error: %s"):format(name, tostring(err)))
    end
  end

  local ok, id_or_err = pcall(function() return tempAlias(spec.pattern, aliasHandler) end)
  if ok and id_or_err then
    CMudWrapper.handles.aliases[name] = id_or_err
  else
      CMudWrapper.notify(DarkmistsTheme.badTag .. ("failed to register alias '%s' pattern=%s error=%s"):format(tostring(name), tostring(spec.pattern), tostring(id_or_err)))
  end
end

function CMudWrapper.installTrigger(name, spec)
  -- Disabled triggers stay defined but do not get runtime handles until re-enabled.
  if spec and spec.enabled == false then
    return
  end
  -- Skip triggers in disabled classes.
  if spec and spec.class then
    local cls = CMudWrapper.state.classes and CMudWrapper.state.classes[spec.class]
    if cls and cls.enabled == false then return end
  end
  if CMudWrapper.handles.triggers[name] then
    pcall(killTrigger, CMudWrapper.handles.triggers[name])
  end

  -- Capture pattern-side @vars so we can recompile this trigger when those variables change.
  CMudWrapper._patternDeps = CMudWrapper._patternDeps or {}
  CMudWrapper._patternDeps[name] = collectPatternVars(spec.pattern)

  -- Translate CMUD wildcard patterns to PCRE when the spec was created with #WTRIGGER.
  local regex, varMapping = spec.pattern, {}
  if spec.cmud then
    regex, varMapping = cmudPatternToRegex(applyPatternVars(spec.pattern, false))
  else
    regex = applyPatternVars(regex, true)
  end

  local handle = tempRegexTrigger(regex, function()
    -- Assign &VarName captures before firing the body so later commands can reuse them.
    if #varMapping > 0 and matches then
      for _, mapping in ipairs(varMapping) do
        local val = matches[mapping.idx + 1]  -- matches[1] = full match, [2+] = captures
        if val ~= nil then
          CMudWrapper.state.vars[mapping.name] = val
        end
      end
    end
    -- Block trigger re-entry while the body is executing.
    if CMudWrapper._callStack[name] then
      CMudWrapper.notify(DarkmistsTheme.warnTag .. ("recursion blocked: trigger '%s'"):format(name))
      return
    end
    CMudWrapper._callStack[name] = true
    CMudWrapper._currentMatches = matches
    local ok, err = pcall(CMudWrapper.runBody, spec.body, matches)
    CMudWrapper._currentMatches = nil
    CMudWrapper._callStack[name] = nil
    if not ok then
      CMudWrapper.notify(DarkmistsTheme.badTag .. ("trigger '%s' error: %s"):format(name, tostring(err)))
    end
  end)

  if handle then
    CMudWrapper.handles.triggers[name] = handle
  else
    CMudWrapper.notify(DarkmistsTheme.badTag .. ("failed to register trigger '%s' pattern=%s"):format(tostring(name), tostring(regex)))
  end
end

function CMudWrapper.replaceTrigger(name, spec)
  if CMudWrapper.handles.triggers[name] then
    pcall(killTrigger, CMudWrapper.handles.triggers[name])
    CMudWrapper.handles.triggers[name] = nil
  end

  CMudWrapper.state.triggers[name] = spec
  CMudWrapper.installTrigger(name, spec)
end

function CMudWrapper.removeAlias(name)
  if CMudWrapper.handles.aliases[name] then
    pcall(killAlias, CMudWrapper.handles.aliases[name])
    CMudWrapper.handles.aliases[name] = nil
  end
  CMudWrapper.state.aliases[name] = nil
  CMudWrapper.save()
  CMudWrapper.notify(DarkmistsTheme.goodTag .. ("alias removed: %s"):format(tostring(name)))
end

function CMudWrapper.removeTrigger(name)
  if CMudWrapper.handles.triggers[name] then
    pcall(killTrigger, CMudWrapper.handles.triggers[name])
    CMudWrapper.handles.triggers[name] = nil
  end
  if CMudWrapper._patternDeps then
    CMudWrapper._patternDeps[name] = nil
  end
    if CMudWrapper.state.triggers[name] ~= nil then
      CMudWrapper.state.triggers[name] = nil
      CMudWrapper.save()
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("trigger removed: %s"):format(tostring(name)))
    else
      CMudWrapper.notify(DarkmistsTheme.warnTag .. ("trigger not found: %s"):format(tostring(name)))
    end
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
  CMudWrapper._patternDeps = {}
  -- Clear any suspended #WAIT state so reloads do not resume stale bodies.
  if CMudWrapper._wait then
    for id in pairs(CMudWrapper._wait.timers or {}) do
      pcall(killTimer, id)
    end
    for id in pairs(CMudWrapper._wait.triggers or {}) do
      pcall(killTrigger, id)
    end
    CMudWrapper._wait = nil
  end
end

function CMudWrapper.exec(line)
  if line:sub(1, 1) ~= CMudWrapper.commandChar then return false end

  local args = parseArgs(line:sub(2))
  local verb = (table.remove(args, 1) or ""):upper()

  -- Support top-level `#WAIT` (and shorthand like `#WA`) by delegating
  -- the full input line to `runBody`, which already implements async
  -- WAIT semantics (timers and wait-for-line triggers) and handles
  -- multiple commands separated by the configured separator.
  if isPrefix(verb, "WAIT") then
    CMudWrapper.runBody(line, {})
    return true
  end

  if isPrefix(verb, "CW") then
    local function cleanColor(s)
      return (tostring(s or "")):match("^{(.-)}$") or tostring(s or "")
    end
    local function splitColors(s)
      local fg_c, bg_c = s:match("^(%S+)%s+(%S+)$")
      return fg_c or s, bg_c
    end
    local function colorWord(text, colorStr)
      if not text or text == "" then return end
      local fg_c, bg_c = splitColors(colorStr)
      local i = 1
      while selectString(text, i) >= 0 do
        fg(fg_c)
        if bg_c then bg(bg_c) end
        i = i + 1
      end
      resetFormat()
    end
    if args[2] then
      -- 2-arg form: #CW {pattern} {fg bg} → persistent trigger that colors matched word
      local pattern  = args[1]
      local colorStr = cleanColor(args[2])
      local autoName = "cw:" .. pattern
      local inlineClass = args[3] or CMudWrapper.defaultClass
      local colorArg = colorStr:find("%s") and ("{" .. colorStr .. "}") or colorStr
      CMudWrapper.replaceTrigger(autoName, {
        pattern = pattern,
        body    = CMudWrapper.commandChar .. "CW " .. colorArg,
        cmud    = true,
        class   = inlineClass,
      })
      CMudWrapper.save()
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("word-color trigger created: %s → %s"):format(pattern, colorStr))
    elseif args[1] then
      -- 1-arg form: #CW {fg bg} → color the trigger match on the current line
      local m = CMudWrapper._currentMatches
      local captured = (m and m[2] ~= nil and m[2] ~= "") and m[2] or (m and m[1])
      if captured and captured ~= "" then
        colorWord(captured, cleanColor(args[1]))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. "#CW: not inside a trigger context — use #CW {pattern} {color} to create a persistent trigger")
      end
    end
    return true

  elseif isPrefix(verb, "COLOR") then
    local function cleanColor(s)
      return (tostring(s or "")):match("^{(.-)}$") or tostring(s or "")
    end
    local function splitColors(s)
      local fg_c, bg_c = s:match("^(%S+)%s+(%S+)$")
      return fg_c or s, bg_c
    end
    if args[2] then
      -- 2-arg form: #COLOR {pattern} {fg bg} → persistent trigger that colors matched line
      local pattern  = args[1]
      local colorStr = cleanColor(args[2])
      local autoName = "co:" .. pattern
      local inlineClass = args[3] or CMudWrapper.defaultClass
      local colorArg = colorStr:find("%s") and ("{" .. colorStr .. "}") or colorStr
      CMudWrapper.replaceTrigger(autoName, {
        pattern = pattern,
        body    = CMudWrapper.commandChar .. "COLOR " .. colorArg,
        cmud    = true,
        class   = inlineClass,
      })
      CMudWrapper.save()
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("line-color trigger created: %s → %s"):format(pattern, colorStr))
    elseif args[1] then
      -- 1-arg form: #COLOR {fg bg} → color the entire current line
      local colorStr = cleanColor(args[1])
      local fg_c, bg_c = splitColors(colorStr)
      selectCurrentLine()
      fg(fg_c)
      if bg_c then bg(bg_c) end
      resetFormat()
    end
    return true

  elseif isPrefix(verb, "ALIAS") then
    -- Form: #ALIAS {name} {body} [{class}]
    -- Inline class (args[3]) takes priority over defaultClass.
    local name = args[1]
    local body = args[2]
    if #args >= 2 and not args[3] then
      -- no class arg; allow unbraced body by joining remaining tokens
      body = table.concat(args, " ", 2)
    end
    -- If no args: list aliases
    -- Single arg matching a known class name: list aliases for that class
    if not name or (not body and CMudWrapper.state.classes[name] and not CMudWrapper.state.aliases[name]) then
      local classFilter = (name and CMudWrapper.state.classes[name]) and name or nil
      do
        local msg = DarkmistsTheme.infoTag .. (classFilter and ("Aliases [" .. classFilter .. "]:\n") or "Aliases:\n")
        local names = {}
        for k in pairs(CMudWrapper.state.aliases) do
          local v = CMudWrapper.state.aliases[k]
          if not classFilter or tostring(v.class or ""):lower() == classFilter:lower() then
            names[#names+1] = k
          end
        end
        table.sort(names, function(a, b)
          local ca = tostring((CMudWrapper.state.aliases[a] or {}).class or ""):lower()
          local cb = tostring((CMudWrapper.state.aliases[b] or {}).class or ""):lower()
          if ca ~= cb then return ca < cb end
          return tostring(a):lower() < tostring(b):lower()
        end)
        for _, k in ipairs(names) do
          local v = CMudWrapper.state.aliases[k]
          local _cls = v.class and CMudWrapper.state.classes and CMudWrapper.state.classes[v.class]
          if classFilter or not (_cls and _cls.hidden) then
            local enabled = not (v and v.enabled == false)
            local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
            local nameDisplay = nameColor .. tostring(k) .. DarkmistsTheme.mutedTag
            local classStr = ""
            if v.class then
              local clsColor = (_cls and _cls.enabled == false) and DarkmistsTheme.warnTag or DarkmistsTheme.goodTag
              classStr = DarkmistsTheme.mutedTag .. "[" .. clsColor .. v.class .. DarkmistsTheme.mutedTag .. "] "
            end
            msg = msg .. string.format("  %s%s %s» %s\n", classStr, nameDisplay, DarkmistsTheme.mutedTag, formatDisplayBody(tostring((v or {}).body or "")))
          end
        end
        CMudWrapper.notify(msg)
      end
      return true
    end

    -- If only name provided, show definition
    if name and not body then
      local def = CMudWrapper.state.aliases[name]
      if def then
        local enabled = not (def and def.enabled == false)
        local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
        local nameDisplay = nameColor .. name .. DarkmistsTheme.mutedTag
        local classStr = ""
        if def.class then
          local cls = CMudWrapper.state.classes and CMudWrapper.state.classes[def.class]
          local clsColor = (cls and cls.enabled == false) and DarkmistsTheme.warnTag or DarkmistsTheme.goodTag
          classStr = DarkmistsTheme.mutedTag .. "[" .. clsColor .. def.class .. DarkmistsTheme.mutedTag .. "] "
        end
        CMudWrapper.notify(DarkmistsTheme.infoTag .. string.format("%s%s %s» %s", classStr, nameDisplay, DarkmistsTheme.mutedTag, formatDisplayBody(tostring(def.body or ""))))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("alias not found: %s"):format(name))
      end
      return true
    end

    -- For the simplified API, build a default pattern that captures a tail.
    -- tempAlias uses PCRE-style regex, so use \W for a non-word boundary and
    -- keep short aliases from matching the start of longer words.
    local usesTail = true
    local pattern = "^" .. escapeRegex(name) .. "(?:\\W(.*))?$"

    assert(name and body, "#ALIAS {name} {body} [{class}]")
    -- Restore any delayed-expansion placeholders back to their original
    -- positional token so %%2 stays %2, %%3 stays %3, and so on.
    body = body:gsub("__CMW_PCT_(%d+)__", function(n) return "%" .. n end)

    local inlineClass = args[3]  -- optional trailing {ClassName}
    CMudWrapper.state.aliases[name] = { pattern = pattern, body = body, tail = usesTail, class = inlineClass or CMudWrapper.defaultClass }
    CMudWrapper.installAlias(name, CMudWrapper.state.aliases[name])
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("alias saved: %s"):format(name))

  elseif isPrefix(verb, "UNALIAS") then
    assert(args[1], "#UNALIAS {name}")
    CMudWrapper.removeAlias(table.concat(args, " "))

  elseif verb == "T+" or verb == "T-" then
    -- #T+ name -> enable alias/trigger/variable
    -- #T- name -> disable alias/trigger/variable
    assert(args[1], "#T+/#T- {name}")
    local tname = args[1]
    if verb == "T+" then
      -- Try alias
      local spec = CMudWrapper.state.aliases[tname]
      if spec then
        spec.enabled = true
        CMudWrapper.installAlias(tname, spec)
        CMudWrapper.save()
        CMudWrapper.notify(DarkmistsTheme.goodTag .. ("alias enabled: %s"):format(tname))
        return true
      end
      -- Try trigger
      spec = CMudWrapper.state.triggers[tname]
      if spec then
        spec.enabled = true
        CMudWrapper.installTrigger(tname, spec)
        CMudWrapper.save()
        CMudWrapper.notify(DarkmistsTheme.goodTag .. ("trigger enabled: %s"):format(tname))
        return true
      end
      -- Try variable
      if CMudWrapper.state.vars[tname] ~= nil then
        CMudWrapper.state.varmeta = CMudWrapper.state.varmeta or {}
        CMudWrapper.state.varmeta[tname] = true
        CMudWrapper.save()
        CMudWrapper.refreshPatternTriggersFor(tname)
        CMudWrapper.notify(DarkmistsTheme.goodTag .. ("variable enabled: %s"):format(tname))
        return true
      end
      CMudWrapper.notify(DarkmistsTheme.warnTag .. ("name not found: %s"):format(tname))
    else
      -- disable: try alias
      if CMudWrapper.handles.aliases[tname] then
        pcall(killAlias, CMudWrapper.handles.aliases[tname])
        CMudWrapper.handles.aliases[tname] = nil
      end
      if CMudWrapper.state.aliases[tname] then
        CMudWrapper.state.aliases[tname].enabled = false
        CMudWrapper.save()
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("alias disabled: %s"):format(tname))
        return true
      end
      -- disable trigger
      if CMudWrapper.handles.triggers[tname] then
        pcall(killTrigger, CMudWrapper.handles.triggers[tname])
        CMudWrapper.handles.triggers[tname] = nil
      end
      if CMudWrapper.state.triggers[tname] then
        CMudWrapper.state.triggers[tname].enabled = false
        CMudWrapper.save()
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("trigger disabled: %s"):format(tname))
        return true
      end
      -- disable variable
      if CMudWrapper.state.vars[tname] ~= nil then
        CMudWrapper.state.varmeta = CMudWrapper.state.varmeta or {}
        CMudWrapper.state.varmeta[tname] = false
        CMudWrapper.save()
        CMudWrapper.refreshPatternTriggersFor(tname)
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("variable disabled: %s"):format(tname))
        return true
      end
      CMudWrapper.notify(DarkmistsTheme.warnTag .. ("name not found: %s"):format(tname))
    end
    return true

  elseif isPrefix(verb, "TRIGGER") or isPrefix(verb, "ACTION") then
    -- #TRIGGER {name} {pattern} {body}
    -- Pattern uses CMUD wildcard syntax (* ? %d %w etc.). Use #RXTRIGGER for raw PCRE.
    local name, pattern, body = args[1], args[2], args[3]

    -- No args: list all triggers
    -- Single arg matching a known class name: list triggers for that class
    if not name or (not pattern and CMudWrapper.state.classes[name] and not CMudWrapper.state.triggers[name]) then
      local classFilter = (name and CMudWrapper.state.classes[name]) and name or nil
      do
        local msg = DarkmistsTheme.infoTag .. (classFilter and ("Triggers [" .. classFilter .. "]:\n") or "Triggers:\n")
        local names = {}
        for k in pairs(CMudWrapper.state.triggers) do
          local v = CMudWrapper.state.triggers[k]
          if v and v.cmud and (not classFilter or tostring(v.class or ""):lower() == classFilter:lower()) then
            names[#names+1] = k
          end
        end
        table.sort(names, function(a, b)
          local ca = tostring((CMudWrapper.state.triggers[a] or {}).class or ""):lower()
          local cb = tostring((CMudWrapper.state.triggers[b] or {}).class or ""):lower()
          if ca ~= cb then return ca < cb end
          return tostring(a):lower() < tostring(b):lower()
        end)
        for _, k in ipairs(names) do
          local v = CMudWrapper.state.triggers[k]
          local _cls = v.class and CMudWrapper.state.classes and CMudWrapper.state.classes[v.class]
          if classFilter or not (_cls and _cls.hidden) then
            local pat  = tostring((v or {}).pattern or "")
            local bod  = tostring((v or {}).body or "")
            local kind = (v and v.cmud) and "[wildcard]" or "[regex]"
            local enabled = not (v and v.enabled == false)
            local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
            local nameDisplay = nameColor .. tostring(k) .. DarkmistsTheme.mutedTag
            local classStr = ""
            if v.class then
              local clsColor = (_cls and _cls.enabled == false) and DarkmistsTheme.warnTag or DarkmistsTheme.goodTag
              classStr = DarkmistsTheme.mutedTag .. "[" .. clsColor .. v.class .. DarkmistsTheme.mutedTag .. "] "
            end
            msg = msg .. string.format("  %s%s %s» %s: %s%s %s» %s\n", 
              classStr, nameDisplay, DarkmistsTheme.mutedTag, 
              kind, DarkmistsTheme.textTag, pat, DarkmistsTheme.mutedTag,
              formatDisplayBody(bod))
          end
        end
        CMudWrapper.notify(msg)
      end
      return true
    end

    -- Single arg: show definition for named trigger
    if name and not pattern then
      local def = CMudWrapper.state.triggers[name]
      if def then
        local pat  = tostring(def.pattern or "")
        local bod  = tostring(def.body or "")
        local kind = def.cmud and "[wildcard]" or "[regex]"
        local enabled = not (def and def.enabled == false)
        local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
        local nameDisplay = nameColor .. name .. DarkmistsTheme.mutedTag
        local classStr = ""
        if def.class then
          local cls = CMudWrapper.state.classes and CMudWrapper.state.classes[def.class]
          local clsColor = (cls and cls.enabled == false) and DarkmistsTheme.warnTag or DarkmistsTheme.goodTag
          classStr = DarkmistsTheme.mutedTag .. "[" .. clsColor .. def.class .. DarkmistsTheme.mutedTag .. "] "
        end
        CMudWrapper.notify(string.format("%s%s %s» %s: %s%s %s» %s", 
            classStr, nameDisplay, DarkmistsTheme.mutedTag, 
            kind, DarkmistsTheme.textTag, pat, DarkmistsTheme.mutedTag,
            formatDisplayBody(bod)))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("trigger not found: %s"):format(name))
      end
      return true
    end

    assert(name and pattern and body, "#TRIGGER {name} {wildcard-pattern} {body} [{class}]")
    local inlineClass = args[4]  -- optional trailing {ClassName}
    CMudWrapper.replaceTrigger(name, { pattern = pattern, body = body, cmud = true, class = inlineClass or CMudWrapper.defaultClass })
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("trigger saved: %s"):format(name))

  elseif isPrefix(verb, "UNTRIGGER") then
    assert(args[1], "#UNTRIGGER {name}")
    CMudWrapper.removeTrigger(args[1])

  elseif isPrefix(verb, "RXTRIGGER") or isPrefix(verb, "RXACTION") then
    -- #RXTRIGGER {name} {pattern} {body}
    -- Pattern is raw PCRE regex. Use #TRIGGER for the friendlier CMUD wildcard syntax.
    local name, pattern, body = args[1], args[2], args[3]

    if not name or (not pattern and CMudWrapper.state.classes[name] and not CMudWrapper.state.triggers[name]) then
      local classFilter = (name and CMudWrapper.state.classes[name]) and name or nil
      do
        local msg = DarkmistsTheme.infoTag .. (classFilter and ("Regex Triggers [" .. classFilter .. "]:\n") or "Regex Triggers:\n")
        local names = {}
        for k, v in pairs(CMudWrapper.state.triggers) do
          if v and not v.cmud and (not classFilter or tostring(v.class or ""):lower() == classFilter:lower()) then
            names[#names+1] = k
          end
        end
        table.sort(names, function(a, b)
          local ca = tostring((CMudWrapper.state.triggers[a] or {}).class or ""):lower()
          local cb = tostring((CMudWrapper.state.triggers[b] or {}).class or ""):lower()
          if ca ~= cb then return ca < cb end
          return tostring(a):lower() < tostring(b):lower()
        end)
        for _, k in ipairs(names) do
          local v = CMudWrapper.state.triggers[k]
          local _cls = v.class and CMudWrapper.state.classes and CMudWrapper.state.classes[v.class]
          if classFilter or not (_cls and _cls.hidden) then
            local enabled = not (v and v.enabled == false)
            local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
            local nameDisplay = nameColor .. tostring(k) .. DarkmistsTheme.mutedTag
            local classStr = ""
            if v.class then
              local clsColor = (_cls and _cls.enabled == false) and DarkmistsTheme.warnTag or DarkmistsTheme.goodTag
              classStr = DarkmistsTheme.mutedTag .. "[" .. clsColor .. v.class .. DarkmistsTheme.mutedTag .. "] "
            end
            local pat  = tostring((v or {}).pattern or "")
            local bod  = tostring((v or {}).body or "")
            local kind = "[regex]"
            msg = msg .. string.format("%s%s %s» %s: %s%s %s» %s\n",
              classStr, nameDisplay, DarkmistsTheme.mutedTag,
              kind, DarkmistsTheme.textTag, pat, DarkmistsTheme.mutedTag,
              formatDisplayBody(bod))
          end
        end
        CMudWrapper.notify(msg)
      end
      return true
    end

    if name and not pattern then
      local def = CMudWrapper.state.triggers[name]
      if def and not def.cmud then
        local enabled = not (def and def.enabled == false)
        local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
        local nameDisplay = nameColor .. name .. DarkmistsTheme.mutedTag
        local classStr = ""
        if def.class then
          local cls = CMudWrapper.state.classes and CMudWrapper.state.classes[def.class]
          local clsColor = (cls and cls.enabled == false) and DarkmistsTheme.warnTag or DarkmistsTheme.goodTag
          classStr = DarkmistsTheme.mutedTag .. "[" .. clsColor .. def.class .. DarkmistsTheme.mutedTag .. "] "
        end
        CMudWrapper.notify(DarkmistsTheme.infoTag .. string.format("%s%s %s» %s: %s%s %s» %s",
          classStr, nameDisplay, DarkmistsTheme.mutedTag,
          "[regex]", DarkmistsTheme.textTag, tostring(def.pattern or ""), DarkmistsTheme.mutedTag,
          formatDisplayBody(tostring(def.body or ""))))
      elseif def then
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("'%s' exists but is a wildcard trigger, not a regex trigger"):format(name))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("trigger not found: %s"):format(name))
      end
      return true
    end

    assert(name and pattern and body, "#RXTRIGGER {name} {pcre-pattern} {body} [{class}]")
    local inlineClass = args[4]  -- optional trailing {ClassName}
    CMudWrapper.replaceTrigger(name, { pattern = pattern, body = body, class = inlineClass or CMudWrapper.defaultClass })
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("regex trigger saved: %s"):format(name))

  elseif isPrefix(verb, "VARIABLE") then
    local name = args[1]
    local value = args[2]

    if not name or (value == nil and CMudWrapper.state.classes[name] and CMudWrapper.state.vars[name] == nil) then
      local classFilter = (name and CMudWrapper.state.classes[name]) and name or nil
      do
        local msg = DarkmistsTheme.infoTag .. (classFilter and ("Variables [" .. classFilter .. "]:\n") or "Variables:\n")
          local names = {}
          for k in pairs(CMudWrapper.state.vars) do
            local varClass = CMudWrapper.state.varmeta and CMudWrapper.state.varmeta["__class__" .. k]
            if not classFilter or tostring(varClass or ""):lower() == classFilter:lower() then
              names[#names+1] = k
            end
          end
          table.sort(names, function(a,b) return tostring(a):lower() < tostring(b):lower() end)
          for _, k in ipairs(names) do
            local v = CMudWrapper.state.vars[k]
            local enabled = not (CMudWrapper.state.varmeta and CMudWrapper.state.varmeta[k] == false)
              msg = msg .. formatDisplayBody(v, {
                kind = "variable",
                name = k,
                enabled = enabled,
                indent = "  ",
              }) .. "\n"
          end
        CMudWrapper.notify(msg)
      end
      return true
    end

    if value == nil then
      local current = CMudWrapper.state.vars[name]
      if current ~= nil then
        local enabled = not (CMudWrapper.state.varmeta and CMudWrapper.state.varmeta[name] == false)
        CMudWrapper.notify(formatDisplayBody(current, {
          kind = "variable",
          name = name,
          enabled = enabled,
        }))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("variable not found: %s"):format(name))
      end
      return true
    end

    -- 3 args: name value class (no default)
    -- 4 args: name value default class
    local default, inlineClass
    if args[4] then
      default = (args[3] ~= "") and args[3] or nil
      inlineClass = args[4]
    else
      default = nil
      inlineClass = (args[3] ~= "") and args[3] or nil
    end
    CMudWrapper.setVariable(name, value, default)
    -- Stamp class on the variable if provided.
    local assignedClass = inlineClass or CMudWrapper.defaultClass
    if assignedClass then
      CMudWrapper.state.varmeta = CMudWrapper.state.varmeta or {}
      CMudWrapper.state.varmeta["__class__" .. name] = assignedClass
      CMudWrapper.save()
    end

  elseif isPrefix(verb, "EXPORT") then
    local first = args[1]
    local second = args[2]

    if not first then
      CMudWrapper.exportAll()
      return true
    end

    -- #EXPORT {classname} → export all members of a class
    if CMudWrapper.state.classes[first] and not second then
      CMudWrapper.exportAll(first)
      return true
    end

    local kind = nil
    local name = first
    if second then
      local lowered = tostring(first):lower()
      if lowered == "alias" or lowered == "trigger" or lowered == "rxtrigger" or lowered == "action" or lowered == "rxaction" or lowered == "variable" then
        kind = lowered
        name = second
      end
    end

    local ok, err = CMudWrapper.exportDefinition(name, kind)
    if not ok and err then
      echo("\n" .. tostring(err) .. "\n")
    end
    return true

  elseif isPrefix(verb, "UNVARIABLE") then
    assert(args[1], "#UNVAR {name}")
    local name = args[1]
    if CMudWrapper.state.vars[name] ~= nil then
      CMudWrapper.state.vars[name] = nil
      CMudWrapper.state.defaults[name] = nil
      CMudWrapper.save()
        CMudWrapper.refreshPatternTriggersFor(name)
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("variable removed: %s"):format(tostring(name)))
    else
      CMudWrapper.notify(DarkmistsTheme.warnTag .. ("variable not found: %s"):format(tostring(name)))
    end

  elseif isPrefix(verb, "SHOW") or isPrefix(verb, "SAY") then
    cecho("\n" .. DarkmistsTheme.textTag .. applyVars(table.concat(args, " ")))

  elseif isPrefix(verb, "SEND") then
    send(applyVars(table.concat(args, " ")))

  elseif isPrefix(verb, "REPEAT") then
    local n = tonumber(args[1]) or 1
    local text = table.concat(args, " ", 2)
    for _ = 1, n do
      CMudWrapper.runLine(text)
    end

  elseif isPrefix(verb, "SEPARATOR") or isPrefix(verb, "SEP") then
    local newSep = args[1]
    if not newSep or newSep == "" then
      CMudWrapper.notify(("Command separator: %s%s"):format(DarkmistsTheme.textTag, CMudWrapper.commandSeparator))
    else
      CMudWrapper.commandSeparator = newSep:sub(1, 1)
      CMudWrapper.notify(("Command separator set to: %s%s"):format(DarkmistsTheme.textTag, CMudWrapper.commandSeparator))
    end

  elseif verb == "KILLALL" then
    -- Must be typed in full — not abbreviatable.
    -- Kill all runtime handles then wipe all state.
    for aname, id in pairs(CMudWrapper.handles.aliases) do
      pcall(killAlias, id)
    end
    for tname, id in pairs(CMudWrapper.handles.triggers) do
      pcall(killTrigger, id)
    end
    CMudWrapper.handles = { aliases = {}, triggers = {} }
    CMudWrapper.state = { aliases = {}, triggers = {}, vars = {}, defaults = {}, varmeta = {}, classes = {} }
    CMudWrapper.defaultClass = nil
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.warnTag .. "KILLALL: all aliases, triggers, variables, and classes have been erased.")

  elseif verb:match("^%d+$") then
    local n = tonumber(verb) or 1
    local text = table.concat(args, " ")
    for _ = 1, n do
      CMudWrapper.runLine(text)
    end

  elseif isPrefix(verb, "CLASS") then
    local classname = args[1]
    local stateArg  = args[2]

    -- #CLASS (no args): list all defined classes and current default.
    if not classname then
      local msg = DarkmistsTheme.infoTag .. "Classes:\n"
      local defDisplay = CMudWrapper.defaultClass or "<None>"
      msg = msg .. string.format("  %sDefault: %s%s\n", DarkmistsTheme.mutedTag, DarkmistsTheme.textTag, defDisplay)
      local names = {}
      for k in pairs(CMudWrapper.state.classes) do names[#names+1] = k end
      table.sort(names, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
      if #names == 0 then
        msg = msg .. DarkmistsTheme.mutedTag .. "  (no classes defined)\n"
      else
        for _, k in ipairs(names) do
          local cls = CMudWrapper.state.classes[k]
          local enabled = cls.enabled ~= false
          local statusColor = enabled and DarkmistsTheme.goodTag or DarkmistsTheme.warnTag
          local status = enabled and "enabled" or "disabled"
          local flags = {}
          if cls.hidden then flags[#flags+1] = "hidden" end
          local flagStr = #flags > 0 and (" " .. DarkmistsTheme.mutedTag .. "[" .. table.concat(flags, ", ") .. "]") or ""
          msg = msg .. string.format("  %s%s%s: %s%s%s\n",
            DarkmistsTheme.textTag, k, DarkmistsTheme.mutedTag,
            statusColor, status, flagStr)
        end
      end
      CMudWrapper.notify(msg)
      return true
    end

    -- #CLASS 0: reset default class to <None>.
    if classname == "0" and not stateArg then
      CMudWrapper.defaultClass = nil
      CMudWrapper.notify(DarkmistsTheme.goodTag .. "Default class reset to <None>")
      return true
    end

    -- #CLASS classname (single arg): set as the default class for new definitions.
    if not stateArg then
      CMudWrapper.defaultClass = classname
      -- Auto-create the class entry if it doesn't exist yet.
      if not CMudWrapper.state.classes[classname] then
        CMudWrapper.state.classes[classname] = { enabled = true }
        CMudWrapper.save()
      end
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("default class set to: %s"):format(classname))
      return true
    end

    -- #CLASS classname {options}: create/configure a class with text options.
    -- Options: enable, disable, remove, hidden, unhide
    local numeric = tonumber(stateArg)
    if numeric == nil then
      local opts = {}
      for opt in tostring(stateArg):lower():gmatch("[^,%s]+") do
        opts[opt] = true
      end
      if opts["remove"] then
        CMudWrapper.state.classes[classname] = nil
        CMudWrapper.save()
        CMudWrapper.notify(DarkmistsTheme.goodTag .. ("class removed: %s"):format(classname))
        return true
      end
      local cls = CMudWrapper.state.classes[classname] or { enabled = true }
      if opts["enable"]  then cls.enabled = true  end
      if opts["disable"] then cls.enabled = false end
      if opts["hidden"]  then cls.hidden  = true  end
      if opts["unhide"] or opts["show"] then cls.hidden = nil end
      CMudWrapper.state.classes[classname] = cls
      CMudWrapper.save()
      -- Apply enable/disable to live handles so triggers/aliases start or stop firing.
      if opts["enable"] or opts["disable"] then
        for aname, spec in pairs(CMudWrapper.state.aliases) do
          if spec.class == classname then
            if cls.enabled then
              if spec.enabled ~= false then CMudWrapper.installAlias(aname, spec) end
            else
              if CMudWrapper.handles.aliases[aname] then
                pcall(killAlias, CMudWrapper.handles.aliases[aname])
                CMudWrapper.handles.aliases[aname] = nil
              end
            end
          end
        end
        for tname, spec in pairs(CMudWrapper.state.triggers) do
          if spec.class == classname then
            if cls.enabled then
              if spec.enabled ~= false then CMudWrapper.installTrigger(tname, spec) end
            else
              if CMudWrapper.handles.triggers[tname] then
                pcall(killTrigger, CMudWrapper.handles.triggers[tname])
                CMudWrapper.handles.triggers[tname] = nil
              end
            end
          end
        end
      end
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("class configured: %s"):format(classname))
      return true
    end

    -- #CLASS classname 1/0: enable or disable, and apply to all members.
    local cls = CMudWrapper.state.classes[classname]
    if not cls then
      CMudWrapper.state.classes[classname] = { enabled = numeric ~= 0 }
      CMudWrapper.save()
      CMudWrapper.notify(DarkmistsTheme.goodTag .. ("class created and %s: %s"):format(
        numeric ~= 0 and "enabled" or "disabled", classname))
      return true
    end

    cls.enabled = numeric ~= 0
    CMudWrapper.save()

    -- Apply the new state to every alias and trigger in this class.
    for aname, spec in pairs(CMudWrapper.state.aliases) do
      if spec.class == classname then
        if cls.enabled then
          -- Only reinstall if the alias itself isn't individually disabled.
          if spec.enabled ~= false then
            CMudWrapper.installAlias(aname, spec)
          end
        else
          if CMudWrapper.handles.aliases[aname] then
            pcall(killAlias, CMudWrapper.handles.aliases[aname])
            CMudWrapper.handles.aliases[aname] = nil
          end
        end
      end
    end
    for tname, spec in pairs(CMudWrapper.state.triggers) do
      if spec.class == classname then
        if cls.enabled then
          if spec.enabled ~= false then
            CMudWrapper.installTrigger(tname, spec)
          end
        else
          if CMudWrapper.handles.triggers[tname] then
            pcall(killTrigger, CMudWrapper.handles.triggers[tname])
            CMudWrapper.handles.triggers[tname] = nil
          end
        end
      end
    end

    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("class %s: %s"):format(
      cls.enabled and "enabled" or "disabled", classname))
    return true

  else
    CMudWrapper.notify(DarkmistsTheme.warnTag .. ("unsupported command: %s"):format(verb))
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
  CMudWrapper.state.varmeta = data.varmeta or {}
  CMudWrapper.state.classes = data.classes or {}
  CMudWrapper.defaultClass = nil  -- always reset to <None> on load

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
  DMLogger.log(DarkmistsTheme.purpleTag .. "CMudWrapper", DarkmistsTheme.goodTag .. "Loaded!")
end
