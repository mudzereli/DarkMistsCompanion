-- =============================================================================
-- ThemeManager.lua
-- =============================================================================
---@type DarkmistsTheme
---@diagnostic disable-next-line: missing-fields
DarkmistsTheme = {}

-- Session guard to avoid repeating background contrast warnings
local _bgWarnShown = false

-- Luminance cutoff for detecting a "light" terminal background (0-255 scale).
-- 200 is conservative — high enough to avoid dim/muted backdrops, low enough
-- to catch obvious light terminals. Tune for your terminal emulator if needed.
local LUMINANCE_LIGHT_CUTOFF = 200

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

  -- Panel header / button chrome (QSS colors) — safe pre-init defaults.
  -- Retro-terminal palette: near-black purple-tinted bar with purple accent.
  t.panel = {
    headerBg            = "rgba(20,10,40,35%)",
    sectionBg           = "rgba(8,4,18,60%)",
    headerBorder        = "rgba(150,120,255,22%)",
    headerAccent        = "rgba(150,120,255,45%)",
    buttonBg            = "rgba(20,10,40,30%)",
    buttonBorder        = "rgba(150,120,255,25%)",
    buttonHoverBg       = "rgba(150,120,255,14%)",
    buttonHoverFg       = "#ffd27a",
    buttonActiveBg      = "#7a5cff",
    buttonActiveFg      = "#ffffff",
    buttonActiveBorder  = "#b9a6ff",
    -- Per-button accent colors (safe pre-init defaults)
    buttonRefreshColor  = "#a78bfa",
    buttonClearColor    = "#ff7b6b",
    buttonIgnoreColor   = "#ffd27a",
  }
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
  local isLightBg = (L >= LUMINANCE_LIGHT_CUTOFF)

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
  t.red    = light and "ansi_001"          or "tomato"
  t.orange = light and "ansi_130"          or "orange"
  t.yellow = light and "ansi_003"          or "khaki"
  t.green  = light and "ansi_002"          or "spring_green"
  t.blue   = light and "ansi_004"          or "dodger_blue"
  t.cyan   = light and "ansi_006"          or "medium_turquoise"
  t.sky    = light and "ansi_033"          or "light_steel_blue"
  t.purple = light and "ansi_005"          or "medium_purple"
  t.pink   = light and "ansi_013"          or "deep_pink"
  t.brown  = light and "ansi_095"          or "peru"
  t.olive  = light and "ansi_058"          or "yellow_green"
  t.silver = light and "ansi_237"          or "slate_gray"
  t.gold   = light and "ansi_011"          or "light_goldenrod"

  -- Semantic aliases
  t.good      = t.green
  t.warn      = t.orange
  t.bad       = t.red
  t.info      = t.blue
  t.muted     = t.silver
  t.text      = "ansi_white"
  t.accent    = t.cyan
  t.highlight = t.yellow

  -- Panel header / button chrome (QSS colors). Retro-terminal: green accent,
  -- amber hover, bright-on-green active state. Light mode keeps the same
  -- accent language on a light terminal bar.
  if light then
    t.panel = {
      headerBg            = "rgb(244,241,250)",
      sectionBg           = "rgb(229,224,240)",
      headerBorder        = "rgb(210,198,235)",
      headerAccent        = "rgb(100,70,190)",
      buttonBg            = "rgb(255,255,255)",
      buttonBorder        = "rgb(200,188,235)",
      buttonHoverBg       = "rgb(232,225,250)",
      buttonHoverFg       = "#9a6a00",
      buttonActiveBg      = "#7a5cff",
      buttonActiveFg      = "#ffffff",
      buttonActiveBorder  = "rgb(90,60,170)",
      -- Per-button accents: darker/deeper so they stay readable on white
      buttonRefreshColor  = "#5b3fd4",
      buttonClearColor    = "#c0392b",
      buttonIgnoreColor   = "#9a6a00",
      -- Chat history filter buttons
      buttonAllColor      = "#5b3fd4",
      buttonSayColor      = "#a16207",
      buttonYellColor     = "#0e7490",
      buttonTellColor     = "#15803d",
      buttonGroupColor    = "#7e22ce",
      buttonOOCColor      = "#0369a1",
      buttonNewbieColor   = "#4d7c0f",
      buttonHouseColor    = "#4b5563",
    }
  else
    t.panel = {
      headerBg            = "rgba(12,6,26,55%)",
      sectionBg           = "rgba(5,2,14,70%)",
      headerBorder        = "rgba(150,120,255,20%)",
      headerAccent        = "rgba(150,120,255,45%)",
      buttonBg            = "rgba(12,6,26,35%)",
      buttonBorder        = "rgba(150,120,255,25%)",
      buttonHoverBg       = "rgba(150,120,255,16%)",
      buttonHoverFg       = "#ffd27a",
      buttonActiveBg      = "#7a5cff",
      buttonActiveFg      = "#ffffff",
      buttonActiveBorder  = "#b9a6ff",
      -- Per-button accents: bright pastels that pop on the dark bar
      buttonRefreshColor  = "#a78bfa",
      buttonClearColor    = "#ff7b6b",
      buttonIgnoreColor   = "#ffd27a",
      -- Chat history filter buttons
      buttonAllColor      = "#a78bfa",
      buttonSayColor      = "#fbbf24",
      buttonYellColor     = "#7dd3fc",
      buttonTellColor     = "#4ade80",
      buttonGroupColor    = "#c084fc",
      buttonOOCColor      = "#67e8f9",
      buttonNewbieColor   = "#86efac",
      buttonHouseColor    = "#d6dbe3",
    }
  end

  buildTags(t)

  -- Build a compact color listing for the log — all keys discovered dynamically
  local keys = {}
  for k, v in pairs(t) do
    if type(v) == "string" and not k:find("Tag$") and not k:find("^_") then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)
  local lines = {}
  for _, k in ipairs(keys) do
    local c = t[k]
    lines[#lines + 1] = string.format("  %s%s<reset>: <%s>%s<reset>", t.mutedTag, k, c, c)
  end

  Darkmists.Log(DarkmistsTheme.purpleTag .. "Darkmists Core",
    (DarkmistsTheme.silverTag .. "Theme Built! Light Mode: %s%s\n%s"):format(
      DarkmistsTheme.infoTag, tostring(light),
      table.concat(lines, "\n")) .. DarkmistsTheme.textTag)
end

-- ---------------------------------------------------------------------------
-- Panel header chrome (used by DMPanelHeader)
-- ---------------------------------------------------------------------------

-- QSS for the fixed header strip above a panel's body console. Retro
-- terminal status bar: dark bar with a glowing purple accent line.
function DarkmistsTheme.buildHeaderStyle()
  local p = DarkmistsTheme.panel or {}
  return string.format([[
QLabel {
  background-color: %s;
  border: 1px solid %s;
  border-bottom: 2px solid %s;
  border-radius: 0px;
}
]], p.headerBg, p.headerBorder, p.headerAccent)
end

-- QSS for a header button. Retro-terminal: `color` is the button's accent
-- text/border color (a QSS color). Hover brightens to amber; `active` flips
-- to a bright fill with dark text (e.g. an on toggle like the ignored view).
function DarkmistsTheme.buildButtonStyle(active, color)
  local p = DarkmistsTheme.panel or {}
  color = color or p.buttonActiveFg
  if active then
    return string.format([[
QLabel {
  color: %s;
  background-color: %s;
  border: 1px solid %s;
  border-radius: 0px;
  padding: 0px 8px;
  margin: 3px 0px;
  font-weight: bold;
}
QLabel:hover {
  color: %s;
  border-color: %s;
}
]], p.buttonActiveFg, p.buttonActiveBg, color, p.buttonHoverFg, color)
  end
  return string.format([[
QLabel {
  color: %s;
  background-color: %s;
  border: 1px solid %s;
  border-radius: 0px;
  padding: 0px 8px;
  margin: 3px 0px;
}
QLabel:hover {
  color: %s;
  border-color: %s;
  background-color: %s;
}
]], color, p.buttonBg, p.buttonBorder, p.buttonHoverFg, color, p.buttonHoverBg)
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

DarkmistsTheme.buildNeutralTheme() -- initialize with a safe default before settings are loaded