-- =============================================================================
-- DMSpamPrevention.lua
-- -----------------------------------------------------------------------------
-- Tracks repeated identical commands and denies them after a threshold.
--
-- Responsibilities:
--   • Count consecutive identical commands via sysDataSendRequest
--   • Deny sends that exceed the configured threshold
--   • Provide a command alias for runtime configuration
--
-- Non-goals:
--   • No gameplay decisions
--   • No command modification (only denial)
--
-- Safe to reload at any time.
-- =============================================================================

SpamPrevention = {
  threshold       = 24,   -- deny after this many consecutive repeats
  fallbackCommand = "save",  -- optional command to send instead when threshold is hit
  lastCommand     = "",
  spamCount       = 0,
  minLength       = 3,
  enabled         = true,
}

-- -----------------------------------------------------------------------------
-- Internal: called by sysDataSendRequest
-- -----------------------------------------------------------------------------
function SpamPrevention._onSend(_, data)
  if not SpamPrevention.enabled then return end
  -- rawget avoids __index metamethod interference on Mudlet's global table
  local denyCurrentSendFn = rawget(_G, "denyCurrentSend")

  if data == SpamPrevention.lastCommand then
    SpamPrevention.spamCount = SpamPrevention.spamCount + 1
  else
    SpamPrevention.spamCount = 0
  end
  SpamPrevention.lastCommand = data

  -- Skip very short commands (e.g. single-char directions) to avoid
  -- blocking movement spam from speedwalks / path aliases.
  if #data < SpamPrevention.minLength then return end

  -- Warn at 75% of threshold before actual denial kicks in
  local warningThreshold = math.max(1, math.floor(SpamPrevention.threshold * 0.75))
  if SpamPrevention.spamCount >= warningThreshold and SpamPrevention.spamCount < SpamPrevention.threshold then
    DMLogger.notify("SpamPrevention", string.format(
      "%sSpam warning: %s%d%s/%s%d%s repeats used",
      (DarkmistsTheme and DarkmistsTheme.warnTag or ""),
      (DarkmistsTheme and DarkmistsTheme.textTag or ""),
      SpamPrevention.spamCount,
      (DarkmistsTheme and DarkmistsTheme.mutedTag or ""),
      (DarkmistsTheme and DarkmistsTheme.textTag or ""),
      SpamPrevention.threshold,
      (DarkmistsTheme and DarkmistsTheme.mutedTag or "")
    ))
  end

  if SpamPrevention.spamCount >= SpamPrevention.threshold then
    if SpamPrevention.fallbackCommand then
      -- Reset count after falling back so the original command can be retried
      SpamPrevention.spamCount = 0
      send(SpamPrevention.fallbackCommand, false)
      return
    end
    if type(denyCurrentSendFn) == "function" then
      denyCurrentSendFn()
    end
    DMLogger.notify("SpamPrevention", string.format(
      "%sDenied repeated command (%dx): %s%s%s",
      (DarkmistsTheme and DarkmistsTheme.badTag or ""),
      SpamPrevention.spamCount,
      (DarkmistsTheme and DarkmistsTheme.textTag or ""),
      data,
      SpamPrevention.fallbackCommand
        and ((DarkmistsTheme and DarkmistsTheme.mutedTag or "") .. " → sent: " .. SpamPrevention.fallbackCommand)
        or ""
    ))
  end
end

-- -----------------------------------------------------------------------------
-- Init / reload-safe registration
-- -----------------------------------------------------------------------------
function SpamPrevention.init()
  if Darkmists and Darkmists.GlobalSettings then
    if Darkmists.GlobalSettings.spamEnabled ~= nil then
      SpamPrevention.enabled = Darkmists.GlobalSettings.spamEnabled
    end
    if Darkmists.GlobalSettings.spamThreshold ~= nil then
      SpamPrevention.threshold = tonumber(Darkmists.GlobalSettings.spamThreshold) or SpamPrevention.threshold
    end
    if Darkmists.GlobalSettings.spamMinLength ~= nil then
      SpamPrevention.minLength = tonumber(Darkmists.GlobalSettings.spamMinLength) or SpamPrevention.minLength
    end
    if Darkmists.GlobalSettings.spamFallbackCommand ~= nil then
      SpamPrevention.fallbackCommand = Darkmists.GlobalSettings.spamFallbackCommand
    end
  end

  DarkmistsEvents.add("spamPreventionSend", "sysDataSendRequest", SpamPrevention._onSend)

  local good = DarkmistsTheme and DarkmistsTheme.goodTag or ""
  local muted = DarkmistsTheme and DarkmistsTheme.mutedTag or ""
  local text = DarkmistsTheme and DarkmistsTheme.textTag or ""
  local fallback = SpamPrevention.fallbackCommand or "(none)"

  DMLogger.log(muted .. "SpamPrevention", string.format(
    "%sLoaded Spam Prevention%s (threshold: %s%d%s, fallback: %s%s)",
    good,
    muted,
    text,
    SpamPrevention.threshold,
    muted,
    text,
    fallback
  ))
end
