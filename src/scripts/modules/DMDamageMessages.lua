-- ============================================================================
-- DMDamageMessages
-- ----------------------------------------------------------------------------
-- Inline damage estimates — subscribes to dmapi damage events and echoes
-- estimated damage ranges using user-configured colors and display mode.
--
-- Relies on: DMConstants.DAMAGE_VERBS, dmapi.player.combat.damage.{outgoing,incoming}
-- ============================================================================

DamageMessages = {}

local function onDamage(_, info)
  if info.avgDamage <= 0 then return end

  local settings = Darkmists and Darkmists.GlobalSettings or {}
  local color = settings.damageMessageColor or "red"
  local mode  = settings.damageMessageMode  or "avg"

  local message
  if mode == "range" then
    message = string.format(
      " <dim_gray>(<%s>%d<dim_gray>-<%s>%d<dim_gray>, avg: <%s>%d<dim_gray>)",
      color, info.minDamage, color, info.maxDamage, color, info.avgDamage
    )
  else
    message = string.format(
      " <dim_gray>(<%s>%d<dim_gray>)",
      color, info.avgDamage
    )
  end

  cecho(message)
end

function DamageMessages.init()
  DarkmistsEvents.add("DamageMessages.outgoing", "dmapi.player.combat.damage.outgoing", onDamage)
  DarkmistsEvents.add("DamageMessages.incoming", "dmapi.player.combat.damage.incoming", onDamage)
  DarkmistsEvents.add("DamageMessages.other",     "dmapi.player.combat.damage.other",     onDamage)
  Darkmists.Log(DarkmistsTheme.mutedTag .. "DamageMessages", "Loaded — listening for damage events")
end
