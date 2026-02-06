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
-- ===================================================================
-- WINDOW MANAGEMENT (Adjustable.Container)
-- ===================================================================

function WhoWindow.create()
  if WhoWindow.window and WhoWindow.console then return end

  WhoWindow.window = Adjustable.Container:new({
      name = "WhoWindow",

      x = tostring(Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
      width = tostring(100 - Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
      y = "0%",
      height = "33.33%",

      titleText = "Who List",
      titleTxtColor = "white",
      padding = 10,
      adjLabelstyle = [[
        background-color: #111111;
        border: 2px solid #666666;
      ]],

      lockStyle = "border",
      locked = false,
      autoSave = true,
      autoLoad = true,
    })

  WhoWindow.console = Geyser.MiniConsole:new({
      name   = "WhoWindowConsole",
      x      = 0,
      y      = 0,
      width  = "100%",
      height = "100%",
      color  = "black",
    }, WhoWindow.window)

  -- font + behavior
  WhoWindow.console:setFont(WhoWindow.config.fontName)
  WhoWindow.console:setFontSize(WhoWindow.config.fontSize)
  WhoWindow.console:enableAutoWrap()
  WhoWindow.console:enableScrollBar()

  -- attach & show
  WhoWindow.window:show()
  WhoWindow.window:raiseAll()

  cecho("\n<dim_gray>[<white>WhoWindow<dim_gray>] <green>Container created")
end

-- ===================================================================
-- DISPLAY FUNCTIONS
-- ===================================================================

--- Display header with player count and age
-- @param age number Seconds since last update
local function displayHeader(age)
  WhoWindow.console:cecho(string.format(
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
    appendBuffer("WhoWindowConsole")
  end
  
  moveCursorEnd(WhoWindow.tempBufferName)
end

--- Update age display and refresh window
function WhoWindow.updateAge()
  if not WhoWindow.window or WhoWindow.config.lastUpdated == 0 then return end
  
  local secondsSinceUpdated = os.time() - WhoWindow.config.lastUpdated
  
  -- Rebuild display
  WhoWindow.console:clear()
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
  WhoWindow.console:clear()
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