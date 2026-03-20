-- =============================================================================
-- ThemeManager.lua
-- =============================================================================
---@type DarkmistsTheme
DarkmistsTheme = DarkmistsTheme or {}

-- Session guard to avoid repeating background warnings
local _dm_theme_bg_warn_shown = false

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
  t.red       = "indian_red"
  t.orange    = "peru"
  t.yellow    = "dark_goldenrod"
  t.green     = "medium_sea_green"
  t.blue      = "steel_blue"
  t.cyan      = "cadet_blue"
  t.sky       = "light_steel_blue"
  t.lightBlue = "cornflower_blue"
  t.darkBlue  = "dark_slate_blue"
  t.purple    = "medium_purple"
  t.pink      = "pale_violet_red"
  t.brown     = "sienna"
  t.olive     = "olive_drab"
  t.silver    = "slate_gray"
  t.gold      = "goldenrod"
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

-- Detect main background color and warn/offer to switch theme for contrast
-- Exposed as DarkmistsTheme.checkBackgroundContrast() so Init() can call it
-- explicitly after ShowUIIntroMessage, keeping buildTheme() side-effect free.
function DarkmistsTheme.checkBackgroundContrast()
  if _dm_theme_bg_warn_shown then return end
  if not Darkmists or not Darkmists.GlobalSettings then return end

  local ok, r, g, b, a = pcall(getBackgroundColor, "main")
  if not ok or type(r) ~= "number" then
    -- try without param as some Mudlet builds map to default
    ok, r, g, b, a = pcall(getBackgroundColor)
  end
  if not ok or type(r) ~= "number" then return end

  -- perceived luminance formula (0-255 scale)
  local L = 0.2126 * r + 0.7152 * g + 0.0722 * b
  local isLightBg = (L >= 200)

  -- If background is light but theme is dark, suggest switching to light
  if isLightBg and not Darkmists.GlobalSettings.lightMode then
    _dm_theme_bg_warn_shown = true
    DMAlertWindow.Show("Theme Contrast Notice", function(win)
      cecho(win, "\nDetected a light/white terminal background while Dark Mode is enabled.\n\n")
      cecho(win, "For readability, switch to Light Mode or keep Dark Mode if you prefer.\n\n")
      cechoLink(win, "<dim_gray><u>[<green>Switch to Light Mode<dim_gray>]",
        [[DMAlertWindow.Hide(); Darkmists.GlobalSettings.lightMode = true; Darkmists.GlobalSettings.hasSeenUIIntroMessage = false; Darkmists.SaveSettings(); DarkmistsTheme.buildTheme(); Darkmists.SafeReload();]],
        "Switch to Light Mode for better contrast", true)
      cechoLink(win, "  <dim_gray><u>[<red>Ignore<dim_gray>]",
        [[DMAlertWindow.Hide()]],
        "Keep current theme", true)
    end, { width = 520, height = 200 })
    return
  end

  -- If background is dark but theme is light, suggest switching to dark
  if (not isLightBg) and Darkmists.GlobalSettings.lightMode then
    _dm_theme_bg_warn_shown = true
    DMAlertWindow.Show("Theme Contrast Notice", function(win)
      cecho(win, "\nDetected a dark/black terminal background while Light Mode is enabled.\n\n")
      cecho(win, "For readability, switch to Dark Mode or keep Light Mode if you prefer.\n\n")
      cechoLink(win, "<dim_gray><u>[<green>Switch to Dark Mode<dim_gray>]",
        [[DMAlertWindow.Hide(); Darkmists.GlobalSettings.lightMode = false; Darkmists.GlobalSettings.hasSeenUIIntroMessage = false; Darkmists.SaveSettings(); DarkmistsTheme.buildTheme(); Darkmists.SafeReload();]],
        "Switch to Dark Mode for better contrast", true)
      cechoLink(win, "  <dim_gray><u>[<red>Ignore<dim_gray>]",
        [[DMAlertWindow.Hide()]],
        "Keep current theme", true)
    end, { width = 520, height = 200 })
    return
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
  t.yellow = light and "goldenrod"         or "yellow"
  t.green  = light and "sea_green"         or "spring_green"
  t.blue   = light and "royal_blue"        or "deep_sky_blue"
  t.cyan   = light and "cadet_blue"        or "ansi_cyan"
  t.sky    = light and "steel_blue"        or "light_steel_blue"
  t.lightBlue = "cornflower_blue"
  t.darkBlue  = "dark_slate_blue"
  t.purple = light and "dark_violet"       or "medium_purple"
  t.pink   = light and "medium_violet_red" or "deep_pink"
  t.brown  = light and "sienna"            or "peru"
  t.olive  = light and "olive_drab"        or "yellow_green"
  t.silver = light and "slate_gray"        or "light_gray"
  t.gold   = light and "goldenrod"         or "gold"

  -- Semantic aliases
  t.good      = t.green
  t.warn      = t.orange
  t.bad       = t.red
  t.info      = t.blue
  t.muted     = light and "dim_gray"   or "slate_gray"
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
        "<%s:%s> %-8s <%s:%s> Sample Text <reset>\n",
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