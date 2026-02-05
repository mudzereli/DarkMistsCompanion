-- ===================================================================
-- Chat History Window (Geyser.UserWindow)
-- ===================================================================

ChatHistory = ChatHistory or {}

-- -------------------------------------------------------------------
-- Configuration
-- -------------------------------------------------------------------

ChatHistory.config = {
  maxMessages = 100,
  fontSize   = Darkmists.GlobalSettings.fontSize,
  fontName   = Darkmists.GlobalSettings.fontName,
}

ChatHistory.messages = {}
ChatHistory.window   = nil

-- ===================================================================
-- WINDOW CREATION
-- ===================================================================

function ChatHistory.create()
  if ChatHistory.window and ChatHistory.console then return end

  ChatHistory.window = Adjustable.Container:new({
      name = "ChatHistory",

      x = "70%",
      y = "33%",
      width = "30%",
      height = "33%",

      titleText = "Chat History",
      titleTxtColor = "white",
      padding = 10,
      adjLabelstyle = [[
        background-color: #111111;
        border: 2px solid #666666;
      ]],

      lockStyle = "border",
      locked = false,
      autoSave = true,
      autoLoad = true,
    })

  ChatHistory.console = Geyser.MiniConsole:new({
      name   = "ChatHistoryConsole",
      x      = 0,
      y      = 0,
      width  = "100%",
      height = "100%",
      color = "black"
    }, ChatHistory.window)

  -- font settings
  ChatHistory.console:setFont(ChatHistory.config.fontName)
  ChatHistory.console:setFontSize(ChatHistory.config.fontSize)
  ChatHistory.console:enableAutoWrap()
  ChatHistory.console:enableScrollBar()

  -- attach + show
  ChatHistory.window:show()
  ChatHistory.window:raiseAll()

  cecho("\n<dim_gray>[<white>ChatHistory<dim_gray>] <green>Container created")
end

-- ===================================================================
-- MESSAGE FORMATTING
-- ===================================================================

-- All message formatting lives here.
-- Adding a new channel only requires adding one entry.
local MESSAGE_FORMATTERS = {
  tell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <white>You tell <light_steel_blue>%s<white>, '<green>%s<white>'\n",
        m.timestamp, m.receiver or "?", m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <light_steel_blue>%s <white>tells you, '<green>%s<white>'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  say = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <white>You say, '<yellow>%s<white>'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <light_steel_blue>%s <white>says, '<yellow>%s<white>'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  yell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <white>You yell, '<sky_blue>%s<white>'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <light_steel_blue>%s <white>yells, '<sky_blue>%s<white>'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  gtell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <white>You tell the group '<purple>%s<white>'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <light_steel_blue>%s <white>tells the group '<purple>%s<white>'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  newbie = function(m)
    return string.format(
      "<dim_gray>[<white>%s<dim_gray>] <gray>[<dark_green>NEWBIE<gray>] <light_steel_blue>%s<gray>: %s<white>\n",
      m.timestamp, m.sender, m.message
    )
  end,

  newbiediscord = function(m)
    return string.format(
      "<dim_gray>[<white>%s<dim_gray>] <gray>[<dark_green>NEWBIE via Discord<gray>] <light_steel_blue>%s<gray>: %s<white>\n",
      m.timestamp, m.sender, m.message
    )
  end,

  ooc = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <ansi_cyan>[OOC] to %s: %s\n",
        m.timestamp, m.receiver or "?", m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<white>%s<dim_gray>] <ansi_cyan>[OOC] %s: %s\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  house = function(m)
    return string.format(
      "<dim_gray>[<white>%s<dim_gray>] <gray>[<dim_gray>%s<gray>] <light_steel_blue>%s<gray>: %s<white>\n",
      m.timestamp, m.receiver, m.sender, m.message
    )
  end,
}

local function formatMessage(m)
  local f = MESSAGE_FORMATTERS[m.msgType]
  if not f then return "" end

  if type(f) == "function" then
    return f(m)
  end

  return (m.sender == "You") and f.sent(m) or f.received(m)
end

-- ===================================================================
-- MESSAGE MANAGEMENT
-- ===================================================================

function ChatHistory.addMessage(msgType, sender, receiver, message)
  local msg = {
    timestamp = os.date("%H:%M:%S"),
    msgType   = msgType,
    sender    = sender,
    receiver  = receiver,
    message   = message,
  }

  table.insert(ChatHistory.messages, 1, msg)
  while #ChatHistory.messages > ChatHistory.config.maxMessages do
    table.remove(ChatHistory.messages)
  end

  ChatHistory.appendMessage(msg)
end

function ChatHistory.appendMessage(msg)
  if not ChatHistory.window then return end
  ChatHistory.console:cecho(formatMessage(msg))
end

function ChatHistory.refresh()
  if not ChatHistory.window then return end
  ChatHistory.console:clear()

  for i = #ChatHistory.messages, 1, -1 do
    ChatHistory.console:cecho(formatMessage(ChatHistory.messages[i]))
  end
end

-- ===================================================================
-- EVENT HANDLERS
-- ===================================================================

function ChatHistory.registerEvents()
  local function bind(event, msgType, sender, receiver)
    registerAnonymousEventHandler(event, function(_, data)
      ChatHistory.addMessage(
        msgType,
        sender or data.sender,
        receiver or data.receiver,
        data.message
      )
    end)
  end

  bind("dmapi.communication.tellreceived", "tell")
  bind("dmapi.communication.tellsent",     "tell", "You")
  bind("dmapi.communication.sayreceived",  "say")
  bind("dmapi.communication.saysent",      "say",  "You")
  bind("dmapi.communication.yellreceived", "yell")
  bind("dmapi.communication.yellsent",     "yell", "You")
  bind("dmapi.communication.gtellreceived","gtell")
  bind("dmapi.communication.gtellsent",    "gtell","You")
  bind("dmapi.communication.oocreceived",  "ooc")
  bind("dmapi.communication.oocsent",      "ooc",  "You")
  bind("dmapi.communication.newbiechannel",  "newbie")
  bind("dmapi.communication.newbiechanneldiscord",  "newbiediscord")
  bind("dmapi.communication.housechannel",  "house")

  registerAnonymousEventHandler("sysProfileSaveStarted", saveWindowLayout)

  cecho("\n<dim_gray>[<white>ChatHistory<dim_gray>] <green>Event handlers registered")
end

-- ===================================================================
-- INIT
-- ===================================================================

tempTimer(0.5, function()
  ChatHistory.create()
  ChatHistory.registerEvents()
  ChatHistory.refresh()
end)
