---@meta
-- Shared type definitions for Dark Mists Mudlet Package
-- This file is for editor tooling only (LuaLS / EmmyLua)

-- ============================================================================
-- DMAPI CORE
-- ============================================================================

---@class dmapi.Meta
---@field name string
---@field version string
---@field author string
---@field description string

---@class dmapi.Settings
---@field themeColor string
---@field debugLevel integer
---@field combatRoundInterval number
---@field promptTimeout number

---@class dmapi.CoreState
---@field initialized boolean
---@field combatMissedPrompts integer
---@field lastCombatRoundFired number
---@field lastCommand string|nil

---@class dmapi.Core
---@field state dmapi.CoreState
---@field log fun(message:string, level?:'"info"'|'"warn"'|'"error"')
---@field warn fun(message:string)
---@field error fun(message:string)
---@field send fun(cmd:string, ...:any)
---@field raiseEvent fun(eventName:string, ...:any)
---@field getLastCommand fun():string|nil
---@field LineTrigger fun(line:string)

-- ============================================================================
-- PLAYER STATE
-- ============================================================================

---@class dmapi.PlayerVitals
---@field hp number
---@field mn number
---@field mv number
---@field rg number
---@field hpMax number
---@field mnMax number
---@field mvMax number
---@field practices number
---@field hpPct number
---@field mnPct number
---@field mvPct number

---@class dmapi.PlayerStatus
---@field sleeping boolean
---@field resting boolean
---@field hungry integer  -- -1=full, 0=ok, 1-4=increasing hunger
---@field thirsty integer -- 0=ok, 1-4=increasing thirst
---@field stunned boolean
---@field position '"standing"'|'"resting"'|'"sleeping"'|'"fighting"'

---@class dmapi.PlayerCombat
---@field active boolean
---@field round integer
---@field target string|nil
---@field lastActivity number
---@field kills integer
---@field deaths integer

---@class dmapi.PlayerCurrency
---@field gold number
---@field silver number

---@class dmapi.PlayerExperience
---@field total number
---@field tnl number
---@field lastGain number
---@field totalGained number

---@class dmapi.PlayerAge
---@field years number
---@field hours number

---@class dmapi.Player
---@field level number
---@field online boolean
---@field age dmapi.PlayerAge
---@field currency dmapi.PlayerCurrency
---@field experience dmapi.PlayerExperience
---@field vitals dmapi.PlayerVitals
---@field status dmapi.PlayerStatus
---@field combat dmapi.PlayerCombat
---@field equipment table<string, any>
---@field state table<string, any>
---@field actions table<string, any>
---@field reset fun()
---@field getStatus fun():table
---@field setSleeping fun(sleeping:boolean)

-- ============================================================================
-- WORLD STATE
-- ============================================================================

---@class dmapi.WorldRoom
---@field seenAt number
---@field vnum number|nil
---@field name string|nil
---@field description string|nil
---@field exits string[]
---@field mobiles string[]
---@field items string[]

---@class dmapi.WorldTime
---@field isDay boolean
---@field weather string

---@class dmapi.World
---@field room dmapi.WorldRoom
---@field time dmapi.WorldTime

-- ============================================================================
-- EVENTS (PAYLOAD SHAPES)
-- ============================================================================

---@class EventLevelUp
---@field hpGain number
---@field hpMax number
---@field mnGain number
---@field mnMax number
---@field mvGain number
---@field mvMax number
---@field prac number
---@field pracTotal number
---@field line string

---@class EventVitalsUpdated
---@field hp number
---@field mn number
---@field mv number
---@field rg number|nil
---@field tnl number
---@field line string

---@class EventCombatRound
---@field target string
---@field condition string
---@field hpPct number
---@field round number
---@field timestamp number
---@field line string

---@class EventCurrencyGain
---@field gold number
---@field silver number
---@field source string
---@field line string

---@class EventSkillImproved
---@field skill string
---@field line string

-- ============================================================================
-- ROOT API
-- ============================================================================

---@class dmapi
---@field meta dmapi.Meta
---@field settings dmapi.Settings
---@field core dmapi.Core
---@field player dmapi.Player
---@field world dmapi.World
