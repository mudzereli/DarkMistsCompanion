-- =============================================================================
-- DMLogger - small miniconsole for developer/runtime logs
-- =============================================================================

DMLogger = DMLogger or {}

-- Standalone defaults (avoid referencing Darkmists globals here)
DMLogger.config = {
  fontSize = 11,
  fontName = "Lucida Console",
  height = 120,
  visible = false
}

function DMLogger.create()
  if DMLogger.console then return end

  -- Create an adjustable container and a mini-console inside it
  DMLogger.container = Adjustable.Container:new({
    name = "DM Log Console",
    x = "20%", y = "20%",
    width = "60%", height = "60%",
    color = "#000000"
  })

  DMLogger.console = Geyser.MiniConsole:new({
    name = "DMLoggerConsole",
    x = "1%", y = "1%",
    width = "98%", height = "98%",
    color = "#000000"
  }, DMLogger.container)

  DMLogger.console:setFont(DMLogger.config.fontName)
  DMLogger.console:setFontSize(DMLogger.config.fontSize)
  DMLogger.console:enableAutoWrap()
  DMLogger.console:enableScrollBar()

  DMLogger.container:show()
  DMLogger.container:raiseAll()
end

function DMLogger.write(plugin, msg)
  if not DMLogger.console then DMLogger.create() end
  local prefix = "\n"..DarkmistsTheme.mutedTag .. "[<r>" .. tostring(plugin) .. (DarkmistsTheme.mutedTag) .. "] " .. (DarkmistsTheme.silverTag)
  DMLogger.console:cecho(prefix .. tostring(msg))
end

function DMLogger.toggle()
  if not DMLogger.container then
    DMLogger.create()
    return
  end
  if DMLogger.visible then
    DMLogger.container:hide()
    DMLogger.visible = false
  else
    DMLogger.container:show()
    DMLogger.container:raiseAll()
    DMLogger.visible = true
  end
end

function DMLogger.clear()
  if DMLogger.console then DMLogger.console:clear() end
end

DMLogger.create()
DMLogger.container:hide()

return DMLogger
