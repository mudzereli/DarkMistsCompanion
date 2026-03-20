-- =============================================================================
-- ThemeManager.lua
-- =============================================================================
---@type DarkmistsTheme
DarkmistsTheme = DarkmistsTheme or {}

-- Session guard to avoid repeating background contrast warnings
local _bgWarnShown = false

-- ---------------------------------------------------------------------------
-- Neutral theme: mid-value colors readable on both black and white backgrounds.
-- Runs immediately at file load with zero dependencies — no Darkmists, no
-- GlobalSettings needed. buildTheme() overwrites this once settings are loaded.
-- ---------------------------------------------------------------------------
local function buildTags(t)
  -- Collect keys first; cannot mutate the table while pairs() is iterating it
  -- (adding keys mid-iteration is undefined in Lua and can produce *TagTag etc.)
  local keys = {}
  for k, v in pairs(t) do
    if type(v) == "string" and not k:find("Tag$") then
      keys[#keys + 1] = k
    end
  end
  for _, k in ipairs(keys) do
    t[k .. "Tag"] = ("<%s>"):format(t[k])
  end
end

function DarkmistsTheme.buildNeutralTheme()
  local t = DarkmistsTheme
  -- Named hues
  t.red       = "indian_red"
  t.orange    = "peru"
  t.yellow    = "dark_goldenrod"
  t.green     = "medium_sea_green"
  t.blue      = "steel_blue"
  t.cyan      = "cadet_blue"
  t.sky       = "light_steel_blue"
  t.purple    = "medium_purple"
  t.pink      = "pale_violet_red"
  t.brown     = "sienna"
  t.olive     = "olive_drab"
  t.silver    = "slate_gray"
  t.gold      = "goldenrod"
  -- Semantic aliases
  t.good      = "medium_sea_green"
  t.warn      = "peru"
  t.bad       = "indian_red"
  t.info      = "steel_blue"
  t.muted     = "slate_gray"
  t.text      = "ansi_white"
  t.accent    = "cornflower_blue"
  t.highlight = "dark_goldenrod"
  buildTags(t)
end

-- Internal helper: show a DMAlertWindow prompting the user to switch theme modes.
-- switchToLight=true → recommend switching from dark to light; false → the reverse.
local function showContrastAlert(switchToLight)
  _bgWarnShown = true
  local bgDesc    = switchToLight and "light/white" or "dark/black"
  local modeDesc  = switchToLight and "Dark Mode"   or "Light Mode"
  local switchLbl = switchToLight and "Light Mode"  or "Dark Mode"
  local modeVal   = switchToLight and "true"        or "false"

  DMAlertWindow.Show("Theme Contrast Notice", function(win)
    cecho(win, string.format("\nDetected a %s terminal background while %s is enabled.\n\n", bgDesc, modeDesc))
    cecho(win, string.format("For readability, switch to %s or keep %s if you prefer.\n\n", switchLbl, modeDesc))
    cechoLink(win,
      string.format("<dim_gray><u>[<green>Switch to %s<dim_gray>]", switchLbl),
      string.format("DMAlertWindow.Hide(); Darkmists.GlobalSettings.lightMode = %s; Darkmists.GlobalSettings.hasSeenUIIntroMessage = false; Darkmists.SaveSettings(); DarkmistsTheme.buildTheme(); Darkmists.SafeReload();", modeVal),
      string.format("Switch to %s for better contrast", switchLbl),
      true)
    cechoLink(win, "  <dim_gray><u>[<red>Ignore<dim_gray>]",
      [[DMAlertWindow.Hide()]],
      "Keep current theme", true)
  end, { width = 520, height = 200 })
end

-- Detect main background color and warn/offer to switch theme for contrast.
-- Exposed as DarkmistsTheme.checkBackgroundContrast() so Init() can call it
-- explicitly after ShowUIIntroMessage, keeping buildTheme() side-effect free.
function DarkmistsTheme.checkBackgroundContrast()
  if _bgWarnShown then return end
  if not Darkmists or not Darkmists.GlobalSettings then return end

  local ok, r, g, b = pcall(getBackgroundColor, "main")
  if not ok or type(r) ~= "number" then
    -- try without param as some Mudlet builds map to default
    ok, r, g, b = pcall(getBackgroundColor)
  end
  if not ok or type(r) ~= "number" then return end

  -- perceived luminance formula (0-255 scale)
  local L = 0.2126 * r + 0.7152 * g + 0.0722 * b
  local isLightBg = (L >= 200)

  -- Suggest switching if background brightness and current theme mode are mismatched
  if isLightBg and not Darkmists.GlobalSettings.lightMode then
    showContrastAlert(true)   -- light bg + dark theme → suggest light mode
  elseif not isLightBg and Darkmists.GlobalSettings.lightMode then
    showContrastAlert(false)  -- dark bg + light theme → suggest dark mode
  end
end

-- ---------------------------------------------------------------------------
-- Build theme from GlobalSettings
-- ---------------------------------------------------------------------------
function DarkmistsTheme.buildTheme()
  local t     = DarkmistsTheme
  local light = Darkmists.GlobalSettings.lightMode

  -- Named hues
  t.red    = light and "firebrick"         or "tomato"
  t.orange = light and "chocolate"         or "orange"
  t.yellow = light and "dark_khaki"        or "khaki"
  t.green  = light and "sea_green"         or "spring_green"
  t.blue   = light and "steel_blue"        or "dodger_blue"
  t.cyan   = light and "dark_slate_gray"   or "medium_turquoise"
  t.sky    = light and "steel_blue"        or "light_steel_blue"
  t.purple = light and "dark_violet"       or "medium_purple"
  t.pink   = light and "medium_violet_red" or "deep_pink"
  t.brown  = light and "sienna"            or "peru"
  t.olive  = light and "olive_drab"        or "yellow_green"
  t.silver = light and "dim_gray"          or "slate_gray"
  t.gold   = light and "dark_khaki"        or "light_goldenrod"

  -- Semantic aliases
  t.good      = t.green
  t.warn      = t.orange
  t.bad       = t.red
  t.info      = t.blue
  t.muted     = t.silver
  t.text      = t.text
  t.accent    = t.cyan
  t.highlight = t.yellow

  buildTags(t)
  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core",
    (DarkmistsTheme.silverTag .. "Theme Built! Light Mode: %s%s%s"):format(DarkmistsTheme.infoTag, tostring(light), DarkmistsTheme.textTag))
end

-- ---------------------------------------------------------------------------
-- Internal helper used by test()
-- ---------------------------------------------------------------------------
local function printPalette(bg)
  local fg = (bg == "white") and "black" or "white"

  for key, value in pairs(DarkmistsTheme) do
    if type(value) == "string" and not key:find("Tag$") then
      cecho(string.format(
        "<%s:%s> %-10s <%s:%s> Sample Text <reset>\n",
        fg, bg, key, value, bg
      ))
    end
  end
end

-- =============================================================================
-- Theme test
-- =============================================================================
function DarkmistsTheme.test()
  if not Darkmists then return end
  local original = Darkmists.GlobalSettings.lightMode

  cecho("\n<white:black>  ═════════ DARK MODE (on black) ═════════  <reset>\n")
  Darkmists.GlobalSettings.lightMode = false
  DarkmistsTheme.buildTheme()
  printPalette("black")

  cecho("\n<black:white>  ═════════ LIGHT MODE (on white) ═════════  <reset>\n")
  Darkmists.GlobalSettings.lightMode = true
  DarkmistsTheme.buildTheme()
  printPalette("white")

  -- restore original state
  Darkmists.GlobalSettings.lightMode = original
  DarkmistsTheme.buildTheme()

  cecho("\n")
end