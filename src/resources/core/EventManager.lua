-- =============================================================================
-- EVENT HANDLER MANAGER (prevents duplicates on reinstall)
-- =============================================================================

DarkmistsEvents = DarkmistsEvents or {}
DarkmistsEvents.registry = DarkmistsEvents.registry or {}

local debug = true


function DarkmistsEvents.add(key, eventName, func, oneshot)
  -- Kill old handler if exists
  if DarkmistsEvents.registry[key] then
    if debug then
      cecho("\n<ansi_red>Killing event handler: <white>" .. key .. " <ansi_red>for <white>" .. eventName .. (oneshot and " <dim_gray>(oneshot)" or ""))
    end
    killAnonymousEventHandler(DarkmistsEvents.registry[key])
  end

  if debug then
    cecho("\n<dim_gray>Adding event handler: <white>" .. key .. " <dim_gray>for <white>" .. eventName .. (oneshot and " <dim_gray>(oneshot)" or ""))
  end
  -- Create and store new handler (oneshot support)
  DarkmistsEvents.registry[key] = registerAnonymousEventHandler(eventName, func, oneshot)
end

function DarkmistsEvents.clearAll()
  for _, id in pairs(DarkmistsEvents.registry) do
    if debug then
      cecho("\n<ansi_red>Killing event handler: <white>" .. key .. " <ansi_red>for <white>" .. eventName .. (oneshot and " <dim_gray>(oneshot)" or ""))
    end
    killAnonymousEventHandler(id)
  end
  DarkmistsEvents.registry = {}
end