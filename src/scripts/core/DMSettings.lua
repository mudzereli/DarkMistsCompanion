-- ============================================================================
-- Dark Mists Settings Registry
-- ============================================================================
-- Coordinates settings owned by individual modules without changing their
-- persistence formats. UI code should use this registry rather than mutating
-- module state directly.
DMSettings = DMSettings or {}

DMSettings.registry = DMSettings.registry or {}
DMSettings.order = DMSettings.order or {}

local function trim(value)
  return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function validateBoolean(value)
  if type(value) ~= "boolean" then
    return false, "Expected true or false."
  end
  return true
end

local function validateInteger(value, minimum, maximum)
  if type(value) ~= "number" or value ~= math.floor(value) then
    return false, "Expected a whole number."
  end
  if value < minimum or value > maximum then
    return false, ("Value must be between %d and %d."):format(minimum, maximum)
  end
  return true
end

local function validatePercent(value)
  return validateInteger(value, 0, 80)
end

local function validateRGB(value)
  local red, green, blue = tostring(value or ""):match("^(%d+),(%d+),(%d+)$")
  red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
  if not red or not green or not blue
      or red > 255 or green > 255 or blue > 255 then
    return false, "Use three comma-separated values from 0 to 255."
  end
  return true, nil, string.format("%d,%d,%d", red, green, blue)
end

local function validateRGBA(value)
  local red, green, blue, alpha = tostring(value or ""):match("^(%d+),(%d+),(%d+),(%d+)$")
  red, green, blue, alpha = tonumber(red), tonumber(green), tonumber(blue), tonumber(alpha)
  if not red or not green or not blue or not alpha
      or red > 255 or green > 255 or blue > 255 or alpha > 255 then
    return false, "Use four comma-separated values from 0 to 255."
  end
  return true, nil, string.format("%d,%d,%d,%d", red, green, blue, alpha)
end

local function validateOptionalText(value)
  value = trim(value)
  if #value > 80 then
    return false, "Value is too long."
  end
  return true, nil, value == "" and nil or value
end

local function validateEnum(value, choices)
  for _, choice in ipairs(choices) do
    if value == choice.value then
      return true
    end
  end
  return false, "Choose one of the available values."
end

local function validateText(value)
  value = trim(value)
  if value == "" then
    return false, "Value cannot be empty."
  end
  if #value > 80 then
    return false, "Value is too long."
  end
  return true, nil, value
end

local knownColors = {
  black = true, blue = true, cyan = true, gray = true, green = true,
  magenta = true, orange = true, chocolate = true, pink = true, purple = true, red = true,
  sienna = true, silver = true, white = true, yellow = true, gold = true,
  olive = true, brown = true, violet = true,
  pale_goldenrod = true, dark_slate_blue = true, darkslateblue = true, slateblue = true,
  dark_red = true, dark_green = true, dark_blue = true, dark_yellow = true,
  dark_magenta = true, dark_cyan = true, dark_gray = true,
  light_red = true, light_green = true, light_blue = true, light_yellow = true,
  light_magenta = true, light_cyan = true, light_gray = true,
  ansired = true, ansilightred = true, ansiyellow = true, ansilightyellow = true,
  ansiblue = true, ansilightblue = true, ansicyan = true, ansilightcyan = true,
  ansimagenta = true, ansilightmagenta = true, ansigreen = true, ansilightgreen = true,
  ansiwhite = true, ansilightwhite = true, ansiblack = true, ansilightblack = true,
}

local colorChoices = {
  {value = "ansiRed"},
  {value = "ansiLightRed"},
  {value = "IndianRed"},
  {value = "LightCoral"},
  {value = "sienna"},
  {value = "chocolate"},
  {value = "coral"},
  {value = "LightSalmon"},
  {value = "ansiYellow"},
  {value = "ansiLightYellow"},
  {value = "LightGoldenrod"},
  {value = "PaleGoldenrod"},
  {value = "ansiGreen"},
  {value = "ansiLightGreen"},
  {value = "LawnGreen"},
  {value = "PaleGreen"},
  {value = "DarkSlateGray"},
  {value = "ansiCyan"},
  {value = "ansiLightCyan"},
  {value = "PaleTurquoise"},
  {value = "ansiBlue"},
  {value = "ansiLightBlue"},
  {value = "SteelBlue"},
  {value = "LightSkyBlue"},
  {value = "DarkSlateBlue"},
  {value = "SlateBlue"},
  {value = "MediumPurple"},
  {value = "LightSteelBlue"},
  {value = "ansiMagenta"},
  {value = "ansiLightMagenta"},
  {value = "MediumOrchid"},
  {value = "Pink"},
  {value = "ansiBlack"},
  {value = "ansiLightBlack"},
  {value = "ansiWhite"},
  {value = "ansiLightWhite"},
}

for _, choice in ipairs(colorChoices) do
  knownColors[choice.value:lower()] = true
end

local function validateColor(value)
  local normalized = trim(value):lower()
  if not knownColors[normalized] then
    return false, "Use a supported Mudlet color name."
  end
  for _, choice in ipairs(colorChoices) do
    if choice.value:lower() == normalized then
      return true, nil, choice.value
    end
  end
  return true, nil, normalized
end

function DMSettings.register(definition)
  if type(definition) ~= "table" or type(definition.key) ~= "string" then
    return false, "A setting key is required."
  end
  if DMSettings.registry[definition.key] == nil then
    table.insert(DMSettings.order, definition.key)
  end
  DMSettings.registry[definition.key] = definition
  return true
end

function DMSettings.get(key)
  return DMSettings.registry[key]
end

function DMSettings.list(group)
  local result = {}
  for _, key in ipairs(DMSettings.order) do
    local setting = DMSettings.registry[key]
    if setting and (not group or setting.group == group) then
      table.insert(result, setting)
    end
  end
  return result
end

function DMSettings.value(key)
  local setting = DMSettings.get(key)
  if not setting then return nil end
  if setting.get then return setting.get() end
  return setting.default
end

function DMSettings.set(key, value)
  local setting = DMSettings.get(key)
  if not setting then
    return false, "Unknown setting: " .. tostring(key)
  end

  local normalized = value
  if setting.validate then
    local ok, message, valueResult = setting.validate(value)
    if not ok then return false, message end
    normalized = valueResult ~= nil and valueResult or value
  end

  local ok, message = true, nil
  if setting.set then
    ok, message = setting.set(normalized)
  end
  if not ok then return false, message end

  if setting.save then
    local saved, saveError = pcall(setting.save, normalized)
    if not saved then
      return false, "Could not save setting: " .. tostring(saveError)
    end
  end

  return true
end

function DMSettings.reloadRequired(setting)
  if not setting then return false end
  if type(setting.reloadRequired) == "function" then
    return setting.reloadRequired()
  end
  return setting.reloadRequired == true
end

local function saveEnchanterAssist()
  if EnchanterAssist and EnchanterAssist.save then
    EnchanterAssist.save()
  end
end

local function setEnchanterAssist(field, value)
  if not EnchanterAssist then
    return false, "Enchanter Assist is not loaded."
  end
  if field == "enabled" and EnchanterAssist.setEnabled then
    return EnchanterAssist.setEnabled(value)
  end
  if field == "autoRun" and EnchanterAssist.setAutoRun then
    return EnchanterAssist.setAutoRun(value)
  end
  EnchanterAssist[field] = value
  if field == "partCount" then
    EnchanterAssist._comboIndices = nil
  end
  return true
end

local function registerEnchanterAssist()
  local definitions = {
    {
      key = "enchanterAssist.partCount",
      group = "Enchanter Assist", section = "Configuration",
      label = "Materials per trial",
      description = "How many different materials to combine in each trial.",
      type = "integer",
      default = 5,
      get = function() return EnchanterAssist.partCount end,
      validate = function(value) return validateInteger(value, 1, 5) end,
      set = function(value) return setEnchanterAssist("partCount", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.container",
      group = "Enchanter Assist", section = "Configuration",
      label = "Materials container",
      description = "Container holding the key and alchemy materials, such as bag.",
      type = "text",
      default = "bag",
      get = function() return EnchanterAssist.container end,
      validate = validateText,
      set = function(value) return setEnchanterAssist("container", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.sleeper",
      group = "Enchanter Assist", section = "Recovery",
      label = "Resting item",
      description = "Item used when resting to recover, such as bedroll.",
      type = "text",
      default = "bedroll",
      get = function() return EnchanterAssist.sleeper end,
      validate = validateText,
      set = function(value) return setEnchanterAssist("sleeper", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.sleepType",
      group = "Enchanter Assist", section = "Recovery",
      label = "Recovery method",
      description = "Choose sleeping or consumables when mana and movement are low.",
      type = "enum",
      choices = {{value = 1, label = "Sleep"}, {value = 0, label = "Consumables"}},
      default = 1,
      get = function() return EnchanterAssist.sleepType end,
      validate = function(value) return validateEnum(value, {{value = 1}, {value = 0}}) end,
      set = function(value) return setEnchanterAssist("sleepType", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.drainItem",
      group = "Enchanter Assist", section = "Recovery",
      label = "Mana-drain item",
      description = "Potion or other item used to drain mana during consumable recovery.",
      type = "text",
      default = "potion",
      get = function() return EnchanterAssist.drainItem end,
      validate = validateText,
      set = function(value) return setEnchanterAssist("drainItem", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.playSoundOnDiscover",
      group = "Enchanter Assist", section = "Workflow",
      label = "Play discovery sound",
      description = "Play a sound when a new formula is discovered.",
      type = "boolean",
      default = true,
      get = function() return EnchanterAssist.playSoundOnDiscover end,
      validate = validateBoolean,
      set = function(value) return setEnchanterAssist("playSoundOnDiscover", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.deterministicOrder",
      group = "Enchanter Assist", section = "Workflow",
      label = "Try combinations in sequence",
      description = "Use repeatable sequential combinations instead of random selection.",
      type = "boolean",
      default = false,
      get = function() return EnchanterAssist.deterministicOrder end,
      validate = validateBoolean,
      set = function(value) return setEnchanterAssist("deterministicOrder", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.enabled",
      group = "Enchanter Assist", section = "Workflow",
      label = "Enchanter Assist enabled",
      description = "Allow Enchanter Assist to process events and run trials.",
      type = "boolean",
      default = true,
      get = function() return EnchanterAssist.enabled end,
      validate = validateBoolean,
      set = function(value) return setEnchanterAssist("enabled", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.autoRun",
      group = "Enchanter Assist", section = "Workflow",
      label = "Automatic run mode",
      description = "Automatically begin another trial after recovery or completion.",
      type = "boolean",
      default = false,
      get = function() return EnchanterAssist.autoRun end,
      validate = validateBoolean,
      set = function(value) return setEnchanterAssist("autoRun", value) end,
      save = saveEnchanterAssist,
    },
  }

  for _, definition in ipairs(definitions) do
    DMSettings.register(definition)
  end
end

local function getGlobalSetting(key, default)
  if Darkmists and Darkmists.GlobalSettings and Darkmists.GlobalSettings[key] ~= nil then
    return Darkmists.GlobalSettings[key]
  end
  return default
end

local function saveGlobalSettings()
  if Darkmists and Darkmists.SaveSettings then Darkmists.SaveSettings() end
end

local function globalValue(key, default)
  return getGlobalSetting(key, default)
end

local function setGlobalValue(key, value)
  Darkmists.GlobalSettings[key] = value
  return true
end

local function getBorderPercent(region)
  local borders = Darkmists.GlobalSettings.borders or {}
  if Darkmists.GetBorderPercentages then
    local current = Darkmists.GetBorderPercentages()
    if current and current[region] then
      return math.floor(current[region] + 0.5)
    end
  end
  return borders[region] or 0
end

local function setBorderPercent(region, value)
  local borders = Darkmists.GlobalSettings.borders or {}
  local opposite = (region == "left" or region == "right")
    and ((region == "left") and "right" or "left")
    or ((region == "top") and "bottom" or "top")
  if value + (borders[opposite] or 0) > 95 then
    return false, "Opposing borders must leave at least 5% of the window."
  end
  if not Darkmists.SetWindowBorderPercent then
    return false, "Window border controls are unavailable."
  end
  Darkmists.SetWindowBorderPercent(region, value)
  return true
end

local function setStatusBarEnabled(value)
  setGlobalValue("statusBarsEnabled", value)
  if StatusBar and StatusBar.container then
    if value and StatusBar.enable then StatusBar.enable() end
    if not value and StatusBar.disable then StatusBar.disable() end
  end
  return true
end

local function setStatusBarMoveable(value)
  setGlobalValue("statusBarsMoveable", value)
  if StatusBar and StatusBar.container and StatusBar.setMoveable then
    StatusBar.setMoveable(value)
  end
  return true
end

local function setStatusBarHeight(value)
  setGlobalValue("statusBarTotalHeightPercent", value)
  if StatusBar and StatusBar.container and StatusBar.setTotalHeightPercent then
    StatusBar.setTotalHeightPercent(value)
  end
  return true
end

local function getStatusBarColor(region, field, default)
  local colors = Darkmists.GlobalSettings.statusBarColors or {}
  local regionColors = colors[region] or {}
  return regionColors[field] or default
end

local function setStatusBarColor(region, field, value)
  local colors = Darkmists.GlobalSettings.statusBarColors or {}
  colors[region] = colors[region] or {}
  colors[region][field] = value
  Darkmists.GlobalSettings.statusBarColors = colors

  if StatusBar and StatusBar.container then
    if StatusBar.config then StatusBar.config.colors = colors end
    if StatusBar.recreate then
      pcall(StatusBar.recreate)
    elseif StatusBar.refreshColors then
      pcall(StatusBar.refreshColors)
    end
  end
  return true
end

local function setItemTrackerLinkColor(key, value)
  setGlobalValue(key, value)
  if ItemTracker and ItemTracker.refreshThemeColors then
    ItemTracker.refreshThemeColors()
  end
  return true
end

local function setAffectsConfig(key, value)
  setGlobalValue(key, value)
  if AffectsWindow and AffectsWindow.refreshConfig then
    AffectsWindow.refreshConfig()
    if AffectsWindow.startAgeTimer then AffectsWindow.startAgeTimer() end
    if AffectsWindow.refreshDisplay then AffectsWindow.refreshDisplay() end
  end
  return true
end

local function setWhoConfig(value)
  setGlobalValue("whoWindowDeleteOriginalLines", value)
  if WhoWindow then WhoWindow.config.deleteOriginalLines = value end
  return true
end

local function setChatHistoryMax(value)
  setGlobalValue("chatHistoryMaxMessages", value)
  if ChatHistory and ChatHistory.setMaxMessages then ChatHistory.setMaxMessages(value) end
  return true
end

local function setSkillUpsMax(value)
  setGlobalValue("skillUpsMaxEntries", value)
  if SkillUps and SkillUps.setMaxEntries then SkillUps.setMaxEntries(value) end
  return true
end

local function setSpamConfig(key, value)
  setGlobalValue(key, value)
  if SpamPrevention then
    if key == "spamEnabled" then SpamPrevention.enabled = value end
    if key == "spamThreshold" then SpamPrevention.threshold = value end
    if key == "spamMinLength" then SpamPrevention.minLength = value end
    if key == "spamFallbackCommand" then SpamPrevention.fallbackCommand = value end
  end
  return true
end

local function setStatRollerConfig(key, field, value)
  setGlobalValue(key, value)
  if StatRoller and StatRoller.settings then StatRoller.settings[field] = value end
  return true
end

local function setMakeArmorConfig(key, field, value)
  setGlobalValue(key, value)
  if MakeArmor then MakeArmor[field] = value end
  return true
end

local function registerDefinitions(definitions)
  for _, definition in ipairs(definitions) do
    DMSettings.register(definition)
  end
end

local function refreshSharedFont(fontName)
  if ChatHistory then
    if ChatHistory.applyTheme then ChatHistory.applyTheme() end
    if ChatHistory.console then ChatHistory.console:setFont(fontName) end
  end
  if WhoWindow then
    WhoWindow.config.fontName = fontName
    if WhoWindow.console then WhoWindow.console:setFont(fontName) end
  end
  if AffectsWindow then
    if AffectsWindow.refreshConfig then AffectsWindow.refreshConfig() end
    if AffectsWindow.console then AffectsWindow.console:setFont(fontName) end
  end
  if ScorePanel then
    if ScorePanel.applyTheme then ScorePanel.applyTheme() end
    if ScorePanel.console then ScorePanel.console:setFont(fontName) end
  end
  if DarkMistsMiniMap and DarkMistsMiniMap.header then
    DarkMistsMiniMap.header:setFont(fontName)
  end
end

local function registerAppearance()
  registerDefinitions({
    {
      key = "appearance.themeMode", page = "Appearance", group = "Appearance",
      label = "Theme mode", type = "enum",
      choices = {{value = false, label = "Dark Mode"}, {value = true, label = "Light Mode"}},
      default = false,
      get = function()
        local settings = Darkmists.GlobalSettings
        if settings.pendingThemeMode ~= nil then return settings.pendingThemeMode end
        return settings.lightMode == true
      end,
      validate = function(value) return validateEnum(value, {{value = false}, {value = true}}) end,
      set = function(value) Darkmists.GlobalSettings.pendingThemeMode = value; return true end,
      save = saveGlobalSettings, reloadRequired = true,
    },
    {
      key = "appearance.fullUI", page = "Appearance", group = "Appearance",
      label = "Full UI", type = "boolean", default = false,
      get = function() return not globalValue("minimalMode", true) end,
      validate = validateBoolean,
      set = function(value) Darkmists.GlobalSettings.minimalMode = not value; return true end,
      save = saveGlobalSettings, reloadRequired = true,
    },
    {
      key = "appearance.fontSize", page = "Appearance", group = "Appearance",
      label = "Font size", type = "integer", default = 12,
      get = function() return globalValue("fontSize", 12) end,
      validate = function(value) return validateInteger(value, 8, 24) end,
      set = function(value) return setGlobalValue("fontSize", value) end,
      save = saveGlobalSettings, reloadRequired = true,
    },
    {
      key = "appearance.fontName", page = "Appearance", group = "Appearance",
      label = "Window font",
      description = "Font face used by the Chat, Who, Affects, and Player windows.",
      type = "text", default = getFont(),
      get = function() return globalValue("fontName", getFont()) end,
      validate = validateText,
      set = function(value)
        setGlobalValue("fontName", value)
        refreshSharedFont(value)
        return true
      end,
      save = saveGlobalSettings,
    },
    {
      key = "appearance.updateChannel", page = "Appearance", group = "Appearance",
      label = "Update channel",
      description = "Choose stable releases or beta builds when updating DMC.",
      type = "enum",
      choices = {{value = "stable", label = "Stable"}, {value = "beta", label = "Beta"}},
      default = "stable",
      get = function() return globalValue("updateChannel", "stable") end,
      validate = function(value)
        return validateEnum(value, {{value = "stable"}, {value = "beta"}})
      end,
      set = function(value) return setGlobalValue("updateChannel", value) end,
      save = saveGlobalSettings,
    },
  })

  for _, region in ipairs({"top", "bottom", "left", "right"}) do
    DMSettings.register({
      key = "appearance.border." .. region, page = "Appearance", group = "Borders",
      label = region:gsub("^%l", string.upper) .. " border %", type = "integer", default = 0,
      get = function() return getBorderPercent(region) end,
      validate = validatePercent,
      set = function(value) return setBorderPercent(region, value) end,
      save = saveGlobalSettings,
    })
  end
end

local function registerStatusBars()
  registerDefinitions({
    {
      key = "statusBars.enabled", page = "Status Bars", group = "Status Bars",
      label = "Enabled", type = "boolean", default = true,
      get = function() return globalValue("statusBarsEnabled", true) end,
      validate = validateBoolean, set = setStatusBarEnabled, save = saveGlobalSettings,
      reloadRequired = function() return not (StatusBar and StatusBar.container) end,
    },
    {
      key = "statusBars.moveable", page = "Status Bars", group = "Status Bars",
      label = "Moveable", type = "boolean", default = true,
      get = function() return globalValue("statusBarsMoveable", true) end,
      validate = validateBoolean, set = setStatusBarMoveable, save = saveGlobalSettings,
      reloadRequired = function() return not (StatusBar and StatusBar.container) end,
    },
    {
      key = "statusBars.totalHeight", page = "Status Bars", group = "Status Bars",
      label = "Total height %", type = "integer", default = 10,
      get = function() return globalValue("statusBarTotalHeightPercent", 10) end,
      validate = function(value) return validateInteger(value, 1, 40) end,
      set = setStatusBarHeight, save = saveGlobalSettings,
      reloadRequired = function() return not (StatusBar and StatusBar.container) end,
    },
  })

  local colorDefinitions = {
    {region = "hp", field = "bar", label = "HP foreground", default = "128,0,0,255"},
    {region = "hp", field = "backdrop", label = "HP background", default = "32,0,0,255"},
    {region = "mn", field = "bar", label = "MN foreground", default = "0,0,128,255"},
    {region = "mn", field = "backdrop", label = "MN background", default = "0,0,32,255"},
    {region = "mv", field = "bar", label = "MV foreground", default = "128,128,0,255"},
    {region = "mv", field = "backdrop", label = "MV background", default = "32,32,0,255"},
    {region = "enemy", field = "bar", label = "Enemy foreground", default = "128,0,0,255"},
    {region = "enemy", field = "backdrop", label = "Enemy background", default = "32,0,0,255"},
    {region = "xp", field = "bar", label = "XP foreground", default = "128,64,0,255"},
    {region = "xp", field = "backdrop", label = "XP background", default = "32,16,0,255"},
  }

  for _, colorDefinition in ipairs(colorDefinitions) do
    local definition = colorDefinition
    DMSettings.register({
      key = "statusBars." .. definition.region .. "." .. definition.field,
      page = "Status Bars", group = "Status Bars",
      label = definition.label, type = "rgba", default = definition.default,
      get = function()
        return getStatusBarColor(definition.region, definition.field, definition.default)
      end,
      validate = validateRGBA,
      set = function(value)
        return setStatusBarColor(definition.region, definition.field, value)
      end,
      save = saveGlobalSettings,
    })
  end
end

local function registerItemTracker()
  registerDefinitions({
    {
      key = "itemTracker.linkColorDarkMode", page = "ItemTracker", group = "ItemTracker",
      label = "Dark mode link color", type = "color", choices = colorChoices,
      default = "PaleGoldenrod",
      get = function() return globalValue("itemTrackerLinkColorDarkMode", "PaleGoldenrod") end,
      validate = function(value) return validateColor(value) end,
      set = function(value) return setItemTrackerLinkColor("itemTrackerLinkColorDarkMode", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "itemTracker.linkColorLightMode", page = "ItemTracker", group = "ItemTracker",
      label = "Light mode link color", type = "color", choices = colorChoices,
      default = "DarkSlateBlue",
      get = function() return globalValue("itemTrackerLinkColorLightMode", "DarkSlateBlue") end,
      validate = function(value) return validateColor(value) end,
      set = function(value) return setItemTrackerLinkColor("itemTrackerLinkColorLightMode", value) end,
      save = saveGlobalSettings,
    },
  })
end

local function registerWindows()
  registerDefinitions({
    {
      key = "windows.affectsInterval", page = "Windows", group = "Affects Window",
      label = "Refresh interval", type = "integer", default = 2,
      get = function() return globalValue("affectsWindowUpdateIntervalSeconds", 2) end,
      validate = function(value) return validateInteger(value, 1, 60) end,
      set = function(value) return setAffectsConfig("affectsWindowUpdateIntervalSeconds", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "windows.affectsNameLength", page = "Windows", group = "Affects Window",
      label = "Affect name length", type = "integer", default = 20,
      get = function() return globalValue("affectsWindowAffectNameLength", 20) end,
      validate = function(value) return validateInteger(value, 5, 80) end,
      set = function(value) return setAffectsConfig("affectsWindowAffectNameLength", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "windows.affectsModLength", page = "Windows", group = "Affects Window",
      label = "Affect modifier length", type = "integer", default = 16,
      get = function() return globalValue("affectsWindowAffectModLength", 16) end,
      validate = function(value) return validateInteger(value, 5, 80) end,
      set = function(value) return setAffectsConfig("affectsWindowAffectModLength", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "windows.affectsDeleteOriginal", page = "Windows", group = "Affects Window",
      label = "Delete original affects", type = "boolean", default = false,
      get = function() return globalValue("affectsWindowDeleteOriginalLines", false) end,
      validate = validateBoolean,
      set = function(value) return setAffectsConfig("affectsWindowDeleteOriginalLines", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "windows.whoDeleteOriginal", page = "Windows", group = "Who Window",
      label = "Delete original who", type = "boolean", default = false,
      get = function() return globalValue("whoWindowDeleteOriginalLines", false) end,
      validate = validateBoolean, set = setWhoConfig, save = saveGlobalSettings,
    },
    {
      key = "windows.chatMaxMessages", page = "Windows", group = "Chat History",
      label = "Maximum messages", type = "integer", default = 100,
      get = function() return globalValue("chatHistoryMaxMessages", 100) end,
      validate = function(value) return validateInteger(value, 10, 2000) end,
      set = setChatHistoryMax, save = saveGlobalSettings,
    },
    {
      key = "windows.skillMaxEntries", page = "Windows", group = "SkillUps",
      label = "Maximum entries", type = "integer", default = 50,
      get = function() return globalValue("skillUpsMaxEntries", 50) end,
      validate = function(value) return validateInteger(value, 5, 500) end,
      set = setSkillUpsMax, save = saveGlobalSettings,
    },
  })
end

local function registerUtilities()
  registerDefinitions({
    {
      key = "spam.enabled", page = "Utilities", group = "Spam Prevention",
      label = "Enabled", type = "boolean", default = true,
      get = function() return globalValue("spamEnabled", true) end,
      validate = validateBoolean,
      set = function(value) return setSpamConfig("spamEnabled", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "spam.threshold", page = "Utilities", group = "Spam Prevention",
      label = "Repeat threshold", type = "integer", default = 24,
      get = function() return globalValue("spamThreshold", 24) end,
      validate = function(value) return validateInteger(value, 1, 1000) end,
      set = function(value) return setSpamConfig("spamThreshold", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "spam.minLength", page = "Utilities", group = "Spam Prevention",
      label = "Minimum command length", type = "integer", default = 3,
      get = function() return globalValue("spamMinLength", 3) end,
      validate = function(value) return validateInteger(value, 1, 20) end,
      set = function(value) return setSpamConfig("spamMinLength", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "spam.fallback", page = "Utilities", group = "Spam Prevention",
      label = "Fallback command", type = "text", default = "save",
      get = function() return globalValue("spamFallbackCommand", "save") end,
      validate = validateOptionalText,
      set = function(value) return setSpamConfig("spamFallbackCommand", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "statRoller.leniency", page = "Utilities", group = "Stat Roller",
      label = "Leniency", type = "integer", default = 1,
      get = function() return globalValue("statRollerLeniency", 1) end,
      validate = function(value) return validateInteger(value, 0, 3) end,
      set = function(value) return setStatRollerConfig("statRollerLeniency", "leniency", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "statRoller.calibrationLines", page = "Utilities", group = "Stat Roller",
      label = "Calibration rolls", type = "integer", default = 20,
      get = function() return globalValue("statRollerCalibrationLines", 20) end,
      validate = function(value) return validateInteger(value, 4, 40) end,
      set = function(value) return setStatRollerConfig("statRollerCalibrationLines", "nCalibrationLines", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "statRoller.showDetails", page = "Utilities", group = "Stat Roller",
      label = "Show stat details", type = "boolean", default = true,
      get = function() return globalValue("statRollerShowDetails", true) end,
      validate = validateBoolean,
      set = function(value) return setStatRollerConfig("statRollerShowDetails", "showDetails", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "statRoller.sparklineWidth", page = "Utilities", group = "Stat Roller",
      label = "Sparkline width", type = "integer", default = 16,
      get = function() return globalValue("statRollerSparklineWidth", 16) end,
      validate = function(value) return validateInteger(value, 4, 40) end,
      set = function(value) return setStatRollerConfig("statRollerSparklineWidth", "sparklineWidth", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "makeArmor.sleeper", page = "Utilities", group = "MakeArmor",
      label = "Sleeper", type = "text", default = "bedroll",
      get = function() return globalValue("makearmorSleeper", "bedroll") end,
      validate = validateText,
      set = function(value) return setMakeArmorConfig("makearmorSleeper", "sleeper", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "makeArmor.container", page = "Utilities", group = "MakeArmor",
      label = "Container", type = "text", default = "bag",
      get = function() return globalValue("makearmorContainer", "bag") end,
      validate = validateText,
      set = function(value) return setMakeArmorConfig("makearmorContainer", "container", value) end,
      save = saveGlobalSettings,
    },
    {
      key = "makeArmor.defaultThreshold", page = "Utilities", group = "MakeArmor",
      label = "Default threshold", type = "integer", default = 15,
      get = function() return globalValue("makearmorDefaultMinimumTotal", 15) end,
      validate = function(value) return validateInteger(value, 5, 20) end,
      set = function(value) return setMakeArmorConfig("makearmorDefaultMinimumTotal", "defaultMinimumTotal", value) end,
      save = saveGlobalSettings,
    },
  })
end

local function registerAdvanced()
  registerDefinitions({
    {
      key = "advanced.statusBarFontColor", page = "Status Bars", group = "Status Bars",
      label = "Status bar font RGB", type = "text", default = "255,255,255",
      get = function() return globalValue("statusBarFontColor", "255,255,255") end,
      validate = validateRGB,
      set = function(value)
        setGlobalValue("statusBarFontColor", value)
        if StatusBar and StatusBar.config then StatusBar.config.fontColor = value end
        return true
      end,
      save = saveGlobalSettings, reloadRequired = true,
    },
  })
end

local function registerShowDamage()
  local definitions = {
    {
      key = "showDamage.enabled",
      group = "ShowDMG",
      label = "Damage messages",
      type = "boolean",
      default = true,
      get = function() return getGlobalSetting("damageMessageEnabled", true) end,
      validate = validateBoolean,
      set = function(value)
        Darkmists.GlobalSettings.damageMessageEnabled = value
        if value then enableTrigger("DamageMessages") else disableTrigger("DamageMessages") end
        return true
      end,
      save = saveGlobalSettings,
    },
    {
      key = "showDamage.mode",
      group = "ShowDMG",
      label = "Damage mode",
      type = "enum",
      choices = {
        {value = "avg", label = "Average"},
        {value = "range", label = "Range"},
        {value = "both", label = "Both"},
      },
      default = "avg",
      get = function() return getGlobalSetting("damageMessageMode", "avg") end,
      validate = function(value)
        return validateEnum(value, {
          {value = "avg"}, {value = "range"}, {value = "both"},
        })
      end,
      set = function(value) Darkmists.GlobalSettings.damageMessageMode = value; return true end,
      save = saveGlobalSettings,
    },
    {
      key = "showDamage.color",
      group = "ShowDMG",
      label = "Damage color",
      type = "color",
      choices = colorChoices,
      default = "red",
      get = function() return getGlobalSetting("damageMessageColor", "red") end,
      validate = validateColor,
      set = function(value) Darkmists.GlobalSettings.damageMessageColor = value; return true end,
      save = saveGlobalSettings,
    },
  }

  for _, definition in ipairs(definitions) do
    DMSettings.register(definition)
  end
end

registerEnchanterAssist()
registerShowDamage()
registerAppearance()
registerStatusBars()
registerItemTracker()
registerWindows()
registerUtilities()
registerAdvanced()