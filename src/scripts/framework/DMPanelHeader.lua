-- ============================================================================
-- DMPanelHeader
-- ----------------------------------------------------------------------------
-- Reusable Geyser panel chrome: creates an Adjustable.Container tab panel with
-- a fixed interactive header bar (a live label/slot + button controls with
-- tooltips and hover styling) above a body console.
--
-- The header lives OUTSIDE the console, so it never scrolls away and is not
-- rebuilt when the body re-renders. This is the "next level" template for the
-- other tabbed windows (ChatHistory, ScorePanel, WhoWindow, ...).
--
-- Usage (flagship consumer: DMAffectsWindow):
--   local ph = DMPanelHeader.create("AffectsWindow", "Current Affects", "Affects", {
--     buttons = {
--       { key = "refresh", label = "Refresh", width = 78,
--         tooltip = "Refresh affects list",
--         onClick = function() send("affects") end },
--     },
--   })
--   ph.controls.age:echo("...")          -- live label (opts.age ~= false)
--   ph.console:setFont(...)             -- style the body console
--   DMPanelHeader.applyButtonStyle(ph.controls.refresh, true)  -- toggle state
-- ============================================================================

DMPanelHeader = {}

-- Create a tab panel with a fixed header strip + body console.
-- opts:
--   headerHeight  (px, default 26)
--   consoleColor  (Geyser color for the body console)
--   age           (default true) — add a stretchy live label slot at the left
--   buttons       array of { key, label, width (px), tooltip, onClick }
-- Returns handle:
--   { panel, layout, header, hbox, controls = { age?, <key> = btn... }, console }
function DMPanelHeader.create(id, title, tabName, opts)
  opts = opts or {}

  local panel = Darkmists.createTabPanel(id, title, tabName)

  -- Vertical stack: fixed header strip on top, body console filling the rest.
  local layout = Geyser.VBox:new({
    name = id .. "Layout",
    x = 0, y = 0,
    width = "100%", height = "100%",
  }, panel)

  local header = Geyser.Label:new({
    name = id .. "Header",
    height = opts.headerHeight or 26,
    v_policy = Geyser.Fixed,
  }, layout)
  header:setStyleSheet(DarkmistsTheme.buildHeaderStyle())

  -- Buttons / live label are laid out horizontally inside the strip.
  local hbox = Geyser.HBox:new({
    name = id .. "HeaderBox",
    x = 0, y = 0,
    width = "100%", height = "100%",
  }, header)

  local controls = {}

  if opts.age ~= false then
    controls.age = Geyser.Label:new({
      name = id .. "Age",
      h_stretch_factor = 4,
      font = opts.font or "",
      fontSize = opts.fontSize or 10,
    }, hbox)
    -- Transparent, vertically-centered text so it reads over the strip.
    controls.age:setStyleSheet(
      "background-color: rgba(0,0,0,0%); padding-left: 6px; qproperty-alignment: 'AlignVCenter | AlignLeft';")
  end

  for _, b in ipairs(opts.buttons or {}) do
    controls[b.key] = DMPanelHeader.makeButton(id, b, hbox, opts.font, opts.fontSize)
  end

  -- Body console: fills the layout below the header.
  local console = Geyser.MiniConsole:new({
    name = id .. "Console",
    x = 0, y = 0,
    width = "100%", height = "100%",
    color = opts.consoleColor or Darkmists.getDefaultBackgroundColor(),
  }, layout)

  local handle = {
    panel = panel,
    layout = layout,
    header = header,
    hbox = hbox,
    controls = controls,
    console = console,
  }
  DMPanelHeader.current = handle
  return handle
end

-- Build a header button label (fixed width, hover + active styling, tooltip).
-- b: { key, label, width (px, default 72), tooltip, onClick, color (optional
--     terminal accent hex used for the button's text/border) }
function DMPanelHeader.makeButton(id, b, parent, font, fontSize)
  local btn = Geyser.Label:new({
    name = id .. "_" .. b.key,
    autoWidth = true,
    h_policy = Geyser.Fixed,
    message = "<center>" .. b.label .. "</center>",
    font = font or "",
    fontSize = fontSize or 10,
    fgColor = b.color,
  }, parent)

  btn.defLabel = b.label
  btn.defColor = b.color
  btn._active = false

  if font then btn:setFont(font) end
  if fontSize then btn:setFontSize(fontSize) end

  if b.tooltip then
    btn:setToolTip(b.tooltip)
  end
  if b.onClick then
    btn:setClickCallback(b.onClick)
  end

  -- QSS can't recolor rich-text labels, so hover brightness is done through
  -- the label's fgColor: amber on enter, back to the accent on leave.
  btn:setOnEnter(function()
    if not btn._active then
      btn:setFgColor((DarkmistsTheme.panel or {}).buttonHoverFg or "#ffd27a")
    end
  end)
  btn:setOnLeave(function()
    if not btn._active then
      btn:setFgColor(btn.defColor)
    end
  end)

  DMPanelHeader.applyButtonStyle(btn, false)
  return btn
end

-- Rebuild a button's stylesheet from the current theme. `active` highlights
-- the button (e.g. a toggle that is currently on). Uses the button's own
-- accent color (btn.defColor) when set.
function DMPanelHeader.applyButtonStyle(btn, active)
  if not btn then return end
  btn._active = active
  btn:setStyleSheet(DarkmistsTheme.buildButtonStyle(active, btn.defColor))
  -- Rich-text labels ignore QSS `color`, so set the text color via fgColor:
  -- active = the bright-fill text color, inactive = the button's accent.
  local panel = DarkmistsTheme.panel or {}
  local textColor = active and (panel.buttonActiveFg or "#ffffff") or btn.defColor
  btn:setFgColor(textColor)
end

-- Rebuild the header strip + all buttons from the current theme.
-- Theme changes currently go through Darkmists.SafeReload(), which recreates
-- panels; this exists for future live-restyle wiring.
function DMPanelHeader.restyle(handle)
  if not handle then return end
  handle.header:setStyleSheet(DarkmistsTheme.buildHeaderStyle())
  for _, btn in pairs(handle.controls) do
    if btn and btn.setStyleSheet then
      DMPanelHeader.applyButtonStyle(btn, false)
    end
  end
end
