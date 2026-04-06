-- DMAlertWindow: lightweight centered alert panel (header + close + body)
DMAlertWindow = {}

local panel    = {}   -- internal UI state and default dimensions
local _queue   = {}   -- pending alerts waiting to be shown
local _current = nil  -- opts table for the currently-displayed alert

local function _applyTheme()
  local light = Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings.lightMode
  if light then
    setBackgroundColor(panel.border, 210,210,210)
    setBackgroundColor(panel.header, 190,190,190)
    setBackgroundColor(panel.close,  190,190,190)
    setBackgroundColor(panel.body,   235,235,235)
    setFgColor(panel.header, 30,30,30)
    setFgColor(panel.close,  160,30,30)
    setFgColor(panel.body,   40,40,40)
  else
    setBackgroundColor(panel.border, 24,24,24)
    setBackgroundColor(panel.header, 40,40,40)
    setBackgroundColor(panel.close,  40,40,40)
    setBackgroundColor(panel.body,   18,18,18)
    setFgColor(panel.header, 255,255,255)
    setFgColor(panel.close,  255,128,128)
    setFgColor(panel.body,   220,220,220)
  end
end

local function ensure_init()
  if panel.inited then return end

  panel.border = "dmalert_border"
  panel.header = "dmalert_header"
  panel.close  = "dmalert_close"
  panel.body   = "dmalert_body"

  createMiniConsole(panel.border, 0, 0, 1, 1)
  disableScrolling(panel.border)
  createMiniConsole(panel.header, 0, 0, 1, 1)
  disableScrolling(panel.header)
  createMiniConsole(panel.close, 0, 0, 1, 1)
  disableScrolling(panel.close)
  createMiniConsole(panel.body, 0, 0, 1, 1)
  disableScrolling(panel.body)

  -- Default panel dimensions; consumers may override via opts
  panel.w            = 640
  panel.h            = 300
  panel.headerH      = 30
  panel.borderSize   = 6
  panel.bodyFontSize = 12

  setMiniConsoleFontSize(panel.header, 14)
  setMiniConsoleFontSize(panel.close, 14)
  setMiniConsoleFontSize(panel.body, panel.bodyFontSize)

  _applyTheme()

  setWindowWrap(panel.body, 80)

  hideWindow(panel.border)
  hideWindow(panel.header)
  hideWindow(panel.close)
  hideWindow(panel.body)

  panel.inited = true
end

function DMAlertWindow.Show(title, renderFunc, opts)
  ensure_init()
  opts = opts or {}

  -- Queue if an alert is already visible
  if _current then
    table.insert(_queue, { title = title, render = renderFunc, opts = opts })
    return
  end

  -- Track current alert so Hide() can call its onClose hook
  _current = opts

  _applyTheme()

  local w = opts.width or panel.w
  local h = opts.height or panel.h
  local headerH = opts.headerH or panel.headerH
  local borderSize = opts.borderSize or panel.borderSize

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

  resizeWindow(panel.border, w, h)
  resizeWindow(panel.header, w - (borderSize*2), headerH)
  resizeWindow(panel.close, 44, headerH)
  resizeWindow(panel.body, w - (borderSize*2), h - headerH - (borderSize*2))

  moveWindow(panel.border, px,                       py)
  moveWindow(panel.header, px + borderSize,          py + borderSize)
  moveWindow(panel.close,  px + w - borderSize - 44, py + borderSize)
  moveWindow(panel.body,   px + borderSize,          py + borderSize + headerH)

  -- Recalculate wrap column from actual pixel width and font metrics
  local bodyFontSize = opts.bodyFontSize or panel.bodyFontSize
  setMiniConsoleFontSize(panel.body, bodyFontSize)
  local charWidth = calcFontSize(bodyFontSize) or 8  -- calcFontSize returns charW, charH
  if charWidth <= 0 then charWidth = 8 end
  local wrapAt = math.max(20, math.floor((w - borderSize * 2) / charWidth) - 2)
  setWindowWrap(panel.body, wrapAt)

  clearWindow(panel.header)
  cecho(panel.header, string.format("<cadet_blue>%s", tostring(title or "Alert")))

  clearWindow(panel.close)
  cechoLink(panel.close, "<dim_gray><u>[<red>X<dim_gray>]", [[DMAlertWindow.Hide()]], "Close", true)

  clearWindow(panel.body)
  if type(renderFunc) == "function" then
    renderFunc(panel.body)
  elseif type(renderFunc) == "string" then
    cecho(panel.body, renderFunc)
  end

  showWindow(panel.border)
  showWindow(panel.header)
  showWindow(panel.close)
  showWindow(panel.body)
end

function DMAlertWindow.Hide()
  if not panel.inited then return end
  hideWindow(panel.body)
  hideWindow(panel.header)
  hideWindow(panel.close)
  hideWindow(panel.border)

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

return DMAlertWindow
