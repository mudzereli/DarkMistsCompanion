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
  magenta = true, orange = true, pink = true, purple = true, red = true,
  sienna = true, silver = true, white = true, yellow = true, gold = true,
  olive = true, brown = true, violet = true,
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
  {value = "ansiRed", label = "Dark Red"},
  {value = "ansiLightRed", label = "Red"},
  {value = "ansiYellow", label = "Dark Yellow"},
  {value = "ansiLightYellow", label = "Yellow"},
  {value = "ansiBlue", label = "Dark Blue"},
  {value = "ansiLightBlue", label = "Blue"},
  {value = "ansiCyan", label = "Dark Cyan"},
  {value = "ansiLightCyan", label = "Cyan"},
  {value = "ansiMagenta", label = "Dark Magenta"},
  {value = "ansiLightMagenta", label = "Magenta"},
  {value = "ansiGreen", label = "Dark Green"},
  {value = "ansiLightGreen", label = "Green"},
  {value = "ansiWhite", label = "Dark White"},
  {value = "ansiLightWhite", label = "White"},
  {value = "ansiBlack", label = "Dark Black"},
  {value = "ansiLightBlack", label = "Black"},
}

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

local function saveEnchanterAssist()
  if EnchanterAssist and EnchanterAssist.save then
    EnchanterAssist.save()
  end
end

local function setEnchanterAssist(field, value)
  if not EnchanterAssist then
    return false, "Enchanter Assist is not loaded."
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
      group = "Enchanter Assist",
      label = "Parts per trial",
      type = "integer",
      default = 5,
      get = function() return EnchanterAssist.partCount end,
      validate = function(value) return validateInteger(value, 1, 5) end,
      set = function(value) return setEnchanterAssist("partCount", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.container",
      group = "Enchanter Assist",
      label = "Container",
      type = "text",
      default = "bag",
      get = function() return EnchanterAssist.container end,
      validate = validateText,
      set = function(value) return setEnchanterAssist("container", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.sleeper",
      group = "Enchanter Assist",
      label = "Sleeper",
      type = "text",
      default = "bedroll",
      get = function() return EnchanterAssist.sleeper end,
      validate = validateText,
      set = function(value) return setEnchanterAssist("sleeper", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.sleepType",
      group = "Enchanter Assist",
      label = "Recovery method",
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
      group = "Enchanter Assist",
      label = "Drain item",
      type = "text",
      default = "potion",
      get = function() return EnchanterAssist.drainItem end,
      validate = validateText,
      set = function(value) return setEnchanterAssist("drainItem", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.playSoundOnDiscover",
      group = "Enchanter Assist",
      label = "Sound on discovery",
      type = "boolean",
      default = true,
      get = function() return EnchanterAssist.playSoundOnDiscover end,
      validate = validateBoolean,
      set = function(value) return setEnchanterAssist("playSoundOnDiscover", value) end,
      save = saveEnchanterAssist,
    },
    {
      key = "enchanterAssist.deterministicOrder",
      group = "Enchanter Assist",
      label = "Deterministic order",
      type = "boolean",
      default = false,
      get = function() return EnchanterAssist.deterministicOrder end,
      validate = validateBoolean,
      set = function(value) return setEnchanterAssist("deterministicOrder", value) end,
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