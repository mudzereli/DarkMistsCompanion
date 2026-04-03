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

local textTag   = DarkmistsTheme.textTag
local mutedTag  = DarkmistsTheme.mutedTag
local yellowTag = DarkmistsTheme.yellowTag
local blueTag   = DarkmistsTheme.blueTag
local greenTag  = DarkmistsTheme.greenTag
local skyTag    = DarkmistsTheme.skyTag
local purpleTag = DarkmistsTheme.purpleTag
local cyanTag   = DarkmistsTheme.cyanTag
local silverTag = DarkmistsTheme.silverTag
-- All message formatting lives here.
-- Adding a new channel only requires adding one entry.
local MESSAGE_FORMATTERS = {
  emotedsay = {
    sent = function(m)
      local em = m.emote and (m.emote .. " ") or ""
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You " .. em .. "say, '" .. yellowTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      local em = m.emote and (m.emote .. " ") or ""
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. em .. "says, '" .. yellowTag .. m.message .. textTag .. "'\n"
    end,
  },
  yellpanic = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You yell in panic, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "yells in panic, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
  },
  mentalblastpanic = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You mentally blast in panic, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "mentally blasts in panic, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
  },
  mentalblast = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You mentally blast, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "mentally blasts, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
  },
  mptell = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You mentally project to " .. blueTag .. (m.receiver or "?") .. textTag .. ", '" .. greenTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "mentally projects to you, '" .. greenTag .. m.message .. textTag .. "'\n"
    end,
  },

  tell = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You tell " .. blueTag .. (m.receiver or "?") .. textTag .. ", '" .. greenTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "tells you, '" .. greenTag .. m.message .. textTag .. "'\n"
    end,
  },

  say = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You say, '" .. yellowTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "says, '" .. yellowTag .. m.message .. textTag .. "'\n"
    end,
  },

  mpsay = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You mentally project, '" .. yellowTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "mentally projects, '" .. yellowTag .. m.message .. textTag .. "'\n"
    end,
  },

  yell = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You yell, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "yells, '" .. skyTag .. m.message .. textTag .. "'\n"
    end,
  },

  gtell = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You tell the group '" .. purpleTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "tells the group '" .. purpleTag .. m.message .. textTag .. "'\n"
    end,
  },

  mpgtell = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. textTag .. "You mentally project to the group '" .. purpleTag .. m.message .. textTag .. "'\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. blueTag .. m.sender .. " " .. textTag .. "mentally projects to the group '" .. purpleTag .. m.message .. textTag .. "'\n"
    end,
  },

  newbie = function(m)
    return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. mutedTag .. "[" .. greenTag .. "NEWBIE" .. mutedTag .. "] " .. blueTag .. m.sender .. mutedTag .. ": " .. textTag .. m.message .. "\n"
  end,

  newbiediscord = function(m)
    return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. mutedTag .. "[" .. greenTag .. "NEWBIE via Discord" .. mutedTag .. "] " .. blueTag .. m.sender .. mutedTag .. ": " .. textTag .. m.message .. "\n"
  end,

  ooc = {
    sent = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. cyanTag .. "[OOC] " .. mutedTag .. "to " .. blueTag .. (m.receiver or "?") .. mutedTag .. ": " .. textTag .. m.message .. "\n"
    end,
    received = function(m)
      return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. cyanTag .. "[OOC] " .. blueTag .. m.sender .. mutedTag .. ": " .. textTag .. m.message .. "\n"
    end,
  },

  house = function(m)
    return mutedTag .. "[" .. textTag .. m.timestamp .. mutedTag .. "] " .. mutedTag .. "[" .. silverTag .. (m.receiver or "") .. mutedTag .. "] " .. blueTag .. m.sender .. mutedTag .. ": " .. textTag .. m.message .. "\n"
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

function ChatHistory.addMessage(msgType, sender, receiver, message, extra)
  local msg = {
    timestamp = os.date("%H:%M:%S"),
    msgType   = msgType,
    sender    = sender,
    receiver  = receiver,
    message   = message,
    emote     = extra and extra.emote
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
        data.message,
        data
      )
    end)
  end

  bind("ChatHistoryTellReceived", "dmapi.communication.tellreceived", "tell")
  bind("ChatHistoryTellSent",     "dmapi.communication.tellsent",     "tell", "You")
  bind("ChatHistorySayReceived",  "dmapi.communication.sayreceived",  "say")
  bind("ChatHistorySaySent",      "dmapi.communication.saysent",      "say",  "You")
  bind("ChatHistoryMPSayReceived",  "dmapi.communication.mpsayreceived",  "mpsay")
  bind("ChatHistoryMPSaySent",      "dmapi.communication.mpsaysent",      "mpsay",  "You")
  bind("ChatHistoryMPTellReceived",  "dmapi.communication.mptellreceived",  "mptell")
  bind("ChatHistoryMPTellSent",      "dmapi.communication.mptellsent",      "mptell",  "You")
  bind("ChatHistoryMPGTellReceived", "dmapi.communication.mpgtellreceived", "mpgtell")
  bind("ChatHistoryMPGTellSent",     "dmapi.communication.mpgtellsent",     "mpgtell", "You")
  bind("ChatHistoryYellReceived",    "dmapi.communication.yellreceived",    "yell")
  bind("ChatHistoryYellSent",        "dmapi.communication.yellsent",        "yell",    "You")
  bind("ChatHistoryGTellReceived",   "dmapi.communication.gtellreceived",   "gtell")
  bind("ChatHistoryGTellSent",       "dmapi.communication.gtellsent",       "gtell",   "You")
  bind("ChatHistoryOOCReceived",     "dmapi.communication.oocreceived",     "ooc")
  bind("ChatHistoryOOCSent",      "dmapi.communication.oocsent",      "ooc",  "You")
  bind("ChatHistoryNewbieChannel",  "dmapi.communication.newbiechannel",  "newbie")
  bind("ChatHistoryNewbieDiscord",  "dmapi.communication.newbiechanneldiscord",  "newbiediscord")
  bind("ChatHistoryHouseChannel",  "dmapi.communication.housechannel",  "house")

  bind("ChatHistoryEmotedSayReceived", "dmapi.communication.emotedsayreceived", "emotedsay")
  bind("ChatHistoryEmotedSaySent",     "dmapi.communication.emotedsaysent",     "emotedsay", "You")

  bind("ChatHistoryYellPanicReceived", "dmapi.communication.yellpanicreceived", "yellpanic")
  bind("ChatHistoryYellPanicSent",     "dmapi.communication.yellpanicsent",     "yellpanic", "You")

  bind("ChatHistoryMentalBlastReceived", "dmapi.communication.mentalblastreceived", "mentalblast")
  bind("ChatHistoryMentalBlastSent",     "dmapi.communication.mentalblastsent",     "mentalblast", "You")

  bind("ChatHistoryMentalBlastPanicReceived", "dmapi.communication.mentalblastpanicreceived", "mentalblastpanic")
  bind("ChatHistoryMentalBlastPanicSent",     "dmapi.communication.mentalblastpanicsent",     "mentalblastpanic", "You")
  
  DarkmistsEvents.add("ChatHistoryProfileSave", "sysProfileSaveStarted", saveWindowLayout)

  Darkmists.Log("ChatHistory","Event Handlers Registered")
end

-- ===================================================================
-- INIT
-- ===================================================================

ChatHistory.create()
ChatHistory.registerEvents()
ChatHistory.refresh()
