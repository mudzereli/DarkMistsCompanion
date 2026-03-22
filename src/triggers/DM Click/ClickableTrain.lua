-- Ignore prompts
if line:sub(1,1) == "<" then return end

-- Only during train command
if not (command and command:match("^train")) then return end

local raw = line

-- Match the main train list
local list = raw:match("^You can train:%s*(.+)")
if not list then return end

-- Clean punctuation
list = list:gsub("[%.]", "")

local stats = {}
for stat in list:gmatch("(%a+)") do
  table.insert(stats, stat)
end

if #stats == 0 then return end

replaceLine("")
cecho("<r>You can train: ")

for _, stat in ipairs(stats) do
  cechoLink(
    string.format("<steel_blue>%s", stat),
    function()
      if holdingModifiers(mudlet.keymodifier.Shift) then
        send("train " .. stat)
        send("train")
      else
        send("help " .. stat)
      end
    end,
    "Click: help " .. stat .. "\nShift+Click: train " .. stat,
    true
  )
  cecho(" ")
end
