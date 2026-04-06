-- =============================================================================
-- TRIGGER MANAGER (prevents duplicates on reinstall)
-- =============================================================================

DarkmistsTrigger = {}
DarkmistsTrigger.registry = {}

local debug = false -- set to false to disable trigger debug messages

function DarkmistsTrigger.addRegex(pattern, code, expireAfter)
  local key = "regex:" .. tostring(pattern)
  if debug then
    cecho("\n<dim_gray>Adding regex trigger: <white>" .. key)
  end
  -- Kill old trigger if it exists
  if DarkmistsTrigger.registry[key] then
    killTrigger(DarkmistsTrigger.registry[key])
  end

  -- Create and store new regex trigger
  DarkmistsTrigger.registry[key] = tempRegexTrigger(pattern, code, expireAfter)
end

function DarkmistsTrigger.add(substring, code, expireAfter)
  local key = "sub:" .. tostring(substring)
  if debug then
    cecho("\n<dim_gray>Adding substring trigger: <white>" .. key)
  end
  -- Kill old trigger if it exists
  if DarkmistsTrigger.registry[key] then
    killTrigger(DarkmistsTrigger.registry[key])
  end

  -- Create and store new substring trigger
  DarkmistsTrigger.registry[key] = tempTrigger(substring, code, expireAfter)
end

function DarkmistsTrigger.addKeyed(key, triggerType, patternOrSubstring, code, expireAfter)
  local fullKey = tostring(key)
  if debug then
    cecho("\n<dim_gray>Adding keyed " .. triggerType .. " trigger: <white>" .. fullKey)
  end
  -- Kill old trigger if it exists
  if DarkmistsTrigger.registry[fullKey] then
    killTrigger(DarkmistsTrigger.registry[fullKey])
  end

  -- Create and store new trigger based on type
  if triggerType == "regex" then
    DarkmistsTrigger.registry[fullKey] = tempRegexTrigger(patternOrSubstring, code, expireAfter)
  elseif triggerType == "substring" then
    DarkmistsTrigger.registry[fullKey] = tempTrigger(patternOrSubstring, code, expireAfter)
  else
    error("Unknown trigger type: " .. tostring(triggerType))
  end
end

function DarkmistsTrigger.clearAll()
  for _, id in pairs(DarkmistsTrigger.registry) do
    killTrigger(id)
  end
  DarkmistsTrigger.registry = {}
end
