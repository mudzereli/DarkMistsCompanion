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

  ChatHistory.window = Darkmists.createTabPanel("ChatHistory","Chat History","Chat")

  ChatHistory.console = Geyser.MiniConsole:new({
      name   = "ChatHistoryConsole",
      x      = "1%",
      y      = "1%",
      width  = "98%",
      height = "98%",
      color = Darkmists.getDefaultBackgroundColor()
    }, ChatHistory.window)

  -- font settings
  ChatHistory.console:setFont(ChatHistory.config.fontName)
  ChatHistory.console:setFontSize(ChatHistory.config.fontSize)
  ChatHistory.console:enableAutoWrap()
  ChatHistory.console:enableScrollBar()

  -- attach + show
  ChatHistory.window:show()
  ChatHistory.window:raiseAll()

  Darkmists.Log("ChatHistory","Container Created")
end

-- ===================================================================
-- MESSAGE FORMATTING
-- ===================================================================

local maincolor = Darkmists.getDefaultTextColor()
local yellow = "yellow"
local blue = "steel_blue"
local green = "spring_green"
if Darkmists.GlobalSettings.lightMode then
  yellow = "ansi_yellow"
  blue = "midnight_blue"
  green = "forest_green"
end
-- All message formatting lives here.
-- Adding a new channel only requires adding one entry.
local MESSAGE_FORMATTERS = {
  mptell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..maincolor..">You mentally project to <"..blue..">%s<"..maincolor..">, '<"..green..">%s<"..maincolor..">'\n",
        m.timestamp, m.receiver or "?", m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..blue..">%s <"..maincolor..">mentally projects to you, '<"..green..">%s<"..maincolor..">'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  tell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..maincolor..">You tell <"..blue..">%s<"..maincolor..">, '<"..green..">%s<"..maincolor..">'\n",
        m.timestamp, m.receiver or "?", m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..blue..">%s <"..maincolor..">tells you, '<"..green..">%s<"..maincolor..">'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  say = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..maincolor..">You say, '<"..yellow..">%s<"..maincolor..">'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..blue..">%s <"..maincolor..">says, '<"..yellow..">%s<"..maincolor..">'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  mpsay = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..maincolor..">You mentally project, '<"..yellow..">%s<"..maincolor..">'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..blue..">%s <"..maincolor..">mentally projects, '<"..yellow..">%s<"..maincolor..">'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  yell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..maincolor..">You yell, '<sky_blue>%s<"..maincolor..">'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..blue..">%s <"..maincolor..">yells, '<sky_blue>%s<"..maincolor..">'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  gtell = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..maincolor..">You tell the group '<purple>%s<"..maincolor..">'\n",
        m.timestamp, m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <"..blue..">%s <"..maincolor..">tells the group '<purple>%s<"..maincolor..">'\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  newbie = function(m)
    return string.format(
      "<dim_gray>[<"..maincolor..">%s<dim_gray>] <gray>[<dark_green>NEWBIE<gray>] <"..blue..">%s<gray>: %s<"..maincolor..">\n",
      m.timestamp, m.sender, m.message
    )
  end,

  newbiediscord = function(m)
    return string.format(
      "<dim_gray>[<"..maincolor..">%s<dim_gray>] <gray>[<dark_green>NEWBIE via Discord<gray>] <"..blue..">%s<gray>: %s<"..maincolor..">\n",
      m.timestamp, m.sender, m.message
    )
  end,

  ooc = {
    sent = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <ansi_cyan>[OOC] to %s: %s\n",
        m.timestamp, m.receiver or "?", m.message
      )
    end,
    received = function(m)
      return string.format(
        "<dim_gray>[<"..maincolor..">%s<dim_gray>] <ansi_cyan>[OOC] %s: %s\n",
        m.timestamp, m.sender, m.message
      )
    end,
  },

  house = function(m)
    return string.format(
      "<dim_gray>[<"..maincolor..">%s<dim_gray>] <gray>[<dim_gray>%s<gray>] <"..blue..">%s<"..maincolor..">: %s<"..maincolor..">\n",
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

  local function bind(key, event, msgType, sender, receiver)
    DarkmistsEvents.add(key, event, function(_, data)
      ChatHistory.addMessage(
        msgType,
        sender or data.sender,
        receiver or data.receiver,
        data.message
      )
    end)
  end

  bind("ChatHistoryTellReceived", "dmapi.communication.tellreceived", "tell")
  bind("ChatHistoryTellSent",     "dmapi.communication.tellsent",     "tell", "You")
  bind("ChatHistorySayReceived",  "dmapi.communication.sayreceived",  "say")
  bind("ChatHistorySaySent",      "dmapi.communication.saysent",      "say",  "You")
  bind("ChatHistoryMPSayReceived",  "dmapi.communication.mpsayreceived",  "mpsay")
  bind("ChatHistoryMPSaySent",      "dmapi.communication.mpsaysent",      "mpsay",  "You")
  bind("ChatHistoryMPTellReceived", "dmapi.communication.mptellreceived", "mptell")
  bind("ChatHistoryMPTellSent",     "dmapi.communication.mptellsent",     "mptell",  "You")
  bind("ChatHistoryYellReceived", "dmapi.communication.yellreceived", "yell")
  bind("ChatHistoryYellSent",     "dmapi.communication.yellsent",     "yell", "You")
  bind("ChatHistoryGTellReceived","dmapi.communication.gtellreceived","gtell")
  bind("ChatHistoryGTellSent",    "dmapi.communication.gtellsent",    "gtell","You")
  bind("ChatHistoryOOCReceived",  "dmapi.communication.oocreceived",  "ooc")
  bind("ChatHistoryOOCSent",      "dmapi.communication.oocsent",      "ooc",  "You")
  bind("ChatHistoryNewbieChannel",  "dmapi.communication.newbiechannel",  "newbie")
  bind("ChatHistoryNewbieDiscord",  "dmapi.communication.newbiechanneldiscord",  "newbiediscord")
  bind("ChatHistoryHouseChannel",  "dmapi.communication.housechannel",  "house")

  DarkmistsEvents.add("ChatHistoryProfileSave", "sysProfileSaveStarted", saveWindowLayout)

  Darkmists.Log("ChatHistory","Event Handlers Registered")
end

-- ===================================================================
-- INIT
-- ===================================================================

ChatHistory.create()
ChatHistory.registerEvents()
ChatHistory.refresh()
