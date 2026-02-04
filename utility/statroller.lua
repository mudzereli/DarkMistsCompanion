-- file: scripts/statroller_update.lua
-- Engaging HUD with Trend scaled to recent min..max

StatRoller = {
  enabled = true,
  settings = {
    nCalibrationLines = 20,
    showDetails = true,
    barWidth = 24,
    sparklineWidth = 16,   -- window size for trend + range
    leniency = Darkmists.GlobalSettings.statRollerLeniency,
    keepalive_interval = 20,   -- seconds between keepalive sends
    keepalive_command  = " ",  -- space = safest (Enter also works)
  },
  state = {
    nRollsCompleted = 0,
    first_ts = nil,
    last_ts  = nil,
  },
  current_stats = { str=0,int=0,wis=0,dex=0,con=0,total=0 },
  maximum_stats = { str=0,int=0,wis=0,dex=0,con=0,total=0 },
  best_total = 0,
  best_stats = nil,
  recent_totals = {},
  _spin = 0,
}

-- ---------- utils ----------
local function color(tag, s) return "<" .. tag .. ">" .. s .. "<white>" end
local function pad(n, w) return string.format("%" .. tostring(w) .. "d", n or 0) end
local function getopt(k, default) local v = StatRoller.settings and StatRoller.settings[k]; return (v==nil) and default or v end
local function now() return (getEpoch and getEpoch()) or os.time() end

local function progress_bar(cur, maxv, width, fg, bg)
  width = tonumber(width) or 1
  if width < 1 then width = 1 end
  cur  = tonumber(cur) or 0
  maxv = tonumber(maxv) or 0
  if maxv <= 0 then return color("grey", string.rep("░", width)) end
  if cur < 0 then cur = 0 elseif cur > maxv then cur = maxv end
  local filled = math.floor((cur / maxv) * width + 0.5); if filled > width then filled = width end
  return color(fg or "green", string.rep("█", filled)) .. color(bg or "grey", string.rep("░", width - filled))
end

local function fmt_delta(delta, maxv)
  delta = tonumber(delta) or 0
  if delta == 0 then return color("green", "0") end
  local pct = (maxv and maxv > 0) and (delta / maxv) or 1
  local tag = (pct <= 0.05) and "yellow" or "red"
  return color(tag, tostring(delta))
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
  if #samples == 0 then return color("grey", string.rep("·", width)) end

  local out = {}
  local start = math.max(1, #samples - width + 1)

  if maxv == nil or minv == nil then
    minv, maxv = recent_range(samples, width)
  end

  if maxv <= minv then
    -- flat series: draw a mid-level line
    local mid = math.max(1, math.min(#SPARKS, math.floor(#SPARKS / 2)))
    return color("cyan", string.rep(SPARKS[mid], math.min(width, #samples - start + 1)))
  end

  for i = start, #samples do
    local v = tonumber(samples[i]) or 0
    local norm = (v - minv) / (maxv - minv)   -- 0..1 over recent window
    local idx = math.floor(norm * (#SPARKS - 1) + 0.5) + 1
    if idx < 1 then idx = 1 elseif idx > #SPARKS then idx = #SPARKS end
    out[#out+1] = SPARKS[idx]
  end
  return color("cyan", table.concat(out))
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
    cecho("\n" .. color("green", "[SR] New best total: " .. stats.total .. "!"))
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

  local status, bar
  local bw = getopt("barWidth", 24)
  if calibrating then
    status = color("yellow", ("CAL %d/%d"):format(rolls, N))
    bar    = progress_bar(rolls, N, bw, "yellow", "grey")
  else
    local phase = (cs.total >= ms.total and ms.total > 0) and color("green","READY") or color("yellow","ROLLING")
    status = color("cyan", "LIVE ") .. color("grey", "• ") .. phase
    bar    = progress_bar(cs.total, ms.total, bw, "green", "grey")
  end

  local totals = (cs.total >= ms.total and ms.total > 0)
    and (color("green", pad(cs.total,2)) .. color("grey","/") .. color("green", pad(ms.total,2)))
    or  (color("white", pad(cs.total,2)) .. color("grey","/") .. color("white", pad(ms.total,2)))

  local rpm = roll_rate()
  local elapsed = 0
  if StatRoller.state.first_ts and StatRoller.state.last_ts then
    elapsed = math.max(0, StatRoller.state.last_ts - StatRoller.state.first_ts)
  end
  local mm = math.floor(elapsed / 60); local ss = elapsed % 60

  local bestStr = StatRoller.best_total and StatRoller.best_total > 0
    and color("green", tostring(StatRoller.best_total)) or color("grey","-")

  cecho(("\n%s %s %s  %s %s  %s %s  %s %s  %s %s  %s %s")
    :format(
      color("grey","[SR]"), color("white", spin), status,
      color("grey","Total"), totals,
      color("grey","Δ"), fmt_delta(delta, ms.total),
      color("grey","Rolls"), color("white", tostring(rolls)),
      color("grey","RPM"), color("white", string.format("%.1f", rpm)),
      color("grey","Elapsed"), color("white", string.format("%02d:%02d", mm, ss))
    ))

  -- Trend sparkline scaled to recent MIN..MAX
  local w = getopt("sparklineWidth", 16)
  if #StatRoller.recent_totals > 0 then
    local minv, maxv = recent_range(StatRoller.recent_totals, w)
    local sl = sparkline(StatRoller.recent_totals, minv, maxv, w)
    cecho(("  %s %s  %s %s")
      :format(
        color("grey","Trend"),
        sl,
        color("grey","Range"),
        color("white", ("%d–%d"):format(minv, maxv))
      ))
    cecho(("  %s %s"):format(color("grey","Best"), bestStr))
  else
    cecho(("  %s %s"):format(color("grey","Best"), bestStr))
  end

  if getopt("showDetails", true) then
    local function statPair(lbl, cur, maxv)
      local curC = (maxv > 0 and cur >= maxv) and "green" or "white"
      return color("grey", lbl) .. " " .. color(curC, pad(cur,2)) .. color("grey","/") .. color("white", pad(maxv,2))
    end
    cecho(("\n   %s  %s  %s  %s  %s")
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

  cecho("\n<cyan>[SR] Keepalive enabled\n")
end

function StatRoller._stop_keepalive()
  if StatRoller._keepalive_timer then
    killTimer(StatRoller._keepalive_timer)
    StatRoller._keepalive_timer = nil
    cecho("\n<yellow>[SR] Keepalive disabled\n")
  end
end

-- ---------- entrypoint ----------
function StatRoller.on_line(line)
  if line:match("^%[R%]oll stats      %- achieve maximum rolling potential %(random rolls%)") then
    --cecho("\nStatRoller.enabled = true")
    StatRoller.enabled = true
  end
  if line:match("^Point Sacrifice: 3 points left") then
    --cecho("\nStatRoller.enabled = false")
    StatRoller.enabled = false
  end
  if not StatRoller.enabled then return false end
  local stats = StatRoller.parse_stats_strict(line)
  if not stats then return false end

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
