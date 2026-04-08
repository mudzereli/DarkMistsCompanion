-- =============================================================================
-- TIMER MANAGER (prevents duplicate timers on reinstall)
-- =============================================================================

DarkmistsTimer = {}
DarkmistsTimer.registry = {}

local debug = false -- set to false to disable timer debug messages

function DarkmistsTimer.add(key, seconds, func, repeating)
  local timerKey = tostring(key)

  -- Kill old timer if it exists
  if DarkmistsTimer.registry[timerKey] then
    if debug then
      cecho("\n" .. DarkmistsTheme.badTag .. "Killing timer: " .. DarkmistsTheme.textTag .. timerKey)
    end
    pcall(killTimer, DarkmistsTimer.registry[timerKey])
    DarkmistsTimer.registry[timerKey] = nil
  end

  if debug then
    cecho(
      "\n"
      .. DarkmistsTheme.goodTag .. "Adding timer: "
      .. DarkmistsTheme.textTag .. timerKey
      .. (repeating and (" " .. DarkmistsTheme.mutedTag .. "(repeating)") or "")
    )
  end

  local wrapped = function(...)
    if not repeating then
      DarkmistsTimer.registry[timerKey] = nil
    end
    return func(...)
  end

  DarkmistsTimer.registry[timerKey] = tempTimer(seconds, wrapped, repeating)
  return DarkmistsTimer.registry[timerKey]
end

function DarkmistsTimer.remove(key)
  local timerKey = tostring(key)
  if DarkmistsTimer.registry[timerKey] then
    pcall(killTimer, DarkmistsTimer.registry[timerKey])
    DarkmistsTimer.registry[timerKey] = nil
    return true
  end
  return false
end

function DarkmistsTimer.clearAll()
  for key, id in pairs(DarkmistsTimer.registry) do
    if debug then
      cecho("\n" .. DarkmistsTheme.badTag .. "Killing timer: " .. DarkmistsTheme.textTag .. tostring(key))
    end
    pcall(killTimer, id)
  end
  DarkmistsTimer.registry = {}
end