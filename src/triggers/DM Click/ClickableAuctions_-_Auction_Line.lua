replaceLine("")
local id = matches["id"]
local name = matches["name"]
local buyout = matches["buyout"]
local time = matches["time"]
local bid = matches["bid"]
local suffix = matches["suffix"]

name = name:gsub("^%s+","")

if #name >= 28 then
  name = name:sub(1,28)
end

cechoLink(
  string.format("<forest_green>%7s  "..Darkmists.getDefaultTextColorTag().."%-28s", id, name),
  function()
      send("auc browse " .. id)
  end,
  string.format("Click: auc browse %s", id),
  true
)
cecho(Darkmists.getDefaultTextColorTag().."  ")
cechoLink(
  string.format("<dark_khaki>%7s", buyout),
  function()
      send("auc buyout " .. id)
      send("auc list")
  end,
  string.format("Click: auc buyout %s", id),
  true
)
cecho(Darkmists.getDefaultTextColorTag().."  ")
cecho(Darkmists.getDefaultTextColorTag()..("%11s"):format(time))
cecho(Darkmists.getDefaultTextColorTag().."  ")
cechoLink(
  string.format("<dark_khaki>%11s", bid),
  function()
      send(("auc bid %s %s"):format(id,bid+1))
      send("auc list")
  end,
  string.format("Click: auc bid %s %d", id, bid+1),
  true
)
if suffix then
  cecho(("<forest_green>%s"):format(suffix))
end
cecho("\n")