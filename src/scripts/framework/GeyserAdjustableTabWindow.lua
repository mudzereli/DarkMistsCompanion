-- Adjustable TabWindow
-- TabWindow code by Mudlet Wiki
-- other functions
-- by Edru 16th May 2020 

Adjustable.TabWindow = Adjustable.TabWindow or Geyser.Container:new({name = "AdjustableTabWindowClass"})
Adjustable.TabWindow.blockNextFloat = false

local tab_pos = nil

-- Shorthand: TN(tab) → tab.."tab", used everywhere for the tab-header container key
local function TN(tab) return tab.."tab" end

-- Queue a layout save through DMTabs (no-op if DMTabs isn't available)
function Adjustable.TabWindow:saveLayout()
  if DMTabs and DMTabs.queueLayoutSave then DMTabs:queueLayoutSave() end
end

-- Reset the aggregate tab layout without deleting its save file.
function Adjustable.TabWindow:resetSaveFile()
        local directory = getMudletHomeDir().."/AdjustableTabWindow/"
        if not io.exists(directory) then lfs.mkdir(directory) end
        table.save(directory.."TabWindowTabs.lua", {})
end

function Adjustable.TabWindow:createBaseContainers()
    self.header = self.header or Geyser.HBox:new({
        name = self.name.."header",
        x = 0, y = 0,
        width = "100%",
        height = self.tabBarHeight,
    },self)
    
    self.overlay = self.overlay or Geyser.Label:new({
        name = self.name.."overlay",
        x = 0, y = 0,
        width = "100%",
        height = self.tabBarHeight,
    },self)
    
    self.overlay:setStyleSheet(self.overlayStyle)
    self.overlay:setMoveCallback(function(event) self:onOverlayMove(event) end)
    self.overlay:setOnLeave(function(event) self:onOverlayLeave(event) end)
    self.overlay:setClickCallback(function(event) self:onOverlayClick(event) end)
    self.overlay:hide()
    
    self.footer = self.footer or Geyser.Label:new({
        name = self.name.."footer",
        x = 0, y = self.tabBarHeight,
        width = "100%",
        height = "-"..self.tabBarHeight,
    },self)
    
    self.footer:setStyleSheet(self.footerStyle)
end

-- function to create new tabs in tabs table or to rewrite/readjust them
function Adjustable.TabWindow:createTabs()
    for _, v in ipairs(self.tabs) do
        local tn = TN(v)
        self[v] = self[v] or Geyser.Label:new({
            name = v,
            x = 0, y = 0,
            width = "100%",
            height = "100%",
        }, self.footer)

        self[v]:setStyleSheet(self.containerStyle)
        self[v].tabText = self[v].tabText or ("<center>" .. v)

        self[tn] = self[tn] or Adjustable.Container:new({
            name = tn,
            tabname = v,
            noLimit = true,
            titleText = self[v].tabText,
            padding = 0,
            locked = true,
            autoSave = false,
            autoLoad = false,
            raiseOnClick = false,
            adjLabelstyle = self.inactiveTabStyle,
            titleTxtColor = self.tabTxtColor
        }, self.header)

        self[tn]:newLockStyle("tab", function(self)
            self.Inside:resize("-" .. self.padding, "-" .. self.padding)
            self.Inside:move(self.padding, self.padding * 2)
        end)

        self[tn].lockStyle = "tab"

        self[tn].unlockContainer = function()
            Adjustable.Container.unlockContainer(self[tn])
            self[tn].adjLabel:echo(self[v].tabText)
        end

        Adjustable.TabWindow.allTabs[v] = self
      
        self[tn].reposition = self.reposition
        table.remove(Adjustable.Container.all_windows, table.index_of(Adjustable.Container.all_windows, tn))
        Adjustable.Container.all[tn] = nil
        self[tn].adjLabelstyle = self.inactiveTabStyle
        self[tn].titleTxtColor = self.tabTxtColor
        self[tn].adjLabel:setStyleSheet(self.inactiveTabStyle)

        self[tn].adjLabel:echo(self[v].tabText)

        self[tn].adjLabel:setClickCallback(function(event) self:onClick(v, event) end)
        self[tn].adjLabel:setReleaseCallback(function(event) self:onRelease(v, event) end)
        self[tn].adjLabel:setMoveCallback(function(event) self:onMove(v, event) end)
        self[tn].adjLabel:setDoubleClickCallback(function(event) self:onDoubleClick(v, event) end)
        self[tn].minimizeLabel:setClickCallback(function() self:onMinimizeClick(v) end)
        self[tn].minimizeLabel:echo("<center>🗗</center>")
        self[tn].minLabel:setClickCallback(function() self:onMinimizeClick(v) end)

        self[v .. "center"] = self[v .. "center"] or Geyser.Label:new({
            name = v .. "center",
            x = 0, y = 0,
            width = "100%",
            height = "100%",
        }, self[v])

        self[v .. "center"]:setStyleSheet(self.centerStyle)
        self[v]:hide()
    end
end

-- finds the right position to drop the tab into
function Adjustable.TabWindow:findPosition(tab)
    local myWindow = Adjustable.TabWindow.currentWindow or self
    local x, w = myWindow.get_x(), myWindow.get_width()
    local total = w/#myWindow.tabs
    local tab_x = tab.get_x() - x
    local position = (tab_x/total) + 1
    position = math.floor(position + 0.5)
    if position < 1 then
        position = 1
    end
    if position > #myWindow.tabs then
        position = #myWindow.tabs + 1
    end
    return position
end

-- checks if 2 elements collide
local function checkCollision(x1,y1,w1,h1, x2,y2,w2,h2)
    if  x1 < x2+w2 and
    x2 < x1+w1 and
    y1 < y2+h2 and
    y2 < y1+h1 then
        return true
    end
end

-- checks if your tab collides with one of the tabwindows
function Adjustable.TabWindow:checkMultiCollision(tab)
    local x1, y1, w1, h1 = tab:get_x(), tab:get_y(), tab:get_width(), tab:get_height()
    for k,v in pairs(Adjustable.TabWindow.all) do
        local x2, y2, w2, h2 = v:get_x(), v:get_y(), v:get_width(), v:get_height()
        
        if checkCollision(x1,y1,w1,h1, x2,y2,w2,h2) and v.windowname == self.windowname then
            return true, v
        end
    end  
end

-- onMove function
-- contains all the functionality to move the tab (collision check, make space ...)
function Adjustable.TabWindow:onMove(tab, event)
    local tn = TN(tab)
    self[tn]:onMove(self[tn].adjLabel, event)
    self[tn].adjLabel:echo(self[tab].tabText)
    if self[tab].floating then
        return
    end
    if Adjustable.TabWindow.clicked then  
        local result, value = self:checkMultiCollision(self[tn])
        if Adjustable.TabWindow.currentWindow and Adjustable.TabWindow.currentWindow ~= value then
            self:makeSpace(Adjustable.TabWindow.currentWindow, nil, true)
        end
        if result then
            Adjustable.TabWindow.currentWindow = value
            tab_pos = value:findPosition(self[tn])
            self:makeSpace(value, tab_pos)
        else
            if Adjustable.TabWindow.currentWindow then
                Adjustable.TabWindow.currentWindow = nil
            end
        end
    end
    self:saveLayout()
end

-- mouse movement on the overlay label
function Adjustable.TabWindow:onOverlayMove(event)  
    Adjustable.TabWindow.currentWindow = self
    local tab = Adjustable.TabWindow.clickedTab.name
    if Adjustable.TabWindow.clickedTab ~= self.header.windowList[tab] then
        -- need to feed values to findPosition
        local fakeTab = {}
        fakeTab.get_x = function() return event.x + self.header.get_x() end    
        tab_pos = self:findPosition(fakeTab)
        self:makeSpace(self, tab_pos)
    end
end

-- reset tabspace after mouse leaves overlay label and resets the currentWindow
function Adjustable.TabWindow:onOverlayLeave(event)
    Adjustable.TabWindow.currentWindow = nil
    if not(Adjustable.TabWindow.doubleClick) then
        return
    end
    local tab = Adjustable.TabWindow.clickedTab.name
    if Adjustable.TabWindow.clickedTab ~= self.header.windowList[tab] then
        self:makeSpace(nil, nil, true)
    end
end

-- reset the Overlay label to be hidden
local function resetOverlay(v)
    if Adjustable.TabWindow.overlayTimer then
        killTimer(Adjustable.TabWindow.overlayTimer)
        Adjustable.TabWindow.overlayTimer = nil
    end
    for k,v in pairs(Adjustable.TabWindow.all) do 
        v.overlay:setStyleSheet("background-color: rgba(0,0,0,0%);") 
        v.overlay:hide()
    end  
    if Adjustable.TabWindow.currentWindow then
        Adjustable.TabWindow.currentWindow:makeSpace(nil, nil, true)
    end
    Adjustable.TabWindow.doubleClick = nil
    tab_pos = nil
end

-- handles on overlay click event
function Adjustable.TabWindow:onOverlayClick(event) 
    Adjustable.TabWindow.doubleClick = nil
    local tab = Adjustable.TabWindow.clickedTab
    local container = Adjustable.TabWindow.clickedTab.container.container or self
    tab.adjLabel:setStyleSheet(container.activeTabStyle)
    if container[tab.tabname].floating then
        container:restoreTab(tab.tabname, self)
        self:addTab(tab.tabname, tab_pos)
    else
        container:onRelease(tab.tabname, event)
    end
    resetOverlay(self)
    self:saveLayout()
end

-- if clicked on the minimize label the tab will be 
-- restored to be in a tabwindow again
function Adjustable.TabWindow:onMinimizeClick(tab)  
    local result, value = self:checkMultiCollision(self[TN(tab)])
    self:restoreTab(tab, value)
    self:saveLayout()
end

-- activates the tab tab (doesn't deactivate the previous tab)
-- @see Adjustable.TabWindow:deactivateTab()
function Adjustable.TabWindow:activateTab(tab)
    self.current = tab
    if self.current then
        local tn = TN(tab)
        self[tn].adjLabelstyle = self.activeTabStyle
        self[tn].adjLabel:setStyleSheet(self.activeTabStyle)
        self[self.current]:show()
    end
end

-- deactivates and hides the current active tab
function Adjustable.TabWindow:deactivateTab()
    if self.current and self[self.current] then
        local tn = TN(self.current)
        self[tn].adjLabelstyle = self.inactiveTabStyle
        self[tn].adjLabel:setStyleSheet(self.inactiveTabStyle)
        self[self.current]:hide()
    end
end

-- handles click event on tab
function Adjustable.TabWindow:onClick(tab, event)
    Adjustable.TabWindow.currentWindow = self
    local tn = TN(tab)
    if event.button == "LeftButton" and not self[tab].floating then
        self[tn]:resize(self[tn].get_width(), self[tn].get_height())
        self[tn].container = Geyser
        self[tn].minimized = true
        self[tn]:unlockContainer()
        self[tn]:onClick(self[tn].adjLabel, event)
        self[tn].adjLabel:raise(false)
        self[tn].exitLabel:hide()
        self[tn].minimizeLabel:hide()
        Adjustable.TabWindow.clicked = true
        Adjustable.TabWindow.clickedTab = self[tn]
        self[tn].adjLabel:echo(self[tab].tabText)
    end
    
    if self[tab].floating then
        self[tn]:onClick(self[tn].adjLabel, event)
    end
    if not self[tab].floating then
        self:deactivateTab()
        self:activateTab(tab)
    end
end

-- handles double click event on getAreaTable
-- activates the tab overlay
function Adjustable.TabWindow:onDoubleClick(tab, event)
    if self[tab] and self[tab].floating then
        -- Block any float logic triggered by mouse release
        Adjustable.TabWindow.blockNextFloat = true
        tempTimer(0.25, function()
            Adjustable.TabWindow.blockNextFloat = false
        end)

        -- Force immediate dock
        self:restoreTab(tab, self)
        self:activateTab(tab)
        self:raiseAll()
    end
end

-- transforms the tab to a window
function Adjustable.TabWindow:transformTabContainer(tab)
    local tn = TN(tab)
    local myWindow = Adjustable.TabWindow.allTabs[tab] or self
    local container = self[tn]
    if container.windowname == "main" then
        Geyser:add(container)
    else
        Geyser.windowList[container.windowname.."Container"].windowList[container.windowname]:add(container)
    end
    container:unlockContainer()
    container:resize(self.get_width(), self.get_height())
    container:add(self[tab])
    myWindow:removeTab(tab)
    myWindow:createTabs()
    container:setPadding(self.tabPadding)
    container:show()
    container:raiseAll()
    myWindow[tab].floating = true
    local center = self[tab .. "center"]
    if center and center.windowList then
        for _, obj in pairs(center.windowList) do
            if obj.type == "adjustablecontainer" then
            obj:lockContainer(nil, "light")
            end
        end
    end
    container.raiseOnClick = true
    container.adjLabel:echo(self[tab].tabText)
    container.minimized = false
    container:setPercent(true, true)
    myWindow:activateTab(tab)
    if #myWindow.tabs > 0 then
        myWindow:activateTab(myWindow.tabs[1])
    else 
        myWindow.current = nil
    end
    self:saveLayout()
end

--restores the window to be a tab again
function Adjustable.TabWindow:restoreTab(tab, myWindow)
    myWindow = myWindow or self
    local tn = TN(tab)
    local center = self[tab .. "center"]

    if center and center.windowList then
        for _, obj in pairs(center.windowList) do
            if obj.type == "adjustablecontainer" then
                obj:lockContainer(nil, "full")
            end
        end
    end
    local container = self[tn]
    container:attachToBorder("none")
    container.container:remove(container)
    container:remove(self[tab])
    container:setPadding(0)
    container:lockContainer()
    container.adjLabel:echo(self[tab].tabText)
    self:changeTabContainer(tab, myWindow)
    self[tab].floating = false
    container.raiseOnClick = false
    scrollTo(-10)
    tempTimer(0,function() scrollTo() end)
    self:saveLayout()
end

-- function to make a gap where the tab can be dropped in
function Adjustable.TabWindow:makeSpace(myWindow, position, resetSpace)
    myWindow = myWindow or self
    position = position or #myWindow.header.windows
    if position < 1 then position = 1 end
    local current_Tab = Adjustable.TabWindow.clickedTab or {}
    local total_count = #myWindow.header.windows + 1
    -- close the space if resetSpace is true
    if resetSpace then
        position = -1
        total_count = total_count -1
    end
    
    if myWindow == self and current_Tab.name and not(Adjustable.TabWindow.doubleClick) then
        total_count = total_count -1
    end
    local new_width = myWindow.get_width() / total_count
    local new_x = 0
    local counter = 1
    for k,v in ipairs(myWindow.header.windows) do
        if v ~= current_Tab.name then
            if counter == position then
                new_x = new_x + new_width
            end
            myWindow.header.windowList[v]:resize(new_width)
            myWindow.header.windowList[v]:move(new_x)   
            new_x = new_x + new_width
            counter = counter + 1  
        end
    end
end

-- function to change the parent window of the tab 
function Adjustable.TabWindow:changeTabContainer(tab, myWindow, position)
    local tn = TN(tab)
    myWindow[tab] = self[tab]
    myWindow[tn] = self[tn]
    myWindow[tab .. "center"] = self[tab .. "center"]
    self[tn].container = not(self[tab].floating) and self.header or Geyser 
    self[tab]:changeContainer(myWindow.footer)
    self[tn]:changeContainer(myWindow.header)
    if not (self[tab].floating) then
        self:removeTab(tab)
        self:createTabs()
    end
    myWindow:createTabs()
    myWindow[tn]:show()
    myWindow:addTab(tab, position)
    if self.current then
        self[self.current]:show()
    end
    if #self.tabs > 0 then
        if not (self[tab].floating) then
            self:activateTab(self.tabs[1])
        end
    else 
        self.current = nil
    end
    myWindow:activateTab(tab)
    self:saveLayout()
end

-- handles the release event
function Adjustable.TabWindow:onRelease(tab, event, position)
    local myWindow = Adjustable.TabWindow.currentWindow or self
    local floating = self[tab].floating
    if event.button == "LeftButton" and Adjustable.TabWindow.currentWindow and not floating then
        self[TN(tab)]:lockContainer()
        self[TN(tab)].container = self.header
        self[TN(tab)]:onRelease(self[TN(tab)].adjLabel, event)
        self[TN(tab)].adjLabel:echo(self[tab].tabText)
        tab_pos = tab_pos or myWindow:findPosition(self[TN(tab)])
        if myWindow ~= self then
            self:changeTabContainer(tab, myWindow)
        end  
        myWindow:addTab(tab, tab_pos)
        myWindow:raiseAll()
        self:saveLayout()
    end
    
    if event.button == "LeftButton"
    and not Adjustable.TabWindow.currentWindow
    and not floating
    and not Adjustable.TabWindow.blockNextFloat
    then
        self:transformTabContainer(tab)
        self[TN(tab)]:onRelease(self[TN(tab)].adjLabel, event)
        self:saveLayout()
    end
    
    if floating then
        self[TN(tab)]:onRelease(self[TN(tab)].adjLabel, event)
        self:saveLayout()
    end
    local c = self[TN(tab)]
    if c and not self[tab].floating then
        c.minimized = false
        c:lockContainer()
    end
    
    Adjustable.TabWindow.clicked = false
    Adjustable.TabWindow.currentWindow = nil
    if not (Adjustable.TabWindow.doubleClick) then
        Adjustable.TabWindow.clickedTab = nil
    end
    tab_pos = nil
end

-- Internal: resolve a tab name or numeric index to its string key
local function tabKey(self, which)
    if type(which) == "number" and which <= #self.tabs then
        return self.tabs[which], which
    end
    local idx = table.index_of(self.tabs, which)
    return which, idx
end

-- change the text a tab displays
function Adjustable.TabWindow:setTabText(which, text)
    assert(type(which) == "string" or type(which) == "number", "setTabText: bad argument #1 type (tab name/position as string or number expected, got "..type(which).."!)")
    assert(type(text) == "string", "setTabText: bad argument #2 type (tab text as string expected, got "..type(text).."!)")
    local name, idx = tabKey(self, which)
    if not idx then return nil, "setTabText: Couldn't find tab to set a new text" end
    text = "<center>"..text
    self[name].tabText = text
    self[TN(name)].adjLabel:echo(text)
    return true
end

-- removes a tab (this won't be saved)
function Adjustable.TabWindow:removeTab(which)
    assert(type(which) == "string" or type(which) == "number", "removeTab: bad argument #1 type (tab name/position as string or number expected, got "..type(which).."!)")
    local name, idx = tabKey(self, which)
    if not idx then return nil, "removeTab: Couldn't find tab to remove" end
    self[TN(name)]:hide()
    self.header:remove(self[TN(name)])
    self.header:organize()
    table.remove(self.tabs, idx)
    return true
end

-- adds a tab (this won't be saved)
function Adjustable.TabWindow:addTab(name, pos)
    assert(type(name) == "string", "addTab: bad argument #1 type (tab name as string expected, got "..type(name).."!)")
    pos = pos or #self.tabs
    pos = pos > #self.tabs and #self.tabs or pos
    assert(type(pos) == "number", "addTab: bad argument #2 type (tab position as number expected, got "..type(pos).."!)")

    local index = table.index_of(self.tabs, name)
    if pos < 1 and #self.tabs ~= 0 then
        return nil, "addTab: not a valid position"
    end

    -- Clamp / adjust position for edge cases
    if index and pos > #self.tabs then
        pos = #self.tabs              -- existing tab clamped to last slot
    elseif not index and pos == #self.tabs then
        pos = pos + 1                 -- new tab appended after last
    end

    -- Already at the right position → nothing to do
    if index == pos then
        self.header:organize()
        return true
    end

    -- Reposition existing tab: remove from current slot, insert at new
    if index then
        table.remove(self.tabs, index)
        table.remove(self.header.windows, index)
    end
    table.insert(self.tabs, pos, name)

    -- New tab: create the label/container, then drop the duplicate header entry
    if not index then
        self:createTabs()
        table.remove(self.header.windows, #self.header.windows)
    end

    table.insert(self.header.windows, pos, self[TN(name)].name)
    self.header:organize()
    self:saveLayout()
    return true
end

--- saves your container settings
-- like tab position and some other variables in your Mudlet Profile Dir/ Adjustable.TabWindow
-- to be reliable it is important that every Adjustable.TabWindow has an unique 'name'
-- @see Adjustable.TabWindow:load
function Adjustable.TabWindow:save()
    local mytable = {}
    -- save fixed tabs
    for k,v in pairs(Adjustable.TabWindow.all) do
        mytable[k] = {}
        mytable[k].tabs = v.tabs
    end
    -- save floating tabs and tabText
    for k,v in pairs(Adjustable.TabWindow.allTabs) do
        for k1,v1 in pairs(v) do
            if type(v1) == "table" and v1.floating then
                -- save the tabs adjustable container settings
                v[k1.."tab"]:save()
                -- get all floating tabs and their windownames
                mytable[v.name].floatingTabs = mytable[v.name].floatingTabs or {}
                mytable[v.name].floatingTabs[k1] = "main"
                if v1.windowname ~= "main" then
                    mytable[v.name].floatingTabs[k1] = v1.windowname
                end
            end
        end
    end
    if not(io.exists(getMudletHomeDir().."/AdjustableTabWindow/")) then lfs.mkdir(getMudletHomeDir().."/AdjustableTabWindow/") end
    table.save(getMudletHomeDir().."/AdjustableTabWindow/TabWindowTabs.lua", mytable)
end


--- restores/loads the before saved settings 
-- it is very important to load after all TabWindows are created
-- @see Adjustable.TabWindow:save
function Adjustable.TabWindow:load()
    local mytable = {}
    if io.exists(getMudletHomeDir().."/AdjustableTabWindow/TabWindowTabs.lua") then
        table.load(getMudletHomeDir().."/AdjustableTabWindow/TabWindowTabs.lua", mytable)
    end

    for k,v in pairs(mytable) do
        -- load fixed Tabs
        local myWindow = Adjustable.TabWindow.all[k]

        if myWindow then
            for k1,v1 in ipairs(v.tabs) do
                local myTabWindow = Adjustable.TabWindow.allTabs[v1]
                if myTabWindow then
                    local myTab = myTabWindow[v1]
                    if myTab.floating then
                        myTabWindow:restoreTab(v1)
                    end
                    if not myWindow.header.windowList[v1.."tab"] then
                        myTabWindow:changeTabContainer(v1, myWindow)
                    end
                    myWindow:addTab(v1,k1)
                end
            end

            -- load floating Tabs
            if v.floatingTabs then
                for k1, v1 in pairs(v.floatingTabs) do
                    local myTabWindow = Adjustable.TabWindow.allTabs[k1]
                    if myTabWindow then
                        local myTab = myTabWindow[k1.."tab"]
                        myTabWindow:transformTabContainer(k1)
                        -- send my Tab to a UserWindow if saved there
                        if v1 ~= "main" then
                            myTab:changeContainer(Geyser.windowList[v1.."Container"].windowList[v1])
                        end
                        -- load Adjustable Container settings
                        myTab:load()
                    end
                end
            end
        end
    end
end

-- Save a reference to our parent constructor
Adjustable.TabWindow.parent = Geyser.Container
-- Create table to put every Adjustable.TabWindow in it
Adjustable.TabWindow.all = Adjustable.TabWindow.all or {}
Adjustable.TabWindow.all_windows = Adjustable.TabWindow.all_windows or {}
Adjustable.TabWindow.allTabs = Adjustable.TabWindow.allTabs or {}

-- tabwindow constructor
function Adjustable.TabWindow:new(cons, container)
    Geyser.HBox.organize = Geyser.HBox.organize or Geyser.HBox.reposition
    local me = self.parent:new(cons, container)
    cons = cons or {}
    setmetatable(me, self)
    self.__index = self
    me.type = "adjustabletabwindow"
    me.tabs = me.tabs or {}
    me.tabTxtColor = me.tabTxtColor or "white"
    me.tabPadding = me.tabPadding or 12
    me.color1 = me.color1 or "rgb(0,0,100)"
    me.color2 = me.color2 or "rgb(0,0,70)"
    me.tabBarHeight = me.tabBarHeight or "10%"
    me.footerStyle = me.footerStyle or ([[
    background-color: ]]..me.color1..[[;
    border-bottom-left-radius: 10px;
    border-bottom-right-radius: 10px;
    ]])
    
    me.centerStyle = me.centerStyle or ([[
    background-color: ]]..me.color2..[[;
    border-radius: 10px;
    margin: 5px;
    ]])
    
    me.inactiveTabStyle = me.inactiveTabStyle or ([[QLabel::hover{
        background-color: ]]..me.color1..[[;
        border-top-left-radius: 10px;
        border-top-right-radius: 10px;
        margin-right: 1px;
        margin-left: 1px;
        qproperty-alignment: 'AlignTop';
    }
    QLabel::!hover{
        background-color: ]]..me.color2..[[;
        border-top-left-radius: 10px;
        border-top-right-radius: 10px;
        margin-right: 1px;
        margin-left: 1px;
        qproperty-alignment: 'AlignTop';
    }
    ]])
    
    me.activeTabStyle = me.activeTabStyle or ([[
    background-color: ]]..me.color1..[[;
    border-top-left-radius: 10px;
    border-top-right-radius: 10px;
    margin-right: 1px;
    margin-left: 1px;
    qproperty-alignment: 'AlignTop';
    ]])
    
    me.chosenTabStyle = me.activeTabStyle
    
    me.containerStyle = me.containerStyle or ([[
    background-color: ]]..me.color1..[[;
    border-top-left-radius: 10px;
    border-top-right-radius: 10px;
    margin-right: 1px;
    margin-left: 1px;
    ]])
    
    me.overlayStyle = me.overlayStyle or [[
    background-color: rgba(0,0,0,0%);
    border: 2px solid white;]]
    
    me:createBaseContainers()
    me:createTabs()

    -- Constructor should not decide active tabs
    me.current = nil

    -- Hide all tab pages until load() restores state
    for _, tab in ipairs(me.tabs) do
        if me[tab] then
            me[tab]:hide()
        end
    end
    
    if not Adjustable.TabWindow.all[me.name] then
        Adjustable.TabWindow.all_windows[#Adjustable.Container.all_windows + 1] = me.name
    end
    Adjustable.TabWindow.all[me.name] = me
    
    return me
end