-- MapColors: Automated terrain coloring system for MUD mapper
-- HIGHLY OPTIMIZED VERSION with pre-computed lookups and minimal iterations

MapColors = {}

-- ============================================================================
-- TERRAIN DEFINITIONS
-- ============================================================================

-- Terrain type constants
MapColors.Terrain = {
  MISTY = "MISTY", SNOWY = "SNOWY", STONY = "STONY", STONE_WHITE = "STONE_WHITE",
  VALLEY = "VALLEY", CLEAR_WATER = "CLEAR_WATER", CALM_WATER = "CALM_WATER",
  SWAMP_WATER = "SWAMP_WATER", DEEP_WATER = "DEEP_WATER", CORRUPTED = "CORRUPTED",
  THICK_WOODS = "THICK_WOODS", LIGHT_WOODS = "LIGHT_WOODS", GRASSY = "GRASSY",
  PLAINS = "PLAINS", WOODEN = "WOODEN", MUDDY = "MUDDY", SANDY = "SANDY",
  METAL = "METAL", HOLY = "HOLY", INTERIOR = "INTERIOR", INTERIOR_POI = "INTERIOR_POI",
  STONY_PATH = "STONY_PATH", SHADOWY = "SHADOWY", ENCAMPMENT = "ENCAMPMENT",
  REGAL = "REGAL", NOEXIT = "NOEXIT", BLOODY = "BLOODY", FIERY = "FIERY",
  CAVE = "CAVE", TUNNEL = "TUNNEL"
}

-- RGB color mappings for each terrain type
MapColors.TerrainColor = {
  [MapColors.Terrain.CLEAR_WATER] = color_table.deep_sky_blue,
  [MapColors.Terrain.CALM_WATER] = color_table.light_sea_green,
  [MapColors.Terrain.SWAMP_WATER] = color_table.sea_green,
  [MapColors.Terrain.DEEP_WATER] = color_table.midnight_blue,
  [MapColors.Terrain.STONY] = color_table.slate_gray,
  [MapColors.Terrain.STONY_PATH] = color_table.light_steel_blue,
  [MapColors.Terrain.SNOWY] = {245, 250, 255},
  [MapColors.Terrain.VALLEY] = {119, 110, 110},
  [MapColors.Terrain.TUNNEL] = {70, 70, 70},
  [MapColors.Terrain.CAVE] = {60, 65, 70},
  [MapColors.Terrain.MISTY] = color_table.light_cyan,
  [MapColors.Terrain.CORRUPTED] = color_table.dark_slate_blue,
  [MapColors.Terrain.THICK_WOODS] = color_table.dark_green,
  [MapColors.Terrain.LIGHT_WOODS] = color_table.lime_green,
  [MapColors.Terrain.GRASSY] = color_table.lawn_green,
  [MapColors.Terrain.PLAINS] = color_table.dark_khaki,
  [MapColors.Terrain.WOODEN] = {160, 82, 45},
  [MapColors.Terrain.SANDY] = color_table.lemon_chiffon,
  [MapColors.Terrain.MUDDY] = {101, 67, 33},
  [MapColors.Terrain.METAL] = {169, 169, 169},
  [MapColors.Terrain.HOLY] = color_table.white,
  [MapColors.Terrain.INTERIOR] = {230, 240, 230},
  [MapColors.Terrain.INTERIOR_POI] = color_table.gold,
  [MapColors.Terrain.SHADOWY] = color_table.dark_slate_gray,
  [MapColors.Terrain.ENCAMPMENT] = color_table.dark_olive_green,
  [MapColors.Terrain.REGAL] = color_table.medium_purple,
  [MapColors.Terrain.BLOODY] = {128, 0, 0},
  [MapColors.Terrain.FIERY] = color_table.dark_orange,
  [MapColors.Terrain.NOEXIT] = color_table.deep_pink,
  [MapColors.Terrain.STONE_WHITE] = {227, 226, 225}
}

-- Hardcoded area overrides (takes precedence over keyword matching)
MapColors.AreaOverrides = {
  emerald_forest = MapColors.Terrain.THICK_WOODS,
  dark_mist_caves = MapColors.Terrain.VALLEY,
  tarot_tower = MapColors.Terrain.VALLEY,
  arkham = MapColors.Terrain.VALLEY,
  rift_of_unending_darkness = MapColors.Terrain.CORRUPTED,
  marsh = MapColors.Terrain.SWAMP_WATER,
  silverwood = MapColors.Terrain.THICK_WOODS,
  mists = MapColors.Terrain.MISTY,
  new_ethshar = MapColors.Terrain.STONY_PATH,
}

-- Terrain category sets (for adjacency analysis and context detection)
MapColors.NatureTerrains = {
  [MapColors.Terrain.THICK_WOODS] = true, [MapColors.Terrain.LIGHT_WOODS] = true,
  [MapColors.Terrain.WOODEN] = true, [MapColors.Terrain.GRASSY] = true,
  [MapColors.Terrain.PLAINS] = true, [MapColors.Terrain.MUDDY] = true,
  [MapColors.Terrain.ENCAMPMENT] = true, [MapColors.Terrain.SANDY] = true,
}

MapColors.UndergroundTerrains = {
  [MapColors.Terrain.SHADOWY] = true, [MapColors.Terrain.VALLEY] = true,
  [MapColors.Terrain.CAVE] = true, [MapColors.Terrain.TUNNEL] = true,
  [MapColors.Terrain.INTERIOR] = true,
}

MapColors.WaterTerrains = {
  [MapColors.Terrain.CALM_WATER] = true, [MapColors.Terrain.DEEP_WATER] = true,
  [MapColors.Terrain.SWAMP_WATER] = true, [MapColors.Terrain.CLEAR_WATER] = true,
}

MapColors.StonyTerrains = {
  [MapColors.Terrain.STONY] = true, [MapColors.Terrain.STONY_PATH] = true,
  [MapColors.Terrain.METAL] = true, [MapColors.Terrain.STONE_WHITE] = true,
}

-- ============================================================================
-- KEYWORD ASSOCIATIONS
-- ============================================================================

-- Maps keywords in room names to terrain types
-- Order matters: later entries override earlier ones
-- Format: { keyword, terrain_type, [onlyIfUncolored], [matchPartial] }
MapColors.WordAssociations = {
  -- Vague/generic keywords (low priority)
  { "entrance", MapColors.Terrain.STONE_WHITE },
  { "mist", MapColors.Terrain.MISTY },
  { "cloud", MapColors.Terrain.MISTY },
  { "fire", MapColors.Terrain.FIERY }, { "flaming", MapColors.Terrain.FIERY },
  { "fiery", MapColors.Terrain.FIERY }, { "burning", MapColors.Terrain.FIERY },
  { "holy", MapColors.Terrain.HOLY },
  { "stone", MapColors.Terrain.STONY },
  { "corruption", MapColors.Terrain.CORRUPTED }, { "corrupted", MapColors.Terrain.CORRUPTED },
  { "evil", MapColors.Terrain.CORRUPTED },
  { "shadowy", MapColors.Terrain.SHADOWY },
  { "floor", MapColors.Terrain.INTERIOR },

  -- Mountainous/rocky terrain
  { "mountain", MapColors.Terrain.STONY }, { "rocky", MapColors.Terrain.STONY },
  { "bluff", MapColors.Terrain.STONY }, { "cliff", MapColors.Terrain.STONY },
  { "slope", MapColors.Terrain.STONY }, { "ledge", MapColors.Terrain.STONY },
  { "trench", MapColors.Terrain.MUDDY }, { "rift", MapColors.Terrain.SHADOWY },
  { "valley", MapColors.Terrain.VALLEY }, { "canyon", MapColors.Terrain.VALLEY },
  { "gorge", MapColors.Terrain.VALLEY }, { "crevasse", MapColors.Terrain.VALLEY },
  { "chasm", MapColors.Terrain.VALLEY }, { "pit", MapColors.Terrain.VALLEY },
  { "ravine", MapColors.Terrain.VALLEY },
  { "summit", MapColors.Terrain.SNOWY }, { "peak", MapColors.Terrain.SNOWY },

  -- Sand/beaches/deserts
  { "sandy", MapColors.Terrain.SANDY }, { "beach", MapColors.Terrain.SANDY },
  { "sand*", MapColors.Terrain.SANDY }, 
  { "dune", MapColors.Terrain.SANDY }, { "desert", MapColors.Terrain.SANDY },

  -- Water bodies (requiring boats)
  { "sea", MapColors.Terrain.DEEP_WATER }, { "waves", MapColors.Terrain.DEEP_WATER },
  { "choppy", MapColors.Terrain.DEEP_WATER }, { "current", MapColors.Terrain.DEEP_WATER },
  { "rapids", MapColors.Terrain.DEEP_WATER }, { "bay", MapColors.Terrain.DEEP_WATER },
  { "cove", MapColors.Terrain.CALM_WATER },

  -- Forested areas (thick)
  { "wood", MapColors.Terrain.THICK_WOODS }, { "wooded", MapColors.Terrain.THICK_WOODS },
  { "forest", MapColors.Terrain.THICK_WOODS }, { "woodland", MapColors.Terrain.THICK_WOODS },
  { "grove", MapColors.Terrain.THICK_WOODS }, { "vine", MapColors.Terrain.THICK_WOODS },
  { "tree", MapColors.Terrain.THICK_WOODS }, { "pine", MapColors.Terrain.THICK_WOODS },
  { "conifer", MapColors.Terrain.THICK_WOODS },
  { "thicket", MapColors.Terrain.THICK_WOODS }, { "copse", MapColors.Terrain.THICK_WOODS },
  { "ranger", MapColors.Terrain.THICK_WOODS },

  -- Lightly wooded/vegetation
  { "hill", MapColors.Terrain.LIGHT_WOODS }, { "clearing", MapColors.Terrain.LIGHT_WOODS },
  { "foothill", MapColors.Terrain.LIGHT_WOODS },
  { "vinyard", MapColors.Terrain.LIGHT_WOODS }, { "shrubbery", MapColors.Terrain.LIGHT_WOODS },
  { "glade", MapColors.Terrain.LIGHT_WOODS }, { "mossy", MapColors.Terrain.LIGHT_WOODS },
  { "moss", MapColors.Terrain.LIGHT_WOODS }, { "orchard", MapColors.Terrain.LIGHT_WOODS },
  { "fruitland", MapColors.Terrain.LIGHT_WOODS }, { "farm", MapColors.Terrain.LIGHT_WOODS },

  -- Grassy areas
  { "yard", MapColors.Terrain.GRASSY }, { "park", MapColors.Terrain.GRASSY },
  { "garden", MapColors.Terrain.GRASSY }, { "grassy", MapColors.Terrain.GRASSY },
  { "grass", MapColors.Terrain.GRASSY }, { "lawn", MapColors.Terrain.GRASSY },

  -- Open plains
  { "meadow", MapColors.Terrain.PLAINS }, { "field", MapColors.Terrain.PLAINS },
  { "plains", MapColors.Terrain.PLAINS }, { "pasture", MapColors.Terrain.PLAINS },

  -- Fresh/standing water
  { "lake", MapColors.Terrain.CLEAR_WATER }, { "stream", MapColors.Terrain.CLEAR_WATER },
  { "pond", MapColors.Terrain.SWAMP_WATER },
  { "swamp", MapColors.Terrain.SWAMP_WATER }, { "moors", MapColors.Terrain.SWAMP_WATER },
  { "bog", MapColors.Terrain.SWAMP_WATER }, { "marsh", MapColors.Terrain.SWAMP_WATER },
  { "shallow", MapColors.Terrain.CALM_WATER },{ "pool", MapColors.Terrain.CALM_WATER },
  { "water", MapColors.Terrain.CALM_WATER }, { "harbor", MapColors.Terrain.CALM_WATER },
  { "paddy", MapColors.Terrain.SWAMP_WATER },
  { "river", MapColors.Terrain.CALM_WATER },

  -- Higher priority overrides below this point
  
  -- Wooden structures
  { "wooden", MapColors.Terrain.WOODEN },

  -- Graveyards/death
  { "graveyard", MapColors.Terrain.SHADOWY }, { "graves", MapColors.Terrain.SHADOWY },
  { "cemetary", MapColors.Terrain.SHADOWY }, { "cemetery", MapColors.Terrain.SHADOWY },
  { "corpse", MapColors.Terrain.SHADOWY },

  -- Castle/city structural elements
  { "ramparts", MapColors.Terrain.STONY }, { "battlement", MapColors.Terrain.STONY },
  { "hallway", MapColors.Terrain.STONY }, { "walkway", MapColors.Terrain.STONY },
  { "tower", MapColors.Terrain.STONY }, { "spire", MapColors.Terrain.STONY },
  { "corridor", MapColors.Terrain.STONY }, { "basement", MapColors.Terrain.STONY },
  { "pews", MapColors.Terrain.WOODEN }, { "suspended walkway", MapColors.Terrain.WOODEN },
  { "gallery", MapColors.Terrain.INTERIOR }, { "roof", MapColors.Terrain.WOODEN },

  -- Fortified rooms
  { "gate", MapColors.Terrain.METAL }, { "cell", MapColors.Terrain.METAL },
  { "stall", MapColors.Terrain.METAL }, { "chamber", MapColors.Terrain.METAL },

  -- Generic interior rooms
  { "room", MapColors.Terrain.INTERIOR }, { "bedroom", MapColors.Terrain.INTERIOR },
  { "site", MapColors.Terrain.INTERIOR }, { "house", MapColors.Terrain.INTERIOR },
  { "abode", MapColors.Terrain.INTERIOR }, { "home", MapColors.Terrain.INTERIOR },
  { "quarter", MapColors.Terrain.INTERIOR }, { "hall", MapColors.Terrain.INTERIOR },
  { "foyer", MapColors.Terrain.INTERIOR }, { "library", MapColors.Terrain.INTERIOR },
  { "lounge", MapColors.Terrain.INTERIOR }, { "kitchen", MapColors.Terrain.INTERIOR },
  { "laboratory", MapColors.Terrain.INTERIOR }, { "ampitheatre", MapColors.Terrain.INTERIOR },
  { "classroom", MapColors.Terrain.INTERIOR }, { "residence", MapColors.Terrain.INTERIOR },
  { "parlor", MapColors.Terrain.INTERIOR }, { "parliament", MapColors.Terrain.INTERIOR },

  -- Building types
  { "hut", MapColors.Terrain.WOODEN }, { "cabin", MapColors.Terrain.WOODEN },
  { "shack", MapColors.Terrain.WOODEN }, { "barn", MapColors.Terrain.WOODEN },
  { "pavilion", MapColors.Terrain.HOLY }, { "gazebo", MapColors.Terrain.HOLY },
  { "chapel", MapColors.Terrain.HOLY }, { "monastery", MapColors.Terrain.HOLY },
  { "nave", MapColors.Terrain.HOLY }, { "narthex", MapColors.Terrain.HOLY },
  { "forge", MapColors.Terrain.STONY }, { "lot", MapColors.Terrain.STONY },
  { "smithy", MapColors.Terrain.STONY }, { "warehouse", MapColors.Terrain.STONY },
  { "storage", MapColors.Terrain.STONY },

  -- Walls/fortifications
  { "wall", MapColors.Terrain.METAL }, { "portcullis", MapColors.Terrain.METAL },
  { "barricade", MapColors.Terrain.METAL },

  -- Civic/office spaces
  { "office", MapColors.Terrain.INTERIOR }, { "lobby", MapColors.Terrain.INTERIOR },
  { "study", MapColors.Terrain.INTERIOR }, { "closet", MapColors.Terrain.INTERIOR },
  { "stage", MapColors.Terrain.INTERIOR },

  -- Military structures
  { "guard post", MapColors.Terrain.STONY }, { "guardpost", MapColors.Terrain.STONY },
  { "arena", MapColors.Terrain.STONY }, { "barracks", MapColors.Terrain.STONY },
  { "outpost", MapColors.Terrain.STONY }, { "stands", MapColors.Terrain.WOODEN },

  -- Large civic structures
  { "courtyard", MapColors.Terrain.STONE_WHITE }, { "turret", MapColors.Terrain.STONY },
  { "abattoir", MapColors.Terrain.SHADOWY }, { "castle", MapColors.Terrain.STONY },
  { "ruins", MapColors.Terrain.CAVE }, { "citadel", MapColors.Terrain.STONE_WHITE },
  { "palace", MapColors.Terrain.STONE_WHITE }, { "aisle", MapColors.Terrain.STONY },
  { "alcove", MapColors.Terrain.STONY }, { "platform", MapColors.Terrain.STONY },
  { "promenade", MapColors.Terrain.STONE_WHITE }, { "ladder", MapColors.Terrain.STONY_PATH },
  { "grounds", MapColors.Terrain.ENCAMPMENT }, { "encampment", MapColors.Terrain.ENCAMPMENT },
  { "camp", MapColors.Terrain.ENCAMPMENT }, { "settlement", MapColors.Terrain.ENCAMPMENT },
  { "village", MapColors.Terrain.ENCAMPMENT }, { "compound", MapColors.Terrain.ENCAMPMENT },
  { "cave", MapColors.Terrain.CAVE }, { "cavern", MapColors.Terrain.CAVE }, { "den", MapColors.Terrain.CAVE },
  { "crater", MapColors.Terrain.CAVE }, { "dungeon", MapColors.Terrain.CAVE },
  { "tent", MapColors.Terrain.HOLY },

  -- Shops/points of interest (high visibility)
  { "market", MapColors.Terrain.INTERIOR_POI }, { "shop", MapColors.Terrain.INTERIOR_POI },
  { "shoppe", MapColors.Terrain.INTERIOR_POI }, { "store", MapColors.Terrain.INTERIOR_POI },
  { "goods", MapColors.Terrain.INTERIOR_POI }, { "butcher", MapColors.Terrain.INTERIOR_POI },
  { "bakery", MapColors.Terrain.INTERIOR_POI }, { "bakoury", MapColors.Terrain.INTERIOR_POI },
  { "depot", MapColors.Terrain.INTERIOR_POI }, { "armory", MapColors.Terrain.INTERIOR_POI },
  { "armoury", MapColors.Terrain.INTERIOR_POI }, { "tavern", MapColors.Terrain.INTERIOR_POI },
  { "bank", MapColors.Terrain.INTERIOR_POI }, { "blacksmith", MapColors.Terrain.INTERIOR_POI },
  { "inn", MapColors.Terrain.INTERIOR_POI }, { "bar", MapColors.Terrain.INTERIOR_POI },
  { "inc", MapColors.Terrain.INTERIOR_POI }, { "incorporated", MapColors.Terrain.INTERIOR_POI },
  { "guild", MapColors.Terrain.REGAL }, { "guildhall", MapColors.Terrain.REGAL },
  { "dojo", MapColors.Terrain.REGAL }, { "guildhouse", MapColors.Terrain.REGAL },

  -- Decorative/special structures (overlay above others)
  { "fountain", MapColors.Terrain.CLEAR_WATER }, { "temple", MapColors.Terrain.HOLY },
  { "shrine", MapColors.Terrain.HOLY }, { "altar", MapColors.Terrain.HOLY },
  { "sanctum", MapColors.Terrain.HOLY }, { "legion", MapColors.Terrain.CORRUPTED },
  { "square", MapColors.Terrain.STONE_WHITE }, { "checkpoint", MapColors.Terrain.STONE_WHITE },

  -- Ship parts
  { "deck", MapColors.Terrain.WOODEN }, { "stern", MapColors.Terrain.WOODEN },
  { "berth", MapColors.Terrain.WOODEN }, { "plank", MapColors.Terrain.WOODEN },
  { "mast", MapColors.Terrain.WOODEN }, { "mizzenmast", MapColors.Terrain.WOODEN },

  -- Roads/passages (high priority - overlays most things)
  { "bridge", MapColors.Terrain.WOODEN }, { "dock", MapColors.Terrain.WOODEN },
  { "wharf", MapColors.Terrain.WOODEN },
  { "street", MapColors.Terrain.STONY_PATH }, { "avenue", MapColors.Terrain.STONY_PATH },
  { "road", MapColors.Terrain.STONY_PATH }, { "row", MapColors.Terrain.STONY_PATH },
  { "way", MapColors.Terrain.STONY_PATH },
  { "alley", MapColors.Terrain.SHADOWY }, { "alleyway", MapColors.Terrain.SHADOWY },
  { "catacomb", MapColors.Terrain.CORRUPTED }, { "crypt", MapColors.Terrain.CORRUPTED },
  { "tomb", MapColors.Terrain.CORRUPTED }, { "sarcophagus", MapColors.Terrain.CORRUPTED },
  { "antechamber", MapColors.Terrain.CORRUPTED },
  { "depth", MapColors.Terrain.CAVE }, { "stair*", MapColors.Terrain.VALLEY },
  --{ "stairwell", MapColors.Terrain.VALLEY }, { "staircase", MapColors.Terrain.VALLEY },
  { "tunnel", MapColors.Terrain.TUNNEL },
  { "enclave", MapColors.Terrain.TUNNEL }, { "labyrinth", MapColors.Terrain.TUNNEL },
  { "passage", MapColors.Terrain.TUNNEL }, { "shaft", MapColors.Terrain.CAVE },
  { "excavation", MapColors.Terrain.CAVE }, { "inlet", MapColors.Terrain.CALM_WATER },
  { "trail", MapColors.Terrain.MUDDY }, { "path", MapColors.Terrain.MUDDY },
  { "dirt", MapColors.Terrain.MUDDY }, { "muddy", MapColors.Terrain.MUDDY },
  { "pathway", MapColors.Terrain.MUDDY }, 
  { "stone path", MapColors.Terrain.STONY_PATH }, { "rocky path*", MapColors.Terrain.STONY_PATH },
  { "woven path*", MapColors.Terrain.WOODEN },
  { "shimmering path*", MapColors.Terrain.REGAL },
  { "cobblestone", MapColors.Terrain.STONY }, { "forest road", MapColors.Terrain.WOODEN },

  -- Custom world-specific locations
  { "miden'nir", MapColors.Terrain.THICK_WOODS },
  { "fisherman's lament", MapColors.Terrain.WOODEN },
  { "citizen's", MapColors.Terrain.STONY_PATH }, { "sultan's", MapColors.Terrain.STONY_PATH },
  { "red roses", MapColors.Terrain.BLOODY }, { "white roses", MapColors.Terrain.HOLY },
  { "plains of sh'goloth", MapColors.Terrain.CORRUPTED },
  { "fair", MapColors.Terrain.STONE_WHITE }, { "carnival", MapColors.Terrain.STONE_WHITE },
  { "sultan's grace", MapColors.Terrain.STONE_WHITE },
  { "fiery sea", MapColors.Terrain.FIERY }, { "of fire", MapColors.Terrain.FIERY },
  { "crystal", MapColors.Terrain.HOLY },

  -- Catchall shop patterns (only match uncolored rooms, partial matching allowed)
  { "'s", MapColors.Terrain.INTERIOR_POI, onlyIfUncolored = true, matchPartial = true },
  { "&", MapColors.Terrain.INTERIOR_POI, onlyIfUncolored = true, matchPartial = true },

  -- Multi-word patterns (processed separately)
  { "corner of * and *", MapColors.Terrain.STONY_PATH },
  { "*'s lane", MapColors.Terrain.STONY_PATH },
  { "dale market", MapColors.Terrain.STONE_WHITE },
  { "market square", MapColors.Terrain.STONE_WHITE },
  { "market area", MapColors.Terrain.STONE_WHITE },
  { "Plaza of the Silver Dragon", MapColors.Terrain.STONE_WHITE },
  { "over windreach", MapColors.Terrain.MISTY },
  { "river bank", MapColors.Terrain.MUDDY },
  { "the banks", MapColors.Terrain.MUDDY },
  { "bank of the", MapColors.Terrain.MUDDY },
}

-- Connector keywords (for rooms linking different terrains)
MapColors.ConnectorWords = {
  "row", "cross", "landing", "intersection", "bend", "turn", "junction",
  "border", "lane", "boulevard", "causeway", "crossing", "culdesac",
  "ramp", "end", "corner", "point"
}

-- Connectors that should NOT be water-based
MapColors.NonWaterConnectorWords = {
  "row", "landing", "border", "lane", "boulevard", "culdesac", "ramp", "bank", "graveyard", "point"
}

-- Words to ignore during keyword extraction
MapColors.Blacklist = {
  within = true, before = true, around = true, along = true,
  inside = true, outside = true, amidst = true, among = true,
  below = true, covered = true, place = true, section = true,
  small = true, great = true, center = true, floor = true,
  intersection = true, junction = true,
}

-- Direction mapping for exit stubs
MapColors.StubMap = {
  [1] = "north", [2] = "northeast", [3] = "northwest", [4] = "east",
  [5] = "west", [6] = "south", [7] = "southeast", [8] = "southwest",
  [9] = "up", [10] = "down", [11] = "in", [12] = "out",
  [13] = "northup", [14] = "southdown", [15] = "southup", [16] = "northdown",
  [17] = "eastup", [18] = "westdown", [19] = "westup", [20] = "eastdown"
}

-- ============================================================================
-- INTERNAL STATE & CACHES
-- ============================================================================

MapColors.ColorNames = {}           -- env_id -> color name (for display)
MapColors.TerrainToEnv = {}         -- terrain_type -> custom_env_id
MapColors.EnvToTerrain = {}         -- custom_env_id -> terrain_type
MapColors._areaTerrainCache = {}    -- areaId -> {nature, stony, underground, water}
MapColors.CustomEnvStart = 275      -- Starting ID for custom environments

-- PERFORMANCE CACHES
MapColors._compiledPatterns = {}    -- keyword -> compiled_pattern
MapColors._connectorWordSet = {}    -- Set lookup for connector words
MapColors._nonWaterConnectorSet = {} -- Set lookup for non-water connectors

-- NEW: Pre-computed room data (built once per update)
MapColors._roomData = {}            -- roomId -> {name, lowername, areaId, areaName}
MapColors._allRoomIds = {}          -- Array of all room IDs

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Check if room has no terrain assigned
function MapColors.isUncolored(id)
  return getRoomEnv(id) == -1
end

-- Get color tag for terrain type
function MapColors.coloredTag(color)
  return ("<%s>"):format(MapColors.ColorNames[color])
end

-- Clear all caches (call when map changes externally)
function MapColors.ClearCaches()
  MapColors._areaTerrainCache = {}
  MapColors._roomData = {}
  MapColors._allRoomIds = {}
end

-- Build room data cache (called once at start of update)
local function buildRoomDataCache()
  MapColors._roomData = {}
  MapColors._allRoomIds = {}
  
  for id, name in pairs(getRooms()) do
    local areaId = getRoomArea(id)
    MapColors._roomData[id] = {
      name = name,
      lowername = name:lower(),
      areaId = areaId,
      areaName = getRoomAreaName(areaId)
    }
    table.insert(MapColors._allRoomIds, id)
  end
end

local function getMostCommonArrayItem(arr)
  if not arr or #arr == 0 then return nil end
  
  local counts = {}
  local max_count = 0
  local most_common_item = nil

  for _, value in ipairs(arr) do
    counts[value] = (counts[value] or 0) + 1
    if counts[value] > max_count then
      max_count = counts[value]
      most_common_item = value
    end
  end

  return most_common_item, max_count
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Register all terrain types as custom map environments with colors
local function registerCustomEnvs()
  local index = MapColors.CustomEnvStart

  for terrain, rgb in pairs(MapColors.TerrainColor) do
    if rgb then
      local r, g, b = unpack(rgb)
      setCustomEnvColor(index, r, g, b, 255)
      MapColors.TerrainToEnv[terrain] = index
      MapColors.EnvToTerrain[index] = terrain
      local cstr = ("<%d,%d,%d>"):format(r, g, b)
      decho(("\n%s[%16s] = %d"):format(cstr, terrain, index))
      index = index + 1
    end
  end
end

-- Pre-compile connector word sets for O(1) lookup
local function initConnectorSets()
  for _, word in ipairs(MapColors.ConnectorWords) do
    MapColors._connectorWordSet[word] = true
  end
  for _, word in ipairs(MapColors.NonWaterConnectorWords) do
    MapColors._nonWaterConnectorSet[word] = true
  end
end

-- ============================================================================
-- ROOM ENVIRONMENT OPERATIONS
-- ============================================================================

-- Apply terrain to a room (handles both string terrain keys and legacy numeric env IDs)
local function applyEnv(id, value)
  if not value then return end

  if type(value) == "string" then
    local env = MapColors.TerrainToEnv[value]
    if env then
      setRoomEnv(id, env)
    end
  elseif type(value) == "number" then
    setRoomEnv(id, value)
  end
end

-- Get HTML color string for terrain (for display purposes)
local function getHColorString(value)
  if not value then return "" end

  if type(value) == "string" then
    local color = MapColors.TerrainColor[value]
    if color then
      local r, g, b = unpack(color)
      return ("<%d,%d,%d>"):format(r, g, b)
    end
  elseif type(value) == "number" then
    return ("<%s>"):format(MapColors.ColorNames[value])
  end

  return ""
end

-- ============================================================================
-- KEYWORD MATCHING (OPTIMIZED)
-- ============================================================================

-- Pre-compile pattern for a keyword (cached)
local function getCompiledPattern(word)
  if not MapColors._compiledPatterns[word] then
    -- Escape Lua pattern characters, then convert glob wildcards
    local pattern = word
      :gsub("([%^%$%(%)%.%[%]%+%-%?])", "%%%1")
      :gsub("%*", ".*")
    
    MapColors._compiledPatterns[word] = pattern
  end
  return MapColors._compiledPatterns[word]
end

-- Match a word against room name (supports wildcards and plural forms)
local function wordMatch(text, word)
  local pattern = getCompiledPattern(word)
  
  -- Match with word boundaries, handling singular and plural forms
  local p1 = "%f[%a]" .. pattern .. "s?%f[%A%-]"      -- base plural: hall/halls
  local p2 = "%f[%a]" .. pattern .. "es?%f[%A%-]"     -- es plural: box/boxes

  return text:find(p1) ~= nil or text:find(p2) ~= nil
end

-- ============================================================================
-- AREA ANALYSIS (CACHED)
-- ============================================================================

-- Analyze terrain composition of an area (cached for performance)
function MapColors.analyzeArea(areaId)
  if MapColors._areaTerrainCache[areaId] then
    return unpack(MapColors._areaTerrainCache[areaId])
  end

  local counts = {nature = 0, stony = 0, underground = 0, water = 0}

  for _, id in ipairs(MapColors._allRoomIds) do
    local data = MapColors._roomData[id]
    if data and data.areaId == areaId then
      local terrain = MapColors.EnvToTerrain[getRoomEnv(id)]
      
      if MapColors.NatureTerrains[terrain] then
        counts.nature = counts.nature + 1
      elseif MapColors.StonyTerrains[terrain] then
        counts.stony = counts.stony + 1
      elseif MapColors.UndergroundTerrains[terrain] then
        counts.underground = counts.underground + 1
      elseif MapColors.WaterTerrains[terrain] then
        counts.water = counts.water + 1
      end
    end
  end

  MapColors._areaTerrainCache[areaId] = {counts.nature, counts.stony, counts.underground, counts.water}
  return counts.nature, counts.stony, counts.underground, counts.water
end

-- Check if room has adjacent rooms of specific terrain types
function MapColors.filterAdjacentTerrain(id, terrainSet)
  local terrains = {}
  for _, adjId in pairs(getRoomExits(id) or {}) do
    local terrain = MapColors.EnvToTerrain[getRoomEnv(adjId)]
    if terrainSet[terrain] then
      table.insert(terrains, terrain)
    end
  end
  return terrains
end

-- Select the best nature terrain for paths (prioritizes path-appropriate terrains)
function MapColors.selectBestNatureTerrain(terrains)
  if not terrains or #terrains == 0 then return nil end
  
  -- Priority order for path selection (higher priority = better for paths)
  local priority = {
    [MapColors.Terrain.MUDDY] = 3,      -- Best for paths
    [MapColors.Terrain.WOODEN] = 3,     -- Best for paths
    [MapColors.Terrain.ENCAMPMENT] = 2, -- Good for paths
    [MapColors.Terrain.SANDY] = 2,      -- Good for paths
    [MapColors.Terrain.LIGHT_WOODS] = 1, -- Acceptable
    [MapColors.Terrain.THICK_WOODS] = 1, -- Acceptable
    [MapColors.Terrain.GRASSY] = 0,     -- Low priority
    [MapColors.Terrain.PLAINS] = 0,     -- Low priority
  }
  
  -- Count occurrences and find highest priority
  local counts = {}
  local maxPriority = -1
  
  for _, terrain in ipairs(terrains) do
    counts[terrain] = (counts[terrain] or 0) + 1
    local p = priority[terrain] or 0
    if p > maxPriority then
      maxPriority = p
    end
  end
  
  -- Among terrains with max priority, pick most common
  local bestTerrain = nil
  local bestCount = 0
  
  for terrain, count in pairs(counts) do
    local p = priority[terrain] or 0
    if p == maxPriority and count > bestCount then
      bestTerrain = terrain
      bestCount = count
    end
  end
  
  return bestTerrain or terrains[1]
end

-- ============================================================================
-- COORDINATE INDEXING (for INTERIOR_POI detection)
-- ============================================================================

-- Build a spatial index of rooms by coordinates
function MapColors.buildCoordIndex()
  local index = {}

  for _, id in ipairs(MapColors._allRoomIds) do
    local x, y, z = getRoomCoordinates(id)
    if x and y and z then
      index[z] = index[z] or {}
      index[z][x] = index[z][x] or {}
      index[z][x][y] = id
    end
  end

  return index
end

-- Check if room has adjacent INTERIOR_POI (within same area)
function MapColors.hasAdjacentInteriorPOI(id, coordIndex)
  local x, y, z = getRoomCoordinates(id)
  if not x then return false end

  local data = MapColors._roomData[id]
  local area = data.areaId
  local poiEnv = MapColors.TerrainToEnv[MapColors.Terrain.INTERIOR_POI]

  -- Check all 6 cardinal directions (±x, ±y, ±z)
  local deltas = {
    {1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}
  }

  for _, d in ipairs(deltas) do
    local layer = coordIndex[z + d[3]]
    if layer then
      local nid = layer[x + d[1]] and layer[x + d[1]][y + d[2]]
      if nid then
        local ndata = MapColors._roomData[nid]
        if ndata and ndata.areaId == area and getRoomEnv(nid) == poiEnv then
          return true
        end
      end
    end
  end

  return false
end

-- Fill uncolored rooms adjacent to INTERIOR_POI with INTERIOR_POI
function MapColors.FillInteriorPOI()
  local changes = 0
  local coordIndex = MapColors.buildCoordIndex()

  for _, id in ipairs(MapColors._allRoomIds) do
    if MapColors.isUncolored(id) and MapColors.hasAdjacentInteriorPOI(id, coordIndex) then
      applyEnv(id, MapColors.Terrain.INTERIOR_POI)
      changes = changes + 1
    end
  end

  cecho(("\n<forest_green>[FillInteriorPOI] filled %d rooms"):format(changes))
end

-- ============================================================================
-- ANALYSIS & REPORTING
-- ============================================================================

-- Report all uncolored rooms
function MapColors.ReportUncoloredRooms()
  cecho("\n<red>[UNCOLORED ROOMS]\n")
  local count = 0

  local c = Darkmists.getDefaultTextColorTag()
  for _, id in ipairs(MapColors._allRoomIds) do
    if getRoomEnv(id) == -1 then
      count = count + 1
      local data = MapColors._roomData[id]
      cecho(("\n<red>%-30s  %s(%s)"):format(data.name, c, data.areaName))
    end
  end

  cecho(("\n\n<red>Total uncolored rooms: %d\n"):format(count))
end

-- Suggest new keywords based on common words in uncolored rooms
function MapColors.SuggestKeywordsForUncolored(minLen, minCount)
  minLen = minLen or 5
  minCount = minCount or 2

  cecho("\n<ansi_cyan>[SUGGESTED KEYWORDS FOR UNCOLORED ROOMS]\n")

  local counts = {}
  local covered = {}

  -- Mark existing keywords as covered
  for _, entry in ipairs(MapColors.WordAssociations) do
    covered[entry[1]:lower()] = true
  end

  -- Count word occurrences in uncolored rooms
  for _, id in ipairs(MapColors._allRoomIds) do
    if MapColors.isUncolored(id) then
      local data = MapColors._roomData[id]
      for word in data.lowername:gmatch("%a+") do
        if #word >= minLen and not covered[word] and not MapColors.Blacklist[word] then
          counts[word] = (counts[word] or 0) + 1
        end
      end
    end
  end

  -- Sort by frequency
  local sorted = {}
  for word, count in pairs(counts) do
    if count >= minCount then
      table.insert(sorted, {word = word, count = count})
    end
  end

  table.sort(sorted, function(a, b) return a.count > b.count end)

  -- Display results
  local c = Darkmists.getDefaultTextColorTag()
  for _, entry in ipairs(sorted) do
    cecho(("\n<ansi_cyan>%-15s %s→ would color <ansi_cyan>%d %srooms"):format(entry.word, c, entry.count, c))
  end

  if #sorted == 0 then
    cecho("\n<dim_gray>No useful keyword candidates found.")
  end

  echo("\n")
end

-- ============================================================================
-- MAIN COLORING ALGORITHMS (HIGHLY OPTIMIZED)
-- ============================================================================

-- Apply keyword-based coloring to all rooms (HIGHLY OPTIMIZED)
function MapColors.UpdateMapColors()
  echo("\nUpdate Map: starting...")
  local startTime = os.clock()
  
  -- Build room data cache once
  buildRoomDataCache()
  local totalRooms = #MapColors._allRoomIds
  echo(("\nCached %d rooms in %.2fs"):format(totalRooms, os.clock() - startTime))
  
  -- Progress tracking
  local processed = 0
  local lastPercent = 0
  local updateStart = os.clock()
  
  -- BATCH 1: Apply area overrides (single pass)
  for _, id in ipairs(MapColors._allRoomIds) do
    if MapColors.isUncolored(id) then
      local data = MapColors._roomData[id]
      local color = MapColors.AreaOverrides[data.areaName]
      if color then
        applyEnv(id, color)
      end
    end
  end

  -- BATCH 2: Apply keyword associations (single pass through all rooms)
  local keywordStats = {}
  for _, entry in ipairs(MapColors.WordAssociations) do
    keywordStats[entry[1]:lower()] = {terrain = entry[2], count = 0}
  end

  -- Single iteration through all rooms, checking all keywords per room
  for _, id in ipairs(MapColors._allRoomIds) do
    local data = MapColors._roomData[id]
    local roomName = data.lowername
    
    -- Check each keyword against this room
    for _, entry in ipairs(MapColors.WordAssociations) do
      local word = entry[1]:lower()
      local terrain = entry[2]
      
      local matches = wordMatch(roomName, word) or 
                     (entry.matchPartial and roomName:find(word, 1, true))
      
      if matches then
        if not entry.onlyIfUncolored or MapColors.isUncolored(id) then
          applyEnv(id, terrain)
          keywordStats[word].count = keywordStats[word].count + 1
        end
      end
    end
    
    -- Progress indicator (every 10%)
    processed = processed + 1
    local percent = math.floor((processed / totalRooms) * 100)
    if percent >= lastPercent + 10 then
      echo(("\n  Progress: %d%% (%.2fs)"):format(percent, os.clock() - updateStart))
      lastPercent = percent
    end
  end

  -- Display statistics
  cecho("\n\n<ansi_cyan>Keyword Statistics:")
  local statCount = 0
  for word, stats in pairs(keywordStats) do
    if stats.count > 0 then
      statCount = statCount + 1
      if statCount <= 20 then  -- Only show top 20 to reduce output lag
        local c = Darkmists.getDefaultTextColorTag()
        local str = "\n"..c.."[<cword>%-12s"..c.."] room count → <cword>%d"..c
        str = decho2cecho(str:gsub("<cword>", getHColorString(stats.terrain)))
        cecho(str:format(word, stats.count))
      end
    end
  end
  if statCount > 20 then
    cecho(("\n<gray>... and %d more keywords"):format(statCount - 20))
  end

  local elapsed = os.clock() - startTime
  echo(("\n\nUpdate Map: done in %.2fs!\n"):format(elapsed))
end

-- Color rooms based on adjacent room colors (majority voting)
function MapColors.AdjacencyCorrection(minNeighbors)
  minNeighbors = minNeighbors or 2
  local changes = 0
  
  -- Pre-build list of uncolored rooms with their exits
  local uncoloredRooms = {}
  for _, id in ipairs(MapColors._allRoomIds) do
    if MapColors.isUncolored(id) then
      table.insert(uncoloredRooms, {id = id, exits = getRoomExits(id) or {}})
    end
  end

  for _, roomInfo in ipairs(uncoloredRooms) do
    local counts = {}

    -- Count terrain types of adjacent rooms
    for _, adjId in pairs(roomInfo.exits) do
      local env = getRoomEnv(adjId)
      if env and env > 0 then
        counts[env] = (counts[env] or 0) + 1
      end
    end

    -- Find majority terrain
    local bestEnv, bestCount = nil, 0
    for env, count in pairs(counts) do
      if count > bestCount then
        bestEnv, bestCount = env, count
      end
    end

    if bestEnv and bestCount >= minNeighbors then
      applyEnv(roomInfo.id, bestEnv)
      changes = changes + 1
    end
  end

  cecho(("\n<forest_green>[Adjacency pass] Colored %d rooms"):format(changes))
  return changes
end

-- Handle connector rooms (roads, passages, etc.) based on context
function MapColors.ConnectorPass()
  local changes = 0
  
  -- Pre-cache connector room list for faster iteration
  local connectorRooms = {}
  
  for _, id in ipairs(MapColors._allRoomIds) do
    local data = MapColors._roomData[id]
    local name = data.lowername

    -- Check if room is a connector (using set lookup)
    for word in name:gmatch("%a+") do
      if MapColors._connectorWordSet[word] then
        connectorRooms[id] = {name = name, areaId = data.areaId}
        break
      end
    end
  end

  -- Process only connector rooms
  for id, info in pairs(connectorRooms) do
    -- Skip if already WOODEN (e.g., "suspended walkway" or "bridge")
    local currentEnv = getRoomEnv(id)
    if currentEnv ~= MapColors.TerrainToEnv[MapColors.Terrain.WOODEN]
      and currentEnv ~= MapColors.TerrainToEnv[MapColors.Terrain.STONE_WHITE] then
      local name = info.name
      local chosenTerrain = nil
    
      -- Check if water connectors are allowed
      local canBeWater = true
      for word in name:gmatch("%a+") do
        if MapColors._nonWaterConnectorSet[word] then
          canBeWater = false
          break
        end
      end

      -- Priority 1: Use adjacent terrain context
      local waterTerrains  = MapColors.filterAdjacentTerrain(id, MapColors.WaterTerrains)
      local stonyTerrains  = MapColors.filterAdjacentTerrain(id, MapColors.StonyTerrains)
      local natureTerrains = MapColors.filterAdjacentTerrain(id, MapColors.NatureTerrains)
      local undergroundTerrains = MapColors.filterAdjacentTerrain(id, MapColors.UndergroundTerrains)
      
      if waterTerrains and #waterTerrains > 0 and canBeWater then
        chosenTerrain = getMostCommonArrayItem(waterTerrains)
      elseif undergroundTerrains and #undergroundTerrains > #stonyTerrains and #undergroundTerrains > #natureTerrains then
        chosenTerrain = getMostCommonArrayItem(undergroundTerrains)
      elseif stonyTerrains and #stonyTerrains > #undergroundTerrains and #stonyTerrains > #natureTerrains then
        chosenTerrain = MapColors.Terrain.STONY_PATH
      elseif natureTerrains and #natureTerrains > #undergroundTerrains and #natureTerrains > #stonyTerrains then
        -- Use intelligent selection for nature terrains (prioritizes MUDDY/WOODEN)
        chosenTerrain = MapColors.selectBestNatureTerrain(natureTerrains)
      else
        -- Priority 2: Use area-wide terrain distribution
        local nature, stony, underground, water = MapColors.analyzeArea(info.areaId)

        if underground > nature and underground > stony and underground > water then
          chosenTerrain = MapColors.Terrain.SHADOWY
        elseif nature > stony and nature > underground and nature > water then
          chosenTerrain = MapColors.Terrain.MUDDY
        elseif canBeWater and water > stony and water > nature and water > underground then
          chosenTerrain = MapColors.Terrain.CLEAR_WATER
        else
          chosenTerrain = MapColors.Terrain.STONY_PATH
        end
      end

      if chosenTerrain then
        applyEnv(id, chosenTerrain)
        changes = changes + 1
      end
    end
  end

  cecho(("\n<forest_green>[ConnectorPass] adjusted %d rooms"):format(changes))
end

-- Color all remaining uncolored rooms as NOEXIT (fallback)
function MapColors.ColorRemainingRooms()
  local changes = 0
  
  for _, id in ipairs(MapColors._allRoomIds) do
    if getRoomEnv(id) == -1 then
      applyEnv(id, MapColors.Terrain.NOEXIT)
      changes = changes + 1
    end
  end
  
  cecho(("\n<forest_green>[ColorRemainingRooms] adjusted %d rooms"):format(changes))
end

-- Reset all rooms to uncolored state
function MapColors.ResetAllRooms()
  -- Batch reset for better performance
  if not MapColors._allRoomIds or #MapColors._allRoomIds == 0 then
    buildRoomDataCache()
  end
  
  for _, id in ipairs(MapColors._allRoomIds) do
    setRoomEnv(id, -1)
  end
  MapColors.ClearCaches()
end

-- ============================================================================
-- BATCH UPDATE FUNCTIONS
-- ============================================================================

-- Full coloring pass (from scratch)
function MapColors.FullUpdatePass()
  local startTime = os.clock()
  
  MapColors.ResetAllRooms()
  MapColors.UpdateMapColors()
  MapColors.ConnectorPass()
  MapColors.FillInteriorPOI()
  MapColors.FillInteriorPOI()  -- Run twice to fill gaps
  
  local elapsed = os.clock() - startTime
  cecho(("\n<forest_green>[FullUpdatePass] Completed in %.2f seconds"):format(elapsed))
end

-- Final cleanup pass (adjacency + fallback)
function MapColors.FinalUpdatePass()
  local startTime = os.clock()
  
  MapColors.AdjacencyCorrection(3)
  MapColors.AdjacencyCorrection(2)
  MapColors.AdjacencyCorrection(1)
  MapColors.AdjacencyCorrection(1)  -- Run twice to propagate colors
  MapColors.ColorRemainingRooms()
  
  local elapsed = os.clock() - startTime
  cecho(("\n<forest_green>[FinalUpdatePass] Completed in %.2f seconds"):format(elapsed))
end

-- ============================================================================
-- AREA CONNECTION AUDITING
-- ============================================================================

-- Audit a specific area for exit stubs and external connections
function MapColors.AuditAreaByRoomID(roomID)
  local areaID = getRoomArea(roomID)
  local areaName = getRoomAreaName(areaID)
  local rooms = getAreaRooms1(areaID)

  local stubRooms = {}         -- roomID -> {directions}
  local stubCount = 0
  local connectedAreas = {}    -- areaID -> {name, links}

  for _, roomID in pairs(rooms) do
    -- Find exit stubs
    local stubs = getExitStubs1(roomID)
    if stubs and next(stubs) then
      stubRooms[roomID] = {}
      for _, dir in pairs(stubs) do
        table.insert(stubRooms[roomID], MapColors.StubMap[dir])
        stubCount = stubCount + 1
      end
    end

    -- Find external connections
    for dir, destRoom in pairs(getRoomExits(roomID) or {}) do
      if destRoom > 0 then
        local destArea = getRoomArea(destRoom)
        if destArea ~= areaID then
          connectedAreas[destArea] = connectedAreas[destArea] or {
            name = getRoomAreaName(destArea),
            links = {}
          }
          table.insert(connectedAreas[destArea].links, {
            fromRoom = roomID,
            direction = dir,
            toRoom = destRoom
          })
        end
      end
    end
  end

  -- Display results
  local c = Darkmists.getDefaultTextColorTag()
  cecho(string.format("<forest_green>[Mapper Audit]\n"..c.."Area: <dark_khaki>%s\n", areaName))
  cecho(string.format(c.."Total unconnected exit stubs: <red>%d\n\n", stubCount))

  -- Show stub rooms
  if next(stubRooms) then
    cecho(c.."Rooms With Exit Stubs:\n")
    for roomID, dirs in pairs(stubRooms) do
      cechoLink(
        string.format("  <blue_violet>%s (%d)", getRoomName(roomID), roomID),
        string.format("gotoRoom(%d)", roomID),
        string.format("Go to room %d", roomID),
        true
      )
      cecho(string.format("<dim_gray>  [%s]\n", table.concat(dirs, ", ")))
    end
    cecho("\n")
  else
    cecho("<dim_gray>No unconnected exit stubs found.\n\n")
  end

  -- Show connected areas
  if next(connectedAreas) then
    cecho(c.."Connected Areas:\n")
    for _, info in pairs(connectedAreas) do
      cechoLink(
        string.format("<dark_khaki>%s\n", info.name),
        string.format("MapColors.AuditAreaByRoomID(%d)", info.links[1].toRoom),
        string.format("Audit area %s", info.name),
        true
      )
      for _, link in ipairs(info.links) do
        cechoLink(
          string.format("  <steel_blue>%-32s", string.format("%s (%s)", getRoomName(link.fromRoom), link.fromRoom)),
          string.format("gotoRoom(%d)", link.fromRoom),
          string.format("Go to room %d", link.fromRoom),
          true
        )
        cecho(string.format(" -[%-5s]-> ", link.direction))
        cechoLink(
          string.format("<steel_blue>%s", getRoomAreaName(getRoomArea(link.toRoom))),
          string.format("gotoRoom(%d)", link.toRoom),
          string.format("Go to room %d", link.toRoom),
          true
        )
        cecho("\n")
      end
    end
  else
    cecho("<dim_gray>No external area connections found.\n")
  end
end

-- Audit current area (based on player location)
function MapColors.AuditCurrentArea()
  local playerRoom = getPlayerRoom()
  if not playerRoom then
    cecho("<red>[Mapper] No player room found.\n")
    return
  end
  MapColors.AuditAreaByRoomID(playerRoom)
end

-- Audit all areas with exit stubs (global scan)
function MapColors.AuditAllAreasWithStubs()
  cecho("\n<forest_green>[GLOBAL AREA STUB AUDIT]\n")

  -- Areas to skip (known locked/inaccessible areas)
  local ignoreAreaIDs = {
    [128] = true,  -- isle of death - locked trap door
    [120] = true,  -- basilica catacombs - locked cells
    [169] = true,  -- pyramid of thaloc - locked door
    [130] = true,  -- bluebeard's hidden pub - locked door
    [196] = true,  -- castle of lost hope - locked entrance
    [47]  = true,  -- eastern forest delta - locked door in castle
    [88]  = true,  -- obsidian order - locked painting
    [116] = true,  -- guldoran castle - locked cells in dungeon
    [49]  = true,  -- halls of legion - locked door at end of secret passage
    [65]  = true,  -- dragon tower - gate behind tiamat
    [144]  = true, -- dragon sea - do last
    [154]  = true, -- ocean of jthar - do last
    [72] = true,   -- aesil am gomany - deep holes?
  }

  for areaName, areaID in pairs(getAreaTable()) do
    if not ignoreAreaIDs[areaID] then
      local areaRooms = getAreaRooms1(areaID)

      if areaRooms and #areaRooms > 0 then
        local stubCount = 0
        local entryRooms = {}

        for _, roomID in pairs(areaRooms) do
          -- Count exit stubs
          local stubs = getExitStubs1(roomID)
          if stubs then
            for _ in pairs(stubs) do
              stubCount = stubCount + 1
            end
          end

          -- Detect entry points (exits to other areas)
          for _, destRoom in pairs(getRoomExits(roomID) or {}) do
            if destRoom > 0 and getRoomArea(destRoom) ~= areaID then
              entryRooms[roomID] = true
            end
          end
        end

        -- Only display areas with stubs
        local c = Darkmists.getDefaultTextColorTag()
        if stubCount > 0 then
          cecho(string.format("\n<dark_khaki>%s <dim_gray>(ID %d)\n", areaName, areaID))
          cecho(string.format(c.."  Unconnected exit stubs: <red>%d\n", stubCount))

          if next(entryRooms) then
            cecho(c.."  Entry points:\n")
            for roomID in pairs(entryRooms) do
              cechoLink(
                string.format("    <steel_blue>%s (%d)\n", getRoomName(roomID), roomID),
                string.format("gotoRoom(%d)", roomID),
                string.format("Go to room %d", roomID),
                true
              )
            end
          else
            cecho("<dim_gray>  No entry points detected.\n")
          end
        end
      end
    end
  end

  cecho("\n<forest_green>[Audit complete]\n")
end

-- ============================================================================
-- INITIALIZATION ON LOAD
-- ============================================================================

registerCustomEnvs()
initConnectorSets()
