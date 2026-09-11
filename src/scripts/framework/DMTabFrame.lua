DMTabFrame = {
  container = nil,
  tabs = nil,
}

-- Tab font is a user setting (Settings Panel -> Appearance -> Tab font); its
-- default and accepted range live in DMConstants so they cannot drift from the
-- Settings Panel entry. The tab bar height is derived from the font so labels
-- always fit and no runtime size guessing is needed.
local TAB_LABEL_PADDING_PX = 3
-- Extra vertical room on top of the measured glyph height: the label's padding
-- is in the stylesheet, the active tab carries a 3px top border, plus slop.
local TAB_BAR_CHROME_PX = 12

local function clamp(v, minv, maxv)
  return math.max(minv, math.min(maxv, v))
end

-- Delete a Geyser object if it exposes delete(), tolerating teardown errors:
-- UI objects may already be gone or mid-callback during a reload.
local function safe_delete(obj)
  if obj and obj.delete then pcall(obj.delete, obj) end
end

-- Returns the configured tab label font size and the tab bar height that fits it.
-- The glyph height is measured rather than assumed: a flat fontPx + constant
-- allowance starts clipping the moment the font outgrows the label's padding.
local function tab_metrics()
  local settings = Darkmists.GlobalSettings or {}
  local fontPx = clamp(
    math.floor(tonumber(settings.tabFontSize) or DMConstants.TAB_FONT_DEFAULT_PX),
    DMConstants.TAB_FONT_MIN_PX, DMConstants.TAB_FONT_MAX_PX)

  local charHeight
  if type(calcFontSize) == "function" then
    local ok, _, height = pcall(calcFontSize, fontPx)
    if ok and type(height) == "number" and height > 0 then
      charHeight = math.ceil(height)
    end
  end
  charHeight = charHeight or math.ceil(fontPx * 1.5)

  return fontPx, charHeight + (TAB_LABEL_PADDING_PX * 2) + TAB_BAR_CHROME_PX
end

local function build_tab_styles()
  local p = (DarkmistsTheme and DarkmistsTheme.panel) or {}

  -- Tab chrome mirrors DMPanelHeader: inactive tabs read like panel buttons,
  -- the active tab is the solid panel purple with a gold accent line.
  local inactiveBg     = p.buttonBg or "rgba(12,6,26,35%)"
  local inactiveBorder = p.buttonBorder or "rgba(150,120,255,25%)"
  local hoverBg        = p.buttonHoverBg or "rgba(150,120,255,16%)"
  local hoverBorder    = p.headerAccent or "rgba(150,120,255,45%)"
  local activeBg       = p.buttonActiveBg or "#7a5cff"
  local accent         = p.tabAccent or "#ffd27a"

  -- Rules shared by both states: 1px side gaps, a padded box, centred label.
  -- NOTE: no `color` here. Rich-text labels ignore the QSS colour property, so
  -- activate/deactivate push the text colour through the label's fgColor
  -- instead - the same reason DMPanelHeader.applyButtonStyle calls setFgColor.
  local chrome = string.format(
    "    margin-left: 1px; margin-right: 1px;\n    padding: %dpx;\n    qproperty-alignment: 'AlignCenter';\n",
    TAB_LABEL_PADDING_PX)

  local inactiveStyle = string.format([[
  QLabel {
    background-color: %s;
    border: 1px solid %s;
%s  }
  QLabel:hover {
    background-color: %s;
    border: 1px solid %s;
  }
]], inactiveBg, inactiveBorder, chrome, hoverBg, hoverBorder)
  local activeStyle = string.format([[
  QLabel {
    background-color: %s;
    border-top: 3px solid %s;
    font-weight: bold;
%s  }
]], activeBg, accent, chrome)
  return inactiveStyle, activeStyle
end

-- Applies the configured tab font and sizes the tab bar to fit it.
-- The strip, its drag overlay and the body are all built together by the tab
-- window's createBaseContainers(), so one check covers all three.
function DMTabFrame.applyTabFont()
  local tabs = DMTabFrame.tabs
  if not tabs or not (tabs.header and tabs.overlay and tabs.footer) then return end

  local fontPx, barHeight = tab_metrics()

  for _, tabName in ipairs(tabs.tabs) do
    local tab = tabs[tabName .. "tab"]
    if tab and tab.adjLabel and tab.adjLabel.setFontSize then
      tab.adjLabel:setFontSize(fontPx)
    end
  end

  tabs.header:resize("100%", barHeight)
  tabs.overlay:resize("100%", barHeight)
  -- Re-anchor the body under the strip so the tab pages follow it, and let it
  -- fill to the bottom. Must use the explicit "100%-Npx" form: a bare negative
  -- height ("-N") is read as an offset from the bottom edge, which leaves an
  -- N px strip below the body instead of a height of (parent - N).
  tabs.footer:move(0, barHeight)
  tabs.footer:resize("100%", "100%-" .. barHeight .. "px")
  -- HBox:resize only re-lays its children out when it holds fixed-size ones, so
  -- the strip has to be organised explicitly for the tabs to take the new height.
  tabs.header:organize()
end

-- Sets a tab label's text colour. Rich-text labels render an inline colour, so
-- the stylesheet cannot recolour them and setFgColor() only changes the widget
-- palette without re-rendering. Re-echoing writes the new colour inline and
-- updates the label's fgColor, which later re-echoes (createTabs) then reuse.
local function set_tab_text_color(tabs, tabName, active)
  local tab = tabs[tabName .. "tab"]
  local label = tab and tab.adjLabel
  if not label or not label.message then return end
  -- A floated tab's label is its own window's title bar, styled by the float
  -- chrome; re-echoing the docked label text here would re-centre its title.
  if tabs[tabName] and tabs[tabName].floating then return end
  local panel = (DarkmistsTheme and DarkmistsTheme.panel) or {}
  label:echo(label.message,
    active and (panel.buttonActiveFg or "#ffffff") or Darkmists.getDefaultTextColor())
end

local function attach_tab_methods(tabs)
  tabs._delete = tabs._delete or tabs.delete

  -- The framework's activate/deactivate only swap stylesheets, which cannot
  -- recolour rich-text labels, so wrap them to re-echo with the right colour.
  local baseActivateTab = tabs.activateTab
  local baseDeactivateTab = tabs.deactivateTab

  function tabs:activateTab(tabName)
    baseActivateTab(self, tabName)
    set_tab_text_color(self, tabName, true)
  end

  function tabs:deactivateTab()
    local previous = self.current
    baseDeactivateTab(self)
    if previous then set_tab_text_color(self, previous, false) end
  end

  function tabs:queueLayoutSave()
    if not self.__layoutSaveQueued then
      self.__layoutSaveQueued = true
      local currentTabs = self
      tempTimer(0.8, function()
        if DMTabFrame.tabs == currentTabs then
          currentTabs:save()
          currentTabs.__layoutSaveQueued = nil
        end
      end)
    end
  end

  tabs.destroy = DMTabFrame.destroy
end

function DMTabFrame.create()
  if DMTabFrame.container and DMTabFrame.tabs then
    DMTabs = DMTabFrame.tabs
    return DMTabFrame.tabs
  end

  local dock = Darkmists.getSmartDockGeometry()
  local inactiveStyle, activeStyle = build_tab_styles()

  DMTabFrame.container = Adjustable.Container:new({
    name = "DMTabFrame",

    x = dock.x,
    y = "50%",
    width  = dock.width,
    height = "50%",

    titleText = "",
    color = Darkmists.getDefaultBackgroundColor(),
    lockStyle = "border",
    titleTxtColor = Darkmists.getDefaultTextColor(),
    adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
    attached = dock.side,
    autoSave = true,
    autoLoad = true,
    raiseOnClick = true
  })

  DMTabFrame.tabs = Adjustable.TabWindow:new({
    x = 0, y = 0,
    width = "100%", height = "100%",

    tabs = {"Chat","Affects","Who","Player","Destinations"},

    color1 = Darkmists.getDefaultBackgroundColor(),
    color2 = Darkmists.getDefaultBackgroundColor(),
    tabTxtColor = Darkmists.getDefaultTextColor(),

    -- Frame for pulled-out tabs: thin sides/bottom with a taller top band so
    -- the window's title text and - / x buttons stay clear of the content.
    tabPadding = DMConstants.TAB_FLOAT_SIDE_PX,
    tabTopBand = DMConstants.TAB_FLOAT_TOP_BAND_PX,

    inactiveTabStyle = inactiveStyle,
    activeTabStyle   = activeStyle,
  }, DMTabFrame.container)

  DMTabs = DMTabFrame.tabs
  attach_tab_methods(DMTabFrame.tabs)
  DMTabFrame.applyTabFont()
  return DMTabFrame.tabs
end

function DMTabFrame.startAutosave()
  local tabs = DMTabFrame.tabs
  if not tabs then return end

  local currentTabs = tabs
  DarkmistsTimer.add("DMTabFrame.Autosave", 120, function()
    if DMTabFrame.tabs == currentTabs then
      currentTabs:save()
    end
  end, true)
end

function DMTabFrame.setTabVisible(tabName, visible)
  local tabs = DMTabFrame.tabs
  local tab = tabs and tabs[tabName .. "tab"]
  if not tab then return false end

  if visible then
    if tabs[tabName] and tabs[tabName].floating then
      local owner = Adjustable.TabWindow.allTabs[tabName] or tabs
      owner:restoreTab(tabName, tabs)
      return true
    end

    if table.index_of(tabs.tabs, tabName) then return true end

    -- removeTab() removes the header bookkeeping but leaves the old parent
    -- pointer on the tab container. Clear it before adding the existing
    -- object back so HBox:add2() rebuilds both parent indexes.
    tab.container = nil
    tabs.header:add2(tab, nil, false)
    tabs:addTab(tabName, #tabs.tabs + 1)
    tab:show()
  else
    if not table.index_of(tabs.tabs, tabName) then return true end

    tabs:removeTab(tabName)
    tab.container = nil
    -- Keep `current` honest: it is the tab the strip shows as active, so hiding
    -- that tab has to leave nothing selected rather than a tab that is gone.
    if tabs and tabs.current == tabName then tabs.current = nil end
  end
  return true
end

-- Bring an undocked tab back on screen, leaving it undocked.
-- The x on a float's title bar is Adjustable's own close button, which runs
-- hideObj(): it hides the container but leaves the tab registered as floating and
-- out of the strip. raiseAll() only restacks windows, it never clears a hide, so
-- nothing else can bring such a tab back - showing it is the missing half.
-- @param tabName string The tab to bring back
-- @return boolean True if the tab was floating and is now shown
function DMTabFrame.showFloatingTab(tabName)
  local tabs = DMTabFrame.tabs
  local page = tabs and tabs[tabName]
  local container = tabs and tabs[tabName .. "tab"]
  if not (page and page.floating and container) then return false end

  container:show()
  container:raiseAll()
  return true
end

function DMTabFrame.postLoadSetup()
  tempTimer(0.2, function()
    local tabs = DMTabFrame.tabs
    if not tabs then return end

    for tabName, owner in pairs(Adjustable.TabWindow.allTabs) do
      local tabObj = owner[tabName]
      if tabObj and tabObj.floating then

        local outer = owner[tabName.."tab"]
        if outer and outer.type == "adjustablecontainer" then
          -- Frame as well as title: loading re-derives the band from the saved
          -- padding (padding * 2), so a saved side inset leaves a band too short
          -- for the title and the page content hides it.
          if owner.applyFloatChrome then owner:applyFloatChrome(tabName) end
        end

        local center = owner[tabName.."center"]
        if center and center.windowList then
          for _, obj in pairs(center.windowList) do
            if obj.type == "adjustablecontainer" then
              obj:lockContainer(nil, "full")
            end
          end
        end
      end
    end

    -- Activate first non-floating tab (only our own window)
    if #tabs.tabs > 0 then
      tabs:deactivateTab()
      tabs.current = nil
      for _, tabName in ipairs(tabs.tabs) do
        if tabs[tabName] and not tabs[tabName].floating then
          tabs:activateTab(tabName)
          break
        end
      end
    end

    DMTabFrame.applyTabFont()
  end)
end

function DMTabFrame.destroy()
  if Adjustable and Adjustable.TabWindow and Adjustable.TabWindow.all then
    -- Delete the tab containers first. allTabs is the only registry that holds
    -- every one of them: a pulled-out tab's container has been re-parented out of
    -- the strip, and it took its page with it, so it is reachable from nowhere
    -- else. The docked containers are deleted here too rather than through the
    -- strip's cascade below, so that nothing below gets deleted twice.
    for tabName, owner in pairs(Adjustable.TabWindow.allTabs) do
      pcall(function() safe_delete(owner[tabName .. "tab"]) end)
      owner[tabName .. "tab"] = nil
    end

    -- The strip, its drag overlay and the body. Deleting the body cascades to
    -- the docked tab pages (and their content); the containers are already gone.
    for _, win in pairs(Adjustable.TabWindow.all) do
      pcall(function()
        safe_delete(win.footer)
        safe_delete(win.overlay)
        safe_delete(win.header)
      end)
    end

    -- Safe to wipe: DMTabFrame owns the only Adjustable.TabWindow, so none of
    -- this bookkeeping belongs to anyone else.
    Adjustable.TabWindow.all = {}
    Adjustable.TabWindow.allTabs = {}
    Adjustable.TabWindow.all_windows = {}
  end

  safe_delete(DMTabFrame.container)
  DMTabFrame.container = nil

  -- Stop the repeating autosave timer. Removing by name is a no-op when it was
  -- never started, and does not depend on the handle still being on the object.
  DarkmistsTimer.remove("DMTabFrame.Autosave")

  -- Defer the final _delete to avoid destroying UI objects while still inside
  -- callbacks/event handlers that expect them to exist.  Nil the globals
  -- immediately so init() won't see stale references.
  local tabsToDelete = DMTabFrame.tabs
  DMTabFrame.tabs = nil
  DMTabs = nil
  if tabsToDelete and tabsToDelete._delete then
    tempTimer(0, function() pcall(tabsToDelete._delete, tabsToDelete) end)
  end
end

function DMTabFrame.init()
  if DMTabFrame.tabs then
    DMTabs = DMTabFrame.tabs
    return DMTabFrame.tabs
  end

  local tabs = DMTabFrame.create()
  if not tabs then return nil end
  tabs:load()
  DMTabFrame.setTabVisible("Destinations", false)
  DMTabFrame.startAutosave()
  DMTabFrame.postLoadSetup()
  return tabs
end