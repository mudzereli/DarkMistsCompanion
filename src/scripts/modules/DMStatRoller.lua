-- file: scripts/statroller_update.lua
-- Engaging HUD with Trend scaled to recent min..max

StatRoller = StatRoller or {}
StatRoller.settings = StatRoller.settings or {}
StatRoller.state = StatRoller.state or {}
StatRoller.current_stats = StatRoller.current_stats or {}
StatRoller.maximum_stats = StatRoller.maximum_stats or {}
StatRoller.recent_totals = StatRoller.recent_totals or {}
StatRoller.enabled = StatRoller.enabled ~= false
StatRoller.best_total = tonumber(StatRoller.best_total) or 0
StatRoller.best_stats = StatRoller.best_stats or nil
StatRoller._spin = tonumber(StatRoller._spin) or 0

-- ---------- utils ----------
local function pad(n, w) return string.format("%" .. tostring(w) .. "d", n or 0) end
local function getopt(k, default) local v = StatRoller.settings and StatRoller.settings[k]; return (v==nil) and default or v end
local function now() return (getEpoch and getEpoch()) or os.time() end

local textTag = DarkmistsTheme.textTag
local mutedTag = DarkmistsTheme.mutedTag
local goodTag = DarkmistsTheme.goodTag
local infoTag = DarkmistsTheme.infoTag
local warnTag = DarkmistsTheme.warnTag
local badTag = DarkmistsTheme.badTag
local highlightTag = DarkmistsTheme.highlightTag
local pluginColor = DarkmistsTheme.orangeTag
local pluginName = pluginColor .. "StatRoller"

local DEFAULT_SETTINGS = {
  nCalibrationLines = 20,
  showDetails = true,
  barWidth = 24,
  sparklineWidth = 16,
  keepalive_interval = 20,
  keepalive_command = " ",
}

local DEFAULT_STATE = {
  nRollsCompleted = 0,
  first_ts = nil,
  last_ts = nil,
  leniency_prompt_shown = false,
  awaiting_leniency_choice = false,
}

local function apply_defaults(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      target[key] = value
    end
  end
end

local function ensure_stat_block(block)
  block.str = tonumber(block.str) or 0
  block.int = tonumber(block.int) or 0
  block.wis = tonumber(block.wis) or 0
  block.dex = tonumber(block.dex) or 0
  block.con = tonumber(block.con) or 0
  block.total = tonumber(block.total) or 0
end

local function refresh_theme_refs()
  local theme = DarkmistsTheme or {}
  textTag = theme.textTag or ""
  mutedTag = theme.mutedTag or ""
  goodTag = theme.goodTag or ""
  infoTag = theme.infoTag or ""
  warnTag = theme.warnTag or ""
  badTag = theme.badTag or ""
  highlightTag = theme.highlightTag or ""
  pluginColor = theme.orangeTag or theme.accentTag or theme.infoTag or ""
  pluginName = pluginColor .. "StatRoller"
end

local function notify(msg)
  DMLogger.notify(pluginName, msg)
end

local function reset_stat_block(block)
  block.str, block.int, block.wis, block.dex, block.con, block.total = 0, 0, 0, 0, 0, 0
end

local KEEPALIVE_STOP_KEY = "StatRoller.KeepaliveStop"

local function clear_keepalive_timer()
  DarkmistsEvents.remove(KEEPALIVE_STOP_KEY)
  if StatRoller._keepalive_timer then
    killTimer(StatRoller._keepalive_timer)
    StatRoller._keepalive_timer = nil
    return true
  end
  return false
end

local function ensure_initialized()
  if not StatRoller._initialized then
    StatRoller.init()
  end
end

function StatRoller.set_leniency(value)
  ensure_initialized()

  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  if value > 3 then value = 3 end

  StatRoller.settings.leniency = value
  Darkmists.GlobalSettings.statRollerLeniency = value
  Darkmists.SaveSettings()
  StatRoller.state.awaiting_leniency_choice = false

  notify(infoTag .. "Leniency set to " .. goodTag .. tostring(value))

  if StatRoller.enabled and (StatRoller.state.nRollsCompleted or 0) > 0 then
    local N = tonumber(getopt("nCalibrationLines", 20)) or 20
    local L = tonumber(getopt("leniency", 0)) or 0
    local keep = (StatRoller.current_stats.total >= math.max(0, (StatRoller.maximum_stats.total or 0) - L))

    if (StatRoller.state.nRollsCompleted < N) or not keep then
      StatRoller.state.done = false
      StatRoller._stop_keepalive()
      send("N")
    else
      if not StatRoller.state.done then
        StatRoller.state.done = true
        StatRoller._start_keepalive()
      end
    end
  end
end

function StatRoller.prompt_leniency()
  ensure_initialized()

  local current = tonumber(Darkmists.GlobalSettings.statRollerLeniency) or tonumber(StatRoller.settings.leniency) or 0
  StatRoller.settings.leniency = current

  notify(highlightTag .. "Choose leniency " .. mutedTag .. "(current " .. goodTag .. tostring(current) .. mutedTag .. "):")

  for value = 0, 3 do
    local tag = value == current and goodTag or highlightTag
    cechoLink(
      tag .. "<u>[" .. tostring(value) .. "]</u>" .. textTag,
      string.format("StatRoller.set_leniency(%d)", value),
      string.format("Set stat roller leniency to %d", value),
      true
    )

    if value < 3 then
      cecho(mutedTag .. " " .. textTag)
    else
      cecho("\n")
    end
  end
end

local function progress_bar(cur, maxv, width, fg, bg)
  width = tonumber(width) or 1
  if width < 1 then width = 1 end
  cur  = tonumber(cur) or 0
  maxv = tonumber(maxv) or 0
  if maxv <= 0 then return mutedTag .. string.rep("░", width) .. textTag end
  if cur < 0 then cur = 0 elseif cur > maxv then cur = maxv end
  local filled = math.floor((cur / maxv) * width + 0.5); if filled > width then filled = width end
  return (fg or goodTag) .. string.rep("█", filled) .. textTag
    .. (bg or mutedTag) .. string.rep("░", width - filled) .. textTag
end

local function fmt_delta(delta, maxv)
  delta = tonumber(delta) or 0
  if delta == 0 then return goodTag .. "0" .. textTag end
  local pct = (maxv and maxv > 0) and (delta / maxv) or 1
  local tag = (pct <= 0.05) and warnTag or badTag
  return tag .. tostring(delta) .. textTag
end

-- ===== Trend helpers: scale by recent MIN..MAX ===============================
local SPARKS = { "▁","▂","▃","▄","▅","▆","▇","█" }

local function recent_range(samples, width)
  if #samples == 0 then return 0, 0 end
  local start = math.max(1, #samples - (width or #samples) + 1)
  local minv, maxv = math.huge, -math.huge
  for i = start, #samples do
    local v = tonumber(samples[i]) or 0
    if v < minv then minv = v end
    if v > maxv then maxv = v end
  end
  if minv == math.huge then minv = 0 end
  if maxv == -math.huge then maxv = 0 end
  return minv, maxv
end

local function sparkline(samples, minv, maxv, width)
  width = tonumber(width) or 1
  if width < 1 then width = 1 end
  if #samples == 0 then return mutedTag .. string.rep("·", width) .. textTag end

  local out = {}
  local start = math.max(1, #samples - width + 1)

  if maxv == nil or minv == nil then
    minv, maxv = recent_range(samples, width)
  end

  if maxv <= minv then
    -- flat series: draw a mid-level line
    local mid = math.max(1, math.min(#SPARKS, math.floor(#SPARKS / 2)))
    return infoTag .. string.rep(SPARKS[mid], math.min(width, #samples - start + 1)) .. textTag
  end

  for i = start, #samples do
    local v = tonumber(samples[i]) or 0
    local norm = (v - minv) / (maxv - minv)   -- 0..1 over recent window
    local idx = math.floor(norm * (#SPARKS - 1) + 0.5) + 1
    if idx < 1 then idx = 1 elseif idx > #SPARKS then idx = #SPARKS end
    out[#out+1] = SPARKS[idx]
  end
  return infoTag .. table.concat(out) .. textTag
end

-- ---------- parsing ----------
function StatRoller.parse_stats_strict(line)
  local s,i,w,d,c = line:match("^Strength:%s*(%d+)%s+Intelligence:%s*(%d+)%s+Wisdom:%s*(%d+)%s+Dexterity:%s*(%d+)%s+Constitution:%s*(%d+)%s*$")
  if not s then return nil, "no match" end
  s,i,w,d,c = tonumber(s), tonumber(i), tonumber(w), tonumber(d), tonumber(c)
  return { str=s, int=i, wis=w, dex=d, con=c, total=s+i+w+d+c }
end

-- ---------- state updates ----------
function StatRoller.update_current(stats)
  local cs = StatRoller.current_stats
  cs.str, cs.int, cs.wis, cs.dex, cs.con = stats.str, stats.int, stats.wis, stats.dex, stats.con
  cs.total = stats.total
  return cs
end

function StatRoller.update_maximum(stats)
  local ms = StatRoller.maximum_stats
  if stats.str > ms.str then ms.str = stats.str end
  if stats.int > ms.int then ms.int = stats.int end
  if stats.wis > ms.wis then ms.wis = stats.wis end
  if stats.dex > ms.dex then ms.dex = stats.dex end
  if stats.con > ms.con then ms.con = stats.con end
  ms.total = ms.str + ms.int + ms.wis + ms.dex + ms.con
  return ms
end

local function update_records(stats)
  if stats.total > (StatRoller.best_total or 0) then
    StatRoller.best_total = stats.total
    StatRoller.best_stats = { str=stats.str, int=stats.int, wis=stats.wis, dex=stats.dex, con=stats.con, total=stats.total }
    notify(goodTag .. "New best total: " .. tostring(stats.total) .. "!")
  end
end

local function push_recent(total)
  local w = getopt("sparklineWidth", 16)
  local buf = StatRoller.recent_totals
  buf[#buf+1] = total
  if #buf > w * 4 then table.remove(buf, 1) end
end

local function roll_rate()
  local first, last = StatRoller.state.first_ts, StatRoller.state.last_ts
  if not first or not last or last <= first then return 0 end
  local minutes = (last - first) / 60
  if minutes <= 0 then return 0 end
  return StatRoller.state.nRollsCompleted / minutes
end

-- ---------- HUD ----------
function StatRoller.echo_hud()
  local cs, ms = StatRoller.current_stats, StatRoller.maximum_stats
  local rolls  = StatRoller.state.nRollsCompleted
  local N      = tonumber(getopt("nCalibrationLines", 20)) or 20
  local calibrating = rolls < N
  local delta  = math.max(0, (ms.total or 0) - (cs.total or 0))

  local frames = { "|","/","-","\\" }
  StatRoller._spin = (StatRoller._spin % #frames) + 1
  local spin = frames[StatRoller._spin]

  local status
  local _bar
  local bw = getopt("barWidth", 24)
  if calibrating then
    status = warnTag .. ("CAL %d/%d"):format(rolls, N) .. textTag
    _bar = progress_bar(rolls, N, bw, warnTag, mutedTag)
  else
    local phase = (cs.total >= ms.total and ms.total > 0) and (goodTag .. "READY" .. textTag) or (warnTag .. "ROLLING" .. textTag)
    status = infoTag .. "LIVE " .. textTag .. mutedTag .. "• " .. textTag .. phase
    _bar = progress_bar(cs.total, ms.total, bw, goodTag, mutedTag)
  end

  local totals = (cs.total >= ms.total and ms.total > 0)
    and (goodTag .. pad(cs.total,2) .. textTag .. mutedTag .. "/" .. textTag .. goodTag .. pad(ms.total,2) .. textTag)
    or  (textTag .. pad(cs.total,2) .. mutedTag .. "/" .. textTag .. pad(ms.total,2))

  local rpm = roll_rate()
  local elapsed = 0
  if StatRoller.state.first_ts and StatRoller.state.last_ts then
    elapsed = math.max(0, StatRoller.state.last_ts - StatRoller.state.first_ts)
  end
  local mm = math.floor(elapsed / 60); local ss = elapsed % 60

  local bestStr = StatRoller.best_total and StatRoller.best_total > 0
    and (goodTag .. tostring(StatRoller.best_total) .. textTag) or (mutedTag .. "-" .. textTag)

  cecho(("\n%s %s %s\n%s %s  %s %s %s %s  %s %s  %s %s")
    :format(
      mutedTag .. "["..pluginColor.."StatRoller"..mutedTag.."]" .. textTag, textTag .. spin .. textTag, status,
      mutedTag .. "Total" .. textTag, totals,
      mutedTag .. "Δ" .. textTag, fmt_delta(delta, ms.total),
      mutedTag .. "Rolls" .. textTag, textTag .. tostring(rolls) .. textTag,
      mutedTag .. "RPM" .. textTag, textTag .. string.format("%.1f", rpm) .. textTag,
      mutedTag .. "Elapsed" .. textTag, textTag .. string.format("%02d:%02d", mm, ss) .. textTag
    ))
  
  cecho("\n")
  -- Trend sparkline scaled to recent MIN..MAX
  local w = getopt("sparklineWidth", 16)
  if #StatRoller.recent_totals > 0 then
    local minv, maxv = recent_range(StatRoller.recent_totals, w)
    local sl = sparkline(StatRoller.recent_totals, minv, maxv, w)
    cecho(("%s %s  %s %s")
      :format(
        mutedTag .. "Trend" .. textTag,
        sl,
        mutedTag .. "Range" .. textTag,
        textTag .. ("%d–%d"):format(minv, maxv) .. textTag
      ))
    cecho(("  %s %s"):format(mutedTag .. "Best" .. textTag, bestStr))
  else
    cecho(("  %s %s"):format(mutedTag .. "Best" .. textTag, bestStr))
  end

  if getopt("showDetails", true) then
    local function statPair(lbl, cur, maxv)
      local curTag = (maxv > 0 and cur >= maxv) and goodTag or textTag
      return mutedTag .. lbl .. textTag .. " " .. curTag .. pad(cur,2) .. textTag .. mutedTag .. "/" .. textTag .. textTag .. pad(maxv,2)
    end
    cecho(("\n%s  %s  %s  %s  %s")
      :format(
        statPair("STR", cs.str, ms.str),
        statPair("INT", cs.int, ms.int),
        statPair("WIS", cs.wis, ms.wis),
        statPair("DEX", cs.dex, ms.dex),
        statPair("CON", cs.con, ms.con)
      ))
  end
end
-- ---------- keepalive ----------
function StatRoller._start_keepalive()
  if StatRoller._keepalive_timer then return end

  StatRoller._keepalive_timer = tempTimer(
    tonumber(StatRoller.settings.keepalive_interval) or 20,
    function()
      if StatRoller.state.done then
        send(StatRoller.settings.keepalive_command or " ")
      end
    end,
    true
  )

  -- Stop automatically on the first prompt after leaving the stat roller screen
  DarkmistsEvents.add(KEEPALIVE_STOP_KEY, "dmapi.world.prompt", function()
    StatRoller._stop_keepalive()
  end, true)  -- one-shot

  notify(infoTag .. "Keepalive enabled")
end

function StatRoller._stop_keepalive()
  if clear_keepalive_timer() then
    notify(warnTag .. "Keepalive disabled")
  end
end

function StatRoller.reset_session()
  ensure_initialized()

  clear_keepalive_timer()

  StatRoller.state.nRollsCompleted = 0
  StatRoller.state.first_ts = nil
  StatRoller.state.last_ts = nil
  StatRoller.state.done = false
  StatRoller.state.leniency_prompt_shown = false
  StatRoller.state.awaiting_leniency_choice = false

  reset_stat_block(StatRoller.current_stats)
  reset_stat_block(StatRoller.maximum_stats)

  StatRoller.best_total = 0
  StatRoller.best_stats = nil
  StatRoller.recent_totals = {}
  StatRoller._spin = 0
end

function StatRoller.init()
  refresh_theme_refs()

  apply_defaults(StatRoller.settings, DEFAULT_SETTINGS)
  apply_defaults(StatRoller.state, DEFAULT_STATE)

  ensure_stat_block(StatRoller.current_stats)
  ensure_stat_block(StatRoller.maximum_stats)

  StatRoller.settings.leniency = tonumber(Darkmists.GlobalSettings.statRollerLeniency)
    or tonumber(StatRoller.settings.leniency)
    or 0

  StatRoller.enabled = true
  StatRoller._initialized = true
end

function StatRoller.destroy()
  clear_keepalive_timer()

  if StatRoller.state then
    StatRoller.state.awaiting_leniency_choice = false
    StatRoller.state.leniency_prompt_shown = false
    StatRoller.state.done = false
  end

  StatRoller._initialized = false
end

-- ---------- entrypoint ----------
function StatRoller.on_line(line)
  ensure_initialized()

  if line:match("^%[R%]oll stats      %- achieve maximum rolling potential %(random rolls%)") then
    StatRoller.reset_session()
    StatRoller.enabled = true
    StatRoller.state.awaiting_leniency_choice = true
    StatRoller.settings.leniency = tonumber(Darkmists.GlobalSettings.statRollerLeniency) or tonumber(StatRoller.settings.leniency) or 0
  end
  if line:match("^Point Sacrifice: 3 points left") then
    StatRoller.enabled = false
    StatRoller.state.leniency_prompt_shown = false
  end
  if not StatRoller.enabled then return false end
  local stats = StatRoller.parse_stats_strict(line)
  if not stats then return false end

  if StatRoller.state.awaiting_leniency_choice then
    if not StatRoller.state.leniency_prompt_shown then
      -- Capture first roll baseline silently; wait for user choice before showing HUD/output.
      StatRoller.state.nRollsCompleted = StatRoller.state.nRollsCompleted + 1
      if not StatRoller.state.first_ts then StatRoller.state.first_ts = now() end
      StatRoller.state.last_ts = now()

      StatRoller.update_current(stats)
      StatRoller.update_maximum(stats)
      push_recent(stats.total)

      if stats.total > (StatRoller.best_total or 0) then
        StatRoller.best_total = stats.total
        StatRoller.best_stats = { str=stats.str, int=stats.int, wis=stats.wis, dex=stats.dex, con=stats.con, total=stats.total }
      end

      StatRoller.prompt_leniency()
      StatRoller.state.leniency_prompt_shown = true
    end
    return true
  end

  StatRoller.state.nRollsCompleted = StatRoller.state.nRollsCompleted + 1
  if not StatRoller.state.first_ts then StatRoller.state.first_ts = now() end
  StatRoller.state.last_ts = now()

  StatRoller.update_current(stats)
  StatRoller.update_maximum(stats)
  update_records(stats)

  -- buffer last totals for trend
  push_recent(stats.total)

  StatRoller.echo_hud()

  local N = tonumber(getopt("nCalibrationLines", 20)) or 20
  local L = tonumber(getopt("leniency", 0)) or 0
  local keep = (StatRoller.current_stats.total >= math.max(0, (StatRoller.maximum_stats.total or 0) - L))

  if (StatRoller.state.nRollsCompleted < N) or not keep then
    -- still rolling
    StatRoller.state.done = false
    StatRoller._stop_keepalive()
    send("N")
  else
    -- finished rolling
    if not StatRoller.state.done then
      StatRoller.state.done = true
      StatRoller._start_keepalive()
    end
  end

  return true
end

-- Trigger usage:
-- do StatRoller.on_line(line) end
