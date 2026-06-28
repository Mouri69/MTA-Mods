-- Data & State Layer
local gangs = {}
local gangColors = {
    ["Mouri"] = {255, 0, 0},
    ["Evil"] = {0, 0, 255}
}

local turfs = {} -- only serializable data (no userdata)
local turfRadarAreas = {} -- table of radarArea elements
local turfColShapes = {} -- table of colShape elements
local dataFile = "turfs.json"

-- Check if a point is inside a polygon (ray casting algorithm)
function isPointInPolygon(x, y, polygon)
    local inside = false
    local n = #polygon
    for i = 1, n do
        local j = (i % n) + 1
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
    end
    return inside
end

-- Calculate bounding box of a polygon
function getPolygonBounds(polygon)
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for _, corner in ipairs(polygon) do
        if corner.x < minX then minX = corner.x end
        if corner.x > maxX then maxX = corner.x end
        if corner.y < minY then minY = corner.y end
        if corner.y > maxY then maxY = corner.y end
    end
    return minX, minY, maxX - minX, maxY - minY
end

-- Load turfs from file
function loadTurfs()
    local file = fileOpen(dataFile)
    if file then
        local json = fileRead(file, fileGetSize(file))
        fileClose(file)
        turfs = fromJSON(json) or {}
        -- Make sure all turfs have bounding boxes
        for i, turf in ipairs(turfs) do
            if turf.corners and #turf.corners >= 3 then
                if not turf.x or not turf.y or not turf.width or not turf.height then
                    local bx, by, bw, bh = getPolygonBounds(turf.corners)
                    turf.x = bx
                    turf.y = by
                    turf.width = bw
                    turf.height = bh
                end
            end
        end
        saveTurfs() -- resave to fix any missing bounding boxes
        outputDebugString("[TurfWar] Loaded " .. #turfs .. " turfs from file!", 3)
    else
        outputDebugString("[TurfWar] No turfs file found, creating default turfs!", 3)
        -- Generate 50+ turfs in Las Venturas (grid)
        local turfWidth = 150
        local turfHeight = 150
        local startX = 1600
        local startY = 1600
        local turfNames = {
            "LV Airport", "The Strip", "Caligulas Palace", "Four Dragons",
            "Emerald Isle", "Pirates Rest", "Come-A-Lot", "Madd Dogg's",
            "Old Venturas", "Rodeo LV", "Glen Park LV", "Temple LV",
            "El Corona LV", "Verdant Bluffs LV", "Jefferson LV", "Idlewood LV",
            "Willowfield LV", "Los Flores LV", "East Beach LV", "Santa Maria LV",
            "Market LV", "Mulholland LV", "Marina LV", "Temple Drive LV",
            "Rodeo Drive LV", "Vinewood LV", "Sunset Strip LV", "Downtown LV",
            "Las Venturas Stadium", "LVPD Station", "Hospital LV", "Fire Station LV",
            "LV Docks", "Warehouse District LV", "Industrial LV", "Commercial LV",
            "Residential LV", "Park LV", "Golf Course LV", "Race Track LV",
            "Airport Hangars LV", "Military Base LV", "Power Plant LV", "Water Treatment LV",
            "Junkyard LV", "Quarry LV", "Farm LV", "Ranch LV", "Vineyard LV"
        }
        
        local nameIndex = 1
        for row = 0, 7 do
            for col = 0, 6 do
                local x = startX + col * turfWidth
                local y = startY + row * turfHeight
                local name = turfNames[nameIndex] or ("Turf LV " .. nameIndex)
                table.insert(turfs, {
                    name = name,
                    x = x,
                    y = y,
                    width = turfWidth,
                    height = turfHeight,
                    owner = nil,
                    progress = 0
                })
                nameIndex = nameIndex + 1
                if nameIndex > 50 then break end
            end
            if nameIndex > 50 then break end
        end
        
        -- Save initial turfs
        saveTurfs()
    end
end

-- Save turfs to file (only serializable data, no userdata!)
function saveTurfs()
    local file = fileCreate(dataFile)
    if file then
        -- Create a copy without userdata
        local toSave = {}
        for i, turf in ipairs(turfs) do
            table.insert(toSave, {
                name = turf.name,
                x = turf.x,
                y = turf.y,
                width = turf.width,
                height = turf.height,
                owner = turf.owner,
                progress = turf.progress,
                corners = turf.corners
            })
        end
        fileWrite(file, toJSON(toSave))
        fileClose(file)
        outputDebugString("[TurfWar] Saved " .. #toSave .. " turfs to file!", 3)
    end
end

-- Helper: Get or create team
function getOrCreateTeam(gangName)
    outputDebugString("[TurfWar] getOrCreateTeam called for " .. tostring(gangName), 3)
    
    for _, team in ipairs(getElementsByType("team")) do
        if getTeamName(team) == gangName then
            outputDebugString("[TurfWar] Found existing team " .. gangName, 3)
            return team
        end
    end
    
    if not gangColors[gangName] then
        outputDebugString("[TurfWar] No color found for gang " .. gangName .. "! Using white.", 2)
        gangColors[gangName] = {255, 255, 255}
    end
    
    local team = createTeam(gangName, gangColors[gangName][1], gangColors[gangName][2], gangColors[gangName][3])
    if isElement(team) then
        outputDebugString("[TurfWar] Created new team " .. gangName .. "!", 3)
    else
        outputDebugString("[TurfWar] Failed to create team " .. gangName .. "!", 1)
    end
    return team
end

-- Helper: Hex to RGB
function hexToRGB(hex)
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return false end
    
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    
    return r, g, b
end

-- Prompt 1: Join Gang
function joinGang(gangName, playerOverride)
    local player = playerOverride or source
    if not isElement(player) then 
        outputDebugString("[TurfWar] joinGang called with invalid player!", 1)
        return 
    end
    
    outputDebugString("[TurfWar] joinGang called for " .. getPlayerName(player) .. " to join " .. tostring(gangName), 3)
    
    local team = getOrCreateTeam(gangName)
    if not isElement(team) then
        outputDebugString("[TurfWar] Failed to get/create team " .. tostring(gangName), 1)
        return
    end
    
    local success = setPlayerTeam(player, team)
    if success then
        setElementData(player, "gangName", gangName) -- Add element data for quick check
        outputChatBox("You have joined " .. gangName .. "!", player, 0, 255, 0)
        outputDebugString("[TurfWar] Successfully set player " .. getPlayerName(player) .. " to team " .. getTeamName(team), 3)
    else
        outputChatBox("Failed to join " .. gangName .. "!", player, 255, 0, 0)
        outputDebugString("[TurfWar] Failed to set player " .. getPlayerName(player) .. " to team " .. getTeamName(team), 1)
    end
end
addEvent("turfwar:joinGang", true)
addEventHandler("turfwar:joinGang", root, function(gangName)
    joinGang(gangName, source)
end)

-- Prompt 2: /groupturfcolor command
function setGangColor(player, cmd, hex)
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
    if not r then
        outputChatBox("Invalid hex color!", player, 255, 0, 0)
        return
    end
    
    local gangName = getTeamName(team)
    gangColors[gangName] = {r, g, b}
    setTeamColor(team, r, g, b)
    
    -- Update existing radar areas for this gang
    for i, turf in ipairs(turfs) do
        if turf.owner == gangName and turfRadarAreas[i] and isElement(turfRadarAreas[i]) then
            setRadarAreaColor(turfRadarAreas[i], r, g, b, 175)
        end
    end
    
    outputChatBox("Gang color updated to " .. hex .. "!", player, 0, 255, 0)
end
addCommandHandler("groupturfcolor", setGangColor)

-- Test command: /testjoin <Mouri/Evil>
addCommandHandler("testjoin", function(player, cmd, gangName)
    if not isElement(player) then return end
    if not gangName then
        outputChatBox("Usage: /testjoin <Mouri/Evil>", player, 255, 0, 0)
        return
    end
    outputDebugString("[TurfWar] /testjoin called by " .. getPlayerName(player) .. " for " .. gangName, 3)
    joinGang(gangName) -- Directly call the function!
end)

-- Command: /saveturf <name> - save current position as a new turf
addCommandHandler("saveturf", function(player, cmd, name)
    if not isElement(player) then return end
    
    if not name or name == "" then
        outputChatBox("Usage: /saveturf <turf name>", player, 255, 0, 0)
        return
    end
    
    local x, y, z = getElementPosition(player)
    local turfWidth = 150
    local turfHeight = 150
    -- Center turf on player position
    x = x - turfWidth / 2
    y = y - turfHeight / 2
    
    local newTurf = {
        name = name,
        x = x,
        y = y,
        width = turfWidth,
        height = turfHeight,
        owner = nil,
        progress = 0
    }
    table.insert(turfs, newTurf)
    
    -- Create col shape and radar area immediately
    local i = #turfs
    turfColShapes[i] = createColRectangle(x, y, turfWidth, turfHeight)
    setElementData(turfColShapes[i], "turfIndex", i)
    
    turfRadarAreas[i] = createRadarArea(x, y, turfWidth, turfHeight, 127, 127, 127, 175)
    
    saveTurfs()
    outputChatBox("Created new turf: " .. name .. "!", player, 0, 255, 0)
end)

-- Handle custom turf creation from client
addEvent("turfwar:createCustomTurf", true)
addEventHandler("turfwar:createCustomTurf", root, function(name, corners)
    local player = source
    if not isElement(player) then return end
    if not name or name == "" or not corners or #corners < 3 then
        outputChatBox("[TurfWar] Invalid custom turf!", player, 255, 0, 0)
        return
    end
    
    local newTurf = {
        name = name,
        corners = corners,
        owner = nil,
        progress = 0
    }
    
    table.insert(turfs, newTurf)
    local i = #turfs
    
    -- Calculate bounding box for col shape and radar area
    local bx, by, bw, bh = getPolygonBounds(corners)
    newTurf.x = bx
    newTurf.y = by
    newTurf.width = bw
    newTurf.height = bh
    
    -- Create col shape and radar area immediately
    turfColShapes[i] = createColRectangle(bx, by, bw, bh)
    setElementData(turfColShapes[i], "turfIndex", i)
    
    turfRadarAreas[i] = createRadarArea(bx, by, bw, bh, 127, 127, 127, 175)
    
    saveTurfs()
    outputChatBox("[TurfWar] Custom turf '" .. name .. "' created!", player, 0, 255, 0)
    outputDebugString("[TurfWar] Created custom turf " .. name .. " at (" .. bx .. "," .. by .. ") size " .. bw .. "x" .. bh, 3)
end)

-- Prompt 3: Turf Control Engine
function initTurfs()
    loadTurfs()
    for i, turf in ipairs(turfs) do
        -- Make sure we have bounding box
        if turf.corners and #turf.corners >= 3 then
            if not turf.x or not turf.y or not turf.width or not turf.height then
                local bx, by, bw, bh = getPolygonBounds(turf.corners)
                turf.x = bx
                turf.y = by
                turf.width = bw
                turf.height = bh
                saveTurfs()
            end
        end
        
        -- Create radar area
        if not turfRadarAreas[i] or not isElement(turfRadarAreas[i]) then
            if turf.x and turf.y and turf.width and turf.height then
                local r, g, b = 127, 127, 127
                if turf.owner == "Mouri" then
                    r, g, b = unpack(gangColors["Mouri"])
                elseif turf.owner == "Evil" then
                    r, g, b = unpack(gangColors["Evil"])
                end
                turfRadarAreas[i] = createRadarArea(turf.x, turf.y, turf.width, turf.height, r, g, b, 175)
                outputDebugString("[TurfWar] Created radar area for " .. tostring(turf.name), 3)
            end
        end
        
        -- Create col shape
        if not turfColShapes[i] or not isElement(turfColShapes[i]) then
            if turf.x and turf.y and turf.width and turf.height then
                turfColShapes[i] = createColRectangle(turf.x, turf.y, turf.width, turf.height)
                setElementData(turfColShapes[i], "turfIndex", i)
                outputDebugString("[TurfWar] Created col shape for " .. tostring(turf.name), 3)
            end
        end
    end
end
addEventHandler("onResourceStart", resourceRoot, initTurfs)

-- Send player's current turf and all turfs to client
function sendTurfUpdates()
    local turfsData = {}
    for i, turf in ipairs(turfs) do
        local tData = {
            name = turf.name,
            owner = turf.owner,
            progress = turf.progress
        }
        if turf.corners then
            tData.corners = turf.corners
        end
        if turf.x and turf.y and turf.width and turf.height then
            tData.x = turf.x
            tData.y = turf.y
            tData.width = turf.width
            tData.height = turf.height
        end
        table.insert(turfsData, tData)
    end
    
    for _, player in ipairs(getElementsByType("player")) do
        local playerTurf = nil
        local px, py = getElementPosition(player)
        
        for i, turf in ipairs(turfs) do
            local inTurf = false
            if turf.corners and #turf.corners >= 3 then
                inTurf = isPointInPolygon(px, py, turf.corners)
            elseif turfColShapes[i] and isElement(turfColShapes[i]) and isElementWithinColShape(player, turfColShapes[i]) then
                inTurf = true
            end
            
            if inTurf then
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
    for i, turf in ipairs(turfs) do
        -- Count players inside, grouped by team
        local teamCounts = {}
        local playersInside = 0
        
        outputDebugString("[TurfWar] Checking turf " .. tostring(turf.name), 3)
        
        for _, player in ipairs(getElementsByType("player")) do
            if isElement(player) then
                local px, py, pz = getElementPosition(player)
                local inTurf = false
                
                if turf.corners and #turf.corners >= 3 then
                    inTurf = isPointInPolygon(px, py, turf.corners)
                    if inTurf then
                        outputDebugString("[TurfWar] " .. getPlayerName(player) .. " inside " .. tostring(turf.name) .. " via polygon", 3)
                    end
                elseif turfColShapes[i] and isElement(turfColShapes[i]) and isElementWithinColShape(player, turfColShapes[i]) then
                    inTurf = true
                    outputDebugString("[TurfWar] " .. getPlayerName(player) .. " inside " .. tostring(turf.name) .. " via col shape", 3)
                end
                
                if inTurf then
                    playersInside = playersInside + 1
                    local team = getPlayerTeam(player)
                    local teamName = nil
                    if team then
                        teamName = getTeamName(team)
                    else
                        teamName = getElementData(player, "gangName") -- Fallback to element data
                    end
                    
                    if teamName then
                        teamCounts[teamName] = (teamCounts[teamName] or 0) + 1
                        outputDebugString("[TurfWar] Player in team " .. teamName, 3)
                    else
                        outputDebugString("[TurfWar] Player not in a team!", 3)
                        outputChatBox("[TurfWar] You must join a team with /group to capture turfs!", player, 255, 0, 0)
                    end
                end
            end
        end
        
        if playersInside > 0 then
            outputDebugString("[TurfWar] Turf " .. tostring(turf.name) .. " has " .. playersInside .. " players inside", 3)
            for k,v in pairs(teamCounts) do
                outputDebugString("[TurfWar] - " .. k .. ": " .. v, 3)
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
        
        outputDebugString("[TurfWar] Dominant team: " .. tostring(dominantTeam) .. " with " .. maxCount, 3)
        
        -- Update progress
        if dominantTeam then
            if turf.owner == nil then
                -- Unowned turf: increase progress by 1% per member
                turf.progress = math.min(100, turf.progress + maxCount)
                if turf.progress >= 51 then
                    -- Capture!
                    turf.owner = dominantTeam
                    local r, g, b = unpack(gangColors[dominantTeam] or {255, 255, 255})
                    if turfRadarAreas[i] and isElement(turfRadarAreas[i]) then
                        setRadarAreaColor(turfRadarAreas[i], r, g, b, 175)
                    end
                    outputChatBox(dominantTeam .. " has captured " .. turf.name .. "!", root, 255, 255, 0)
                    saveTurfs()
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
                    if turfRadarAreas[i] and isElement(turfRadarAreas[i]) then
                        setRadarAreaColor(turfRadarAreas[i], r, g, b, 175)
                    end
                    outputChatBox(dominantTeam .. " has captured " .. turf.name .. "!", root, 255, 255, 0)
                    saveTurfs()
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
    end
end
setTimer(processTurfProgress, 10000, 0)

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

outputDebugString("[TurfWar] Server script loaded!", 3)
