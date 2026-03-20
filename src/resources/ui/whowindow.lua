-- ===================================================================
-- Who Window - Player list tracker with age display
--
-- This module captures the output of the in-game "who" command,
-- stores the most recent player entries and the time they were
-- collected, and renders a small scrollable UI showing the
-- player list along with an "age" (seconds since last update).
-- ===================================================================
WhoWindow = WhoWindow or {}

--[[
  WhoWindow responsibilities:
  - Register a trigger to capture the "Players found: N" line
  - Walk back through the scrollback to collect the printed player
    lines (preserving color formatting) and keep them in `WhoWindow.lines`
  - Render a compact UI with a clickable Refresh link and an age counter
]]

-- Configuration
WhoWindow.config = {
  -- font settings pulled from global configuration for consistent UI
  fontSize = Darkmists.GlobalSettings.fontSize,
  fontName = Darkmists.GlobalSettings.fontName,
  -- whether to delete the original who lines from the main window
  deleteOriginalLines = Darkmists.GlobalSettings.whoWindowDeleteOriginalLines,
  -- timestamp (os.time) of the last successful capture; 0 == never
  lastUpdated = 0
}

-- State
WhoWindow.lines = WhoWindow.lines or {}   -- array of formatted player lines
WhoWindow.window = nil                    -- container tab panel
WhoWindow.console = nil                   -- Geyser.MiniConsole instance
WhoWindow.playerCount = 0                 -- last captured player count

-- ===================================================================
-- WINDOW MANAGEMENT
-- ===================================================================

--- Create the Who window (only if it doesn't exist)
function WhoWindow.create()
  -- avoid recreating UI if already present
  if WhoWindow.window and WhoWindow.console then return end

  -- create a tabbed panel that will host the mini console
  WhoWindow.window = Darkmists.createTabPanel("WhoWindow", "Who List", "Who")

  -- MiniConsole is used for small read-only, scrollable text output
  WhoWindow.console = Geyser.MiniConsole:new({
      name   = "WhoWindowConsole",
      x      = "1%",
      y      = "1%",
      width  = "98%",
      height = "98%",
      color  = Darkmists.getDefaultBackgroundColor(),
    }, WhoWindow.window)

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

-- ===================================================================
-- DISPLAY FUNCTIONS
-- ===================================================================

--- Display header with player count and age
-- @param age number Seconds since last update
local function displayHeader(age)
  -- choose colorized template based on global light/dark setting
  WhoWindow.console:cecho(string.format(
    "%sPlayers Online: %s%d %s| %sAge: %s%ds %s| ",
    DarkmistsTheme.goodTag,
    DarkmistsTheme.infoTag,
    WhoWindow.playerCount,
    DarkmistsTheme.textTag,
    DarkmistsTheme.highlightTag,
    DarkmistsTheme.textTag,
    age,
    DarkmistsTheme.textTag
  ))
  resetFormat()

  WhoWindow.console:cechoLink(
    DarkmistsTheme.textTag .. "<u>[Refresh]",
    function() send("who") end,
    "Refresh player list",
    true
  )

  -- spacing between header and entries
  WhoWindow.console:cecho("\n\n")
end

--- Update age display and refresh window
-- Called by prompt / periodic events so the age shown stays current
function WhoWindow.updateAge()
  if not WhoWindow.window or WhoWindow.config.lastUpdated == 0 then return end
  WhoWindow.render()
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
  WhoWindow.render()

end

--- Render collected data into the mini console
function WhoWindow.render()
  -- if we've never captured data, there is nothing to render
  if WhoWindow.config.lastUpdated == 0 then return end
  
  WhoWindow.console:clear()

  -- compute age (seconds since last capture) and render header
  local age = os.time() - WhoWindow.config.lastUpdated
  displayHeader(age)

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

--- Register prompt event handler for age updates
-- We update the age display on each prompt so the counter remains accurate
DarkmistsEvents.add("WhoWindowPromptHandler", "dmapi.world.prompt", WhoWindow.updateAge)
DarkmistsEvents.add("WhoWindowResize","sysWindowResizeEvent",
  function()
    if WhoWindow.window and WhoWindow.config.lastUpdated ~= 0 then
      WhoWindow.render()
    end
  end
)

--- Initialize window and triggers
WhoWindow.create()
WhoWindow.registerTriggers()
Darkmists.Log("WhoWindow", "Initialized")
