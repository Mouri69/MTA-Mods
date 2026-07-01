local groups = {}
local dataFile = "groups.json"

-- Default ranks
local defaultRanks = {
    {name = "Founder", permissions = {"*"}, color = {255, 0, 0}},
    {name = "Leader", permissions = {"invite", "kick", "promote", "demote", "manage_ranks", "edit_description"}, color = {255, 128, 0}},
    {name = "Officer", permissions = {"invite", "kick"}, color = {255, 255, 0}},
    {name = "Member", permissions = {}, color = {0, 255, 0}}
}

-- Save groups
function saveGroups()
    local file = fileCreate(dataFile)
    if file then
        fileWrite(file, toJSON(groups))
        fileClose(file)
        outputDebugString("[GroupSystem] Saved groups to file!", 3)
    end
end

-- Load groups
function loadGroups()
    local file = fileOpen(dataFile)
    if file then
        local json = fileRead(file, fileGetSize(file))
        fileClose(file)
        groups = fromJSON(json) or {}
        outputDebugString("[GroupSystem] Loaded " .. #groups .. " groups!", 3)
    else
        groups = {}
        saveGroups()
    end
end

-- Helper: Get player's account name
function getPlayerAccountName(player)
    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        return getAccountName(account)
    end
    return false
end

-- Helper: Find group by ID
function findGroupById(groupId)
    for _, group in ipairs(groups) do
        if group.id == groupId then
            return group
        end
    end
    return false
end

-- Helper: Find group by member
function findPlayerGroup(player)
    local accName = getPlayerAccountName(player)
    if not accName then return false end
    
    for _, group in ipairs(groups) do
        if group.members[accName] then
            return group
        end
    end
    return false
end

-- Helper: Check player permission
function hasPermission(player, permission)
    local group = findPlayerGroup(player)
    if not group then return false end
    
    local accName = getPlayerAccountName(player)
    if not accName then return false end
    
    local member = group.members[accName]
    if not member then return false end
    
    local rank = group.ranks[member.rank]
    if not rank then return false end
    
    if rank.permissions then
        for _, perm in ipairs(rank.permissions) do
            if perm == "*" or perm == permission then
                return true
            end
        end
    end
    
    return false
end

-- Create group
function createGroup(player, groupName)
    if not isElement(player) then return false end
    if not groupName or groupName == "" then return false end
    
    local accName = getPlayerAccountName(player)
    if not accName then
        outputChatBox("[GroupSystem] You must be logged in!", player, 255, 0, 0)
        return false
    end
    
    -- Check if already in a group
    if findPlayerGroup(player) then
        outputChatBox("[GroupSystem] You're already in a group!", player, 255, 0, 0)
        return false
    end
    
    -- Check if group name exists
    for _, g in ipairs(groups) do
        if g.name == groupName then
            outputChatBox("[GroupSystem] Group name already taken!", player, 255, 0, 0)
            return false
        end
    end
    
    local groupId = #groups + 1
    local newGroup = {
        id = groupId,
        name = groupName,
        description = "",
        founder = accName,
        created = getRealTime().timestamp,
        members = {},
        ranks = {},
        members = {}
    }
    
    -- Copy default ranks
    newGroup.ranks = {}
    for i, rank in ipairs(defaultRanks) do
        newGroup.ranks[i] = {
            name = rank.name,
            permissions = {unpack(rank.permissions)},
            color = {unpack(rank.color)}
        }
    end
    
    -- Add founder as member
    newGroup.members[accName] = {
        username = getPlayerName(player),
        accountName = accName,
        joined = getRealTime().timestamp,
        lastSeen = getRealTime().timestamp,
        rank = 1,
        online = true
    }
    
    table.insert(groups, newGroup)
    saveGroups()
    
    outputChatBox("[GroupSystem] Group '" .. groupName .. "' created!", player, 0, 255, 0)
    triggerClientEvent(player, "groupsystem:update", resourceRoot, newGroup, true)
    return true
end

-- Delete group
function deleteGroup(player)
    if not isElement(player) then return false end
    
    local group = findPlayerGroup(player)
    if not group then
        outputChatBox("[GroupSystem] You're not in a group!", player, 255, 0, 0)
        return false
    end
    
    local accName = getPlayerAccountName(player)
    if group.founder ~= accName then
        outputChatBox("[GroupSystem] Only the founder can delete the group!", player, 255, 0, 0)
        return false
    end
    
    local groupName = group.name
    for i, g in ipairs(groups) do
        if g.id == group.id then
            table.remove(groups, i)
            break
        end
    end
    
    saveGroups()
    outputChatBox("[GroupSystem] Group '" .. groupName .. "' deleted!", player, 0, 255, 0)
    triggerClientEvent(player, "groupsystem:update", resourceRoot, false, false)
    
    -- Notify all members
    for _, memberAcc in pairs(group.members) do
        local memPlayer = getAccountPlayer(getAccount(memberAcc.accountName))
        if memPlayer and isElement(memPlayer) then
            triggerClientEvent(memPlayer, "groupsystem:update", resourceRoot, false, false)
        end
    end
    
    return true
end

-- Invite player
function invitePlayer(player, targetPlayer)
    if not isElement(player) or not isElement(targetPlayer) then return false end
    
    local group = findPlayerGroup(player)
    if not group then
        outputChatBox("[GroupSystem] You're not in a group!", player, 255, 0, 0)
        return false
    end
    
    if not hasPermission(player, "invite") then
        outputChatBox("[GroupSystem] You don't have permission to invite!", player, 255, 0, 0)
        return false
    end
    
    local targetAccName = getPlayerAccountName(targetPlayer)
    if not targetAccName then
        outputChatBox("[GroupSystem] Target isn't logged in!", player, 255, 0, 0)
        return false
    end
    
    if findPlayerGroup(targetPlayer) then
        outputChatBox("[GroupSystem] Target is already in a group!", player, 255, 0, 0)
        return false
    end
    
    -- Send invite
    outputChatBox("[GroupSystem] You've been invited to join '" .. group.name .. "'! Use /acceptinvite or /declineinvite", targetPlayer, 0, 255, 255)
    outputChatBox("[GroupSystem] Invitation sent to " .. getPlayerName(targetPlayer) .. "!", player, 0, 255, 0)
    
    -- Store pending invite
    if not group.pendingInvites then group.pendingInvites = {} end
    group.pendingInvites[targetAccName] = {
        inviter = getPlayerAccountName(player),
        timestamp = getRealTime().timestamp
    }
    saveGroups()
    
    triggerClientEvent(targetPlayer, "groupsystem:inviteReceived", resourceRoot, group)
    return true
end

-- Accept invite
function acceptInvite(player)
    if not isElement(player) then return false end
    
    local accName = getPlayerAccountName(player)
    if not accName then return false end
    
    -- Find pending invite
    for _, group in ipairs(groups) do
        if group.pendingInvites and group.pendingInvites[accName] then
            -- Add member
            group.members[accName] = {
                username = getPlayerName(player),
                accountName = accName,
                joined = getRealTime().timestamp,
                lastSeen = getRealTime().timestamp,
                rank = #group.ranks, -- Default to lowest rank
                online = true
            }
            group.pendingInvites[accName] = nil
            saveGroups()
            
            outputChatBox("[GroupSystem] You joined '" .. group.name .. "'!", player, 0, 255, 0)
            triggerClientEvent(player, "groupsystem:update", resourceRoot, group, true)
            
            -- Notify other members
            for memberAcc, memberData in pairs(group.members) do
                local memPlayer = getAccountPlayer(getAccount(memberAcc))
                if memPlayer and isElement(memPlayer) and memPlayer ~= player then
                    outputChatBox("[GroupSystem] " .. getPlayerName(player) .. " joined the group!", memPlayer, 0, 255, 0)
                    triggerClientEvent(memPlayer, "groupsystem:update", resourceRoot, group, false)
                end
            end
            
            return true
        end
    end
    
    outputChatBox("[GroupSystem] No pending invites!", player, 255, 0, 0)
    return false
end

-- Decline invite
function declineInvite(player)
    if not isElement(player) then return false end
    
    local accName = getPlayerAccountName(player)
    if not accName then return false end
    
    for _, group in ipairs(groups) do
        if group.pendingInvites and group.pendingInvites[accName] then
            group.pendingInvites[accName] = nil
            saveGroups()
            outputChatBox("[GroupSystem] Invitation declined!", player, 0, 255, 0)
            return true
        end
    end
    
    outputChatBox("[GroupSystem] No pending invites!", player, 255, 0, 0)
    return false
end

-- Leave group
function leaveGroup(player)
    if not isElement(player) then return false end
    
    local group = findPlayerGroup(player)
    if not group then
        outputChatBox("[GroupSystem] You're not in a group!", player, 255, 0, 0)
        return false
    end
    
    local accName = getPlayerAccountName(player)
    if group.founder == accName then
        outputChatBox("[GroupSystem] Founder can't leave! Use /deletegroup instead!", player, 255, 0, 0)
        return false
    end
    
    group.members[accName] = nil
    saveGroups()
    
    outputChatBox("[GroupSystem] You left the group!", player, 0, 255, 0)
    triggerClientEvent(player, "groupsystem:update", resourceRoot, false, false)
    
    -- Notify other members
    for memberAcc, memberData in pairs(group.members) do
        local memPlayer = getAccountPlayer(getAccount(memberAcc))
        if memPlayer and isElement(memPlayer) then
            outputChatBox("[GroupSystem] " .. getPlayerName(player) .. " left the group!", memPlayer, 255, 0, 0)
            triggerClientEvent(memPlayer, "groupsystem:update", resourceRoot, group, false)
        end
    end
    
    return true
end

-- Kick member
function kickMember(player, targetAccName)
    if not isElement(player) then return false end
    
    local group = findPlayerGroup(player)
    if not group then
        outputChatBox("[GroupSystem] You're not in a group!", player, 255, 0, 0)
        return false
    end
    
    if not hasPermission(player, "kick") then
        outputChatBox("[GroupSystem] You don't have permission to kick!", player, 255, 0, 0)
        return false
    end
    
    local accName = getPlayerAccountName(player)
    if accName == targetAccName then
        outputChatBox("[GroupSystem] You can't kick yourself!", player, 255, 0, 0)
        return false
    end
    
    local targetMember = group.members[targetAccName]
    if not targetMember then
        outputChatBox("[GroupSystem] Member not found!", player, 255, 0, 0)
        return false
    end
    
    -- Check rank hierarchy
    local playerRank = group.members[accName].rank
    local targetRank = targetMember.rank
    if targetRank <= playerRank and group.founder ~= accName then
        outputChatBox("[GroupSystem] You can't kick someone of equal or higher rank!", player, 255, 0, 0)
        return false
    end
    
    local targetPlayer = getAccountPlayer(getAccount(targetAccName))
    local targetName = targetMember.username
    group.members[targetAccName] = nil
    saveGroups()
    
    outputChatBox("[GroupSystem] " .. targetName .. " has been kicked!", player, 0, 255, 0)
    
    if targetPlayer and isElement(targetPlayer) then
        outputChatBox("[GroupSystem] You've been kicked from '" .. group.name .. "'!", targetPlayer, 255, 0, 0)
        triggerClientEvent(targetPlayer, "groupsystem:update", resourceRoot, false, false)
    end
    
    -- Notify other members
    for memberAcc, memberData in pairs(group.members) do
        local memPlayer = getAccountPlayer(getAccount(memberAcc))
        if memPlayer and isElement(memPlayer) then
            outputChatBox("[GroupSystem] " .. targetName .. " has been kicked!", memPlayer, 255, 0, 0)
            triggerClientEvent(memPlayer, "groupsystem:update", resourceRoot, group, false)
        end
    end
    
    return true
end

-- Promote/demote member
function setMemberRank(player, targetAccName, newRank)
    if not isElement(player) then return false end
    
    local group = findPlayerGroup(player)
    if not group then
        outputChatBox("[GroupSystem] You're not in a group!", player, 255, 0, 0)
        return false
    end
    
    if not hasPermission(player, "promote") and not hasPermission(player, "demote") then
        outputChatBox("[GroupSystem] You don't have permission to manage ranks!", player, 255, 0, 0)
        return false
    end
    
    if newRank < 1 or newRank > #group.ranks then
        outputChatBox("[GroupSystem] Invalid rank!", player, 255, 0, 0)
        return false
    end
    
    local targetMember = group.members[targetAccName]
    if not targetMember then
        outputChatBox("[GroupSystem] Member not found!", player, 255, 0, 0)
        return false
    end
    
    local accName = getPlayerAccountName(player)
    if accName == targetAccName then
        outputChatBox("[GroupSystem] You can't change your own rank!", player, 255, 0, 0)
        return false
    end
    
    local playerRank = group.members[accName].rank
    if newRank <= playerRank and group.founder ~= accName then
        outputChatBox("[GroupSystem] You can't set someone to equal or higher rank!", player, 255, 0, 0)
        return false
    end
    
    local oldRank = targetMember.rank
    targetMember.rank = newRank
    saveGroups()
    
    local rankName = group.ranks[newRank].name
    outputChatBox("[GroupSystem] " .. targetMember.username .. " is now " .. rankName .. "!", player, 0, 255, 0)
    
    local targetPlayer = getAccountPlayer(getAccount(targetAccName))
    if targetPlayer and isElement(targetPlayer) then
        outputChatBox("[GroupSystem] You've been promoted to " .. rankName .. "!", targetPlayer, 0, 255, 0)
        triggerClientEvent(targetPlayer, "groupsystem:update", resourceRoot, group, false)
    end
    
    -- Notify other members
    for memberAcc, memberData in pairs(group.members) do
        local memPlayer = getAccountPlayer(getAccount(memberAcc))
        if memPlayer and isElement(memPlayer) and memPlayer ~= player and memPlayer ~= targetPlayer then
            outputChatBox("[GroupSystem] " .. targetMember.username .. " is now " .. rankName .. "!", memPlayer, 0, 255, 0)
            triggerClientEvent(memPlayer, "groupsystem:update", resourceRoot, group, false)
        end
    end
    
    return true
end

-- Edit group description
function setGroupDescription(player, description)
    if not isElement(player) then return false end
    
    local group = findPlayerGroup(player)
    if not group then
        outputChatBox("[GroupSystem] You're not in a group!", player, 255, 0, 0)
        return false
    end
    
    if not hasPermission(player, "edit_description") then
        outputChatBox("[GroupSystem] You don't have permission!", player, 255, 0, 0)
        return false
    end
    
    group.description = description or ""
    saveGroups()
    outputChatBox("[GroupSystem] Group description updated!", player, 0, 255, 0)
    
    -- Notify all members
    for memberAcc, memberData in pairs(group.members) do
        local memPlayer = getAccountPlayer(getAccount(memberAcc))
        if memPlayer and isElement(memPlayer) then
            triggerClientEvent(memPlayer, "groupsystem:update", resourceRoot, group, false)
        end
    end
    
    return true
end

-- Send group data to client
function sendGroupDataToPlayer(player)
    if not isElement(player) then return end
    
    local group = findPlayerGroup(player)
    local accName = getPlayerAccountName(player)
    
    -- Update last seen if in group
    if group and accName and group.members[accName] then
        group.members[accName].lastSeen = getRealTime().timestamp
        group.members[accName].online = true
        group.members[accName].username = getPlayerName(player)
    end
    
    triggerClientEvent(player, "groupsystem:update", resourceRoot, group, false)
end

-- Command handlers
addCommandHandler("creategroup", function(player, cmd, ...)
    local groupName = table.concat({...}, " ")
    createGroup(player, groupName)
end)

addCommandHandler("deletegroup", deleteGroup)
addCommandHandler("leavegroup", leaveGroup)
addCommandHandler("acceptinvite", acceptInvite)
addCommandHandler("declineinvite", declineInvite)

-- Event: Player joins
addEventHandler("onPlayerJoin", root, function()
    setTimer(sendGroupDataToPlayer, 1000, 1, source)
end)

-- Event: Player quits
addEventHandler("onPlayerQuit", root, function()
    local player = source
    local group = findPlayerGroup(player)
    local accName = getPlayerAccountName(player)
    if group and accName and group.members[accName] then
        group.members[accName].online = false
    end
end)

-- Event: Resource start
addEventHandler("onResourceStart", resourceRoot, function()
    loadGroups()
    -- Send data to all online players
    for _, player in ipairs(getElementsByType("player")) do
        setTimer(sendGroupDataToPlayer, 500, 1, player)
    end
end)

-- Network events
addEvent("groupsystem:createGroup", true)
addEventHandler("groupsystem:createGroup", root, function(groupName)
    createGroup(source, groupName)
end)

addEvent("groupsystem:deleteGroup", true)
addEventHandler("groupsystem:deleteGroup", root, deleteGroup)

addEvent("groupsystem:leaveGroup", true)
addEventHandler("groupsystem:leaveGroup", root, leaveGroup)

addEvent("groupsystem:acceptInvite", true)
addEventHandler("groupsystem:acceptInvite", root, acceptInvite)

addEvent("groupsystem:declineInvite", true)
addEventHandler("groupsystem:declineInvite", root, declineInvite)

addEvent("groupsystem:invitePlayer", true)
addEventHandler("groupsystem:invitePlayer", root, function(targetName)
    local target = getPlayerFromName(targetName)
    if target then
        invitePlayer(source, target)
    else
        outputChatBox("[GroupSystem] Player not found!", source, 255, 0, 0)
    end
end)

addEvent("groupsystem:kickMember", true)
addEventHandler("groupsystem:kickMember", root, function(targetAccName)
    kickMember(source, targetAccName)
end)

addEvent("groupsystem:setMemberRank", true)
addEventHandler("groupsystem:setMemberRank", root, function(targetAccName, newRank)
    setMemberRank(source, targetAccName, newRank)
end)

addEvent("groupsystem:setDescription", true)
addEventHandler("groupsystem:setDescription", root, function(description)
    setGroupDescription(source, description)
end)

addEvent("groupsystem:requestData", true)
addEventHandler("groupsystem:requestData", root, function()
    sendGroupDataToPlayer(source)
end)

outputDebugString("[GroupSystem] Server script loaded!", 3)
