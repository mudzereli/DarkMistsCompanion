-- =============================================================================
-- DarkMistsStartup
-- -----------------------------------------------------------------------------
-- Startup orchestration boundary. The implementation remains in DarkMistsCore
-- until each phase can be moved without changing persisted settings behavior.
-- =============================================================================
DarkmistsStartup = {}

DarkmistsStartup.phase = "idle"
DarkmistsStartup.generation = 0

function DarkmistsStartup.setPhase(phase)
  DarkmistsStartup.phase = phase
end

function DarkmistsStartup.invalidate()
  DarkmistsStartup.generation = DarkmistsStartup.generation + 1
  DarkmistsStartup.phase = "shutting-down"
end

function DarkmistsStartup.start()
  if type(Darkmists.runStartup) ~= "function" then
    return false
  end

  DarkmistsStartup.generation = DarkmistsStartup.generation + 1
  DarkmistsStartup.phase = "starting"
  local result = Darkmists.runStartup()
  DarkmistsStartup.phase = "ready"
  return result
end

return DarkmistsStartup
