-- Damage verb → {min, max} range lookup
local DAMAGE_VERBS = {
  ["misses"]                    = {0, 0},
  ["nicks"]                     = {1, 2},
  ["scratches"]                 = {3, 4},
  ["grazes"]                    = {5, 8},
  ["hits"]                      = {9, 13},
  ["injures"]                   = {14, 18},
  ["wounds"]                    = {19, 23},
  ["thrashes"]                  = {24, 25},
  ["mauls"]                     = {26, 28},
  ["decimates"]                 = {29, 35},
  ["devastates"]                = {36, 38},
  ["maims"]                     = {39, 42},
  ["MUTILATES"]                 = {43, 56},
  ["DISEMBOWELS"]               = {57, 64},
  ["DISMEMBERS"]                = {65, 73},
  ["GORES"]                     = {74, 81},
  ["PULVERIZES"]                = {82, 97},
  ["RAZES"]                     = {98, 114},
  ["MASSACRES"]                 = {115, 130},
  ["MANGLES"]                   = {131, 145},
  ["*** DEMOLISHES ***"]        = {146, 160},
  ["*** DEVASTATES ***"]        = {161, 185},
  ["*** SLAUGHTERS ***"]        = {186, 205},
  ["=== OBLITERATES ==="]       = {206, 225},
  ["=== EVISCERATES ==="]       = {226, 250},
  [">>> ANNIHILATES <<<"]       = {251, 280},
  [">>> EXTERMINATES <<<"]      = {281, 360},
  ["<<< RAVAGES >>>"]           = {361, 450},
  ["<<< ERADICATES >>>"]        = {451, 599},
  ["does UNSPEAKABLE things to"]    = {600, 699},
  ["does UNGODLY things to"]        = {700, 899},
  ["DOES UNSPEAKABLE THINGS TO"]    = {900, 999},
}

local range = DAMAGE_VERBS[matches[2]]
local minDMG = range and range[1] or 0
local maxDMG = range and range[2] or 0
local avgDMG = math.ceil((minDMG + maxDMG) / 2)
local settings = Darkmists and Darkmists.GlobalSettings or {}
local color = settings.damageMessageColor or "red"
local mode  = settings.damageMessageMode  or "avg"
local damageMessage
if mode == "range" then
  damageMessage = (" <dim_gray>(<%s>%d<dim_gray>-<%s>%d<dim_gray>)"):format(color,minDMG,color,maxDMG,color,avgDMG)
else
  damageMessage = (" <dim_gray>(<%s>%d<dim_gray>)"):format(color, avgDMG)
end
if avgDMG > 0 then
  cecho(damageMessage)
end
