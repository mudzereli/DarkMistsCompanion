local cmain = Darkmists.getDefaultTextColorTag()
local chighlight = "<forest_green>"
local ln = line
replaceLine("")
ln = ln:gsub(
  "%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-",
  ("-%sCLICKABLE AUCTIONS ENABLED%s"):format(chighlight,cmain))
cecho(ln)