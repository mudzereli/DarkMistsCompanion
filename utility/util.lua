DMUtil = {}

-- Helper Functions
DMUtil.escape_string = function(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"):gsub('"','\\"') .. '"'
end

DMUtil.is_int = function(n) return type(n) == "number" and n == math.floor(n) end

-- Table Functions
DMUtil.is_array = function(t)
  if type(t) ~= "table" then return false end
  local n, count = 0, 0
  for k in pairs(t) do if DMUtil.is_int(k) and k > n then n = k end end
  for k in pairs(t) do if DMUtil.is_int(k) and k >= 1 and k <= n then count = count + 1 else return false end end
  return n == count
end

DMUtil.sorted_keys = function(t)
  local ks = {}
  for k in pairs(t) do ks[#ks+1] = k end
  table.sort(ks, function(a,b)
    local ta, tb = type(a), type(b)
    if ta == tb and (ta == "number" or ta == "string") then return a < b end
    return tostring(a) < tostring(b)
  end)
  return ks
end

DMUtil.dump_table = function(value, opts)
  opts = opts or {}
  local indent, depth_limit, max_items = opts.indent or "  ", opts.depth_limit or 8, opts.max_items or 1000
  local seen = {}

  local function tostr(v, depth)
    local tv = type(v)
    if tv == "string" then return DMUtil.escape_string(v)
    elseif tv == "number" or tv == "boolean" or tv == "nil" then return tostring(v)
    elseif tv ~= "table" then return "<"..tv..">" end

    if seen[v] then return "<cycle@"..seen[v]..">" end
    if depth >= depth_limit then return "<max-depth>" end
    local id = tostring(v):gsub("table: ", "")
    seen[v] = id

    if DMUtil.is_array(v) then
      local out, limit = {}, math.min(#v, max_items)
      for i=1,limit do out[#out+1] = tostr(v[i], depth+1) end
      if #v > limit then out[#out+1] = "…(" .. (#v-limit) .. " more)" end
      return "[" .. table.concat(out, ", ") .. "]"
    end

    local keys, out, shown = DMUtil.sorted_keys(v), {}, 0
    local pad = string.rep(indent, depth+1)
    local cur = string.rep(indent, depth)
    for _,k in ipairs(keys) do
      shown = shown + 1
      if shown > max_items then
        out[#out+1] = pad .. "…(" .. (#keys-max_items) .. " more)"
        break
      end
      local key = (type(k)=="string" and k:match("^[_%a][_%w]*$")) and k or "["..tostr(k, depth+1).."]"
      out[#out+1] = pad .. key .. " = " .. tostr(v[k], depth+1)
    end
    if #out == 0 then return "{}" end
    return "{\n" .. table.concat(out, ",\n") .. "\n" .. cur .. "}"
  end

  return tostr(value, 0)
end

DMUtil.minify = function(str)
    -- Replace newlines and tabs with spaces
    str = str:gsub("[%s\n\r\t]+", " ")
    -- Trim leading and trailing spaces
    str = str:match("^%s*(.-)%s*$")
    return str
end

DMUtil.cap = function(str,max)
  if #str <= max then return str end
  return str:sub(1, max)
end

DMUtil.escape_pattern_lua = function(s)
  return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Deeply Copy Table Values Into Another Table
DMUtil.deep_copy_into = function(dest, src, seen)
  if type(src) ~= "table" then
    return dest
  end

  seen = seen or {}

  if seen[src] then
    return dest
  end
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

-- Take an entire text file (Log) and run it through triggers... (Debug Purposes)
DMUtil.replayFileToTriggers = function(path)
  local f, err = io.open(path, "r")
  if not f then
    cecho("<red>Could not open file: " .. tostring(err) .. "\n")
    return
  end

  cecho("<cyan>[Replay] Feeding lines from " .. path .. "\n")

  for line in f:lines() do
    line = "\n"..line
    feedTriggers(line)
  end

  f:close()
  cecho("<green>[Replay] Done\n")
end

-- Mudlet Helper Functions
DMUtil.registerAnonymousEventHandlerVerbose = function(e,h)
  local n = registerAnonymousEventHandler(e,h)
  local hSanitized = "unknown"
  if type(h) == "string" then
    hSanitized = h
  elseif type(h) == "function" then
    hSanitized = "function"
  end
  cecho(string.format("<green>[UT] <yellow>registerAnonymousEventHandler: <white>[%d] %s > %s\n",n,e,hSanitized))
end