-- ===================================================================
-- Who Window - Player list tracker with age display
-- ===================================================================

WhoWindow = WhoWindow or {}

-- Configuration
WhoWindow.config = {
  fontSize = Darkmists.GlobalSettings.fontSize,
  fontName = Darkmists.GlobalSettings.fontName,
  deleteOriginalLines = true,
  lastUpdated = 0
}

-- State
WhoWindow.window = nil
WhoWindow.playerCount = 0
WhoWindow.tempBufferName = "WhoWindow_temp"

-- ===================================================================
-- WINDOW MANAGEMENT
-- ===================================================================

--- Create the Who window (only if it doesn't exist)
function WhoWindow.create()
  if WhoWindow.window then return end

  WhoWindow.window = Geyser.UserWindow:new({
    name = "WhoWindow",
    titleText = "Who List",
    docked = true,
    dockPosition = "top"
  })

  WhoWindow.window:setStyleSheet([[
    QWidget {
      background-color: black;
    }
    QDockWidget::title {
      background-color: #222;
      color: white;
      padding: 4px;
    }
  ]])

  WhoWindow.window:setFont(WhoWindow.config.fontName)
  WhoWindow.window:setFontSize(WhoWindow.config.fontSize)
  WhoWindow.window:enableScrolling()
  WhoWindow.window:enableScrollBar()
  WhoWindow.window:enableAutoWrap()

  cecho("\n<dim_gray>[<white>WhoWindow<dim_gray>] <green>Window created")
end

-- ===================================================================
-- DISPLAY FUNCTIONS
-- ===================================================================

--- Display header with player count and age
-- @param age number Seconds since last update
local function displayHeader(age)
  WhoWindow.window:cecho(string.format(
    "<green>Players Online: <white>%d <dim_gray>| <yellow>Age: <white>%ds\n\n",
    WhoWindow.playerCount,
    age
  ))
end

--- Copy all player lines from temp buffer to main window
local function copyPlayerLinesToWindow()
  local lineCount = getLineCount(WhoWindow.tempBufferName)
  if lineCount == 0 then return end
  
  for i = 0, lineCount - 1 do
    moveCursor(WhoWindow.tempBufferName, 0, i)
    selectCurrentLine(WhoWindow.tempBufferName)
    copy(WhoWindow.tempBufferName)
    appendBuffer("WhoWindow")
  end
  
  moveCursorEnd(WhoWindow.tempBufferName)
end

--- Update age display and refresh window
function WhoWindow.updateAge()
  if not WhoWindow.window or WhoWindow.config.lastUpdated == 0 then return end
  
  local secondsSinceUpdated = os.time() - WhoWindow.config.lastUpdated
  
  -- Rebuild display
  WhoWindow.window:clear()
  displayHeader(secondsSinceUpdated)
  copyPlayerLinesToWindow()
end

-- ===================================================================
-- CAPTURE LOGIC
-- ===================================================================

--- Append pending continuation line to last line in temp buffer
-- @param pendingLine string The continuation text to append
local function appendContinuationLine(pendingLine)
  moveCursorEnd(WhoWindow.tempBufferName)
  moveCursorUp(WhoWindow.tempBufferName, 1)
  selectCurrentLine(WhoWindow.tempBufferName)
  
  local prevLineSelection = getSelection(WhoWindow.tempBufferName)
  local prevLineNumber = getLineNumber(WhoWindow.tempBufferName)
  
  -- Move to end of previous line
  moveCursor(WhoWindow.tempBufferName, #prevLineSelection, prevLineNumber)
  
  cinsertText(WhoWindow.tempBufferName, pendingLine)
  moveCursorEnd(WhoWindow.tempBufferName)
end

--- Capture and display the player list
function WhoWindow.capturePlayerList()
  if not WhoWindow.window then return end
  
  -- Parse "Players found: N" line
  local numPlayers = line:match("^Players found: (.*)")
  if not numPlayers then return end
  
  numPlayers = tonumber(numPlayers)
  local currentLine = getLineNumber()
  
  -- Update state
  WhoWindow.config.lastUpdated = os.time()
  WhoWindow.playerCount = numPlayers
  
  -- Initialize temp buffer for formatted player lines
  if not exists(WhoWindow.tempBufferName, "buffer") then
    createBuffer(WhoWindow.tempBufferName)
  end
  clearWindow(WhoWindow.tempBufferName)
  
  -- Calculate lines to capture (header + 2 lines per player)
  local linesToCapture = 1 + (2 * numPlayers)
  local pendingLine = nil
  
  -- Process lines backward from current position
  for i = 1, linesToCapture do
    local targetLine = currentLine - i
    if targetLine >= 0 then
      moveCursor(0, targetLine)
      selectCurrentLine()
      local lineText = getCurrentLine()
      
      -- Skip blank lines
      if lineText:match("^%s*$") then
        if WhoWindow.config.deleteOriginalLines then
          deleteLine()
        end
        
      -- Player line starts with '['
      elseif lineText:match("^%[") then
        copy()
        appendBuffer(WhoWindow.tempBufferName)
        
        -- If we have a continuation line, append it
        if pendingLine then
          appendContinuationLine(pendingLine)
          pendingLine = nil
          
          if WhoWindow.config.deleteOriginalLines then
            deleteLine() -- Delete continuation line too
          end
        end
        
        if WhoWindow.config.deleteOriginalLines then
          deleteLine()
        end
        
      -- Continuation line (doesn't start with '[')
      else
        pendingLine = lineText
      end
    end
  end
  
  moveCursorEnd()
  
  -- Clean up original output
  if WhoWindow.config.deleteOriginalLines then
    replaceLine("")
    cecho("\n<dark_orange>Who List Captured.")
  end
  
  -- Display initial capture
  WhoWindow.window:clear()
  displayHeader(0)
  copyPlayerLinesToWindow()
end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================

--- Register trigger for "Players found:" line
function WhoWindow.registerTriggers()
  if WhoWindow.playersFoundTrigger then 
    killTrigger(WhoWindow.playersFoundTrigger) 
  end
  
  WhoWindow.playersFoundTrigger = tempTrigger(
    "Players found:",
    WhoWindow.capturePlayerList
  )
  
  cecho("\n<dim_gray>[<white>WhoWindow<dim_gray>] <green>Trigger registered")
end

--- Register prompt event handler for age updates
WhoWindow.promptHandler = registerAnonymousEventHandler(
  "dmapi.world.prompt",
  WhoWindow.updateAge
)

--- Initialize window and triggers
tempTimer(0.5, function()
  WhoWindow.create()
  WhoWindow.registerTriggers()
  cecho("\n<dim_gray>[<white>WhoWindow<dim_gray>] <green>Initialized!")
end)