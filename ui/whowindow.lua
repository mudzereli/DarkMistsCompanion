-- ===================================================================
-- Who Window - Player list tracker with age display
-- ===================================================================

WhoWindow = WhoWindow or {}

-- Configuration
WhoWindow.config = {
  fontSize = Darkmists.GlobalSettings.fontSize,
  fontName = Darkmists.GlobalSettings.fontName,
  deleteOriginalLines = Darkmists.GlobalSettings.whoWindowDeleteOriginalLines,
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

      x = Darkmists.getDefaultXPosition(),
      width = tostring(100 - Darkmists.GlobalSettings.mainWindowPanelWidth).."%",
      y = "40%",
      height = "30%",

      titleText = "Who List",
      titleTxtColor = Darkmists.getDefaultTextColor(),
      padding = 10,
      adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),

      lockStyle = "border",
      locked = false,
      autoSave = true,
      autoLoad = true
    })

  WhoWindow.console = Geyser.MiniConsole:new({
      name   = "WhoWindowConsole",
      x      = 0,
      y      = 0,
      width  = "100%",
      height = "100%",
      color  = Darkmists.getDefaultBackgroundColor(),
    }, WhoWindow.window)

  -- font + behavior
  WhoWindow.console:setFont(WhoWindow.config.fontName)
  WhoWindow.console:setFontSize(WhoWindow.config.fontSize)
  WhoWindow.console:enableAutoWrap()
  WhoWindow.console:enableScrollBar()

  -- attach & show
  WhoWindow.window:show()
  WhoWindow.window:raiseAll()
  Darkmists.Log("WhoWindow","Container Created!")
end

-- ===================================================================
-- DISPLAY FUNCTIONS
-- ===================================================================

--- Display header with player count and age
-- @param age number Seconds since last update
local function displayHeader(age)
  local disp
  if Darkmists.GlobalSettings.lightMode then
    disp = "<dark_green>Players Online: <black>%d <black>| <ansi_yellow>Age: <black>%ds\n\n"
  else
    disp = "<green:black>Players Online: <white>%d <dim_gray>| <light_goldenrod>Age: <white>%ds\n\n"
  end
  WhoWindow.console:cecho(string.format(
    disp,
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
local function getLastCharColors(win)
  -- select the whole line first so we know its length
  selectCurrentLine(win)
  local line = getSelection(win)
  if not line or line == "" then
    return nil
  end

  local lineNum = getLineNumber(win)
  local lastPos = #line

  -- select ONLY the last character
  selectSection(win, lastPos, lineNum, lastPos, lineNum)

  local fr, fg, fb = getFgColor(win)
  local br, bg, bb = getBgColor(win)

  return fr, fg, fb, br, bg, bb
end

local function rgbToHex(r, g, b)
  return string.format("%02x%02x%02x", r, g, b)
end

--- Append pending continuation line to last line in temp buffer
-- @param pendingLine string The continuation text to append
local function appendContinuationLine(pendingLine)
  moveCursorEnd(WhoWindow.tempBufferName)
  moveCursorUp(WhoWindow.tempBufferName, 1)
  selectCurrentLine(WhoWindow.tempBufferName)
  
  local prevLineSelection = getSelection(WhoWindow.tempBufferName)
  local prevLineNumber = getLineNumber(WhoWindow.tempBufferName)
  
  local t = WhoWindow.tempBufferName
  selectSection(t,#getCurrentLine(t)-1,1)
  local fr, fg, fb = getFgColor(t)
  local br, bg, bb = getBgColor(t)
  local f = string.format("%02X%02X%02X", fr, fg, fb)
  local b = string.format("%02X%02X%02X", br, bg, bb)

  -- Move to end of previous line
  moveCursor(WhoWindow.tempBufferName, #prevLineSelection, prevLineNumber)
  
  local txt = ("#%s,%s %s"):format(f,b,pendingLine)
  hinsertText(WhoWindow.tempBufferName, txt)
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
    cecho("\n<coral>Who List Captured.")
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
  
  Darkmists.Log("WhoWindow","Trigger Registered")
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
  Darkmists.Log("WhoWindow","Initialized")
end)