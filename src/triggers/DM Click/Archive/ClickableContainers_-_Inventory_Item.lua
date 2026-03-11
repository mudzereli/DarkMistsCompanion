-- Ignore "A Pack Holds:" line
if line:match("holds:") then return end

-- Ignore Prompts
if line:sub(1,1) == "<" or not CLICKABLE_CONTAINERS_RUNNING then 
  CLICKABLE_CONTAINERS_RUNNING = false
  return true
end

-- Get Container "Name" from Command
local CLICKABLE_CONTAINERS_CURRENT = command:match("l[o]?[o]?[k]? in (.*)")

-- Extract the actual item name (strip counts & tags)
local item = line
  :gsub("^%s*", "")
  :gsub("^%(%s*%d+%)%s*", "")           -- remove (28)
  --:gsub("^(%b())%s*", "")               -- remove first tag
  --:gsub("^(%b())%s*", "")               -- remove second tag
  --:gsub("^(%b())%s*", "")               -- remove third tag
  --:gsub("^(%b())%s*", "")               -- remove fourth tag

-- If after stripping it’s empty, bail
if not item or item == "" then return end
if not CLICKABLE_CONTAINERS_DELETE_LINES then return end
if not CLICKABLE_CONTAINERS_CURRENT then return end

CLICKABLE_CONTAINERS_CURRENT_ITEM = CLICKABLE_CONTAINERS_CURRENT_ITEM + 1

local lastSeenItem = CLICKABLE_CONTAINERS_SEEN[item] or {}
lastSeenItem.count = lastSeenItem.count or 0
lastSeenItem.line = lastSeenItem.line or getLineNumber()

local tcount = lastSeenItem.count + 1

--echo(Util.dump_table(lastSeenItem))

if tcount > 1 then
  table.insert(CLICKABLE_CONTAINERS_DELETE_LINES,lastSeenItem.line)
  --echo(lastSeenItem.line.." : "..getLineNumber())
  moveCursor(0,getLineNumber())
  cinsertText((" (%2d) "):format(lastSeenItem.count))
else
  moveCursor(0,getLineNumber())
  cinsertText(("      "):format(lastSeenItem.count))
end

local sendCmd = string.format(
  "get %s. from %s",
  tostring(CLICKABLE_CONTAINERS_CURRENT_ITEM),
  CLICKABLE_CONTAINERS_CURRENT
)

moveCursor(0,getLineNumber())
cinsertLink(
  "<green>[+]",
  function()
    send(sendCmd)
    expandAlias(command)
  end,
  string.format(
    "Click: get %s from %s",
    item,
    CLICKABLE_CONTAINERS_CURRENT
  ), true)

lastSeenItem.count = tcount
lastSeenItem.line = getLineNumber()
CLICKABLE_CONTAINERS_SEEN[item] = lastSeenItem