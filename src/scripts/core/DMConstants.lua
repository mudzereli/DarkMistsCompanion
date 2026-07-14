-- ============================================================================
-- DMConstants
-- ----------------------------------------------------------------------------
-- Shared constant/enum lookup tables used across the framework.
-- Keeps data separate from logic so any module can reference the same values.
-- ============================================================================

DMConstants = {}

-- ============================================================================
-- Combat Condition Descriptions
-- ----------------------------------------------------------------------------
-- Ordered list of mob condition phrases from most healthy to near death.
-- Used by DMAPI's mobCondition parser to assess target health in combat.
-- ============================================================================

DMConstants.COMBAT_CONDITIONS = {
  "is in perfect condition",
  "has a few nicks",
  "has a few scratches",
  "looks a little beat up",
  "has a few bruises",
  "has quite a few bruises",
  "is heavily bruised",
  "has some small wounds",
  "has some nasty cuts",
  "has quite a few wounds",
  "is covered in bleeding wounds",
  "is bleeding profusely",
  "is spurting blood",
  "is gushing blood",
  "is screaming in pain",
  "looks like a bloody mess",
  "is stumbling in pain",
  "is in pretty bad shape",
  "is writhing in agony",
  "is spasming in shock",
  "is catatonic from the intense pain",
  "is stumbling from grave injuries",
  "is convulsing on the ground",
  "nearly dead",
}

-- ============================================================================
-- Damage Verb Ranges
-- ----------------------------------------------------------------------------
-- Maps combat message keywords to {min, max} damage ranges.
-- Used by DamageMessages.lua and any other damage display/parsing modules.
-- Source: Darkmists combat output conventions.
-- ============================================================================

DMConstants.DAMAGE_VERBS = {
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
