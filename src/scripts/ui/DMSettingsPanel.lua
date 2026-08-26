-- ============================================================================
-- Dark Mists Settings Panel
-- ============================================================================
-- A movable settings window backed by DMSettings. Values are applied and
-- persisted immediately after validation; module-specific file formats remain
-- owned by their modules.
DMSettingsPanel = {}

DMSettingsPanel.container = nil
DMSettingsPanel.content = nil
DMSettingsPanel.status = nil
DMSettingsPanel.controls = {}
DMSettingsPanel.pages = {
  "Appearance", "Status Bars", "Windows", "Enchanter Assist",
  "ShowDMG", "ItemTracker", "Utilities",
}
DMSettingsPanel.pageContainers = {}
DMSettingsPanel.pageHeights = {}
DMSettingsPanel.activePage = "Appearance"
DMSettingsPanel.visible = false

local rowHeight = 30
local labelWidth = 220
local controlWidth = 150
local controlX = labelWidth + 4
local actionX = controlX + controlWidth + 16
local actionWidth = 92
local integerButtonWidth = 44
local integerButtonGap = 4
local inputWidth = actionX + actionWidth - controlX
local headerMargin = 0
local headerY = 8
local headerHeight = 128
local headerContentInset = 8
local headerContentX = headerMargin + headerContentInset
local headerContentY = headerY + headerContentInset
local headerWidth = "100%-" .. (headerMargin * 2)
local headerPageWidth = 140
local headerPageButtonWidth = 136
local headerPageRowHeight = 27
local headerStatusY = headerContentY + 54
local headerStatusHeight = 26
local headerActionGap = 6
local headerActionWidth = 104
local headerActionY = headerStatusY + headerStatusHeight + headerActionGap
local headerActionX = "100%-" .. (headerActionWidth * 2 + headerActionGap + headerContentInset)
local headerCancelX = "100%-" .. (headerActionWidth + headerContentInset)
local headerStatusWidth = "100%-" .. (headerContentInset * 2)
local headerPageGap = 8
local pageY = headerY + headerHeight + headerPageGap
local panelWidth = 605
local panelMinHeight = 520
local panelMaxHeight = 900
local panelBottomPadding = 28
local inputFontSize = math.max(8, ((Darkmists.GlobalSettings and Darkmists.GlobalSettings.fontSize) or 12) - 2)

local labelStyle
local labelTextColor
local sectionStyle
local sectionTextColor
local valueStyle
local valueTextColor
local buttonStyle
local buttonTextColor
local selectedButtonStyle
local selectedButtonTextColor
local inputStyle
local colorMenuStyle
local containerStyle
local headerControlStyle
local notificationStyle
local statusMutedTag
local statusGoodTag
local statusBadTag
local statusTextColor

local function opaqueColor(color, fallback)
  local value = tostring(color or fallback or "")
  local red, green, blue = value:match(
    "^rgba%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*[%d%.]+%%%s*%)"
  )
  if red then
    return string.format("rgb(%d,%d,%d)", tonumber(red), tonumber(green), tonumber(blue))
  end
  return value
end

local function opaqueStyle(style)
  return (style or ""):gsub(
    "rgba%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*[%d%.]+%%%s*%)",
    function(red, green, blue)
      return string.format("rgb(%d,%d,%d)", tonumber(red), tonumber(green), tonumber(blue))
    end
  )
end

local function refreshThemeStyles()
  local panel = (DarkmistsTheme and DarkmistsTheme.panel) or {}
  local lightMode = Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings.lightMode
  local textColor = lightMode
    and "#202020" or "#e0d6ff"
  statusMutedTag = lightMode and "<dark_gray>" or nil
  statusGoodTag = lightMode and "<dark_green>" or nil
  statusBadTag = lightMode and "<dark_red>" or nil
  statusTextColor = lightMode and "#202020" or nil
  local headerBg = opaqueColor(panel.headerBg, "#101418")
  local sectionBg = opaqueColor(panel.sectionBg, headerBg)
  local headerBorder = opaqueColor(panel.headerBorder, "#536372")
  local headerAccent = opaqueColor(panel.headerAccent, headerBorder)
  local headerControlAccent = "#b8860b"
  local buttonBg = opaqueColor(panel.buttonBg, "#1b2229")
  local buttonBorder = opaqueColor(panel.buttonBorder, "#394550")
  local buttonHoverBg = opaqueColor(panel.buttonHoverBg, "#27313a")
  local buttonHoverFg = panel.buttonHoverFg or "#f0c674"

  labelStyle = string.format([[
  QLabel {
    background-color: %s;
    color: %s;
    border: 1px solid %s;
    padding-left: 6px;
  }
]], headerBg, textColor, headerBorder)

  valueStyle = string.format([[
  QLabel {
    background-color: %s;
    color: %s;
    border: 1px solid %s;
    padding-left: 6px;
  }
  QLabel::hover { background-color: %s; }
]], buttonBg, buttonHoverFg, buttonBorder, buttonHoverBg)

  local buttonActiveBg = opaqueColor(panel.buttonActiveBg, buttonBg)
  local buttonActiveFg = panel.buttonActiveFg or "#ffffff"
  local buttonActiveBorder = opaqueColor(panel.buttonActiveBorder, buttonBorder)

  labelTextColor = textColor
  sectionTextColor = buttonHoverFg
  valueTextColor = buttonHoverFg
  buttonTextColor = buttonHoverFg
  selectedButtonTextColor = buttonActiveFg

  sectionStyle = string.format([[
  QLabel {
    background-color: %s;
    color: %s;
    border: 1px solid %s;
    border-bottom: 2px solid %s;
    border-radius: 0px;
    padding-left: 8px;
    font-weight: bold;
  }
]], sectionBg, textColor, headerBorder, headerAccent)

  notificationStyle = string.format([[
  QLabel {
    background-color: %s;
    color: %s;
    border: 2px solid %s;
    border-radius: 0px;
    padding-left: 8px;
    font-weight: bold;
  }
]], buttonBg, textColor, buttonActiveBorder)

  buttonStyle = string.format([[
  QLabel {
    background-color: %s;
    color: %s;
    border: 1px solid %s;
    border-radius: 0px;
    padding-left: 4px;
    padding-right: 4px;
  }
  QLabel::hover {
    background-color: %s;
    color: %s;
  }
]], buttonBg, buttonHoverFg, buttonBorder, buttonHoverBg, buttonHoverFg)

  selectedButtonStyle = string.format([[
  QLabel {
    background-color: %s;
    color: %s;
    border: 1px solid %s;
    border-radius: 0px;
    padding-left: 4px;
    padding-right: 4px;
    font-weight: bold;
  }
  QLabel::hover {
    background-color: %s;
    color: %s;
  }
]], buttonActiveBg, buttonActiveFg, buttonActiveBorder, buttonActiveBg, buttonActiveFg)

  inputStyle = string.format([[
  QPlainTextEdit {
    background-color: %s;
    color: %s;
    border: 1px solid %s;
    font-size: 10pt;
    padding: 0px 2px;
  }
]], buttonBg, buttonHoverFg, buttonBorder)

  colorMenuStyle = string.format([[
  QLabel {
    background-color: %s;
    border: 1px solid %s;
  }
]], headerBg, headerBorder)

  containerStyle = string.format("QLabel { background-color: %s; }", buttonBg)

  headerControlStyle = string.format([[
  QLabel {
    background-color: %s;
    border: 1px solid %s;
    border-top: 2px solid %s;
    border-bottom: 2px solid %s;
    border-radius: 0px;
  }
]], sectionBg, headerControlAccent, headerControlAccent, headerControlAccent)
end

local function themeTag(name, fallback)
  if DarkmistsTheme and DarkmistsTheme[name] then
    return DarkmistsTheme[name]
  end
  return fallback
end

local function makeLabel(name, x, y, width, height, message, parent, style, foregroundColor)
  local label = Geyser.Label:new({
    name = name,
    x = x, y = y,
    width = width, height = height,
    message = message or "",
  }, parent)
  label:setFontSize((Darkmists.GlobalSettings and Darkmists.GlobalSettings.fontSize) or 12)
  label:setStyleSheet(style or labelStyle)
  if foregroundColor and label.setFgColor then
    label:setFgColor(foregroundColor)
  end
  return label
end

local function choiceLabel(setting, value)
  for _, choice in ipairs(setting.choices or {}) do
    if choice.value == value then return choice.label or tostring(choice.value) end
  end
  return tostring(value)
end

local function displayValue(setting)
  local value = DMSettings.value(setting.key)
  if setting.type == "boolean" then
    return value and "Enabled" or "Disabled"
  elseif setting.type == "enum" then
    return choiceLabel(setting, value)
  elseif setting.type == "color" then
    return "<" .. tostring(value) .. ">" .. tostring(value) .. "<r>"
  end
  return tostring(value or "")
end

local function setStatus(message, isError)
  if not DMSettingsPanel.status then return end
  DMSettingsPanel.status:setStyleSheet(notificationStyle)
  if DMSettingsPanel.status.setFgColor and statusTextColor then
    DMSettingsPanel.status:setFgColor(statusTextColor)
  end
  local tag = isError
    and (statusBadTag or themeTag("badTag", "<red>"))
    or (statusGoodTag or themeTag("goodTag", "<green>"))
  DMSettingsPanel.status:echo(tag .. tostring(message) .. "<r>")
end

local function pageForSetting(setting)
  if setting.page then return setting.page end
  if setting.group == "Enchanter Assist" then return "Enchanter Assist" end
  if setting.group == "ShowDMG" then return "ShowDMG" end
  return setting.group
end

local function settingsForPage(pageName)
  local result = {}
  for _, setting in ipairs(DMSettings.list()) do
    if pageForSetting(setting) == pageName then
      table.insert(result, setting)
    end
  end
  return result
end

function DMSettingsPanel.apply(key, value)
  local ok, message = DMSettings.set(key, value)
  if not ok then
    setStatus(message or "Setting rejected.", true)
    return false
  end
  if DMSettings.reloadRequired(DMSettings.get(key)) then
    setStatus("Saved. Reload UI to apply.", false)
  else
    setStatus("Saved.", false)
  end
  DMSettingsPanel.refresh(key)
  return true
end

local function cycleValue(setting)
  local current = DMSettings.value(setting.key)
  if setting.type == "boolean" then
    DMSettingsPanel.apply(setting.key, not current)
    return
  end

  local choices = setting.choices or {}
  for index, choice in ipairs(choices) do
    if choice.value == current then
      local nextChoice = choices[index + 1] or choices[1]
      DMSettingsPanel.apply(setting.key, nextChoice.value)
      return
    end
  end
  if choices[1] then DMSettingsPanel.apply(setting.key, choices[1].value) end
end

local function adjustInteger(setting, delta)
  local current = tonumber(DMSettings.value(setting.key)) or setting.default
  DMSettingsPanel.apply(setting.key, current + delta)
end

local function makeButton(name, x, y, width, message, action, parent)
  local button = makeLabel(name, x, y, width, rowHeight - 6, message, parent,
    buttonStyle, buttonTextColor)
  button:setAlignment("center")
  button:setClickCallback(action)
  return button
end

local function closeColorMenu(control)
  if control.menu then control.menu:hide() end
  control.menuOpen = false
end

local function colorSwatchStyle(color, selected)
  local red, green, blue = Geyser.Color.parse(color)
  if not red then
    return buttonStyle
  end
  local panel = (DarkmistsTheme and DarkmistsTheme.panel) or {}
  local borderColor = selected and opaqueColor(panel.buttonActiveBorder, "#f0c674")
    or opaqueColor(panel.buttonBorder, "#394550")
  local hoverBorder = panel.buttonHoverFg or "#ffffff"
  return string.format([[
    QLabel {
      background-color: rgb(%d, %d, %d);
      border: 2px solid %s;
    }
    QLabel::hover { border: 2px solid %s; }
  ]], red, green, blue, borderColor, hoverBorder)
end

local function refreshColorMenu(control)
  local current = DMSettings.value(control.setting.key)
  if control.value then
    control.value:echo("")
    control.value:setStyleSheet(colorSwatchStyle(current, true))
  end
  if control.selector and control.selector.setToolTip then
    control.selector:setToolTip("Change " .. control.setting.label:lower() .. ": " .. choiceLabel(control.setting, current))
  end
  if control.menuItems then
    for value, item in pairs(control.menuItems) do
      item:setStyleSheet(colorSwatchStyle(value, value == current))
    end
  end
end

local function makeColorMenu(control, y)
  local choices = control.setting.choices or {}
  local columns = 4
  local itemWidth = 74
  local itemHeight = 28
  local menuWidth = columns * itemWidth + 8
  local menuHeight = math.ceil(#choices / columns) * itemHeight + 8
  local keyName = control.setting.key:gsub("[^%w]", "_")

  control.menu = Geyser.Container:new({
    name = "DMSettingsColorMenu_" .. keyName,
    x = actionX, y = y + rowHeight - 2,
    width = menuWidth, height = menuHeight,
  }, control.parent)
  makeLabel("DMSettingsColorMenuBackground_" .. keyName, 0, 0,
    "100%", "100%", "", control.menu, colorMenuStyle)
  control.menuItems = {}

  for index, choice in ipairs(choices) do
    local column = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    local item = makeLabel("DMSettingsColorOption_" .. keyName .. "_" .. index,
      4 + column * itemWidth, 4 + row * itemHeight,
      itemWidth - 4, itemHeight - 4,
      "", control.menu, colorSwatchStyle(choice.value, false))
    item:setAlignment("center")
    if item.setToolTip then item:setToolTip(tostring(choice.value)) end
    item:setClickCallback(function()
      DMSettingsPanel.apply(control.setting.key, choice.value)
      closeColorMenu(control)
    end)
    control.menuItems[choice.value] = item
  end

  refreshColorMenu(control)
  return control.menu
end

local function toggleColorMenu(control, y)
  if not control.menu then makeColorMenu(control, y) end
  if control.menuOpen then
    closeColorMenu(control)
  else
    refreshColorMenu(control)
    control.menu:show()
    control.menuOpen = true
  end
end

local function makeRow(setting, y)
  local keyName = setting.key:gsub("[^%w]", "_")
  local parent = DMSettingsPanel.currentPageContainer
  local label = makeLabel("DMSettingsLabel_" .. keyName, 0, y, labelWidth, rowHeight - 6,
    setting.label .. (DMSettings.reloadRequired(setting) and " *" or ""),
    parent, labelStyle, labelTextColor)
  if setting.description and label.setToolTip then
    label:setToolTip(setting.description)
  end

  local control = {setting = setting, parent = parent}
  if setting.type == "text" or setting.type == "rgba" then
    local input = Geyser.CommandLine:new({
      name = "DMSettingsInput_" .. keyName,
      x = controlX, y = y,
      width = inputWidth, height = rowHeight - 6,
    }, parent)
    input:setStyleSheet(inputStyle)
    input:setFontSize(inputFontSize)
    if setting.description and input.setToolTip then
      input:setToolTip(setting.description)
    end
    input:setAction(function(settingKey, text)
      DMSettingsPanel.apply(settingKey, text)
    end, setting.key)
    control.input = input
  else
    control.value = makeLabel("DMSettingsValue_" .. keyName, controlX, y,
      controlWidth, rowHeight - 6, "", parent, valueStyle, valueTextColor)
    control.value:setAlignment("center")
    if setting.description and control.value.setToolTip then
      control.value:setToolTip(setting.description)
    end

    if setting.type == "integer" then
      makeButton("DMSettingsMinus_" .. keyName, actionX, y, integerButtonWidth, "-", function()
        adjustInteger(setting, -1)
      end, parent)
      makeButton("DMSettingsPlus_" .. keyName,
        actionX + integerButtonWidth + integerButtonGap, y, integerButtonWidth, "+", function()
        adjustInteger(setting, 1)
      end, parent)
    elseif setting.type == "color" then
      control.selector = makeButton("DMSettingsColorSelect_" .. keyName, actionX, y, actionWidth, "Change", function()
        toggleColorMenu(control, y)
      end, parent)
    else
      makeButton("DMSettingsCycle_" .. keyName, actionX, y, actionWidth, "Change", function()
        cycleValue(setting)
      end, parent)
    end
  end

  DMSettingsPanel.controls[setting.key] = control
  return y + rowHeight
end

local function makeSection(title, y)
  local heading = makeLabel("DMSettingsSection_" .. title:gsub("%s", "_"), 0, y,
    "100%", rowHeight - 6, "<b>" .. title .. "</b>", DMSettingsPanel.currentPageContainer,
    sectionStyle, sectionTextColor)
  heading:setAlignment("left")
  return y + rowHeight
end

local function resetEnchanterSession()
  if not EnchanterAssist or not EnchanterAssist.reset then
    setStatus("Enchanter Assist is not loaded.", true)
    return
  end

  setStatus("Resetting Enchanter session...", false)
  local ok, message = pcall(EnchanterAssist.reset)
  if not ok then
    setStatus("Could not reset Enchanter session: " .. tostring(message), true)
    return
  end

  setStatus("Session reset. Settings unchanged; attempted history preserved.", false)
  DMSettingsPanel.refresh()
end

local function runEnchanterTrial()
  if not EnchanterAssist or not EnchanterAssist.run then
    setStatus("Enchanter Assist is not loaded.", true)
    return
  end
  if not EnchanterAssist.enabled then
    setStatus("Enchanter Assist is disabled.", true)
    return
  end

  setStatus("Starting one Enchanter trial...", false)
  local ok, message = pcall(EnchanterAssist.run)
  if not ok then
    setStatus("Could not start Enchanter trial: " .. tostring(message), true)
    return
  end

  setStatus("One Enchanter trial requested. See module notifications for progress.", false)
end

local function stopEnchanterAssist()
  if not EnchanterAssist or not EnchanterAssist.hardStop then
    setStatus("Enchanter Assist is not loaded.", true)
    return
  end

  local wasBrewing = EnchanterAssist.state == "brewing"
  local ok, message = pcall(EnchanterAssist.hardStop)
  if not ok then
    setStatus("Could not stop Enchanter Assist: " .. tostring(message), true)
    return
  end

  if wasBrewing then
    setStatus("Stop requested; the current attempt will finish.", false)
  else
    setStatus("Enchanter Assist stopped.", false)
  end
  DMSettingsPanel.refresh()
end

local function resizeForPage(pageName)
  local container = DMSettingsPanel.container
  local pageHeight = DMSettingsPanel.pageHeights[pageName]
  if not container or not pageHeight or not container.resize then return end

  local maximumHeight = panelMaxHeight
  if type(getMainWindowSize) == "function" then
    local ok, _, mainHeight = pcall(getMainWindowSize)
    if ok and type(mainHeight) == "number" then
      local panelY = 0
      if container.get_y then
        local yOk, value = pcall(container.get_y, container)
        if yOk and type(value) == "number" then panelY = value end
      end
      maximumHeight = math.max(panelMinHeight, mainHeight - panelY - 24)
    end
  end

  local desiredHeight = math.max(panelMinHeight,
    math.min(maximumHeight, pageY + pageHeight + panelBottomPadding))
  local currentWidth = panelWidth
  local currentHeight
  if container.get_width then
    local widthOk, width = pcall(container.get_width, container)
    if widthOk and type(width) == "number" then currentWidth = width end
  end
  if container.get_height then
    local heightOk, height = pcall(container.get_height, container)
    if heightOk then currentHeight = height end
  end
  if currentHeight ~= desiredHeight then
    container:resize(currentWidth, desiredHeight)
  end
end

local function showPage(pageName)
  local page = DMSettingsPanel.pageContainers[pageName]
  if not page then return end

  for name, container in pairs(DMSettingsPanel.pageContainers) do
    if name == pageName then container:show() else container:hide() end
  end
  DMSettingsPanel.activePage = pageName
  resizeForPage(pageName)

  for name, button in pairs(DMSettingsPanel.pageButtons or {}) do
    local selected = name == pageName
    button:setStyleSheet(selected and selectedButtonStyle or buttonStyle)
    if button.setFgColor then
      button:setFgColor(selected and selectedButtonTextColor or buttonTextColor)
    end
  end
end

local function buildPage(pageName)
  local keyName = pageName:gsub("[^%w]", "_")
  local page = Geyser.Container:new({
    name = "DMSettingsPage_" .. keyName,
    x = 0, y = pageY,
    width = "100%", height = "100%-" .. pageY,
  }, DMSettingsPanel.content)
  makeLabel("DMSettingsPageBackground_" .. keyName, 0, 0,
    "100%", "100%", "", page, containerStyle)
  DMSettingsPanel.pageContainers[pageName] = page
  DMSettingsPanel.currentPageContainer = page

  local y = 0
  local previousSection = nil
  for _, setting in ipairs(settingsForPage(pageName)) do
    local section = setting.section or setting.group
    if section ~= previousSection then
      if previousSection then y = y + 4 end
      y = makeSection(section, y)
      previousSection = section
    end
    y = makeRow(setting, y)
  end
  if pageName == "Enchanter Assist" then
    y = y + 4
    y = makeSection("Session controls", y)
    local sessionControlsWidth = controlX + inputWidth
    local sessionActionWidth = math.floor((sessionControlsWidth - headerActionGap * 2) / 3)
    makeButton("DMSettingsEnchanterRun", 0, y, sessionActionWidth,
      "Run", runEnchanterTrial, page)
    makeButton("DMSettingsEnchanterStop",
      sessionActionWidth + headerActionGap, y, sessionActionWidth,
      "Stop", stopEnchanterAssist, page)
    makeButton("DMSettingsEnchanterReset",
      (sessionActionWidth + headerActionGap) * 2, y,
      sessionActionWidth, "Reset", resetEnchanterSession, page)
    y = y + rowHeight
  end
  DMSettingsPanel.pageHeights[pageName] = y
end

local function refreshControl(key, control)
  local setting = control.setting
  if control.value then
    if setting.type == "color" then
      refreshColorMenu(control)
    else
      control.value:echo(displayValue(setting))
    end
  elseif control.input then
    local value = tostring(DMSettings.value(key) or "")
    if not control.input.getText or control.input:getText() ~= value then
      control.input:print(value)
    end
  end
end

function DMSettingsPanel.refresh(key)
  if key then
    local control = DMSettingsPanel.controls[key]
    if control then refreshControl(key, control) end
    return
  end

  for controlKey, control in pairs(DMSettingsPanel.controls) do
    refreshControl(controlKey, control)
  end
end

function DMSettingsPanel.destroy()
  if DMSettingsPanel.container and DMSettingsPanel.container.delete then
    pcall(DMSettingsPanel.container.delete, DMSettingsPanel.container)
  end
  DMSettingsPanel.container = nil
  DMSettingsPanel.content = nil
  DMSettingsPanel.status = nil
  DMSettingsPanel.controls = {}
  DMSettingsPanel.pageContainers = {}
  DMSettingsPanel.pageHeights = {}
  DMSettingsPanel.pageButtons = {}
  DMSettingsPanel.currentPageContainer = nil
  DMSettingsPanel.visible = false
end

function DMSettingsPanel.init()
  if DMSettingsPanel.container then
    DMSettingsPanel.refresh()
    return true
  end

  refreshThemeStyles()
  DMSettingsPanel.container = Adjustable.Container:new({
    name = "DMSettingsPanel",
    x = "20%", y = "12%",
    width = panelWidth, height = panelMinHeight,
    titleText = "Dark Mists Settings",
    titleTxtColor = Darkmists.getDefaultTextColor(),
    padding = 14,
    buttonsize = 18,
    locked = false,
    lockStyle = "border",
    autoSave = true,
    autoLoad = true,
    adjLabelstyle = Darkmists.getDefaultAdjLabelstyle(),
  })

  if DarkmistsTheme and DarkmistsTheme.buildHeaderStyle then
    DMSettingsPanel.container.adjLabel:setStyleSheet(
      opaqueStyle(DarkmistsTheme.buildHeaderStyle())
    )
  end

  DMSettingsPanel.container.exitLabel:setClickCallback(function()
    DMSettingsPanel.hide()
  end)

  DMSettingsPanel.content = Geyser.Container:new({
    name = "DMSettingsContent",
    x = 0, y = 0,
    width = "100%", height = "100%",
  }, DMSettingsPanel.container.Inside)
  makeLabel("DMSettingsContentBackground", 0, 0,
    "100%", "100%", "", DMSettingsPanel.content, containerStyle)
  makeLabel("DMSettingsHeaderControls", headerMargin, headerY,
    headerWidth, headerHeight, "", DMSettingsPanel.content, headerControlStyle)

  DMSettingsPanel.pageButtons = {}
  local pageColumns = 4
  for index, pageName in ipairs(DMSettingsPanel.pages) do
    local keyName = pageName:gsub("[^%w]", "_")
    local column = (index - 1) % pageColumns
    local row = math.floor((index - 1) / pageColumns)
    DMSettingsPanel.pageButtons[pageName] = makeButton(
      "DMSettingsPageButton_" .. keyName,
      headerContentX + column * headerPageWidth,
      headerContentY + row * headerPageRowHeight,
      headerPageButtonWidth, pageName,
      function() showPage(pageName) end,
      DMSettingsPanel.content)
  end

  DMSettingsPanel.status = makeLabel("DMSettingsStatus", headerContentX, headerStatusY,
    headerStatusWidth, headerStatusHeight,
    (statusMutedTag or themeTag("mutedTag", "<gray>")) .. "Changes save immediately.<r>",
    DMSettingsPanel.content, notificationStyle, statusTextColor)
  DMSettingsPanel.status:setAlignment("left")

  makeButton("DMSettingsReload", headerActionX, headerActionY, headerActionWidth, "Reload UI", function()
    if Darkmists and Darkmists.PromptSafeReload then
      Darkmists.PromptSafeReload()
    end
  end, DMSettingsPanel.content)
  makeButton("DMSettingsClose", headerCancelX,
    headerActionY, headerActionWidth, "Cancel", function()
    DMSettingsPanel.hide()
  end, DMSettingsPanel.content)

  for _, pageName in ipairs(DMSettingsPanel.pages) do
    buildPage(pageName)
  end
  DMSettingsPanel.currentPageContainer = nil

  DMSettingsPanel.container:hide()
  DMSettingsPanel.visible = false
  showPage(DMSettingsPanel.activePage)
  DMSettingsPanel.refresh()

  if DMLogger and DMLogger.log then
    DMLogger.log("DMSettingsPanel", "Loaded!")
  end
  return true
end

function DMSettingsPanel.show()
  if not DMSettingsPanel.init() then return false end
  DMSettingsPanel.container:show()
  DMSettingsPanel.visible = true
  DMSettingsPanel.refresh()
  return true
end

function DMSettingsPanel.hide()
  if DMSettingsPanel.container then DMSettingsPanel.container:hide() end
  DMSettingsPanel.visible = false
end

function DMSettingsPanel.toggle()
  if DMSettingsPanel.visible then
    DMSettingsPanel.hide()
  else
    DMSettingsPanel.show()
  end
end