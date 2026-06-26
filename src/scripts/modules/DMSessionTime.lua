-- =============================================================================
-- DMSessionTime.lua
-- -----------------------------------------------------------------------------
-- Tracks session duration and provides a formatted display string for the
-- ButtonBar or other UI elements.
--
-- Design:
--   - Captures session start via getEpoch() on init
--   - Updates every second via DarkmistsTimer (repeating)
--   - Pushes formatted "⏱ H:MM:SS" to ButtonBar.setTimeDisplay()
--   - Reload-safe: resets module table + stops timer on load
-- =============================================================================

SessionTime = {}

-- Clean up any stale timer from a previous load before re-initializing.
if SessionTime.timer then
  DarkmistsTimer.remove("SessionTime.Tick")
  SessionTime.timer = nil
end

-- -----------------------------------------------------------------------------
-- Format elapsed seconds as a compact human-readable string.
-- Uses "M:SS" for durations under 1 hour, "H:MM:SS" for longer sessions.
-- -----------------------------------------------------------------------------
function SessionTime.formatTime(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = math.floor(seconds % 60)
  if h > 0 then
    return string.format("%d:%02d:%02d", h, m, s)
  end
  return string.format("%d:%02d", m, s)
end

-- -----------------------------------------------------------------------------
-- Push the current elapsed time to the ButtonBar display label.
-- Silently no-ops if the session hasn't started or the ButtonBar isn't ready.
-- -----------------------------------------------------------------------------
function SessionTime.updateDisplay()
  if not SessionTime.sessionStart then return end
  local elapsed = math.floor(getEpoch() - SessionTime.sessionStart)
  local text = "⏱ " .. SessionTime.formatTime(elapsed)
  if ButtonBar and ButtonBar.setTimeDisplay then
    ButtonBar.setTimeDisplay(text)
  end
end

-- -----------------------------------------------------------------------------
-- Timer management: start / stop the repeating 1-second tick.
-- -----------------------------------------------------------------------------
function SessionTime.startTimer()
  SessionTime.stopTimer()
  SessionTime.timer = DarkmistsTimer.add("SessionTime.Tick", 1, SessionTime.updateDisplay, true)
end

function SessionTime.stopTimer()
  if SessionTime.timer then
    DarkmistsTimer.remove("SessionTime.Tick")
    SessionTime.timer = nil
  end
end

-- -----------------------------------------------------------------------------
-- Reset the session clock. Called on login and logout so the display
-- always reflects the current world session.
-- -----------------------------------------------------------------------------
function SessionTime.reset()
  SessionTime.sessionStart = getEpoch()
  SessionTime.startTimer()
  SessionTime.updateDisplay()
end

-- -----------------------------------------------------------------------------
-- Entry point. Records session start, registers world-enter/exit events,
-- and begins the display timer.
-- Called by DarkMistsCore during initialization.
-- -----------------------------------------------------------------------------
function SessionTime.init()
  -- Reset on each fresh login or reconnect.
  DarkmistsEvents.add("SessionTime.WorldEnter", "dmapi.world.enter", function()
    SessionTime.reset()
  end)

  -- Reset on disconnect — stops the clock until next login.
  DarkmistsEvents.add("SessionTime.WorldExit", "dmapi.world.exit", function()
    SessionTime.stopTimer()
    SessionTime.sessionStart = nil
    SessionTime.updateDisplay() -- clear the label
  end)

  SessionTime.reset()
  SessionTime.updateDisplay()

  if DMLogger then
    DMLogger.log("SessionTime", "Ready")
  end
end
