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
DMSettingsPanel.visible = false

local rowHeight = 36
local labelWidth = 190
local controlWidth = 152
local inputWidth = 248

local labelStyle = [[
  QLabel {
    background-color: #101418;
    color: #d7dee5;
    padding-left: 6px;
  }
]]

local valueStyle = [[
  QLabel {
    background-color: #1b2229;
    color: #f0c674;
    border: 1px solid #394550;
    padding-left: 6px;
  }
  QLabel::hover { background-color: #27313a; }
]]

local buttonStyle = [[
  QLabel {
    background-color: #26333d;
    color: #d7dee5;
    border: 1px solid #536372;
    padding-left: 4px;
    padding-right: 4px;
  }
  QLabel::hover { background-color: #38505f; }
]]

local inputStyle = [[
  QPlainTextEdit {
    background-color: #1b2229;
    color: #f0c674;
    border: 1px solid #394550;
    padding: 2px;
  }
]]

local colorMenuStyle = [[
  QLabel {
    background-color: #101418;
    border: 1px solid #536372;
  }
]]

local function themeTag(name, fallback)
  if DarkmistsTheme and DarkmistsTheme[name] then
    return DarkmistsTheme[name]
  end
  return fallback
end

local function makeLabel(name, x, y, width, height, message, parent, style)
  local label = Geyser.Label:new({
    name = name,
    x = x, y = y,
    width = width, height = height,
    message = message or "",
  }, parent)
  label:setFontSize((Darkmists.GlobalSettings and Darkmists.GlobalSettings.fontSize) or 12)
  label:setStyleSheet(style or labelStyle)
  return label
end

local function choiceLabel(setting, value)
  for _, choice in ipairs(setting.choices or {}) do
    if choice.value == value then return choice.label end
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
  local tag = isError and themeTag("badTag", "<red>") or themeTag("goodTag", "<green>")
  DMSettingsPanel.status:echo(tag .. tostring(message) .. "<r>")
end

function DMSettingsPanel.apply(key, value)
  local ok, message = DMSettings.set(key, value)
  if not ok then
    setStatus(message or "Setting rejected.", true)
    return false
  end
  setStatus("Saved.", false)
  DMSettingsPanel.refresh()
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

local function adjustPartCount(setting, delta)
  local current = tonumber(DMSettings.value(setting.key)) or setting.default
  DMSettingsPanel.apply(setting.key, current + delta)
end

local function makeButton(name, x, y, width, message, action, parent)
  local button = makeLabel(name, x, y, width, rowHeight - 6, message, parent, buttonStyle)
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
  local borderColor = selected and "#f0c674" or "#394550"
  return string.format([[
    QLabel {
      background-color: rgb(%d, %d, %d);
      border: 2px solid %s;
    }
    QLabel::hover { border: 2px solid #ffffff; }
  ]], red, green, blue, borderColor)
end

local function refreshColorMenu(control)
  local current = DMSettings.value(control.setting.key)
  if control.value then
    control.value:echo("")
    control.value:setStyleSheet(colorSwatchStyle(current, true))
  end
  if control.selector and control.selector.setToolTip then
    control.selector:setToolTip("Change damage color: " .. choiceLabel(control.setting, current))
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
    x = 230, y = y + rowHeight - 2,
    width = menuWidth, height = menuHeight,
  }, DMSettingsPanel.content)
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
    if item.setToolTip then item:setToolTip(choice.label) end
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
  local parent = DMSettingsPanel.content
  makeLabel("DMSettingsLabel_" .. keyName, 0, y, labelWidth, rowHeight - 6,
    setting.label, parent)

  local control = {setting = setting}
  if setting.type == "text" then
    local input = Geyser.CommandLine:new({
      name = "DMSettingsInput_" .. keyName,
      x = labelWidth + 4, y = y,
      width = inputWidth, height = rowHeight - 6,
    }, parent)
    input:setStyleSheet(inputStyle)
    input:setAction(function(settingKey, text)
      DMSettingsPanel.apply(settingKey, text)
    end, setting.key)
    control.input = input
  else
    control.value = makeLabel("DMSettingsValue_" .. keyName, labelWidth + 4, y,
      controlWidth, rowHeight - 6, "", parent, valueStyle)
    control.value:setAlignment("center")

    if setting.key == "enchanterAssist.partCount" then
      makeButton("DMSettingsMinus", 350, y, 44, "-", function()
        adjustPartCount(setting, -1)
      end, parent)
      makeButton("DMSettingsPlus", 398, y, 44, "+", function()
        adjustPartCount(setting, 1)
      end, parent)
    elseif setting.type == "color" then
      control.selector = makeButton("DMSettingsColorSelect_" .. keyName, 350, y, 92, "Change", function()
        toggleColorMenu(control, y)
      end, parent)
    else
      makeButton("DMSettingsCycle_" .. keyName, 350, y, 92, "Change", function()
        cycleValue(setting)
      end, parent)
    end
  end

  DMSettingsPanel.controls[setting.key] = control
  return y + rowHeight
end

local function makeSection(title, y)
  local tag = themeTag("infoTag", "<cyan>")
  local heading = makeLabel("DMSettingsSection_" .. title:gsub("%s", "_"), 0, y,
    "100%", rowHeight - 6, tag .. "<b>" .. title .. "</b><r>", DMSettingsPanel.content)
  heading:setAlignment("left")
  return y + rowHeight
end

function DMSettingsPanel.refresh()
  for key, control in pairs(DMSettingsPanel.controls) do
    local setting = control.setting
    if control.value then
      if setting.type == "color" then
        refreshColorMenu(control)
      else
        control.value:echo(displayValue(setting))
      end
    elseif control.input then
      control.input:print(tostring(DMSettings.value(key) or ""))
    end
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
  DMSettingsPanel.visible = false
end

function DMSettingsPanel.init()
  if DMSettingsPanel.container then
    DMSettingsPanel.refresh()
    return true
  end

  DMSettingsPanel.container = Adjustable.Container:new({
    name = "DMSettingsPanel",
    x = "20%", y = "12%",
    width = 560, height = 570,
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

  DMSettingsPanel.container.exitLabel:setClickCallback(function()
    DMSettingsPanel.hide()
  end)

  DMSettingsPanel.content = Geyser.Container:new({
    name = "DMSettingsContent",
    x = 0, y = 0,
    width = "100%", height = "100%",
  }, DMSettingsPanel.container.Inside)

  local y = 0
  y = makeSection("Enchanter Assist", y)
  for _, setting in ipairs(DMSettings.list("Enchanter Assist")) do
    y = makeRow(setting, y)
  end

  y = makeSection("ShowDMG", y + 8)
  for _, setting in ipairs(DMSettings.list("ShowDMG")) do
    y = makeRow(setting, y)
  end

  DMSettingsPanel.status = makeLabel("DMSettingsStatus", 0, y + 4, "100%", rowHeight,
    themeTag("mutedTag", "<gray>") .. "Changes save immediately.<r>",
    DMSettingsPanel.content, labelStyle)
  DMSettingsPanel.status:setAlignment("left")

  makeButton("DMSettingsReload", 0, y + rowHeight + 4, 120, "Reload UI", function()
    if Darkmists and Darkmists.PromptSafeReload then
      Darkmists.PromptSafeReload()
    end
  end, DMSettingsPanel.content)
  makeButton("DMSettingsClose", 128, y + rowHeight + 4, 120, "Close", function()
    DMSettingsPanel.hide()
  end, DMSettingsPanel.content)

  DMSettingsPanel.container:hide()
  DMSettingsPanel.visible = false
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