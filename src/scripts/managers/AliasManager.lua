-- =============================================================================
-- ALIAS MANAGER (prevents duplicates on reinstall)
-- =============================================================================

DarkmistsAlias = {}
DarkmistsAlias.registry = {}

local debug = false

function DarkmistsAlias.add(pattern, func)
  local key = tostring(pattern)
  if debug then
    cecho("\n<dim_gray>Adding alias: <white>" .. key)
  end
  -- Kill old alias if it exists
  if DarkmistsAlias.registry[key] then
    killAlias(DarkmistsAlias.registry[key])
  end

  -- Create and store new alias
  DarkmistsAlias.registry[key] = tempAlias(pattern, func)
end

function DarkmistsAlias.clearAll()
  for _, id in pairs(DarkmistsAlias.registry) do
    killAlias(id)
  end
  DarkmistsAlias.registry = {}
end