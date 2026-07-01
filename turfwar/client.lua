local currentTurf = nil
local allTurfs = {}

-- Drawing variables
local isDrawingTurf = false
local drawnCorners = {}
local helpText = ""

-- Start drawing turf
addCommandHandler("startdrawturf", function()
    isDrawingTurf = true
    drawnCorners = {}
    helpText = "Walk to a corner and press 'M' to add it. When done, use /enddrawturf <name>"
    outputChatBox("[TurfWar] Started drawing a custom turf! Walk to each corner and press M!", 0, 255, 0)
end)

-- End drawing turf
addCommandHandler("enddrawturf", function(cmd, name)
    if not isDrawingTurf then
        outputChatBox("You are not currently drawing a turf! Use /startdrawturf first!", 255, 0, 0)
        return
    end
    
    if #drawnCorners < 3 then
        outputChatBox("You need at least 3 corners to make a turf! Add more with M!", 255, 0, 0)
        return
    end
    
    if not name or name == "" then
        outputChatBox("Usage: /enddrawturf <turf name>", 255, 0, 0)
        return
    end
    
    -- Send corners to server
    triggerServerEvent("turfwar:createCustomTurf", resourceRoot, name, drawnCorners)
    
    -- Stop drawing
    isDrawingTurf = false
    drawnCorners = {}
    helpText = ""
end)

-- M key to add corner
bindKey("m", "down", function()
    if not isDrawingTurf then return end
    
    local x, y, z = getElementPosition(localPlayer)
    table.insert(drawnCorners, {x = x, y = y})
    outputChatBox("[TurfWar] Added corner " .. #drawnCorners .. " at (" .. math.floor(x) .. ", " .. math.floor(y) .. ")", 0, 255, 0)
end)

-- Draw turf preview when drawing
addEventHandler("onClientRender", root, function()
    if isDrawingTurf and #drawnCorners > 1 then
        -- Draw lines between corners
        for i = 1, #drawnCorners do
            local j = i % #drawnCorners + 1
            local x1, y1 = drawnCorners[i].x, drawnCorners[i].y
            local x2, y2 = drawnCorners[j].x, drawnCorners[j].y
            dxDrawLine3D(x1, y1, 10, x2, y2, 10, tocolor(0, 255, 0, 255), 3)
        end
    end
    
    if helpText ~= "" then
        dxDrawText(helpText, 0.5, 0.9, 0.5, 0.9, tocolor(255, 255, 255, 255), 1, "default-bold", "center", "bottom")
    end
end)

-- Group menu variables
local groupWindow = nil
local mouriButton = nil
local evilButton = nil
local closeButton = nil

-- Simple group menu (original style)
function openGroupMenu()
    if groupWindow and isElement(groupWindow) then return end
    
    groupWindow = guiCreateWindow(0.4, 0.35, 0.2, 0.3, "Join a Gang", true)
    mouriButton = guiCreateButton(0.1, 0.2, 0.8, 0.2, "Join Mouri", true, groupWindow)
    evilButton = guiCreateButton(0.1, 0.45, 0.8, 0.2, "Join Evil", true, groupWindow)
    closeButton = guiCreateButton(0.1, 0.75, 0.8, 0.2, "Close", true, groupWindow)
    
    -- Show cursor
    showCursor(true)
    
    addEventHandler("onClientGUIClick", mouriButton, function(button, state)
        if button == "left" and state == "up" then
            outputChatBox("[TurfWar] Attempting to join Mouri...", 0, 255, 0)
            outputDebugString("[TurfWar] (Client) Mouri button clicked! Triggering turfwar:joinGang with 'Mouri'", 3)
            triggerServerEvent("turfwar:joinGang", root, "Mouri")
            closeGroupMenu()
        end
    end, false)
    
    addEventHandler("onClientGUIClick", evilButton, function(button, state)
        if button == "left" and state == "up" then
            outputChatBox("[TurfWar] Attempting to join Evil...", 0, 255, 0)
            outputDebugString("[TurfWar] (Client) Evil button clicked! Triggering turfwar:joinGang with 'Evil'", 3)
            triggerServerEvent("turfwar:joinGang", root, "Evil")
            closeGroupMenu()
        end
    end, false)
    
    addEventHandler("onClientGUIClick", closeButton, closeGroupMenu, false)
end

function closeGroupMenu()
    if groupWindow and isElement(groupWindow) then
        destroyElement(groupWindow)
        groupWindow = nil
    end
    showCursor(false)
end

-- /group command to open menu
addCommandHandler("group", openGroupMenu)

-- Draw turf info on screen
addEventHandler("onClientRender", root, function()
    if currentTurf then
        local screenW, screenH = guiGetScreenSize()
        local x = screenW * 0.9
        local y = screenH * 0.85
        
        -- Draw turf name
        dxDrawText(currentTurf.name, x - 100, y, x + 100, y, tocolor(255, 255, 255, 255), 1.2, "default-bold", "center", "top")
        
        -- Draw owner
        local ownerText = "Unowned"
        local ownerColor = tocolor(200, 200, 200, 255) -- Lighter gray for readability
        if currentTurf.owner == "Mouri" then
            ownerText = "Owned by Mouri"
            ownerColor = tocolor(255, 0, 0, 255)
        elseif currentTurf.owner == "Evil" then
            ownerText = "Owned by Evil"
            ownerColor = tocolor(0, 0, 255, 255)
        end
        
        y = y + 25
        dxDrawText(ownerText, x - 100, y, x + 100, y, ownerColor, 1, "default", "center", "top")
        
        -- Draw progress bar
        y = y + 25
        local barWidth = 200
        local barHeight = 20
        local barX = x - barWidth / 2
        local barY = y
        
        -- Background
        dxDrawRectangle(barX, barY, barWidth, barHeight, tocolor(0, 0, 0, 127))
        
        -- Progress
        local progressWidth = (currentTurf.progress / 100) * barWidth
        dxDrawRectangle(barX, barY, progressWidth, barHeight, ownerColor)
        
        -- Progress text (in white for contrast
        dxDrawText(currentTurf.progress .. "%", barX, barY, barX + barWidth, barY + barHeight, tocolor(255, 255, 255, 255), 1, "default", "center", "center")
    end
end)

-- Draw turfs on both radar and F11 map
function drawTurfs()
    if #allTurfs == 0 then return end
    
    local screenW, screenH = guiGetScreenSize()
    local isRadarVisible = isPlayerHudComponentVisible("radar")
    local isBigMapVisible = false
    
    -- Check if F11 map is visible (check if camera is really high
    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
    if camZ > 1000 then
        isBigMapVisible = true
    end
    
    if isRadarVisible then
        -- Draw on radar
        local radarSize = 256
        local radarX = screenW - radarSize - 20
        local radarY = screenH - radarSize - 20
        local minX, minY = -3000, -3000
        local maxX, maxY = 3000, 3000
        local mapScale = radarSize / (maxX - minX)
        
        for i, turf in ipairs(allTurfs) do
            local r, g, b, a = 127, 127, 127, 175
            if turf.owner == "Mouri" then
                r, g, b = 255, 0, 0
            elseif turf.owner == "Evil" then
                r, g, b = 0, 0, 255
            end
            
            -- Flash if progress between 30-50%
            if turf.progress and turf.progress >= 30 and turf.progress <= 50 then
                a = math.sin(getTickCount() / 200) * 127 + 128
            end
            
            -- Draw bounding box
            if turf.x and turf.y and turf.width and turf.height then
                local x1 = radarX + (turf.x - minX) * mapScale
                local y1 = radarY + (turf.y - minY) * mapScale
                local x2 = x1 + turf.width * mapScale
                local y2 = y1 + turf.height * mapScale
                dxDrawRectangle(x1, y1, x2 - x1, y2 - y1, tocolor(r, g, b, a * 0.7))
            end
            
            -- Draw custom polygon if present
            if turf.corners and #turf.corners >= 3 then
                local corners = {}
                for _, corner in ipairs(turf.corners) do
                    local sx = radarX + (corner.x - minX) * mapScale
                    local sy = radarY + (corner.y - minY) * mapScale
                    table.insert(corners, sx)
                    table.insert(corners, sy)
                end
                if #corners >= 6 then
                    dxDrawPolygon(unpack(corners), tocolor(r, g, b, a))
                end
            end
        end
    end
    
    if isBigMapVisible then
        -- Draw on big map (F11)
        local mapWidth = screenW * 0.8
        local mapHeight = screenH * 0.8
        local mapX = (screenW - mapWidth) / 2
        local mapY = (screenH - mapHeight) / 2
        local minX, minY = -3000, -3000
        local maxX, maxY = 3000, 3000
        local mapScale = mapWidth / (maxX - minX)
        
        for i, turf in ipairs(allTurfs) do
            local r, g, b, a = 127, 127, 127, 200
            if turf.owner == "Mouri" then
                r, g, b = 255, 0, 0
            elseif turf.owner == "Evil" then
                r, g, b = 0, 0, 255
            end
            
            -- Flash if progress between 30-50%
            if turf.progress and turf.progress >= 30 and turf.progress <= 50 then
                a = math.sin(getTickCount() / 200) * 127 + 128
            end
            
            -- Draw bounding box
            if turf.x and turf.y and turf.width and turf.height then
                local x1 = mapX + (turf.x - minX) * mapScale
                local y1 = mapY + (turf.y - minY) * mapScale
                local x2 = x1 + turf.width * mapScale
                local y2 = y1 + turf.height * mapScale
                dxDrawRectangle(x1, y1, x2 - x1, y2 - y1, tocolor(r, g, b, a * 0.7))
            end
            
            -- Draw custom polygon if present
            if turf.corners and #turf.corners >= 3 then
                local corners = {}
                for _, corner in ipairs(turf.corners) do
                    local sx = mapX + (corner.x - minX) * mapScale
                    local sy = mapY + (corner.y - minY) * mapScale
                    table.insert(corners, sx)
                    table.insert(corners, sy)
                end
                if #corners >= 6 then
                    dxDrawPolygon(unpack(corners), tocolor(r, g, b, a))
                end
            end
        end
    end
end
addEventHandler("onClientRender", root, drawTurfs)

-- Receive updates from server
addEvent("turfwar:sendPlayerTurf", true)
addEventHandler("turfwar:sendPlayerTurf", resourceRoot, function(turf)
    currentTurf = turf
end)

addEvent("turfwar:sendAllTurfs", true)
addEventHandler("turfwar:sendAllTurfs", resourceRoot, function(turfs)
    allTurfs = turfs
end)

outputDebugString("[TurfWar] Client script loaded!", 3)
