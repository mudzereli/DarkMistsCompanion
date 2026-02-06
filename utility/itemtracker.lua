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

ItemTracker = {
  name = "DM Item Tracker",
  version = "1.3.1",
  author = "mudzereli",

  -- Runtime item data
  items = {},          -- Flat list of all items
  by_name = {},        -- lower(name) → {item, item, ...}
  by_area = {},        -- lower(area) → {item, item, ...}
  sorted_names = {},   -- Lowercase names, longest-first for matching

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
    cursorOffset = 15,        -- Distance from mouse cursor
    screenMargin = 10,        -- Clamp margin from screen edges
    statusBarHeight = 110,    -- Reserved space at bottom for status bars

    -- Colors (RGBA)
    tooltipHeaderBGColor = {255, 255, 255, 255},
    tooltipTextColor = {255, 255, 255, 255},
    tooltipBGColor = {0, 0, 0, 255},
    tooltipBorderColor = {255, 255, 255, 255},

    -- MUD colors (see https://wiki.mudlet.org/images/c/c3/ShowColors.png)
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
  },
}

-- Format color strings for use in cecho
local s = ItemTracker.settings
if Darkmists.GlobalSettings.lightMode then
  s.itemLinkColor = Darkmists.GlobalSettings.itemTrackerLinkColorLightMode
end
s.itemLinkColor = string.format("<%s>", s.itemLinkColor)
s.tooltipItemNameColor = string.format("<%s>", s.tooltipItemNameColor)
s.tooltipItemDetailsColor = string.format("<%s>", s.tooltipItemDetailsColor)

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- Trim whitespace from string
local function trim(str)
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Validate item name (must be 2+ chars with at least one letter)
local function is_valid_item_name(name)
  if type(name) ~= "string" then return false end
  name = trim(name)
  return #name >= 2 and name:match("%a") ~= nil
end

-- Extract area from details string (expects "Area: <name>" on first line)
local function extract_area(details)
  if type(details) ~= "string" then return nil end
  local firstLine = details:match("([^\n]+)")
  if not firstLine then return nil end
  return firstLine:match("^Area:%s*(.+)$")
end

-- Move "extra flags ..." to its own indented line for better tooltip formatting
local function indent_extra_flags(details)
  if type(details) ~= "string" then return details end
  return details:gsub(",%s*extra flags%s+", ",\n  extra flags ")
end

-- Calculate tooltip dimensions from text lines
local function calc_tooltip_size(lines, fontSize, minChars, maxChars)
  local longest = minChars
  
  for _, line in ipairs(lines) do
    longest = math.max(longest, #line)
  end
  
  if maxChars then
    longest = math.min(longest, maxChars)
  end
  
  local charW, charH = calcFontSize(fontSize)
  return longest * charW, #lines * charH
end

-- Get length of longest line in character count
local function get_longest_line_chars(lines)
  local longest = 0
  for _, line in ipairs(lines) do
    longest = math.max(longest, #line)
  end
  return longest
end

-- ============================================================================
-- Tooltip Management
-- ============================================================================

-- Initialize tooltip windows (border, header, content)
function ItemTracker.initTooltip()
  local s = ItemTracker.settings
  local t = ItemTracker.tooltip
  
  -- Create border window
  t.border = "itemTooltipBorder"
  createMiniConsole(t.border, 0, 0, 1, 1)
  setBackgroundColor(t.border, unpack(s.tooltipBorderColor))
  hideWindow(t.border)
  
  -- Create header window
  t.header = "itemTooltipHeader"
  createMiniConsole(t.header, 0, 0, 1, 1)
  setMiniConsoleFontSize(t.header, s.tooltipHeaderFontSize)
  setBackgroundColor(t.header, unpack(s.tooltipHeaderBGColor))
  setFgColor(t.header, 255, 255, 255)
  hideWindow(t.header)
  
  -- Create content window
  t.win = "itemTooltip"
  createMiniConsole(t.win, s.tooltipBorderSize, s.tooltipBorderSize, 1, 1)
  setMiniConsoleFontSize(t.win, s.tooltipFontSize)
  setBackgroundColor(t.win, unpack(s.tooltipBGColor))
  setFgColor(t.win, unpack(s.tooltipTextColor))
  setWindowWrap(t.win, s.wrapWidth)
  hideWindow(t.win)
end

-- Hide all tooltip windows
function ItemTracker.hideTooltip()
  local t = ItemTracker.tooltip
  hideWindow(t.header)
  hideWindow(t.border)
  hideWindow(t.win)
end

-- Display tooltip for given item name(s)
function ItemTracker.showTooltip(name)
  local list = ItemTracker.by_name[name:lower()]
  if not list then return end

  local s = ItemTracker.settings
  local t = ItemTracker.tooltip
  
  -- Calculate header height
  local _, headerCharH = calcFontSize(s.tooltipHeaderFontSize)
  local headerHeight = headerCharH

  -- Build preview text to calculate if indentation is needed
  local preview_raw = {}
  for idx, item in ipairs(list) do
    if item.details then
      for line in item.details:gmatch("[^\n]+") do
        table.insert(preview_raw, line)
      end
    end
    if idx < #list then
      table.insert(preview_raw, "\n")
    end
  end

  -- Determine if we need to indent extra flags for better formatting
  local longestChars = get_longest_line_chars(preview_raw)
  local needsIndent = s.tooltipMaxChars and longestChars > s.tooltipMaxChars

  -- Build final preview with proper formatting
  local preview = {}
  for idx, item in ipairs(list) do
    if item.details then
      local text = needsIndent and indent_extra_flags(item.details) or item.details
      for line in text:gmatch("[^\n]+") do
        table.insert(preview, line)
      end
    end
    if idx < #list then
      table.insert(preview, "\n")
    end
  end

  -- Calculate final dimensions
  local contentW, contentH = calc_tooltip_size(
    preview,
    s.tooltipFontSize,
    s.tooltipMinChars,
    s.tooltipMaxChars
  )
  
  local totalWidth = contentW + (s.tooltipBorderSize * 2)
  local totalHeight = headerHeight + contentH + (s.tooltipBorderSize * 2)

  -- Resize all windows
  resizeWindow(t.border, totalWidth, totalHeight)
  resizeWindow(t.header, contentW, headerHeight)
  resizeWindow(t.win, contentW, contentH)
  
  t.width = totalWidth
  t.height = totalHeight

  -- Populate content
  clearWindow(t.win)
  
  for idx, item in ipairs(list) do
    clearWindow(t.header)
    cecho(t.header, s.tooltipItemNameColor .. item.name)
    
    if item.details then
      local text = needsIndent and indent_extra_flags(item.details) or item.details
      cecho(t.win, s.tooltipItemDetailsColor .. text .. "\n")
    end
    
    if idx < #list then
      cecho(t.win, "\n")
    end
  end

  -- Position tooltip relative to cursor, avoiding status bars
  local mx, my = getMousePosition()
  local winW, winH = getMainWindowSize()
  
  local px = mx + s.cursorOffset
  local py = my + s.cursorOffset
  
  -- Reserve space for status bars at bottom
  local bottomThreshold = winH - s.statusBarHeight
  
  -- Horizontal clamping
  if px + t.width > winW then
    px = winW - t.width - s.screenMargin
  end
  px = math.max(px, s.screenMargin)
  
  -- Vertical positioning: show above cursor if near bottom or would overlap status bar
  if py + t.height > bottomThreshold or my > bottomThreshold then
    py = my - t.height - s.cursorOffset
  end
  py = math.max(py, s.screenMargin)
  
  -- Position all windows (border → header → content)
  moveWindow(t.border, px, py)
  moveWindow(t.header, px + s.tooltipBorderSize, py + s.tooltipBorderSize)
  moveWindow(t.win, px + s.tooltipBorderSize, py + s.tooltipBorderSize + headerHeight)
  
  -- Show all windows
  showWindow(t.border)
  showWindow(t.header)
  showWindow(t.win)

  -- Register click handler to hide tooltip
  registerAnonymousEventHandler("sysWindowMousePressEvent", "ItemTracker.hideTooltip")
end

-- ============================================================================
-- Data Loading and Indexing
-- ============================================================================

-- Load item data from JSON file and build indices
function ItemTracker.load(path)
  cecho(string.format(
    "<green>[ID] <white>Loading %s v%s by %s\n",
    ItemTracker.name,
    ItemTracker.version,
    ItemTracker.author
  ))

  -- Read JSON file
  local f, err = io.open(path, "r")
  if not f then
    cecho("<red>[ID] Failed to open JSON: " .. tostring(err) .. "\n")
    return false
  end

  local data = yajl.to_value(f:read("*a"))
  f:close()

  if type(data) ~= "table" then
    cecho("<red>[ID] JSON root is not a list\n")
    return false
  end

  -- Reset all indices
  ItemTracker.items = {}
  ItemTracker.by_name = {}
  ItemTracker.by_area = {}
  ItemTracker.sorted_names = {}

  local dropped = 0

  -- Process each item
  for _, item in ipairs(data) do
    if is_valid_item_name(item.name) then
      item.name = trim(item.name)
      local key = item.name:lower()

      -- Add to flat list
      table.insert(ItemTracker.items, item)
      
      -- Add to name index (supports duplicates)
      ItemTracker.by_name[key] = ItemTracker.by_name[key] or {}
      table.insert(ItemTracker.by_name[key], item)
      table.insert(ItemTracker.sorted_names, key)

      -- Add to area index
      local area = extract_area(item.details)
      if area then
        item.area = area
        local akey = area:lower()
        ItemTracker.by_area[akey] = ItemTracker.by_area[akey] or {}
        table.insert(ItemTracker.by_area[akey], item)
      end
    else
      dropped = dropped + 1
    end
  end

  -- Sort names by length (longest first) to prevent partial matching issues
  table.sort(ItemTracker.sorted_names, function(a, b)
    return #a > #b
  end)

  cecho(string.format(
    "<green>[ID]<white> Loaded %d items (%d dropped)\n",
    #ItemTracker.items, dropped
  ))

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
    if nlen <= #phrase and phrase:sub(-nlen) == name then
      local s = offset + (#phrase - nlen) + 1
      local e = offset + #phrase
      return name, s, e
    end
  end

  return nil
end

-- ============================================================================
-- Line Rendering
-- ============================================================================

-- Convert item names in line to clickable links
function ItemTracker.renderLineWithLinks(line)
  -- Skip prompt and exit lines
  if line:match("^<%d") or line:find("^%[Exits:") then
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
    ItemTracker.settings.itemLinkColor .. itemText .. "<white>",
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
  cecho("\n" .. s.itemLinkColor .. "===[ " .. item.name .. " ]===<white>\n")

  if item.details then
    for line in item.details:gmatch("[^\n]+") do
      cecho("<white>" .. line .. "\n")
    end
  else
    cecho("<grey>(no details)<white>\n")
  end

  cecho(s.itemLinkColor .. "===[ " .. item.name .. " ]===<white>\n\n")
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