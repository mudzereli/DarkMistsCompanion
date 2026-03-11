-- ============================================================================
-- ItemTracker v1.3.1
-- ----------------------------------------------------------------------------
-- Clickable item identification with tooltip support for MUD environments.
-- Loads item data from JSON and detects item names at the END of output lines.
--
-- Key behaviors:
--   • Items indexed by lowercase name (duplicates stored as list)
--   • Matching is END-OF-LINE only (prevents "egg" in "leggings")
--   • Longest names tried first (prevents partial shadowing)
--   • Click → tooltip | Shift+Click → full output | Any click → hide tooltip
--   • Tooltip avoids covering status bars at bottom
-- ============================================================================

local WHO_HEADER_PATTERN = "^%[[^%]]*[A-Za-z][^%]]*%]"

ItemTracker = {
  name = "DM Item Tracker",
  version = "1.3.1",
  author = "mudzereli",

  -- Runtime item data
  items = {},
  by_name = {},
  by_area = {},
  sorted_names = {},

  -- User configuration (safe to modify)
  settings = {
    alias = "dmid",

    -- Font sizes
    tooltipHeaderFontSize = 14,
    tooltipFontSize = 12,

    -- Tooltip sizing
    tooltipMinChars = 30,
    tooltipMaxChars = 90,
    tooltipBorderSize = 2,
    wrapWidth = 400,

    -- Positioning
    cursorOffset = 15,
    screenMargin = 10,
    statusBarHeight = 110,

    -- Colors (RGBA)
    tooltipHeaderBGColor = {255, 255, 255, 255},
    tooltipTextColor = {255, 255, 255, 255},
    tooltipBGColor = {0, 0, 0, 255},
    tooltipBorderColor = {255, 255, 255, 255},

    -- MUD colors
    itemLinkColor = Darkmists.GlobalSettings.itemTrackerLinkColorDarkMode,
    tooltipItemNameColor = "black",
    tooltipItemDetailsColor = "white"
  },

  -- Tooltip state (internal use only)
  tooltip = {
    win = nil,
    border = nil,
    header = nil,
    width = 0,
    height = 0,
    clickHandler = nil
  },
}

-- ============================================================================
-- Settings Initialization
-- ============================================================================

local settings = ItemTracker.settings

-- Apply light mode overrides
if Darkmists.GlobalSettings.lightMode then
  settings.itemLinkColor = Darkmists.GlobalSettings.itemTrackerLinkColorLightMode
  settings.tooltipItemDetailsColor = "black"
  settings.tooltipItemNameColor = "white"
  settings.tooltipHeaderBGColor = {0, 0, 0, 255}
  settings.tooltipTextColor = {0, 0, 0, 255}
  settings.tooltipBGColor = {255, 255, 255, 255}
  settings.tooltipBorderColor = {0, 0, 0, 255}
end

local defaultTextColor = Darkmists.getDefaultTextColorTag()

-- Pre-format cecho color tags once
settings.itemLinkColor          = string.format("<%s>", settings.itemLinkColor)
settings.tooltipItemNameColor   = string.format("<%s>", settings.tooltipItemNameColor)
settings.tooltipItemDetailsColor= string.format("<%s>", settings.tooltipItemDetailsColor)

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function trim(str)
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end

local function is_valid_item_name(name)
  if type(name) ~= "string" then return false end
  name = trim(name)
  return #name >= 2 and name:match("%a") ~= nil
end

local function extract_area(details)
  if type(details) ~= "string" then return nil end
  local firstLine = details:match("([^\n]+)")
  if not firstLine then return nil end
  return firstLine:match("^Area:%s*(.+)$")
end

local function indent_extra_flags(details)
  if type(details) ~= "string" then return details end
  return details:gsub(",%s*extra flags%s+", ",\n  extra flags ")
end

local function get_longest_line_chars(lines)
  local longest = 0
  for _, line in ipairs(lines) do
    longest = math.max(longest, #line)
  end
  return longest
end

local function calc_tooltip_size(lines, fontSize, minChars, maxChars)
  local longest = math.max(minChars, get_longest_line_chars(lines))
  if maxChars then longest = math.min(longest, maxChars) end
  local charW, charH = calcFontSize(fontSize)
  return longest * charW, #lines * charH
end

-- ============================================================================
-- Tooltip Management
-- ============================================================================

function ItemTracker.initTooltip()
  local s = settings
  local t = ItemTracker.tooltip

  t.border = "itemTooltipBorder"
  createMiniConsole(t.border, 0, 0, 1, 1)
  setBackgroundColor(t.border, unpack(s.tooltipBorderColor))
  hideWindow(t.border)

  t.header = "itemTooltipHeader"
  createMiniConsole(t.header, 0, 0, 1, 1)
  setMiniConsoleFontSize(t.header, s.tooltipHeaderFontSize)
  setBackgroundColor(t.header, unpack(s.tooltipHeaderBGColor))
  setFgColor(t.header, 255, 255, 255)
  hideWindow(t.header)

  t.win = "itemTooltip"
  createMiniConsole(t.win, s.tooltipBorderSize, s.tooltipBorderSize, 1, 1)
  setMiniConsoleFontSize(t.win, s.tooltipFontSize)
  setBackgroundColor(t.win, unpack(s.tooltipBGColor))
  setFgColor(t.win, unpack(s.tooltipTextColor))
  setWindowWrap(t.win, s.wrapWidth)
  hideWindow(t.win)
end

function ItemTracker.hideTooltip()
  local t = ItemTracker.tooltip
  hideWindow(t.header)
  hideWindow(t.border)
  hideWindow(t.win)
  if t.clickHandler then
    killAnonymousEventHandler(t.clickHandler)
    t.clickHandler = nil
  end
end

function ItemTracker.showTooltip(name)
  local list = ItemTracker.by_name[name:lower()]
  if not list then return end

  local s = settings
  local t = ItemTracker.tooltip

  local _, headerCharH = calcFontSize(s.tooltipHeaderFontSize)
  local headerHeight = headerCharH

  local preview_raw = {}
  for idx, item in ipairs(list) do
    if item.details then
      for line in item.details:gmatch("[^\n]+") do
        preview_raw[#preview_raw+1] = line
      end
    end
    if idx < #list then preview_raw[#preview_raw+1] = "\n" end
  end

  local needsIndent = s.tooltipMaxChars
    and get_longest_line_chars(preview_raw) > s.tooltipMaxChars

  local preview = {}
  for idx, item in ipairs(list) do
    if item.details then
      local text = needsIndent and indent_extra_flags(item.details) or item.details
      for line in text:gmatch("[^\n]+") do
        preview[#preview+1] = line
      end
    end
    if idx < #list then preview[#preview+1] = "\n" end
  end

  local contentW, contentH = calc_tooltip_size(
    preview, s.tooltipFontSize, s.tooltipMinChars, s.tooltipMaxChars
  )

  local totalWidth  = contentW + (s.tooltipBorderSize * 2)
  local totalHeight = headerHeight + contentH + (s.tooltipBorderSize * 2)

  resizeWindow(t.border, totalWidth, totalHeight)
  resizeWindow(t.header, contentW, headerHeight)
  resizeWindow(t.win, contentW, contentH)

  t.width, t.height = totalWidth, totalHeight

  clearWindow(t.win)

  for idx, item in ipairs(list) do
    clearWindow(t.header)
    cecho(t.header, s.tooltipItemNameColor .. item.name)

    if item.details then
      local text = needsIndent and indent_extra_flags(item.details) or item.details
      cecho(t.win, s.tooltipItemDetailsColor .. text .. "\n")
    end

    if idx < #list then cecho(t.win, "\n") end
  end

  local mx, my = getMousePosition()
  local winW, winH = getMainWindowSize()

  local px = mx + s.cursorOffset
  local py = my + s.cursorOffset

  local borders = Darkmists.GlobalSettings.borders or {}

  local safeLeft   = ((borders.left   or 0) / 100) * winW + s.screenMargin
  local safeRight  = winW - ((borders.right  or 0) / 100) * winW - s.screenMargin
  local safeTop    = ((borders.top    or 0) / 100) * winH + s.screenMargin
  local safeBottom = winH - ((borders.bottom or 0) / 100) * winH - s.screenMargin

  if px + t.width > safeRight then px = safeRight - t.width end
  if px < safeLeft then px = safeLeft end

  if py + t.height > safeBottom or my > safeBottom then
    py = my - t.height - s.cursorOffset
  end
  if py < safeTop then py = safeTop end

  moveWindow(t.border, px, py)
  moveWindow(t.header, px + s.tooltipBorderSize, py + s.tooltipBorderSize)
  moveWindow(t.win, px + s.tooltipBorderSize, py + s.tooltipBorderSize + headerHeight)

  showWindow(t.border)
  showWindow(t.header)
  showWindow(t.win)

  if t.clickHandler then
    killAnonymousEventHandler(t.clickHandler)
    t.clickHandler = nil
  end

  t.clickHandler = registerAnonymousEventHandler(
    "sysWindowMousePressEvent",
    "ItemTracker.hideTooltip"
  )
end

-- ============================================================================
-- Data Loading and Indexing
-- ============================================================================

function ItemTracker.load(path)
  Darkmists.Log("ItemTracker",
    string.format("<forest_green>Loading %s v%s by %s",
      ItemTracker.name, ItemTracker.version, ItemTracker.author
    )
  )

  local f, err = io.open(path, "r")
  if not f then
    Darkmists.Log("ItemTracker", "<red>Failed to open JSON: " .. tostring(err))
    return false
  end

  local data = yajl.to_value(f:read("*a"))
  f:close()

  if type(data) ~= "table" then
    Darkmists.Log("ItemTracker", "<red>JSON root is not a list")
    return false
  end

  ItemTracker.items, ItemTracker.by_name, ItemTracker.by_area, ItemTracker.sorted_names =
    {}, {}, {}, {}

  local dropped = 0

  for _, item in ipairs(data) do
    if is_valid_item_name(item.name) then
      item.name = trim(item.name)
      local key = item.name:lower()

      ItemTracker.items[#ItemTracker.items+1] = item

      local nameList = ItemTracker.by_name[key]
      if not nameList then
        nameList = {}
        ItemTracker.by_name[key] = nameList
        ItemTracker.sorted_names[#ItemTracker.sorted_names+1] = key
      end
      nameList[#nameList+1] = item

      local area = extract_area(item.details)
      if area then
        item.area = area
        local akey = area:lower()
        local areaList = ItemTracker.by_area[akey] or {}
        areaList[#areaList+1] = item
        ItemTracker.by_area[akey] = areaList
      end
    else
      dropped = dropped + 1
    end
  end

  table.sort(ItemTracker.sorted_names, function(a, b) return #a > #b end)

  Darkmists.Log("ItemTracker",
    string.format("<white>Loaded <green>%d<white> items (<yellow>%d dropped<white>)", #ItemTracker.items, dropped)
  )

  return true
end

-- ============================================================================
-- Search Functions
-- ============================================================================

-- Find items by name (exact or partial match)
function ItemTracker.find(query)
  if not query or query == "" then return nil end
  query = query:lower()

  -- Try exact match first
  local exact = ItemTracker.by_name[query]
  if exact then return exact end

  -- Fall back to partial matches
  local hits = {}
  for name, list in pairs(ItemTracker.by_name) do
    if name:find(query, 1, true) then
      for _, item in ipairs(list) do
        table.insert(hits, item)
      end
    end
  end

  table.sort(hits, function(a, b) return a.name < b.name end)
  return hits
end

-- Find items by area (partial match supported)
function ItemTracker.listByArea(areaQuery)
  if not areaQuery or areaQuery == "" then return nil end
  areaQuery = areaQuery:lower()

  local results = {}

  for area, items in pairs(ItemTracker.by_area) do
    if area:find(areaQuery, 1, true) then
      for _, item in ipairs(items) do
        table.insert(results, item)
      end
    end
  end

  table.sort(results, function(a, b)
    if a.name == b.name then return false end
    return a.name < b.name
  end)

  return results
end

-- Detect item name at END of line only
-- Returns: normalized name, start index, end index (in trimmed-lower string)
function ItemTracker.findFirstItemInLine(line)
  local trimmed = line:gsub("%s+$", "")
  local lower = trimmed:lower()

  -- Handle special case: "You get <item> from ..."
  local phrase, offset = lower:match("^you get (.+) from ")
  if phrase then
    offset = 8  -- Length of "you get "
  else
    phrase = lower
    offset = 0
  end

  -- Try each item name (longest first)
  for _, name in ipairs(ItemTracker.sorted_names) do
    local nlen = #name
    if nlen <= #phrase then
      local candidate = phrase:sub(-nlen)
      if candidate == name then
        local prev = phrase:sub(-(nlen + 1), -(nlen + 1))
        -- Ensure start boundary (space or punctuation or start of string)
        if prev == "" or prev:match("[%s%p]") then
          local s = offset + (#phrase - nlen) + 1
          local e = offset + #phrase
          return name, s, e
        end
      end
    end
  end

  return nil
end

-- ============================================================================
-- Line Rendering
-- ============================================================================

-- Convert item names in line to clickable links
function ItemTracker.renderLineWithLinks(line)
  -- Skip prompt, exits, and WHO-list lines
  if line:match("^<%d")
  or line:find("^%[Exits:")
  or line:match(WHO_HEADER_PATTERN) then
    return false
  end

  -- Skip while DMAPI room capture is active (room parsing in progress)
  if dmapi and dmapi.core and dmapi.core.state
  and dmapi.core.state.capturingRoom then
    return false
  end

  local _, s, e = ItemTracker.findFirstItemInLine(line)
  if not s then return false end

  local pos0 = s - 1
  local len = e - s + 1
  local itemText = line:sub(s, e)

  -- Select and modify current line
  selectCurrentLine()
  local lineNo = getLineNumber()

  if not selectSection(pos0, len) then
    resetFormat()
    return false
  end

  -- Replace with clickable link
  replace("")
  moveCursor(pos0, lineNo)

  cinsertLink(
    ItemTracker.settings.itemLinkColor .. itemText .. defaultTextColor,
    function() ItemTracker.handleClick(itemText) end,
    "Click: tooltip | Shift+Click: full identify",
    true
  )
  moveCursorEnd()
  resetFormat()
  return true
end

-- ============================================================================
-- Output Display
-- ============================================================================

-- Display single item details in main window
function ItemTracker.show(item)
  local s = ItemTracker.settings
  cecho("\n" .. s.itemLinkColor .. "===[ " .. item.name .. " ]==="..defaultTextColor.."\n")

  if item.details then
    for line in item.details:gmatch("[^\n]+") do
      cecho(defaultTextColor .. line .. "\n")
    end
  else
    cecho("<dim_gray>(no details)"..defaultTextColor.."\n")
  end

  cecho(s.itemLinkColor .. "===[ " .. item.name .. " ]==="..defaultTextColor.."\n\n")
end

-- Display all items matching exact name (handles duplicates)
function ItemTracker.click(name)
  local list = ItemTracker.by_name[name:lower()]
  if not list then return end
  
  for _, item in ipairs(list) do
    ItemTracker.show(item)
  end
end

-- Handle click on item link (tooltip or full display based on modifiers)
function ItemTracker.handleClick(name)
  if holdingModifiers(mudlet.keymodifier.Shift) then
    -- Shift+Click: full identify in chat
    ItemTracker.hideTooltip()
    ItemTracker.click(name)
  else
    -- Normal click: show tooltip
    ItemTracker.showTooltip(name)
  end
end

-- ============================================================================
-- Initialization
-- ============================================================================

ItemTracker.load(getMudletHomeDir() .. "/DarkMistsCompanion/assets/darkmists_items.json")
ItemTracker.initTooltip()