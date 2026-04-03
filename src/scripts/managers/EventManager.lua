-- =============================================================================
-- EVENT HANDLER MANAGER (prevents duplicates on reinstall)
-- =============================================================================

DarkmistsEvents = DarkmistsEvents or {}
DarkmistsEvents.registry = DarkmistsEvents.registry or {}

local debug = false -- set to false to disable event handler debug messages

function DarkmistsEvents.add(key, eventName, func, oneshot)
  -- Kill old handler if exists
  if DarkmistsEvents.registry[key] then
    if debug then
      cecho(string.format("\n%sKilling event handler: %s%s %sfor %s%s",
        DarkmistsTheme.badTag,
        DarkmistsTheme.textTag,
        key,
        DarkmistsTheme.badTag,
        DarkmistsTheme.textTag,
        eventName
      ) .. (oneshot and string.format(" %s(oneshot)", DarkmistsTheme.mutedTag) or ""))
    end
    killAnonymousEventHandler(DarkmistsEvents.registry[key])
  end

  if debug then
    cecho(string.format("\n%sAdding event handler: %s%s %sfor %s%s",
      DarkmistsTheme.goodTag,
      DarkmistsTheme.textTag,
      key,
      DarkmistsTheme.mutedTag,
      DarkmistsTheme.textTag,
      eventName
    ) .. (oneshot and string.format(" %s(oneshot)", DarkmistsTheme.mutedTag) or ""))
  end
  -- Create and store new handler (oneshot support)
  DarkmistsEvents.registry[key] = registerAnonymousEventHandler(eventName, func, oneshot)
end

function DarkmistsEvents.remove(key)
  if DarkmistsEvents.registry[key] then
    killAnonymousEventHandler(DarkmistsEvents.registry[key])
    DarkmistsEvents.registry[key] = nil
    return true
  end
  return false
end

function DarkmistsEvents.clearAll()
  for _, id in pairs(DarkmistsEvents.registry) do
    if debug then
      cecho(string.format("\n%sKilling event handler: %s%s",
        DarkmistsTheme.badTag,
        DarkmistsTheme.textTag,
        id
      ))
    end
    killAnonymousEventHandler(id)
  end
  DarkmistsEvents.registry = {}
end