-- Data & State Layer
local gangs = {}
local gangColors = {
    ["Mouri"] = {255, 0, 0},
    ["Evil"] = {0, 0, 255}
}

local turfs = {
    {name = "Downtown LS", x = 500, y = -1000, width = 200, height = 200, owner = nil, progress = 0},
    {name = "Grove Street", x = 1300, y = -800, width = 200, height = 200, owner = nil, progress = 0},
    {name = "Santa Maria Beach", x = 1900, y = -1300, width = 200, height = 200, owner = nil, progress = 0},
    {name = "Los Santos Airport", x = 100, y = -1500, width = 200, height = 200, owner = nil, progress = 0},
    {name = "Verdant Bluffs", x = 800, y = -500, width = 200, height = 200, owner = nil, progress = 0},
    {name = "East Beach", x = 1600, y = -1100, width = 200, height = 200, owner = nil, progress = 0}
}

-- Helper: Get or create team
function getOrCreateTeam(gangName)
    for _, team in ipairs(getElementsByType("team")) do
        if getTeamName(team) == gangName then
            return team
        end
    end
    local team = createTeam(gangName, gangColors[gangName][1], gangColors[gangName][2], gangColors[gangName][3])
    return team
end

-- Helper: Hex to RGB
function hexToRGB(hex)
    outputDebugString("[TurfWar] hexToRGB called with: " .. tostring(hex), 3)
    hex = hex:gsub("#", "")
    outputDebugString("[TurfWar] After gsub: " .. tostring(hex), 3)
    if #hex ~= 6 then return false end
    
    local r = tonumber(hex:sub(1,2), 16)
    local g = tonumber(hex:sub(3,4), 16)
    local b = tonumber(hex:sub(5,6), 16)
    
    outputDebugString("[TurfWar] Converted to RGB: " .. tostring(r) .. ", " .. tostring(g) .. ", " .. tostring(b), 3)
    return r, g, b
end

-- Prompt 1: Join Gang
function joinGang(gangName)
    local player = source
    if not isElement(player) then 
        outputDebugString("[TurfWar] Invalid player in joinGang", 2)
        return 
    end
    
    local team = getOrCreateTeam(gangName)
    setPlayerTeam(player, team)
    outputChatBox("You have joined " .. gangName .. "!", player, 0, 255, 0)
end
addEvent("turfwar:joinGang", true)
addEventHandler("turfwar:joinGang", root, joinGang)

-- Prompt 2: /groupturfcolor command
function setGangColor(player, cmd, hex)
    outputChatBox("Command called with: " .. tostring(hex), player, 255, 255, 0)
    local team = getPlayerTeam(player)
    if not team then
        outputChatBox("You must be in a team first!", player, 255, 0, 0)
        return
    end
    if not hex or not hex:match("^#[0-9a-fA-F]{6}$") then
        outputChatBox("Usage: /groupturfcolor #RRGGBB", player, 255, 0, 0)
        return
    end
    
    local r, g, b = hexToRGB(hex)
    outputChatBox("Converted color: " .. tostring(r) .. ", " .. tostring(g) .. ", " .. tostring(b), player, 255, 255, 0)
    if not r then
        outputChatBox("Invalid hex color!", player, 255, 0, 0)
        return
    end
    
    local gangName = getTeamName(team)
    gangColors[gangName] = {r, g, b}
    setTeamColor(team, r, g, b)
    
    -- Update existing radar areas for this gang
    for _, turf in ipairs(turfs) do
        if turf.owner == gangName and turf.radarArea then
            setRadarAreaColor(turf.radarArea, r, g, b, 175)
        end
    end
    
    outputChatBox("Gang color updated to " .. hex .. "!", player, 0, 255, 0)
end
addCommandHandler("groupturfcolor", setGangColor)

-- Debug: Resource start
outputDebugString("[TurfWar] Server script loaded!", 3)

-- Prompt 3: Turf Control Engine
function initTurfs()
    outputDebugString("[TurfWar] Initializing turfs...", 3)
    for i, turf in ipairs(turfs) do
        -- Create radar area
        turf.radarArea = createRadarArea(turf.x, turf.y, turf.width, turf.height, 127, 127, 127, 175)
        -- Create colshape
        turf.colShape = createColRectangle(turf.x, turf.y, turf.width, turf.height)
        setElementData(turf.colShape, "turfData", turf)
        outputDebugString("[TurfWar] Created turf: " .. turf.name .. " at " .. tostring(turf.x) .. "," .. tostring(turf.y), 3)
    end
end
addEventHandler("onResourceStart", resourceRoot, initTurfs)

-- Send player's current turf and all turfs to client
function sendTurfUpdates()
    local turfsData = {}
    for _, turf in ipairs(turfs) do
        table.insert(turfsData, {
            name = turf.name,
            owner = turf.owner,
            progress = turf.progress,
            x = turf.x,
            y = turf.y,
            width = turf.width,
            height = turf.height
        })
    end
    
    for _, player in ipairs(getElementsByType("player")) do
        local playerTurf = nil
        for _, turf in ipairs(turfs) do
            if turf.colShape and isElement(turf.colShape) and isElementWithinColShape(player, turf.colShape) then
                playerTurf = {
                    name = turf.name,
                    owner = turf.owner,
                    progress = turf.progress
                }
                break
            end
        end
        
        if isElement(player) then
            triggerClientEvent(player, "turfwar:sendPlayerTurf", resourceRoot, playerTurf)
            triggerClientEvent(player, "turfwar:sendAllTurfs", resourceRoot, turfsData)
        end
    end
end
setTimer(sendTurfUpdates, 500, 0)

function processTurfProgress()
    for _, turf in ipairs(turfs) do
        -- Make sure colShape exists
        if turf.colShape and isElement(turf.colShape) then
            -- Count players inside, grouped by team
            local teamCounts = {}
            local playersInside = getElementsWithinColShape(turf.colShape, "player")
            
            if playersInside then
                for _, player in ipairs(playersInside) do
                    local team = getPlayerTeam(player)
                    if team then
                        local teamName = getTeamName(team)
                        teamCounts[teamName] = (teamCounts[teamName] or 0) + 1
                    end
                end
            end
            
            -- Find dominant team
            local dominantTeam = nil
            local maxCount = 0
            for teamName, count in pairs(teamCounts) do
                if count > maxCount then
                    maxCount = count
                    dominantTeam = teamName
                end
            end
            
            -- Update progress
            if dominantTeam then
                if turf.owner == nil then
                    -- Unowned turf: increase progress by 1% per member
                    turf.progress = math.min(100, turf.progress + maxCount)
                    if turf.progress >= 51 then
                        -- Capture!
                        turf.owner = dominantTeam
                        local r, g, b = unpack(gangColors[dominantTeam] or {255, 255, 255})
                        if turf.radarArea then
                            setRadarAreaColor(turf.radarArea, r, g, b, 175)
                        end
                        outputChatBox(dominantTeam .. " has captured " .. turf.name .. "!", root, 255, 255, 0)
                    end
                elseif turf.owner == dominantTeam then
                    -- Owner present: restore progress towards 100
                    turf.progress = math.min(100, turf.progress + maxCount)
                else
                    -- Enemy present: decrease progress
                    turf.progress = math.max(0, turf.progress - maxCount)
                    if turf.progress < 51 then
                        -- Capture!
                        turf.owner = dominantTeam
                        turf.progress = 51
                        local r, g, b = unpack(gangColors[dominantTeam] or {255, 255, 255})
                        if turf.radarArea then
                            setRadarAreaColor(turf.radarArea, r, g, b, 175)
                        end
                        outputChatBox(dominantTeam .. " has captured " .. turf.name .. "!", root, 255, 255, 0)
                    end
                end
            else
                -- No players present: decay towards 0 if unowned, or slowly back to 100 if owned
                if turf.owner then
                    turf.progress = math.min(100, turf.progress + 1)
                else
                    turf.progress = math.max(0, turf.progress - 1)
                end
            end
        else
            outputDebugString("[TurfWar] Missing colShape for turf: " .. turf.name, 2)
        end
    end
end
setTimer(processTurfProgress, 10, 0)

-- Prompt 4: Passive Revenue Loop
function processPayouts()
    -- Calculate payouts per gang
    local payouts = {}
    for _, turf in ipairs(turfs) do
        if turf.owner then
            payouts[turf.owner] = (payouts[turf.owner] or 0) + 3000
        end
    end
    
    -- Distribute payouts
    for gangName, amount in pairs(payouts) do
        local team = getOrCreateTeam(gangName)
        for _, player in ipairs(getPlayersInTeam(team)) do
            givePlayerMoney(player, amount)
            outputChatBox("You received $" .. amount .. " from turf ownership!", player, 0, 255, 0)
        end
    end
end
setTimer(processPayouts, 60000, 0)
