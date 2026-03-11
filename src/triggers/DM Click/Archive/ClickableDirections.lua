if not CAPTURING_ROOM then return end
local ln = line
-- Ignore prompts
if ln:sub(1,1) == "<" then return end

local dirs = { "north", "south", "east", "west", "up", "down" }
local lower = ln:lower()

-- collect matches
local matches = {}
for _, dir in ipairs(dirs) do
  local start = 1
  while true do
    local s, e = lower:find("%f[%a]" .. dir .. "%f[%A]", start)
    if not s then break end
    table.insert(matches, { s = s, e = e, dir = dir, word = ln:sub(s, e) })
    start = e + 1
  end
end

if #matches == 0 then return end

-- process right-to-left so indices don't shift
table.sort(matches, function(a, b) return a.s > b.s end)
moveCursorEnd()
local lnum = getLineNumber()
for _, m in ipairs(matches) do
  local pos0 = m.s - 1
  local len  = m.e - m.s + 1

  if selectSection(pos0, len) then
    replace("")
    moveCursor(pos0, lnum)

    cinsertLink(
      "<forest_green>" .. m.word,
      function() send(m.dir) end,
      "Go " .. m.dir,
      true
    )
    moveCursorEnd()
  end
end
