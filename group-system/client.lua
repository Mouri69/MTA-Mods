local currentGroup = nil
local mainWindow = nil
local isWindowOpen = false

-- GUI Elements
local tabs = nil
local tabCreate = nil
local tabManage = nil
local tabMembers = nil
local tabRanks = nil

-- Tab Create elements
local createNameEdit = nil
local createBtn = nil

-- Tab Manage elements
local descEdit = nil
local saveDescBtn = nil
local deleteBtn = nil
local leaveBtn = nil

-- Tab Members elements
local membersGrid = nil
local inviteEdit = nil
local inviteBtn = nil
local promoteBtn = nil
local demoteBtn = nil
local kickBtn = nil

-- Tab Ranks elements
local ranksGrid = nil

-- Helper: Format timestamp
function formatTimestamp(timestamp)
    if not timestamp then return "Unknown" end
    local time = getRealTime(timestamp)
    return string.format("%02d/%02d/%04d %02d:%02d", time.monthday, time.month + 1, time.year + 1900, time.hour, time.minute)
end

-- Helper: Update GUI
function updateGUI()
    if not mainWindow then return end
    
    -- Update manage tab
    if tabManage and descEdit and currentGroup then
        guiSetText(descEdit, currentGroup.description or "")
    end
    
    -- Update members tab
    if membersGrid and currentGroup then
        -- Clear grid
        guiGridListClear(membersGrid)
        
        -- Add members
        if currentGroup.members then
            for accName, member in pairs(currentGroup.members) do
                local row = guiGridListAddRow(membersGrid)
                local rankName = "Unknown"
                local rankColor = tocolor(200, 200, 200, 255)
                if currentGroup.ranks and currentGroup.ranks[member.rank] then
                    rankName = currentGroup.ranks[member.rank].name
                    local rc = currentGroup.ranks[member.rank].color
                    rankColor = tocolor(rc[1], rc[2], rc[3], 255)
                end
                guiGridListSetItemText(membersGrid, row, 1, member.username, false, false)
                guiGridListSetItemText(membersGrid, row, 2, accName, false, false)
                guiGridListSetItemText(membersGrid, row, 3, rankName, false, false)
                guiGridListSetItemText(membersGrid, row, 4, formatTimestamp(member.joined), false, false)
                guiGridListSetItemText(membersGrid, row, 5, formatTimestamp(member.lastSeen), false, false)
                guiGridListSetItemText(membersGrid, row, 6, member.online and "Yes" or "No", false, false)
                guiGridListSetItemData(membersGrid, row, 1, accName)
            end
        end
    end
    
    -- Update ranks tab
    if ranksGrid and currentGroup then
        guiGridListClear(ranksGrid)
        if currentGroup.ranks then
            for i, rank in ipairs(currentGroup.ranks) do
                local row = guiGridListAddRow(ranksGrid)
                guiGridListSetItemText(ranksGrid, row, 1, rank.name, false, false)
                guiGridListSetItemText(ranksGrid, row, 2, table.concat(rank.permissions, ", "), false, false)
            end
        end
    end
end

-- Open main window
function openMainWindow()
    if isWindowOpen then return end
    isWindowOpen = true
    showCursor(true)
    
    local screenW, screenH = guiGetScreenSize()
    local winW = 800
    local winH = 600
    local winX = (screenW - winW) / 2
    local winY = (screenH - winH) / 2
    
    mainWindow = guiCreateWindow(winX, winY, winW, winH, "Group System", false)
    guiWindowSetSizable(mainWindow, false)
    
    -- Tabs
    tabs = guiCreateTabPanel(0.02, 0.05, 0.96, 0.9, true, mainWindow)
    
    -- Create Tab
    tabCreate = guiCreateTab("Create Group", tabs)
    local createLabel = guiCreateLabel(0.1, 0.1, 0.8, 0.1, "Group Name:", true, tabCreate)
    createNameEdit = guiCreateEdit(0.1, 0.2, 0.8, 0.1, "", true, tabCreate)
    createBtn = guiCreateButton(0.1, 0.4, 0.8, 0.15, "Create Group", true, tabCreate)
    
    -- Manage Tab
    tabManage = guiCreateTab("Manage Group", tabs)
    local descLabel = guiCreateLabel(0.1, 0.1, 0.8, 0.1, "Group Description:", true, tabManage)
    descEdit = guiCreateMemo(0.1, 0.2, 0.8, 0.4, "", true, tabManage)
    saveDescBtn = guiCreateButton(0.1, 0.65, 0.8, 0.1, "Save Description", true, tabManage)
    leaveBtn = guiCreateButton(0.1, 0.78, 0.38, 0.1, "Leave Group", true, tabManage)
    deleteBtn = guiCreateButton(0.52, 0.78, 0.38, 0.1, "Delete Group", true, tabManage)
    
    -- Members Tab
    tabMembers = guiCreateTab("Members", tabs)
    local inviteLabel = guiCreateLabel(0.1, 0.05, 0.6, 0.08, "Invite Player (name):", true, tabMembers)
    inviteEdit = guiCreateEdit(0.1, 0.13, 0.6, 0.08, "", true, tabMembers)
    inviteBtn = guiCreateButton(0.72, 0.13, 0.18, 0.08, "Invite", true, tabMembers)
    
    membersGrid = guiCreateGridList(0.1, 0.25, 0.8, 0.5, true, tabMembers)
    guiGridListAddColumn(membersGrid, "Username", 0.2)
    guiGridListAddColumn(membersGrid, "Account", 0.2)
    guiGridListAddColumn(membersGrid, "Rank", 0.15)
    guiGridListAddColumn(membersGrid, "Joined", 0.15)
    guiGridListAddColumn(membersGrid, "Last Seen", 0.15)
    guiGridListAddColumn(membersGrid, "Online", 0.1)
    
    promoteBtn = guiCreateButton(0.1, 0.78, 0.2, 0.1, "Promote", true, tabMembers)
    demoteBtn = guiCreateButton(0.32, 0.78, 0.2, 0.1, "Demote", true, tabMembers)
    kickBtn = guiCreateButton(0.54, 0.78, 0.2, 0.1, "Kick", true, tabMembers)
    
    -- Ranks Tab
    tabRanks = guiCreateTab("Ranks", tabs)
    local ranksInfo = guiCreateLabel(0.1, 0.05, 0.8, 0.1, "Default ranks (customization coming soon!)", true, tabRanks)
    ranksGrid = guiCreateGridList(0.1, 0.15, 0.8, 0.75, true, tabRanks)
    guiGridListAddColumn(ranksGrid, "Rank Name", 0.4)
    guiGridListAddColumn(ranksGrid, "Permissions", 0.6)
    
    -- Close button
    local closeBtn = guiCreateButton(0.85, 0.93, 0.13, 0.05, "Close", true, mainWindow)
    
    -- Event handlers
    addEventHandler("onClientGUIClick", closeBtn, closeMainWindow, false)
    addEventHandler("onClientGUIClick", createBtn, function()
        local groupName = guiGetText(createNameEdit)
        if groupName and groupName ~= "" then
            triggerServerEvent("groupsystem:createGroup", resourceRoot, groupName)
        end
    end, false)
    addEventHandler("onClientGUIClick", saveDescBtn, function()
        triggerServerEvent("groupsystem:setDescription", resourceRoot, guiGetText(descEdit))
    end, false)
    addEventHandler("onClientGUIClick", deleteBtn, function()
        triggerServerEvent("groupsystem:deleteGroup", resourceRoot)
    end, false)
    addEventHandler("onClientGUIClick", leaveBtn, function()
        triggerServerEvent("groupsystem:leaveGroup", resourceRoot)
    end, false)
    addEventHandler("onClientGUIClick", inviteBtn, function()
        local targetName = guiGetText(inviteEdit)
        if targetName and targetName ~= "" then
            triggerServerEvent("groupsystem:invitePlayer", resourceRoot, targetName)
            guiSetText(inviteEdit, "")
        end
    end, false)
    addEventHandler("onClientGUIClick", kickBtn, function()
        local selectedRow, selectedCol = guiGridListGetSelectedItem(membersGrid)
        if selectedRow ~= -1 then
            local accName = guiGridListGetItemData(membersGrid, selectedRow, 1)
            if accName then
                triggerServerEvent("groupsystem:kickMember", resourceRoot, accName)
            end
        end
    end, false)
    addEventHandler("onClientGUIClick", promoteBtn, function()
        local selectedRow, selectedCol = guiGridListGetSelectedItem(membersGrid)
        if selectedRow ~= -1 and currentGroup then
            local accName = guiGridListGetItemData(membersGrid, selectedRow, 1)
            if accName and currentGroup.members and currentGroup.members[accName] then
                local currentRank = currentGroup.members[accName].rank
                local newRank = currentRank - 1
                if newRank >= 1 then
                    triggerServerEvent("groupsystem:setMemberRank", resourceRoot, accName, newRank)
                end
            end
        end
    end, false)
    addEventHandler("onClientGUIClick", demoteBtn, function()
        local selectedRow, selectedCol = guiGridListGetSelectedItem(membersGrid)
        if selectedRow ~= -1 and currentGroup then
            local accName = guiGridListGetItemData(membersGrid, selectedRow, 1)
            if accName and currentGroup.members and currentGroup.members[accName] then
                local currentRank = currentGroup.members[accName].rank
                local newRank = currentRank + 1
                if newRank <= #currentGroup.ranks then
                    triggerServerEvent("groupsystem:setMemberRank", resourceRoot, accName, newRank)
                end
            end
        end
    end, false)
    
    updateGUI()
end

-- Close main window
function closeMainWindow()
    if not isWindowOpen then return end
    isWindowOpen = false
    showCursor(false)
    
    if mainWindow and isElement(mainWindow) then
        destroyElement(mainWindow)
        mainWindow = nil
    end
end

-- Toggle main window on F5
bindKey("F5", "down", function()
    if isWindowOpen then
        closeMainWindow()
    else
        openMainWindow()
    end
end)

-- Receive group data from server
addEvent("groupsystem:update", true)
addEventHandler("groupsystem:update", resourceRoot, function(groupData)
    currentGroup = groupData
    updateGUI()
end)

-- Receive invite
addEvent("groupsystem:inviteReceived", true)
addEventHandler("groupsystem:inviteReceived", resourceRoot, function(group)
    outputChatBox("[GroupSystem] You've been invited to join '" .. group.name .. "'!", 0, 255, 255)
end)

-- Request data when resource starts
addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("groupsystem:requestData", resourceRoot)
end)

outputDebugString("[GroupSystem] Client script loaded!", 3)
