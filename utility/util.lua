-- ============================================================================
-- DMUtil
-- ----------------------------------------------------------------------------
-- General-purpose utility helpers for strings, tables, debugging, and Mudlet.
-- All functions preserve original behavior.
-- ============================================================================

DMUtil = {}

-- ============================================================================
-- BASIC HELPERS
-- ============================================================================

-- Escape a string for safe Lua literal output
function DMUtil.escape_string(s)
  return '"' .. tostring(s)
    :gsub("\\", "\\\\")
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
    :gsub('"', '\\"') .. '"'
end

-- Check for integer numbers
function DMUtil.is_int(n)
  return type(n) == "number" and n == math.floor(n)
end

-- ============================================================================
-- TABLE HELPERS
-- ============================================================================

-- Determine if a table is a dense 1-based array
function DMUtil.is_array(t)
  if type(t) ~= "table" then return false end

  local max, count = 0, 0
  for k in pairs(t) do
    if not DMUtil.is_int(k) or k < 1 then return false end
    if k > max then max = k end
  end

  for _ in pairs(t) do count = count + 1 end
  return count == max
end

-- Return table keys sorted deterministically
function DMUtil.sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end

  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta == tb and (ta == "number" or ta == "string") then
      return a < b
    end
    return tostring(a) < tostring(b)
  end)

  return keys
end

-- Deep-copy values from src into dest without destroying dest
function DMUtil.deep_copy_into(dest, src, seen)
  if type(src) ~= "table" then return dest end

  seen = seen or {}
  if seen[src] then return dest end
  seen[src] = true

  for k, v in pairs(src) do
    if type(v) == "table" then
      dest[k] = dest[k] or {}
      DMUtil.deep_copy_into(dest[k], v, seen)
    else
      dest[k] = v
    end
  end

  return dest
end

-- Pretty-print tables with cycle detection and limits
function DMUtil.dump_table(value, opts)
  opts = opts or {}
  local indent      = opts.indent or "  "
  local depth_limit = opts.depth_limit or 8
  local max_items   = opts.max_items or 1000
  local seen        = {}

  local function stringify(v, depth)
    local tv = type(v)

    -- Scalars
    if tv == "string"  then return DMUtil.escape_string(v) end
    if tv == "number" or tv == "boolean" or tv == "nil" then return tostring(v) end
    if tv ~= "table" then return "<" .. tv .. ">" end

    -- Cycles / depth
    if seen[v] then return "<cycle@" .. seen[v] .. ">" end
    if depth >= depth_limit then return "<max-depth>" end

    local id = tostring(v):gsub("table: ", "")
    seen[v] = id

    -- Arrays
    if DMUtil.is_array(v) then
      local out, limit = {}, math.min(#v, max_items)
      for i = 1, limit do
        out[#out + 1] = stringify(v[i], depth + 1)
      end
      if #v > limit then
        out[#out + 1] = "…(" .. (#v - limit) .. " more)"
      end
      return "[" .. table.concat(out, ", ") .. "]"
    end

    -- Maps
    local pad  = string.rep(indent, depth + 1)
    local base = string.rep(indent, depth)
    local out, shown = {}, 0

    for _, k in ipairs(DMUtil.sorted_keys(v)) do
      shown = shown + 1
      if shown > max_items then
        out[#out + 1] = pad .. "…(" .. (#out - max_items) .. " more)"
        break
      end

      local key =
        (type(k) == "string" and k:match("^[_%a][_%w]*$"))
        and k
        or "[" .. stringify(k, depth + 1) .. "]"

      out[#out + 1] = pad .. key .. " = " .. stringify(v[k], depth + 1)
    end

    if #out == 0 then return "{}" end
    return "{\n" .. table.concat(out, ",\n") .. "\n" .. base .. "}"
  end

  return stringify(value, 0)
end

-- ============================================================================
-- STRING HELPERS
-- ============================================================================

-- Minify whitespace (used for comparisons / logs)
function DMUtil.minify(str)
  return tostring(str)
    :gsub("[%s\n\r\t]+", " ")
    :match("^%s*(.-)%s*$")
end

-- Cap string length (non-ellipsis by design)
function DMUtil.cap(str, max)
  return (#str <= max) and str or str:sub(1, max)
end

-- Escape string for safe Lua pattern usage
function DMUtil.escape_pattern_lua(s)
  return tostring(s):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- ============================================================================
-- MUDLET-SPECIFIC UTILITIES
-- ============================================================================

-- Replay a text file through triggers (debug / regression testing)
function DMUtil.replayFileToTriggers(path)
  local f, err = io.open(path, "r")
  if not f then
    cecho("<red>Could not open file: " .. tostring(err) .. "\n")
    return
  end

  cecho("<cyan>[Replay] Feeding lines from " .. path .. "\n")

  for line in f:lines() do
    feedTriggers("\n" .. line)
  end

  f:close()
  cecho("<green>[Replay] Done\n")
end

-- Verbose wrapper for anonymous event handlers (debug visibility)
function DMUtil.registerAnonymousEventHandlerVerbose(event, handler)
  local id = registerAnonymousEventHandler(event, handler)
  local label =
    (type(handler) == "string" and handler)
    or (type(handler) == "function" and "function")
    or "unknown"

  cecho(string.format(
    "<green>[UT] <yellow>registerAnonymousEventHandler: <white>[%d] %s > %s\n",
    id, event, label
  ))
end
