local questNum = matches[2]
local rest = matches[3]
local txtColor = Darkmists.getDefaultTextColorTag()

replaceLine("")

cechoLink(
  string.format("<forest_green>%5s%s  %s\n", questNum, txtColor, rest),
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