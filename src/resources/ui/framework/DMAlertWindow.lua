-- DMAlertWindow: lightweight centered alert panel (header + close + body)
DMAlertWindow = DMAlertWindow or {}

local panel = {}

local function ensure_init()
  if panel.inited then return end

  panel.border = "dmalert_border"
  panel.header = "dmalert_header"
  panel.close  = "dmalert_close"
  panel.body   = "dmalert_body"

  createMiniConsole(panel.border, 0,0,1,1)
  disableScrolling(panel.border)
  createMiniConsole(panel.header, 0,0,1,1)
  disableScrolling(panel.header)
  createMiniConsole(panel.close, 0,0,1,1)
  disableScrolling(panel.close)
  createMiniConsole(panel.body, 0,0,1,1)
  disableScrolling(panel.body)

  panel.w = 640
  panel.h = 300
  panel.headerH = 30
  panel.borderSize = 6

  -- sensible defaults; consumers may override by providing opts
  setMiniConsoleFontSize(panel.header, 14)
  setMiniConsoleFontSize(panel.close, 14)
  panel.bodyFontSize = 12
  setMiniConsoleFontSize(panel.body, panel.bodyFontSize)

  setBackgroundColor(panel.border, 24,24,24)
  setBackgroundColor(panel.header, 40,40,40)
  setBackgroundColor(panel.close, 40,40,40)
  setBackgroundColor(panel.body, 18,18,18)

  setFgColor(panel.header, 255,255,255)
  setFgColor(panel.close, 255,128,128)
  setFgColor(panel.body, 220,220,220)

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

  local w = opts.width or panel.w
  local h = opts.height or panel.h
  local headerH = opts.headerH or panel.headerH
  local borderSize = opts.borderSize or panel.borderSize

  local winW, winH = getMainWindowSize()
  local borders = getBorderSizes()
  local left = borders.left or 0
  local right = borders.right or 0
  local top = borders.top or 0
  local bottom = borders.bottom or 0

  local usableW = math.max(0, winW - left - right)
  local usableH = math.max(0, winH - top - bottom)

  if w > usableW then w = usableW end
  if h > usableH then h = usableH end

  local px = left + math.floor((usableW - w) / 2)
  local py = top + math.floor((usableH - h) / 2)

  resizeWindow(panel.border, w, h)
  resizeWindow(panel.header, w - (borderSize*2), headerH)
  resizeWindow(panel.close, 44, headerH)
  resizeWindow(panel.body, w - (borderSize*2), h - headerH - (borderSize*2))

  moveWindow(panel.border, px, py)
  moveWindow(panel.header, px + borderSize, py + borderSize)
  moveWindow(panel.close, px + w - borderSize - 44, py + borderSize)
  moveWindow(panel.body, px + borderSize, py + borderSize + headerH)

  -- Recalculate wrap columns for the body based on the resized pixel width
  local bodyPixelWidth = (w - (borderSize * 2))
  local bodyFontSize = opts.bodyFontSize or panel.bodyFontSize or 12
  setMiniConsoleFontSize(panel.body, bodyFontSize)
  local charWidth = select(1, calcFontSize(bodyFontSize)) or 8
  if charWidth <= 0 then charWidth = 8 end
  local wrapAt = math.max(20, math.floor(bodyPixelWidth / charWidth) - 2)
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
end

return DMAlertWindow
