-- ===================================================================
-- Who Window - Player list tracker with age display
--
-- This module captures the output of the in-game "who" command,
-- stores the most recent player entries and the time they were
-- collected, and renders a small scrollable UI showing the
-- player list along with an "age" (seconds since last update).
-- ===================================================================
WhoWindow = {}

--[[
  WhoWindow responsibilities:
  - Register a trigger to capture the "Players found: N" line
  - Walk back through the scrollback to collect the printed player
    lines (preserving color formatting) and keep them in `WhoWindow.lines`
  - Render a compact UI with a clickable Refresh link and an age counter
]]

-- Configuration
WhoWindow.config = {}

-- State
WhoWindow.lines = {}                      -- array of formatted player lines
WhoWindow.window = nil                    -- container tab panel
WhoWindow.header = nil                    -- fixed header strip label
WhoWindow.headerBox = nil                 -- header HBox (for reflow)
WhoWindow.controls = nil                  -- header controls (age label, buttons)
WhoWindow.console = nil                   -- Geyser.MiniConsole instance
WhoWindow.playerCount = 0                 -- last captured player count

-- ===================================================================
-- WINDOW MANAGEMENT
-- ===================================================================

--- Create the Who window (only if it doesn't exist)
function WhoWindow.create()
  -- avoid recreating UI if already present
  if WhoWindow.window and WhoWindow.console then return end

  -- Fixed interactive header (live Players Online + Age label and a Refresh
  -- button) above the scrollable player-list console, using the same
  -- DMPanelHeader template as the Affects window.
  local panelColors = DarkmistsTheme.panel or {}

  local ph = DMPanelHeader.create("WhoWindow", "Who List", "Who", {
    consoleColor = Darkmists.getDefaultBackgroundColor(),
    font = WhoWindow.config.fontName,
    fontSize = WhoWindow.config.fontSize,
    buttons = {
      { key = "refresh", label = "Refresh", marginX = 1, marginR = 4,
        color = panelColors.buttonRefreshColor or "#a78bfa",
        tooltip = "Refresh player list",
        onClick = function() send("who") end },
    },
  })

  WhoWindow.window    = ph.panel
  WhoWindow.header    = ph.header
  WhoWindow.headerBox = ph.hbox
  WhoWindow.controls  = ph.controls
  WhoWindow.console   = ph.console

  -- configure fonts and behavior for readability
  WhoWindow.console:setFont(WhoWindow.config.fontName)
  WhoWindow.console:setFontSize(WhoWindow.config.fontSize)
  WhoWindow.console:enableAutoWrap()
  WhoWindow.console:enableScrollBar()

  -- show the window and make sure it is visible to the user
  WhoWindow.window:show()
  WhoWindow.window:raiseAll()
  Darkmists.Log("WhoWindow", "Container Created!")
end

--- Destroy the Who window and its trigger state during UI cleanup/reload.
function WhoWindow.destroy()
  if WhoWindow.playersFoundTrigger then
    pcall(killTrigger, WhoWindow.playersFoundTrigger)
    WhoWindow.playersFoundTrigger = nil
  end

  if WhoWindow.console and WhoWindow.console.delete then
    pcall(WhoWindow.console.delete, WhoWindow.console)
  end
  WhoWindow.console = nil

  if WhoWindow.window and WhoWindow.window.delete then
    pcall(WhoWindow.window.delete, WhoWindow.window)
  end
  WhoWindow.window = nil
  WhoWindow.header = nil
  WhoWindow.headerBox = nil
  WhoWindow.controls = nil

  WhoWindow.lines = {}
  WhoWindow.playerCount = 0
  WhoWindow.config.lastUpdated = 0
end

-- ===================================================================
-- DISPLAY FUNCTIONS
-- ===================================================================

--- Update the fixed header (live Players Online + Age label) without
-- touching the console. Called after capture and on every prompt tick so
-- the age stays current without rebuilding the whole player list.
function WhoWindow.updateHeader()
  if not WhoWindow.controls then return end

  local ageLabel = WhoWindow.controls.age
  if not ageLabel then return end

  local infoHex = cecho2hecho("<" .. DarkmistsTheme.info .. ">") or "#ffffff"
  local goodHex = cecho2hecho("<" .. DarkmistsTheme.good .. ">") or "#7ee787"
  local dimHex  = cecho2hecho("<" .. DarkmistsTheme.muted .. ">") or "#8a8a8a"

  local age = os.time() - (WhoWindow.config.lastUpdated or os.time())
  ageLabel:echo(
    ("<span style='color:%s;'><b>Players Online: %d</b></span> <span style='color:%s;'>|</span> <span style='color:%s;'><b>Age: %ds</b></span>")
    :format(infoHex, WhoWindow.playerCount or 0, dimHex, goodHex, age))
end

--- Update age display and refresh window
-- Called by prompt / periodic events so the age shown stays current
function WhoWindow.updateAge()
  if not WhoWindow.window or WhoWindow.config.lastUpdated == 0 then return end
  WhoWindow.updateHeader()
end

--- Capture and display the player list
-- This function is intended as the trigger handler for the line
-- matching "Players found: N". It walks back through the scrollback
-- to capture the earlier printed, formatted player lines.
function WhoWindow.capturePlayerList()

  -- match the trigger context for the players found count
  local numPlayers = line:match("^Players found:%s*(%d+)")
  if not numPlayers then return end

  numPlayers = tonumber(numPlayers)

  -- update state metadata
  WhoWindow.playerCount = numPlayers
  WhoWindow.config.lastUpdated = os.time()

  -- clear any previously captured lines
  WhoWindow.lines = {}

  -- walk backwards from the current line to collect the printed player lines
  local current = getLineNumber()
  local headers = 0
  local i = 1

  -- iterate backwards until we've found `numPlayers` entries or a safety limit
  while headers < numPlayers and i < 999 do

    local target = current - i
    if target < 0 then break end

    moveCursor(0, target)
    local text = getCurrentLine()

    -- detect player entry lines by their bracketed prefix (e.g. [rank])
    if text:match("^%[[^%]]+%]") then
      headers = headers + 1

      -- copy the formatted line (colors preserved) into our list
      selectCurrentLine()
      table.insert(WhoWindow.lines, 1, copy2decho())
    end

    i = i + 1
  end

  -- refresh UI after capture
  WhoWindow.updateHeader()
  WhoWindow.render()

end

--- Render collected data into the mini console
function WhoWindow.render()
  -- if we've never captured data, there is nothing to render
  if WhoWindow.config.lastUpdated == 0 then return end
  
  WhoWindow.console:clear()

  -- render each captured, formatted entry line
  for _, entry in ipairs(WhoWindow.lines) do
    WhoWindow.console:decho(entry .. "\n")
  end

end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
--- Register trigger for "Players found:" line
function WhoWindow.registerTriggers()
  -- remove existing trigger if present to avoid duplicates
  if WhoWindow.playersFoundTrigger then
    killTrigger(WhoWindow.playersFoundTrigger)
  end

  -- temporary trigger that fires when the server prints the players count
  WhoWindow.playersFoundTrigger = tempTrigger(
    "Players found:",
    WhoWindow.capturePlayerList
  )

  Darkmists.Log("WhoWindow", "Trigger Registered")
end

--- Initialize the Who window module.
-- This sets config defaults and performs the runtime side effects.
function WhoWindow.init()
  -- font settings pulled from global configuration for consistent UI
  WhoWindow.config.fontSize = Darkmists.GlobalSettings.fontSize
  WhoWindow.config.fontName = Darkmists.GlobalSettings.fontName

  -- whether to delete the original who lines from the main window
  WhoWindow.config.deleteOriginalLines = Darkmists.GlobalSettings.whoWindowDeleteOriginalLines

  -- timestamp (os.time) of the last successful capture; 0 == never
  WhoWindow.config.lastUpdated = WhoWindow.config.lastUpdated or 0

  WhoWindow.create()
  WhoWindow.registerTriggers()

  DarkmistsEvents.add("WhoWindowPromptHandler", "dmapi.world.prompt", WhoWindow.updateAge)
  DarkmistsEvents.add("WhoWindowResize","sysWindowResizeEvent",
    function()
      if WhoWindow.window and WhoWindow.config.lastUpdated ~= 0 then
        WhoWindow.render()
      end
    end
  )

  Darkmists.Log("WhoWindow", "Initialized")
end
