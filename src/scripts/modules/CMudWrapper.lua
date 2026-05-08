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
  state = { aliases = {}, triggers = {}, vars = {}, defaults = {}, varmeta = {} },
  handles = { aliases = {}, triggers = {} },
  commandHandle = nil,
  -- Tracks names of aliases/triggers currently executing. Used to block
  -- self/mutual recursion when alias bodies call other aliases.
  _callStack = {},
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

local function expandMatchTokens(text, matchTable)
  if matchTable then
    for i = 2, #matchTable do
      local replacement = matchTable[i] or ""
      text = text:gsub("%%" .. tostring(i - 1), function()
        return replacement
      end)
    end

    text = text:gsub("%%(%d+)", "")
  end

  return text
end

local function applyMatches(text, matchTable)
  if not matchTable then return text end
  local delayed = {}

  -- Protect delayed-expansion sequences like %%1 -> placeholder so they survive the first pass.
  text = text:gsub("%%%%(%d+)", function(num)
    local key = "__CMW_PCT_" .. num .. "__"
    delayed[key] = "%" .. num
    return key
  end)

  text = expandMatchTokens(text, matchTable)

  -- restore delayed placeholders back to literal percent tokens without expanding them again.
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

local function exportArg(text)
  return "{" .. tostring(text or "") .. "}"
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
  return DarkmistsTheme.textTag .. "{" .. formatDisplayBody(tostring(text or "")) .. DarkmistsTheme.textTag .. "}"
end

local function buildExportAliasLines(name)
  local spec = CMudWrapper.state.aliases[name]
  if not spec then
    return nil, ("alias not found: %s"):format(tostring(name))
  end

  local lines = {
    DarkmistsTheme.blueTag .. "#ALIAS" .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. formatExportBody(spec.body),
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
  local lines = {
    DarkmistsTheme.blueTag .. commandName .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. DarkmistsTheme.textTag .. exportArg(spec.pattern or "") .. " "
      .. formatExportBody(spec.body),
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
  local line = DarkmistsTheme.blueTag .. "#VARIABLE" .. DarkmistsTheme.textTag .. " "
    .. DarkmistsTheme.textTag .. exportArg(name) .. " "
    .. DarkmistsTheme.textTag .. exportArg(value)
  if default ~= nil then
    line = line .. " " .. exportArg(default)
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

  local lines = {
    DarkmistsTheme.blueTag .. "#ALIAS" .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. formatExportBody(spec.body),
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
  local lines = {
    DarkmistsTheme.blueTag .. commandName .. DarkmistsTheme.textTag .. " "
      .. DarkmistsTheme.textTag .. exportArg(name) .. " "
      .. DarkmistsTheme.textTag .. exportArg(spec.pattern or "") .. " "
      .. formatExportBody(spec.body),
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
  local line = DarkmistsTheme.blueTag .. "#VARIABLE" .. DarkmistsTheme.textTag .. " "
    .. DarkmistsTheme.textTag .. exportArg(name) .. " "
    .. DarkmistsTheme.textTag .. exportArg(value)
  if default ~= nil then
    line = line .. " " .. exportArg(default)
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

function CMudWrapper.exportAll()
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

  local aliasNames = {}
  for name in pairs(CMudWrapper.state.aliases) do aliasNames[#aliasNames + 1] = name end
  table.sort(aliasNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  if #aliasNames > 0 then
    --addSection("Aliases:")
    for _, name in ipairs(aliasNames) do
      addItem((buildExportAliasLines(name)))
    end
  end

  local triggerNames = {}
  for name in pairs(CMudWrapper.state.triggers) do triggerNames[#triggerNames + 1] = name end
  table.sort(triggerNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  if #triggerNames > 0 then
    --addSection("Triggers:")
    for _, name in ipairs(triggerNames) do
      addItem((buildExportTriggerLines(name)))
    end
  end

  local variableNames = {}
  for name in pairs(CMudWrapper.state.vars) do variableNames[#variableNames + 1] = name end
  table.sort(variableNames, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  if #variableNames > 0 then
    --addSection("Variables:")
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
  if default then
    if default == "_nodef" then
      CMudWrapper.state.defaults[name] = nil
    else
      CMudWrapper.state.defaults[name] = default
    end
  end

  CMudWrapper.state.vars[name] = value
  CMudWrapper.save()
  CMudWrapper.notify(DarkmistsTheme.goodTag .. ("variable set: %s = %s"):format(name, tostring(value)))
end

-- Attempt to invoke a registered alias by name for the given command line.
-- Returns true if a matching alias was found and executed (or blocked by the
-- recursion guard), false otherwise.  Falls through to send() when false.
function CMudWrapper.tryInvokeAlias(line)
  local word = line:match("^([^%s]+)")
  if not word then return false end

  local spec = CMudWrapper.state.aliases[word]
  if not spec then return false end
  if spec.enabled == false then return false end

  if CMudWrapper._callStack[word] then
    CMudWrapper.notify(DarkmistsTheme.warnTag .. ("recursion blocked: alias '%s' called itself"):format(word))
    return true
  end

  local tail = trim(line:sub(#word + 1))
  local args = parseArgs(tail)
  local matchTable = { tail }
  for i = 1, #args do matchTable[i + 1] = args[i] end

  CMudWrapper._callStack[word] = true
  local ok, err = pcall(CMudWrapper.runBody, spec.body, matchTable)
  CMudWrapper._callStack[word] = nil

  if not ok then
    CMudWrapper.notify(DarkmistsTheme.badTag .. ("alias '%s' error: %s"):format(word, tostring(err)))
  end

  return true
end

function CMudWrapper.runLine(line, matchTable)
  line = trim(applyMatches(applyVars(line), matchTable))
  if line == "" then return end

  if line:sub(1, 1) == CMudWrapper.commandChar then
    CMudWrapper.exec(line)
  else
    -- Check registered aliases first so trigger/alias bodies can chain into
    -- other aliases without sending the command to the server.
    if CMudWrapper.tryInvokeAlias(line) then return end
    send(line)
  end
end

function CMudWrapper.runBody(body, matchTable)
  body = applyMatches(applyVars(body or ""), matchTable)

  -- Split only on top-level separators so nested alias bodies like
  -- `#al h {hang %1|hang %2|hang %3}` stay intact until the inner #AL runs.
  local commands = splitTopLevelCommands(body, CMudWrapper.commandSeparator)

  -- Helper to execute commands from index `i` forward. Supports
  -- asynchronous pause via the `#WAIT <ms>` (delay milliseconds)
  -- or `#WAIT` (wait for next MUD line) commands. Remaining commands
  -- are resumed after the delay/event.
  CMudWrapper._wait = CMudWrapper._wait or { timers = {}, triggers = {} }

  local function executeFrom(i)
    for idx = i, #commands do
      local cmd = commands[idx]
      if cmd ~= "" then
        -- If this is a CMudWrapper command, check for WAIT specially.
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
  -- If a alias spec has `enabled = false`, do not create a runtime
  -- handle. This lets aliases remain defined but disabled until the
  -- user explicitly enables them with `#T+ name`.
  if spec and spec.enabled == false then
    return
  end
  if CMudWrapper.handles.aliases[name] then
    pcall(killAlias, CMudWrapper.handles.aliases[name])
  end

  local function aliasHandler()
    local captured = matches or {}

    -- Recursion guard: block re-entry if this alias is already on the call stack.
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
  -- If a trigger spec has `enabled = false`, do not create a runtime
  -- handle. This lets triggers remain defined but disabled until the
  -- user explicitly enables them with `#T+ name`.
  if spec and spec.enabled == false then
    return
  end
  if CMudWrapper.handles.triggers[name] then
    pcall(killTrigger, CMudWrapper.handles.triggers[name])
  end

  -- Translate CMUD wildcard patterns to PCRE when the spec was created with #WTRIGGER.
  local regex, varMapping = spec.pattern, {}
  if spec.cmud then
    regex, varMapping = cmudPatternToRegex(spec.pattern)
  end

  local handle = tempRegexTrigger(regex, function()
    -- Assign &VarName captures into CMudWrapper variables before running the body.
    if #varMapping > 0 and matches then
      for _, mapping in ipairs(varMapping) do
        local val = matches[mapping.idx + 1]  -- matches[1] = full match, [2+] = captures
        if val ~= nil then
          CMudWrapper.state.vars[mapping.name] = val
        end
      end
    end
    -- Recursion guard: block re-entry if this trigger is already on the call stack.
    if CMudWrapper._callStack[name] then
      CMudWrapper.notify(DarkmistsTheme.warnTag .. ("recursion blocked: trigger '%s'"):format(name))
      return
    end
    CMudWrapper._callStack[name] = true
    local ok, err = pcall(CMudWrapper.runBody, spec.body, matches)
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
  -- cleanup any pending wait timers/triggers
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

  if isPrefix(verb, "ALIAS") then
    -- New simplified form: #ALIAS {name} {body}
    local name = args[1]
    local body = nil
    if #args >= 2 then
      body = table.concat(args, " ", 2)
    end
    -- If no args: list aliases
    if not name then
      do
        local msg = DarkmistsTheme.infoTag .. "Aliases:\n"
        local names = {}
        for k in pairs(CMudWrapper.state.aliases) do names[#names+1] = k end
        table.sort(names, function(a,b) return tostring(a):lower() < tostring(b):lower() end)
        for _, k in ipairs(names) do
          local v = CMudWrapper.state.aliases[k]
          local enabled = not (v and v.enabled == false)
          local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
          local nameDisplay = nameColor .. tostring(k) .. DarkmistsTheme.mutedTag
          msg = msg .. string.format("  %s %s» %s\n", nameDisplay, DarkmistsTheme.mutedTag, formatDisplayBody(tostring((v or {}).body or "")))
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
        CMudWrapper.notify(DarkmistsTheme.infoTag .. string.format("%s %s» %s", nameDisplay, DarkmistsTheme.mutedTag, formatDisplayBody(tostring(def.body or ""))))
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

    assert(name and body, "#ALIAS {name} {body}")
    -- Restore any delayed-expansion placeholders back to their original
    -- positional token so %%2 stays %2, %%3 stays %3, and so on.
    body = body:gsub("__CMW_PCT_(%d+)__", function(n) return "%" .. n end)

    CMudWrapper.state.aliases[name] = { pattern = pattern, body = body, tail = usesTail }
    CMudWrapper.installAlias(name, CMudWrapper.state.aliases[name])
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("alias saved: %s"):format(name))

  elseif isPrefix(verb, "UNALIAS") then
    assert(args[1], "#UNALIAS {name}")
    CMudWrapper.removeAlias(args[1])

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
    if not name then
      do
        local msg = DarkmistsTheme.infoTag .. "Triggers:\n"
        local names = {}
        for k in pairs(CMudWrapper.state.triggers) do names[#names+1] = k end
        table.sort(names, function(a,b) return tostring(a):lower() < tostring(b):lower() end)
        for _, k in ipairs(names) do
          local v = CMudWrapper.state.triggers[k]
          local pat  = tostring((v or {}).pattern or "")
          local bod  = tostring((v or {}).body or "")
          local kind = (v and v.cmud) and "[wildcard]" or "[regex]"
          local enabled = not (v and v.enabled == false)
          local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
          local nameDisplay = nameColor .. tostring(k) .. DarkmistsTheme.mutedTag
          msg = msg .. string.format("  %s %s» %s: %s%s %s» %s\n", 
            nameDisplay, DarkmistsTheme.mutedTag, 
            kind, DarkmistsTheme.textTag, pat, DarkmistsTheme.mutedTag,
            formatDisplayBody(bod))
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
        CMudWrapper.notify(string.format("%s %s» %s: %s%s %s» %s", 
            nameDisplay, DarkmistsTheme.mutedTag, 
            kind, DarkmistsTheme.textTag, pat, DarkmistsTheme.mutedTag,
            formatDisplayBody(bod)))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("trigger not found: %s"):format(name))
      end
      return true
    end

    assert(name and pattern and body, "#TRIGGER {name} {wildcard-pattern} {body}")
    CMudWrapper.replaceTrigger(name, { pattern = pattern, body = body, cmud = true })
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("trigger saved: %s"):format(name))

  elseif isPrefix(verb, "UNTRIGGER") then
    assert(args[1], "#UNTRIGGER {name}")
    CMudWrapper.removeTrigger(args[1])

  elseif isPrefix(verb, "RXTRIGGER") or isPrefix(verb, "RXACTION") then
    -- #RXTRIGGER {name} {pattern} {body}
    -- Pattern is raw PCRE regex. Use #TRIGGER for the friendlier CMUD wildcard syntax.
    local name, pattern, body = args[1], args[2], args[3]

    if not name then
      do
        local msg = DarkmistsTheme.infoTag .. "Regex Triggers:\n"
        local names = {}
        for k, v in pairs(CMudWrapper.state.triggers) do if v and not v.cmud then names[#names+1] = k end end
        table.sort(names, function(a,b) return tostring(a):lower() < tostring(b):lower() end)
        for _, k in ipairs(names) do
          local v = CMudWrapper.state.triggers[k]
          local enabled = not (v and v.enabled == false)
          local nameColor = enabled and (DarkmistsTheme.goodTag) or (DarkmistsTheme.warnTag)
          local nameDisplay = nameColor .. tostring(k) .. DarkmistsTheme.mutedTag
          local pat  = tostring((v or {}).pattern or "")
          local bod  = tostring((v or {}).body or "")
          local kind = "[regex]"
          msg = msg .. string.format("%s %s» %s: %s%s %s» %s\n",
            nameDisplay, DarkmistsTheme.mutedTag,
            kind, DarkmistsTheme.textTag, pat, DarkmistsTheme.mutedTag,
            formatDisplayBody(bod))
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
        CMudWrapper.notify(DarkmistsTheme.infoTag .. string.format("%s %s» %s: %s%s %s» %s",
          nameDisplay, DarkmistsTheme.mutedTag,
          "[regex]", DarkmistsTheme.textTag, tostring(def.pattern or ""), DarkmistsTheme.mutedTag,
          formatDisplayBody(tostring(def.body or ""))))
      elseif def then
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("'%s' exists but is a wildcard trigger, not a regex trigger"):format(name))
      else
        CMudWrapper.notify(DarkmistsTheme.warnTag .. ("trigger not found: %s"):format(name))
      end
      return true
    end

    assert(name and pattern and body, "#RXTRIGGER {name} {pcre-pattern} {body}")
    CMudWrapper.replaceTrigger(name, { pattern = pattern, body = body })
    CMudWrapper.save()
    CMudWrapper.notify(DarkmistsTheme.goodTag .. ("regex trigger saved: %s"):format(name))

  elseif isPrefix(verb, "VARIABLE") then
    local name = args[1]
    local value = args[2]

    if not name then
      do
        local msg = DarkmistsTheme.infoTag .. "Variables:\n"
          local names = {}
          for k in pairs(CMudWrapper.state.vars) do names[#names+1] = k end
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

    local default = args[3]
    CMudWrapper.setVariable(name, value, default)

  elseif isPrefix(verb, "EXPORT") then
    local first = args[1]
    local second = args[2]

    if not first then
      CMudWrapper.exportAll()
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

  elseif verb:match("^%d+$") then
    local n = tonumber(verb) or 1
    local text = table.concat(args, " ")
    for _ = 1, n do
      CMudWrapper.runLine(text)
    end

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
