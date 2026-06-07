-- Damage verb → {min, max} range lookup (defined in core/DMConstants.lua)
local range = DMConstants.DAMAGE_VERBS[matches[2]]
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
