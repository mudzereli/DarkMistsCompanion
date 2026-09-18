-- =============================================================================
-- DarkMistsSetup
-- -----------------------------------------------------------------------------
-- First-run onboarding sequence, owned by a single state machine.
--
-- The SET UP DMC button (see DMButtonBar) starts this. Steps run strictly in
-- order:
--   1. UI mode prompt      - Minimal or Full UI
--   2. first score refresh - sent by MarkUIIntroSeen -> reconcileOnlineState
--   3. bundled-map prompt  - binary: install the map, or keep the current one
--   4. settle              - only when the map was installed (~4s)
--   5. theme contrast check - followed by the completion notice in chat
--
-- The completion notice is printed here rather than by the alert handlers: this
-- is the only point every successful path converges on, and a dismissed UI
-- prompt returns to STEP_IDLE without ever arriving here.
--
-- `hasSeenUIIntroMessage` doubles as the "setup completed" marker, which is what
-- keeps a fresh install passive until the player presses the button.
--
-- Reload safety: begin() captures the startup generation and every deferred
-- callback bails when it changes, so a reload cannot advance a dead sequence.
-- CleanupUI() calls DarkmistsStartup.invalidate() first, which bumps it.
-- =============================================================================
DarkmistsSetup = {}

DarkmistsSetup.STEP_IDLE       = "idle"
DarkmistsSetup.STEP_UI_CHOICE  = "ui-choice"
DarkmistsSetup.STEP_MAP_CHOICE = "map-choice"
DarkmistsSetup.STEP_SETTLING   = "settling"
DarkmistsSetup.STEP_DONE       = "done"

-- Gap between an installed map and the contrast check. LoadMapDat fires its own
-- follow-up commands ~2s after loadMap(), and the `look` response needs to land
-- before another panel opens.
DarkmistsSetup.MAP_SETTLE_SECONDS = 4

DarkmistsSetup.step = DarkmistsSetup.STEP_IDLE
DarkmistsSetup.generation = nil

local function stillCurrent(generation)
  return generation ~= nil and generation == DarkmistsStartup.generation
end

--- Is the client connected to the game?
--- Uses Mudlet's real connection state rather than `dmapi.player.online`, which
--- is a parser inference: it only turns true once a prompt line has been parsed
--- since DMC loaded, so it reads false right after a mid-session install or any
--- reload even though the player is connected. Fails open - if the API is
--- unavailable we would rather let setup proceed than block a local UI choice.
local function isConnected()
  if type(getConnectionInfo) ~= "function" then return true end
  local _, _, connected = getConnectionInfo()
  return connected and true or false
end

function DarkmistsSetup.isDone()
  return DarkmistsSetup.step == DarkmistsSetup.STEP_DONE
end

function DarkmistsSetup.isActive()
  local step = DarkmistsSetup.step
  return step ~= DarkmistsSetup.STEP_IDLE and step ~= DarkmistsSetup.STEP_DONE
end

--- True while the sequence owns the map prompt, so DarkmistsStartup must not
--- schedule a competing one. Covers ui-choice too: that state is on its way to
--- showing the map prompt itself.
function DarkmistsSetup.ownsMapPrompt()
  return DarkmistsSetup.isActive()
end

local function runContrastCheck(generation)
  if not stillCurrent(generation) then return end
  -- Final step, so the sequence is no longer active: ownsMapPrompt() must stop
  -- claiming the map prompt, and begin() must be usable again.
  DarkmistsSetup.step = DarkmistsSetup.STEP_DONE
  Darkmists._contrastCheckPending = false
  -- Printed before the contrast check so the line lands ahead of the alert panel
  -- when the theme does need switching. Silent paths (no mismatch) would
  -- otherwise end the sequence with no feedback at all.
  -- Deliberately does not advertise Settings -> Setup Wizard: that entry only
  -- offers the UI-mode choice, while the bundled-map prompt is its own entry
  -- (Settings -> Load Map), so it is not a way back into this sequence.
  -- The trailing \n is belt-and-braces. notify() prefixes a newline but does not
  -- terminate the line, and raw command echoes carry no leading newline of their
  -- own, so anything that does slip in - a menu-driven map load, or a map
  -- installed before the session is up - would otherwise glue onto the end here.
  -- Commands are picked out in the theme's success colour, the same way the intro
  -- panel styles `dmc help` and `dmc settings`.
  DMLogger.notify("Darkmists Setup",
    DarkmistsTheme.goodTag .. "Setup complete!" ..
    DarkmistsTheme.mutedTag .. " Type '" .. DarkmistsTheme.goodTag .. "dmc help" ..
    DarkmistsTheme.mutedTag .. "' for commands, or '" ..
    DarkmistsTheme.goodTag .. "dmc settings" .. DarkmistsTheme.mutedTag .. "' for options.\n")
  DarkmistsTheme.checkBackgroundContrast()
end

-- Step 4 + 5: settle (only after an install), then the contrast check.
local function settleThenCheckContrast(generation, installed)
  if not stillCurrent(generation) then return end
  DarkmistsSetup.step = DarkmistsSetup.STEP_SETTLING
  -- A fixed delay, long enough for the map's own follow-up commands to go out
  -- and their replies to land. It cannot see the case where those commands wait
  -- for the next world enter, so a map installed before the session is up can
  -- still finish first - the trailing newline on the notice keeps that tidy.
  local delay = installed and DarkmistsSetup.MAP_SETTLE_SECONDS or 0
  tempTimer(delay, function() runContrastCheck(generation) end)
end

-- Step 3: the bundled-map prompt.
local function stepMapPrompt(generation)
  if not stillCurrent(generation) then return end

  if Darkmists.GlobalSettings.hasSeenMapPrompt then
    -- Answered on a previous run; go straight to the contrast check.
    settleThenCheckContrast(generation, false)
    return
  end

  DarkmistsSetup.step = DarkmistsSetup.STEP_MAP_CHOICE
  Darkmists.PromptLoadMap(function(installed)
    settleThenCheckContrast(generation, installed)
  end)
end

-- Steps 1 + 2: the UI mode prompt. Choosing a mode runs EnableUI/DisableUI and
-- MarkUIIntroSeen inside the link handlers; MarkUIIntroSeen is what sends the
-- first score refresh, via reconcileOnlineState("setup-complete").
local function stepUiChoice(generation)
  if not stillCurrent(generation) then return end
  DarkmistsSetup.step = DarkmistsSetup.STEP_UI_CHOICE

  Darkmists.ShowUIIntroMessage(true,
    function()
      -- Already deferred by commitChoice, so the click handler has returned
      -- before this builds the next alert panel.
      stepMapPrompt(generation)
    end,
    function()
      -- Dismissed without choosing. Nothing runs and the button stays, so the
      -- player can start the sequence again.
      if not stillCurrent(generation) then return end
      DarkmistsSetup.step = DarkmistsSetup.STEP_IDLE
    end)
end

--- Entry point for the SET UP DMC button.
function DarkmistsSetup.begin()
  if DarkmistsSetup.isDone() or DarkmistsSetup.isActive() then return false end

  if not isConnected() then
    DMLogger.notify("Darkmists Setup", DarkmistsTheme.warnTag ..
      "You need to be connected to the game to set up Darkmists Companion.")
    -- Step stays idle: the player presses SET UP DMC again once connected.
    -- Nothing is scheduled on their behalf, so nothing pops up unrequested.
    return false
  end

  local generation = DarkmistsStartup.generation
  DarkmistsSetup.generation = generation
  stepUiChoice(generation)
  return true
end

return DarkmistsSetup
