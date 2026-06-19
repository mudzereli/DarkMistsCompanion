MakeArmor = MakeArmor or {}

-- Reload-safe defaults: existing state survives module re-evaluation
MakeArmor.active = MakeArmor.active or false
MakeArmor.target = MakeArmor.target or nil
MakeArmor.minimumTotal = MakeArmor.minimumTotal or 15
MakeArmor.defaultMinimumTotal = MakeArmor.defaultMinimumTotal or 15
MakeArmor.step = MakeArmor.step or 1
MakeArmor.resting = MakeArmor.resting or false
MakeArmor.container = MakeArmor.container or "bag"
MakeArmor.sleeper = MakeArmor.sleeper or "bedroll"
MakeArmor._wakeIssued = MakeArmor._wakeIssued or false
MakeArmor._restTimer = MakeArmor._restTimer or nil

local ma_plugin = DarkmistsTheme.accentTag .. "MakeArmor"
local ma_text = DarkmistsTheme.textTag
local ma_good = DarkmistsTheme.goodTag
local ma_warn = DarkmistsTheme.warnTag
local ma_bad = DarkmistsTheme.badTag
local ma_muted = DarkmistsTheme.mutedTag

local function ma_log(message)
  DMLogger.notify(ma_plugin, message)
end

function MakeArmor._castMakeArmor()
  if not MakeArmor.target then
    return
  end
  MakeArmor.step = 1
  send("cast 'make armor' " .. MakeArmor.target)
end

function MakeArmor._castIdentify()
  if not MakeArmor.target then
    return
  end
  MakeArmor.step = 2
  send("cast identify " .. MakeArmor.target)
end

function MakeArmor._castFade()
  if not MakeArmor.target then
    return
  end
  MakeArmor.step = 3
  send("cast fade " .. MakeArmor.target)
end

function MakeArmor._retryCurrentStep()
  if not MakeArmor.active or not MakeArmor.target then
    return
  end

  if MakeArmor.step == 1 then
    MakeArmor._castMakeArmor()
    return
  end

  if MakeArmor.step == 2 then
    MakeArmor._castIdentify()
    return
  end

  -- Step 3 (fade) is the fallback when no other step matches
  MakeArmor._castFade()
end

function MakeArmor._restAndRetry()
  if MakeArmor.resting then
    return
  end

  MakeArmor.resting = true
  MakeArmor._wakeIssued = false
  ma_log(ma_warn .. "Low mana detected, resting before retry.")

  -- Retrieve bedroll from container, drop it, then sleep
  send("get " .. MakeArmor.sleeper .. " " .. MakeArmor.container)
  send("drop " .. MakeArmor.sleeper)
  send("sleep " .. MakeArmor.sleeper)

  -- Fallback: force wake if no vitals updates arrive (quiet period, lag, etc.)
  MakeArmor._restTimer = tempTimer(60, function()
    if MakeArmor.active and MakeArmor.resting then
      ma_log(ma_warn .. "Rest timeout reached, forcing wake.")
      MakeArmor._wakeIssued = true
      send("wake")
      -- Give it a moment then resume regardless
      tempTimer(2, function()
        if MakeArmor.active and MakeArmor.resting then
          send("get " .. MakeArmor.sleeper)
          send("put " .. MakeArmor.sleeper .. " " .. MakeArmor.container)
          MakeArmor.resting = false
          MakeArmor._wakeIssued = false
          MakeArmor._retryCurrentStep()
        end
      end)
    end
  end)
end

-- Clears all state and logs the stop reason. Callable externally or as part of
-- the normal success/failure flow.
function MakeArmor.stop(reason)
  local oldTarget = MakeArmor.target
  if MakeArmor._restTimer then
    killTimer(MakeArmor._restTimer)
    MakeArmor._restTimer = nil
  end
  MakeArmor.active = false
  MakeArmor.target = nil
  MakeArmor.step = 1
  MakeArmor.resting = false
  MakeArmor._wakeIssued = false

  if reason then
    ma_log(reason)
  elseif oldTarget then
    ma_log(ma_warn .. "Stopped makearmor for " .. ma_text .. oldTarget)
  else
    ma_log(ma_warn .. "Makearmor stopped.")
  end
end

function MakeArmor.start(target, minimumTotal)
  target = (target or ""):match("^%s*(.-)%s*$")
  if target == "" then
    ma_log(ma_bad .. "Usage: makearmor <item> [5-20]")
    return
  end

  local minTotal = tonumber(minimumTotal) or MakeArmor.defaultMinimumTotal
  minTotal = math.floor(minTotal)
  if minTotal < 5 or minTotal > 20 then
    ma_log(ma_bad .. "Minimum total must be between 5 and 20.")
    return
  end

  MakeArmor.active = true
  MakeArmor.target = target
  MakeArmor.minimumTotal = minTotal
  MakeArmor.step = 1
  MakeArmor.resting = false

  ma_log(
    ma_good .. "Started makearmor for " .. ma_text .. target ..
    ma_muted .. " (target total: " .. ma_text .. tostring(minTotal) .. ma_muted .. ")"
  )

  MakeArmor._castMakeArmor()
end

function MakeArmor.status()
  if not MakeArmor.active then
    ma_log(ma_warn .. "Idle")
    return
  end

  local stepName = "fade"
  if MakeArmor.step == 1 then
    stepName = "make armor"
  elseif MakeArmor.step == 2 then
    stepName = "identify"
  end

  ma_log(
    ma_good .. "Active" .. ma_muted .. " target=" .. ma_text .. tostring(MakeArmor.target) ..
    ma_muted .. " threshold=" .. ma_text .. tostring(MakeArmor.minimumTotal) ..
    ma_muted .. " step=" .. ma_text .. stepName
  )
end

-- Extracts optional trailing threshold from "item 15" syntax.
-- Returns (item_name, nil) when no number is present.
function MakeArmor._parseStartArgs(raw)
  local trimmed = (raw or ""):match("^%s*(.-)%s*$")
  local target, threshold = trimmed:match("^(.-)%s+(%d+)$")

  if target and threshold then
    target = target:match("^%s*(.-)%s*$")
    return target, tonumber(threshold)
  end

  return trimmed, nil
end

function MakeArmor._showSleeper()
  ma_log(ma_good .. "Sleeper: " .. ma_text .. MakeArmor.sleeper)
end

function MakeArmor._setSleeper(item)
  item = (item or ""):match("^%s*(.-)%s*$")
  if item == "" then
    ma_log(ma_bad .. "Usage: makearmor sleeper <item>")
    return
  end

  MakeArmor.sleeper = item
  Darkmists.GlobalSettings.makearmorSleeper = item
  Darkmists.SaveSettings()
  ma_log(ma_good .. "Sleeper set to " .. ma_text .. item)
end

function MakeArmor._showContainer()
  ma_log(ma_good .. "Container: " .. ma_text .. MakeArmor.container)
end

function MakeArmor._setContainer(item)
  item = (item or ""):match("^%s*(.-)%s*$")
  if item == "" then
    ma_log(ma_bad .. "Usage: makearmor container <item>")
    return
  end

  MakeArmor.container = item
  Darkmists.GlobalSettings.makearmorContainer = item
  Darkmists.SaveSettings()
  ma_log(ma_good .. "Container set to " .. ma_text .. item)
end

function MakeArmor.init()
  -- Load persisted settings with fallbacks to current defaults
  MakeArmor.sleeper = Darkmists.GlobalSettings.makearmorSleeper or MakeArmor.sleeper
  MakeArmor.container = Darkmists.GlobalSettings.makearmorContainer or MakeArmor.container
  MakeArmor.defaultMinimumTotal = Darkmists.GlobalSettings.makearmorDefaultMinimumTotal or MakeArmor.defaultMinimumTotal

  DarkmistsEvents.add("MakeArmor.NewLine", "dmapi.core.line", function(_, data)
    if not MakeArmor.active then
      return
    end

    local line = data.line or ""

    -- Step 1 success: item became armor → identify to check quality
    if line:match("flares and becomes armor%.") then
      MakeArmor._castIdentify()
      return
    end

    -- Step 2 response: parse AC values, compare against threshold
    local pierce, bash, slash, magic = line:match("^Armor class is (%-?%d+) pierce, (%-?%d+) bash, (%-?%d+) slash, and (%-?%d+) vs%. magic%.$")
    if pierce and bash and slash and magic then
      local total = tonumber(pierce) + tonumber(bash) + tonumber(slash) + tonumber(magic)

      if total >= MakeArmor.minimumTotal then
        MakeArmor.stop(ma_good .. "Armor accepted at total " .. ma_text .. tostring(total) .. ma_good .. ".")
      else
        ma_log(ma_warn .. "Armor total " .. ma_text .. tostring(total) .. ma_warn .. " below target, continuing.")
        MakeArmor._castFade()
      end
      return
    end

    -- Step 3 success: fade cleared the enchantment → restart the cycle
    if line:match("shudders violently and then fades%.") then
      MakeArmor._castMakeArmor()
      return
    end

    if line:match("^You do not have enough mana%.$") then
      MakeArmor._restAndRetry()
      return
    end

    -- Item can't be made into armor (wrong slot type, etc.)
    if line:match("^This just cannot be done%.$") then
      MakeArmor.stop(ma_bad .. "Cannot make armor on " .. ma_text .. tostring(MakeArmor.target) .. ma_bad .. ".")
      return
    end

    -- Transient failures: brief delay before retry to let the server settle
    if line:match("^You lost your concentration%.$") then
      ma_log(ma_warn .. "Lost concentration, retrying current step.")
      tempTimer(0.2, function()
        if MakeArmor.active and not MakeArmor.resting then
          MakeArmor._retryCurrentStep()
        end
      end)
      return
    end

    if line:match("^You fail the conversion%.$") then
      ma_log(ma_warn .. "Conversion failed, retrying current step.")
      tempTimer(0.2, function()
        if MakeArmor.active and not MakeArmor.resting then
          MakeArmor._retryCurrentStep()
        end
      end)
      return
    end

    if line:match("^You fail and the object is unchanged%.$") then
      ma_log(ma_warn .. "Object unchanged, retrying current step.")
      tempTimer(0.2, function()
        if MakeArmor.active and not MakeArmor.resting then
          MakeArmor._retryCurrentStep()
        end
      end)
      return
    end
  end)

  -- Monitors mana/move recovery while resting; issues wake once thresholds met
  DarkmistsEvents.add("MakeArmor.Vitals", "dmapi.player.vitals.updated", function()
    if not MakeArmor.active or not MakeArmor.resting then
      return
    end

    local vitals = dmapi.player.vitals or {}
    local manaPct = vitals.mnPct or 0
    local movePct = vitals.mvPct or 0
    local recovered = manaPct >= 90 and movePct >= 90

    if dmapi.player.status.sleeping then
      -- Send wake exactly once to avoid spamming while vitals tick
      if recovered and not MakeArmor._wakeIssued then
        MakeArmor._wakeIssued = true
        send("wake")
      end
      return
    end

    if recovered then
      -- Stow the bedroll and resume the armor cycle
    if MakeArmor._restTimer then
      killTimer(MakeArmor._restTimer)
      MakeArmor._restTimer = nil
    end
      send("get " .. MakeArmor.sleeper)
      send("put " .. MakeArmor.sleeper .. " " .. MakeArmor.container)
      MakeArmor.resting = false
      MakeArmor._wakeIssued = false
      MakeArmor._retryCurrentStep()
    end
  end)

  DMLogger.log(ma_plugin, ma_good .. "Ready. Type '" .. ma_text .. "makearmor" .. ma_good .. "' for commands.")
end
