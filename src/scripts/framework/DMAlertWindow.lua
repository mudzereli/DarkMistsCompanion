-- ============================================================================
-- DMAlertWindow
-- ----------------------------------------------------------------------------
-- Movable retro-styled alert panel built on Adjustable.Container.
-- Drag by the title bar to move; close via the [X]. The DMAlertWindow API
-- (Show / Hide / ScheduleAlert + sizing helpers) is unchanged, so existing
-- callers that render into the passed console name keep working untouched.
-- ============================================================================
DMAlertWindow = {}

local panel    = {}   -- internal UI state and default dimensions
local _queue   = {}   -- pending alerts waiting to be shown
local _current = nil  -- opts table for the currently-displayed alert

-- Default dimensions; consumers may override via opts
panel.w            = 640
panel.h            = 300
panel.headerH      = 30      -- title bar estimate (sizing helper)
panel.borderSize   = 6       -- chrome padding estimate (sizing helper)
panel.bodyFontSize = 12
panel.title        = "Alert"

-- ---------------------------------------------------------------------------
-- Theming (retro-terminal)
-- ---------------------------------------------------------------------------
local function _applyTheme()
  if not panel.container then return end

  local light = Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings.lightMode
  local p = (DarkmistsTheme and DarkmistsTheme.panel) or {}

  local adjStyle, exitStyle, titleColor, bodyColor
  if light then
    adjStyle = [[
QLabel {
  background-color: rgb(244,241,250);
  border: 1px solid rgb(210,198,235);
  border-bottom: 2px solid rgb(100,70,190);
  border-radius: 0px;
}]]
    exitStyle = [[
QLabel { color: #c22; background-color: rgba(255,230,230,70%); border: 1px solid rgba(200,60,60,50%); border-radius: 0px; font-weight: bold; qproperty-alignment: 'AlignVCenter | AlignCenter'; }
QLabel:hover { background-color: rgb(255,215,215); border-color: rgb(180,50,50); }
]]
    titleColor = "#202020"
    bodyColor = { 235, 235, 235 }
  else
    adjStyle = [[
QLabel {
  background-color: rgba(20,10,40,92%);
  border: 1px solid rgba(150,120,255,30%);
  border-bottom: 2px solid rgba(150,120,255,55%);
  border-radius: 0px;
}]]
    exitStyle = [[
QLabel { color: #ff6b6b; background-color: rgba(40,10,10,80%); border: 1px solid rgba(255,90,90,40%); border-radius: 0px; font-weight: bold; qproperty-alignment: 'AlignVCenter | AlignCenter'; }
QLabel:hover { background-color: rgba(255,90,90,25%); border-color: rgba(255,120,110,70%); }
]]
    titleColor = "#e0d6ff"
    bodyColor = { 18, 18, 18 }
  end

  panel.container.adjLabel:setStyleSheet(adjStyle)
  panel.container.exitLabel:setStyleSheet(exitStyle)
  panel.container.minimizeLabel:setStyleSheet(exitStyle)
  panel.container:setTitle(nil, titleColor)
  panel.body:setColor(unpack(bodyColor))
end

local function ensure_init()
  if panel.inited then return end

  panel.container = Adjustable.Container:new({
    name = "dmalert_container",
    autoLoad = false,
    autoSave = false,
    -- Small content padding; the body is positioned below the title bar in
    -- Show() so it never overlaps it.
    titleText = panel.title,
    padding = 6,
    buttonsize = 18,
    buttonFontSize = 11,
  })
  -- Larger, readable title bar text.
  panel.container.adjLabel:setFontSize(14)

  panel.body = Geyser.MiniConsole:new({
    name = "dmalert_body",
    x = 0, y = 0,
    width = "100%", height = "100%",
  }, panel.container)
  panel.body:setFont(getFont())
  panel.body:setFontSize(panel.bodyFontSize)
  panel.body:disableScrollBar()
  panel.body:disableScrolling()

  -- Keep only the close button for a clean, alert-like title bar.
  panel.container.minimizeLabel:hide()

  -- Retro red close button. QSS color can't recolor rich-text labels, so the
  -- red comes from the echoed span; the stylesheet adds the border + hover.
  panel.container.exitLabel:setFontSize(12)
  panel.container.exitLabel:setAlignment("c")
  panel.container.exitLabel:echo("<center><span style='color:#ff6b6b;'><b>✕</b></span></center>")
  -- Make the close button a full-title-bar-height square anchored in the top
  -- corner, and update the stored geometry so Adjustable keeps this placement
  -- on subsequent repositions.
  local btnW = panel.container.buttonsize + 8
  local btnH = panel.container.buttonsize + 10   -- title bar height
  panel.container.exitLabel.width  = btnW
  panel.container.exitLabel.height = btnH
  panel.container.exitLabel.x = -btnW   -- flush against the far right corner
  panel.container.exitLabel.y = 0
  panel.container.exitLabel:resize(btnW, btnH)
  panel.container.exitLabel:move(panel.container.exitLabel.x, panel.container.exitLabel.y)
  panel.container.exitLabel:setClickCallback(function() DMAlertWindow.Hide() end)

  _applyTheme()
  panel.container:hide()
  panel.inited = true

  if DMLogger then
    DMLogger.log("DMAlertWindow", "Loaded!")
  end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function DMAlertWindow.Show(title, renderFunc, opts)
  ensure_init()
  opts = opts or {}

  -- Queue if an alert is already visible
  if _current then
    table.insert(_queue, { title = title, render = renderFunc, opts = opts })
    return
  end

  _current = opts
  panel.title = tostring(title or "Alert")

  _applyTheme()
  panel.container:setTitle(panel.title)

  local w = opts.width or panel.w
  local h = opts.height or panel.h

  -- Constrain to the usable window area (respecting UI borders)
  local winW, winH = getMainWindowSize()
  local borders    = getBorderSizes()
  local left   = borders.left   or 0
  local right  = borders.right  or 0
  local top    = borders.top    or 0
  local bottom = borders.bottom or 0

  local usableW = math.max(0, winW - left - right)
  local usableH = math.max(0, winH - top - bottom)

  w = math.min(w, usableW)
  h = math.min(h, usableH)

  local px = left + math.floor((usableW - w) / 2)
  local py = top + math.floor((usableH - h) / 2)

  panel.container:resize(w, h)
  panel.container:move(px, py)

  -- Fit the body tightly to the content area: start below the title bar and
  -- keep only a small padding margin on the other three sides. The stored
  -- geometry is updated too so Adjustable's reposition keeps this until the
  -- next Show.
  local titleBarH = panel.container.buttonsize + 10
  local pad = panel.container.padding
  panel.container.Inside.x = pad
  panel.container.Inside.y = titleBarH
  panel.container.Inside.width = w - pad * 2
  panel.container.Inside.height = h - titleBarH - pad
  panel.container.Inside:move(pad, titleBarH)
  panel.container.Inside:resize(w - pad * 2, h - titleBarH - pad)

  -- Body font + wrap computed from the actual pixel width
  local bodyFontSize = opts.bodyFontSize or panel.bodyFontSize
  panel.body:setFontSize(bodyFontSize)
  local charWidth = calcFontSize(bodyFontSize) or 8  -- calcFontSize returns charW, charH
  if charWidth <= 0 then charWidth = 8 end
  local wrapAt = math.max(20, math.floor((w - panel.container.padding * 2) / charWidth) - 2)
  setWindowWrap(panel.body.name, wrapAt)

  if opts.scrollable then
    panel.body:enableScrollBar()
    panel.body:enableScrolling()
  else
    panel.body:disableScrollBar()
    panel.body:disableScrolling()
  end

  panel.body:clear()
  if type(renderFunc) == "function" then
    renderFunc(panel.body.name)
  elseif type(renderFunc) == "string" then
    cecho(panel.body.name, renderFunc)
  end

  panel.container:show()
  panel.container:raiseAll()
end

function DMAlertWindow.Hide()
  if not panel.inited then return end
  panel.container:hide()

  -- Run onClose hook if supplied (pcall so callback errors don't break the queue)
  if _current and type(_current.onClose) == "function" then
    pcall(_current.onClose)
  end

  -- Show next queued alert on next tick to avoid re-entrancy
  _current = nil
  if #_queue > 0 then
    local nextAlert = table.remove(_queue, 1)
    tempTimer(0, function()
      DMAlertWindow.Show(nextAlert.title, nextAlert.render, nextAlert.opts)
    end)
  end
end

-- Schedule an alert explicitly (alias for Show but kept for clarity)
function DMAlertWindow.ScheduleAlert(title, renderFunc, opts)
  return DMAlertWindow.Show(title, renderFunc, opts)
end

-- Tear down the Geyser container on unload (reload safety)
function DMAlertWindow.destroy()
  if panel.container and panel.container.delete then
    pcall(panel.container.delete, panel.container)
  end
  panel.container = nil
  panel.body = nil
  panel.inited = false
  _current = nil
  _queue = {}
end

-- Expose panel dimensions so content sizing can derive from the actual config
function DMAlertWindow.getBodyFontSize()
  ensure_init()
  return panel.bodyFontSize
end

function DMAlertWindow.getChromeHeight()
  ensure_init()
  return (panel.container.buttonsize or 16) + 10 + panel.container.padding * 2
end

function DMAlertWindow.getBorderPx()
  ensure_init()
  return panel.container.padding * 2
end

return DMAlertWindow
