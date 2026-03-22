local isLight = Darkmists.GlobalSettings.lightMode
local dock = Darkmists.getSmartDockGeometry()

-- Tab font tuning guide:
-- TAB_FONT_SCALE_FACTOR: main growth with tab height (higher = grows faster)
-- TAB_FONT_OFFSET_PX: fixed global nudge (+/- px at all sizes)
-- TAB_FONT_MIN_PX / TAB_FONT_MAX_PX: hard clamp bounds
-- TAB_FONT_SMALL_HEIGHT_THRESHOLD: start applying small-window correction at/below this height
-- TAB_FONT_SMALL_RAMP_RANGE: smoothness of small-window correction (higher = gentler ramp)
-- TAB_FONT_SMALL_MAX_ADJUST_PX: max extra shrink in small-window mode (negative values)
-- TAB_LABEL_PADDING_PX: visual tab padding (not direct font size)
local TAB_FONT_BASE_PX = 12
local TAB_FONT_SCALE_FACTOR = 0.48
local TAB_FONT_OFFSET_PX = 1
local TAB_FONT_SMALL_HEIGHT_THRESHOLD = 60
local TAB_FONT_SMALL_RAMP_RANGE = 14
local TAB_FONT_SMALL_MAX_ADJUST_PX = -4
local TAB_FONT_MIN_PX = 9
local TAB_FONT_MAX_PX = 24
local TAB_LABEL_PADDING_PX = 3

local function clamp(v, minv, maxv)
  return math.max(minv, math.min(maxv, v))
end

local function build_tab_styles()
  local inactiveStyle = isLight and string.format([[ 
  QLabel {
    background-color: rgb(245,245,250);
    border: 1px solid rgb(220,220,235);
    margin-left: 1px;
    margin-right: 1px;
    padding: %dpx;
    qproperty-alignment: 'AlignCenter';
  }
  QLabel:hover {
    background-color: rgb(235,225,255);
    border: 1px solid rgb(200,180,255);
  }
]], TAB_LABEL_PADDING_PX)
  or string.format([[ 
  QLabel {
    background-color: rgba(255,255,255,5%%);
    margin-left: 1px;
    margin-right: 1px;
    padding: %dpx;
    qproperty-alignment: 'AlignCenter';
  }
  QLabel:hover {
    background-color: rgba(180,160,255,28%%);
  }
]], TAB_LABEL_PADDING_PX)

  local activeStyle = isLight and string.format([[ 
  QLabel {
    background-color: rgb(170,140,255);
    color: white;
    border-top: 3px solid rgb(48, 51, 107);   /* Dark Mists deep purple */
    margin-left: 1px;
    margin-right: 1px;
    padding: %dpx;
    font-weight: bold;
    qproperty-alignment: 'AlignCenter';
  }
]], TAB_LABEL_PADDING_PX)
  or string.format([[ 
  QLabel {
    background-color: rgb(48, 51, 107);   /* Dark Mists deep purple */
    color: white;
    border-top: 3px solid rgb(170,140,255);
    margin-left: 1px;
    margin-right: 1px;
    padding: %dpx;
    font-weight: bold;
    qproperty-alignment: 'AlignCenter';
  }
]], TAB_LABEL_PADDING_PX)

  return inactiveStyle, activeStyle
end

local inactiveStyle, activeStyle = build_tab_styles()

DMTabFrame = Adjustable.Container:new({
  name = "DMTabFrame",

  x = dock.x,
  y = "50%",
  width  = dock.width,
  height = "50%",

  titleText = "",
  lockStyle = "border",
  titleTxtColor = Darkmists.getDefaultTextColor(),
  adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
  --padding = 4,
  attached = dock.side,
  autoSave = true,
  autoLoad = true,
  raiseOnClick = true
})

DMTabs = Adjustable.TabWindow:new({
  x = 0, y = 0,
  width = "100%", height = "100%",

  tabs = {"Chat","Affects","Who","Player"},

  color1 = Darkmists.getDefaultTextColor(),
  color2 = Darkmists.getDefaultTextColor(),
  tabTxtColor = Darkmists.getDefaultTextColor(),

  inactiveTabStyle = inactiveStyle,
  activeTabStyle   = activeStyle,
  --tabBarHeight = "7%"
}, DMTabFrame)

function DMTabs:queueLayoutSave()
  if not self.__layoutSaveQueued then
    self.__layoutSaveQueued = true
    tempTimer(0.8, function()
      if DMTabs then DMTabs:save() end
      if DMTabs then DMTabs.__layoutSaveQueued = nil end
    end)
  end
end

function DMTabs:computeTabFontPx()
  if not self.tabs then return TAB_FONT_BASE_PX end
  for _, tabName in ipairs(self.tabs) do
    local tab = self[tabName .. "tab"]
    if tab and tab.adjLabel and tab.adjLabel.get_height then
      local h = tab.adjLabel:get_height()
      if type(h) == "number" and h > 0 then
        local scaled = math.floor(h * TAB_FONT_SCALE_FACTOR) + TAB_FONT_OFFSET_PX
        if h <= TAB_FONT_SMALL_HEIGHT_THRESHOLD then
          local below = math.min(TAB_FONT_SMALL_RAMP_RANGE, TAB_FONT_SMALL_HEIGHT_THRESHOLD - h)
          local t = below / TAB_FONT_SMALL_RAMP_RANGE
          scaled = scaled + math.floor(TAB_FONT_SMALL_MAX_ADJUST_PX * t)
        end
        return clamp(scaled, TAB_FONT_MIN_PX, TAB_FONT_MAX_PX)
      end
    end
  end
  return TAB_FONT_BASE_PX
end

function DMTabs:applyScaledTabFonts()
  local fontPx = self:computeTabFontPx()
  self._lastTabFontPx = fontPx
  if not self.tabs then return end
  for _, tabName in ipairs(self.tabs) do
    local tab = self[tabName .. "tab"]
    if tab and tab.adjLabel then
      if tab.adjLabel.setFontSize then
        tab.adjLabel:setFontSize(fontPx)
      end
    end
  end
end

function DMTabs:queueScaledTabFonts()
  if self.__tabFontScaleQueued then return end
  self.__tabFontScaleQueued = true
  tempTimer(0, function()
    if DMTabs and DMTabs.applyScaledTabFonts then
      DMTabs:applyScaledTabFonts()
      DMTabs.__tabFontScaleQueued = nil
    end
  end)
end

function DMTabs.destroy()
  -- destroy tabwindows/containers created by Adjustable.TabWindow
  if Adjustable and Adjustable.TabWindow and Adjustable.TabWindow.all then
    for _, win in pairs(Adjustable.TabWindow.all) do
      pcall(function()
        if win.header and win.header.windowList then
          for _, wname in ipairs(win.header.windows or {}) do
            local tabc = win[wname .. "tab"] or win[wname]
            if tabc and tabc.delete then pcall(tabc.delete, tabc) end
          end
        end
        if win.footer and win.footer.delete then pcall(win.footer.delete, win.footer) end
        if win.overlay and win.overlay.delete then pcall(win.overlay.delete, win.overlay) end
        if win.header and win.header.delete then pcall(win.header.delete, win.header) end
      end)
    end
    -- Also destroy any floating adjustable containers (pulled-out tabs).
    -- These may not be reachable via each window's header.windows if they've been transformed.
    if Adjustable.TabWindow.allTabs then
      for tabName, owner in pairs(Adjustable.TabWindow.allTabs or {}) do
        pcall(function()
          local cont = owner[tabName.."tab"]
          if cont and cont.delete then cont:delete() end
          local page = owner[tabName]
          if page and page.delete then page:delete() end
          owner[tabName.."tab"] = nil
          owner[tabName] = nil
          -- remove header bookkeeping if present
          if owner.header then
            owner.header:remove(tabName.."tab")
            owner.header:organize()
          end
        end)
      end
    end
    Adjustable.TabWindow.all = {}
    Adjustable.TabWindow.allTabs = {}
    Adjustable.TabWindow.all_windows = {}
  end

  if DMTabFrame and DMTabFrame.delete then pcall(DMTabFrame.delete, DMTabFrame) end
  DMTabFrame = nil

  -- Stop the repeating autosave timer if present
  if DMTabs and DMTabs._autosaveTimer then
    pcall(killTimer, DMTabs._autosaveTimer)
    DMTabs._autosaveTimer = nil
  end

  tempTimer(0, function()
    -- drop module globals so saved UI won't reference stale functions/objects
    if DMTabs and DMTabs.delete then pcall(DMTabs.delete, DMTabs) end
    DMTabs = nil
  end)
end

--[[
DarkmistsEvents.add("DMTabFrameProfileSave", "sysProfileSaveStarted", function()
  DMTabs:queueLayoutSave()
end)
]]--

-- repeating autosave timer (assign to var so it can be killed on reload)
DMTabs._autosaveTimer = tempTimer(120, function()
  if DMTabs then DMTabs:save() end
end, true)

DMTabs:load()

DarkmistsEvents.add("DMTabFrameFontScaleResize", "sysWindowResizeEvent", function()
  if DMTabs and DMTabs.queueScaledTabFonts then
    DMTabs:queueScaledTabFonts()
  end
end)

tempTimer(0.2, function()
  for tabName, owner in pairs(Adjustable.TabWindow.allTabs) do
    local tabObj = owner[tabName]
    if tabObj and tabObj.floating then

      -- OUTER FLOATING WINDOW (make movable/resizable)
      local outer = owner[tabName.."tab"]
      if outer and outer.type == "adjustablecontainer" then
        outer:unlockContainer()
      end

      -- INNER CONTENT PANELS (clean minimal look)
      local center = owner[tabName.."center"]
      if center and center.windowList then
        for _, obj in pairs(center.windowList) do
          if obj.type == "adjustablecontainer" then
            obj:lockContainer(nil, "light")
          end
        end
      end

    end
  end

  -- SAFE ACTIVATION PASS
  for _, win in pairs(Adjustable.TabWindow.all) do
    if win.tabs and #win.tabs > 0 then
      win:deactivateTab()
      win.current = nil

      for _, tabName in ipairs(win.tabs) do
        if win[tabName] and not win[tabName].floating then
          win:activateTab(tabName)
          break
        end
      end
    end
  end

  if DMTabs and DMTabs.applyScaledTabFonts then
    DMTabs:applyScaledTabFonts()
  end
end)