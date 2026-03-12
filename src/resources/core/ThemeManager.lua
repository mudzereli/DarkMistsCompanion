-- =============================================================================
-- ThemeManager.lua
-- =============================================================================
DarkmistsTheme = DarkmistsTheme or {}

-- ---------------------------------------------------------------------------
-- Build theme from GlobalSettings
-- ---------------------------------------------------------------------------
function DarkmistsTheme.buildTheme()
  local t     = DarkmistsTheme
  local light = Darkmists.GlobalSettings.lightMode
  local tagKeys = {}

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
  t.good   = t.green
  t.warn   = t.orange
  t.bad    = t.red
  t.info   = t.blue
  t.muted  = light and "dim_gray"   or "slate_gray"
  t.text   = light and "black"      or "white"
  t.accent = light and "slate_blue" or "cornflower_blue"

  -- Build cecho tags
  for k, v in pairs(t) do
    if type(v) == "string" and not k:find("Tag$") then
      table.insert(tagKeys, k)
    end
  end

  for _, key in ipairs(tagKeys) do
    local value = t[key]
    if type(value) == "string" then
      t[key .. "Tag"] = ("<%s>"):format(value)
    end
  end
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