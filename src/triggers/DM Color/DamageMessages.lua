local verb = matches[2]
local minDMG = 0
local maxDMG = 0
if verb == "misses" then
  minDMG = 0
  maxDMG = 0
elseif verb == "nicks" then
  minDMG = 1
  maxDMG = 2
elseif verb == "scratches" then
  minDMG = 3
  maxDMG = 4
elseif verb == "grazes" then
  minDMG = 5
  maxDMG = 8
elseif verb == "hits" then
  minDMG = 9
  maxDMG = 13
elseif verb == "injures" then
  minDMG = 14
  maxDMG = 18
elseif verb == "wounds" then
  minDMG = 19
  maxDMG = 23
elseif verb == "thrashes" then
  minDMG = 24
  maxDMG = 25
elseif verb == "mauls" then
  minDMG = 26
  maxDMG = 28
elseif verb == "decimates" then
  minDMG = 29
  maxDMG = 35
elseif verb == "devastates" then
  minDMG = 36
  maxDMG = 38
elseif verb == "maims" then
  minDMG = 39
  maxDMG = 42
elseif verb == "MUTILATES" then
  minDMG = 43
  maxDMG = 56
elseif verb == "DISEMBOWELS" then
  minDMG = 57
  maxDMG = 64
elseif verb == "DISMEMBERS" then
  minDMG = 65
  maxDMG = 73
elseif verb == "GORES" then
  minDMG = 74
  maxDMG = 81
elseif verb == "PULVERIZES" then
  minDMG = 82
  maxDMG = 97
elseif verb == "RAZES" then
  minDMG = 98
  maxDMG = 114
elseif verb == "MASSACRES" then
  minDMG = 115
  maxDMG = 130
elseif verb == "MANGLES" then
  minDMG = 131
  maxDMG = 145
elseif verb == "*** DEMOLISHES ***" then
  minDMG = 146
  maxDMG = 160
elseif verb == "*** DEVASTATES ***" then
  minDMG = 161
  maxDMG = 185
elseif verb == "*** SLAUGHTERS ***" then
  minDMG = 186
  maxDMG = 205
elseif verb == "=== OBLITERATES ===" then
  minDMG = 206
  maxDMG = 225
elseif verb == "=== EVISCERATES ===" then
  minDMG = 226
  maxDMG = 250
elseif verb == ">>> ANNIHILATES <<<" then
  minDMG = 251
  maxDMG = 280
elseif verb == ">>> EXTERMINATES <<<" then
  minDMG = 281
  maxDMG = 360
elseif verb == "<<< RAVAGES >>>" then
  minDMG = 361
  maxDMG = 450
elseif verb == "<<< ERADICATES >>>" then
  minDMG = 451
  maxDMG = 599
elseif verb == "does UNSPEAKABLE things to" then
  minDMG = 600
  maxDMG = 699
elseif verb == "does UNGODLY things to" then
  minDMG = 700
  maxDMG = 899
elseif verb == "DOES UNSPEAKABLE THINGS TO" then
  minDMG = 900
  maxDMG = 999
end
local avgDMG = math.ceil((minDMG + maxDMG)/2)
--damageMessage = (" <dim_gray>(<red>%d<dim_gray>-<red>%d<dim_gray> [<red>%d<dim_gray>])"):format(minDMG,maxDMG,avgDMG)
local damageMessage = (" <dim_gray>(<red>%d<dim_gray>)"):format(avgDMG)
if avgDMG > 0 then
  cecho(damageMessage)
end
