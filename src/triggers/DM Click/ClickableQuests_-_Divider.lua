local cmain = "<r>"
local chighlight = "<forest_green>"
local ln = line
replaceLine("")
ln = ln:gsub("%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-",("-%sCLICKABLE QUESTS ENABLED%s"):format(chighlight,cmain))
cecho(ln)