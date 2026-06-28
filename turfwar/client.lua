local currentTurf = nil
local lastUpdate = 0
local groupMenu = nil
local allTurfs = {}
local isDrawing = false
local turfCorners = {}
local turfMarkers = {}

-- Start drawing a turf
addCommandHandler("startdrawturf", function()
    isDrawing = true
    turfCorners = {}
    for _, marker in ipairs(turfMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    turfMarkers = {}
    outputChatBox("[TurfWar] Drawing mode enabled! Click to mark corners (at least 3)!", 0, 255, 0)
end)

-- Cancel drawing
addCommandHandler("canceldrawturf", function()
    isDrawing = false
    for _, marker in ipairs(turfMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    turfMarkers = {}
    turfCorners = {}
    outputChatBox("[TurfWar] Drawing cancelled!", 255, 255, 0)
end)

-- End drawing and send to server
addCommandHandler("enddrawturf", function(cmd, name)
    if not isDrawing then
        outputChatBox("[TurfWar] Use /startdrawturf first!", 255, 0, 0)
        return
    end
    if #turfCorners < 3 then
        outputChatBox("[TurfWar] Need at least 3 corners!", 255, 0, 0)
        return
    end
    if not name or name == "" then
        outputChatBox("[TurfWar] Usage: /enddrawturf <turf name>", 255, 0, 0)
        return
    end
    
    triggerServerEvent("turfwar:createCustomTurf", localPlayer, name, turfCorners)
    isDrawing = false
    for _, marker in ipairs(turfMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    turfMarkers = {}
    turfCorners = {}
end)

-- Add corner on key press (use M key)
bindKey("m", "down", function()
    if isDrawing then
        local x, y, z = getElementPosition(localPlayer)
        z = z - 0.5 -- place marker on ground
        table.insert(turfCorners, {x = x, y = y})
        local marker = createMarker(x, y, z, "corona", 2, 255, 0, 0, 175)
        table.insert(turfMarkers, marker)
        outputChatBox("[TurfWar] Corner " .. #turfCorners .. " marked! (total: " .. #turfCorners .. ")", 0, 255, 255)
    end
end)

-- Draw preview of the turf being drawn
function drawTurfPreview()
    if isDrawing and #turfCorners >= 2 then
        for i = 1, #turfCorners do
            local c1 = turfCorners[i]
            local c2 = turfCorners[(i % #turfCorners) + 1]
            
            local z1 = getGroundPosition(c1.x, c1.y)
            local z2 = getGroundPosition(c2.x, c2.y)
            
            -- Draw lines between consecutive corners
            dxDrawLine3D(c1.x, c1.y, z1 + 1, c2.x, c2.y, z2 + 1, tocolor(255, 0, 0, 255), 5)
        end
    end
end

-- Receive all turfs from server
addEvent("turfwar:sendAllTurfs", true)
addEventHandler("turfwar:sendAllTurfs", root, function(turfs)
    allTurfs = turfs
end)

-- Open group menu with /group
function openGroupMenu()
    if groupMenu and isElement(groupMenu) then
        destroyElement(groupMenu)
        groupMenu = nil
        showCursor(false)
        return
    end
    
    showCursor(true)
    
    local screenW, screenH = guiGetScreenSize()
    groupMenu = guiCreateWindow(screenW/2 - 150, screenH/2 - 150, 300, 300, "Turf War - Group Menu", false)
    
    -- Join Mouri
    local joinMouriBtn = guiCreateButton(10, 30, 280, 40, "Join Mouri", false, groupMenu)
    addEventHandler("onClientGUIClick", joinMouriBtn, function()
        triggerServerEvent("turfwar:joinGang", localPlayer, "Mouri")
    end, false)
    
    -- Join Evil
    local joinEvilBtn = guiCreateButton(10, 80, 280, 40, "Join Evil", false, groupMenu)
    addEventHandler("onClientGUIClick", joinEvilBtn, function()
        triggerServerEvent("turfwar:joinGang", localPlayer, "Evil")
    end, false)
    
    -- Close button
    local closeBtn = guiCreateButton(10, 250, 280, 40, "Close", false, groupMenu)
    addEventHandler("onClientGUIClick", closeBtn, function()
        destroyElement(groupMenu)
        groupMenu = nil
        showCursor(false)
    end, false)
end
addCommandHandler("group", openGroupMenu)

function drawTurfInfo()
    local now = getTickCount()
    if now - lastUpdate > 500 then
        -- Don't trigger the event every frame, just use currentTurf
        lastUpdate = now
    end
    
    if currentTurf then
        local screenW, screenH = guiGetScreenSize()
        local x = screenW - 250
        local y = 100
        
        -- Background
        dxDrawRectangle(x, y, 240, 120, tocolor(0, 0, 0, 180))
        
        -- Turf name
        dxDrawText("Current Turf: " .. currentTurf.name, x + 10, y + 10, x + 230, y + 30, tocolor(255, 255, 255, 255), 1, "default-bold", "left", "top")
        
        -- Owner
        local ownerText = currentTurf.owner and ("Owner: " .. currentTurf.owner) or "Owner: Unowned"
        dxDrawText(ownerText, x + 10, y + 40, x + 230, y + 60, tocolor(255, 255, 255, 255), 1, "default", "left", "top")
        
        -- Progress
        dxDrawText("Progress: " .. math.floor(currentTurf.progress) .. "%", x + 10, y + 70, x + 230, y + 90, tocolor(255, 255, 255, 255), 1, "default", "left", "top")
        
        -- Progress bar
        dxDrawRectangle(x + 10, y + 95, 220, 15, tocolor(50, 50, 50, 200))
        local progressColor
        if currentTurf.owner then
            progressColor = tocolor(0, 255, 0, 200)
        else
            progressColor = tocolor(255, 200, 0, 200)
        end
        dxDrawRectangle(x + 10, y + 95, (currentTurf.progress / 100) * 220, 15, progressColor)
    end
    
    if isDrawing then
        local screenW, screenH = guiGetScreenSize()
        dxDrawRectangle(20, 20, 300, 70, tocolor(0, 0, 0, 200))
        dxDrawText("DRAWING TURF MODE!", 30, 30, 320, 50, tocolor(255, 0, 0, 255), 1.5, "default-bold", "left", "top")
        dxDrawText("Corners: " .. #turfCorners .. "/3+ - Press M to add corner!", 30, 55, 320, 75, tocolor(255, 255, 255, 255), 1, "default", "left", "top")
    end
end

-- Draw turfs on the map
function drawTurfs()
    local isRadarVisible = isPlayerHudComponentVisible("radar")
    if not isRadarVisible then return end
    
    local screenW, screenH = guiGetScreenSize()
    local radarSize = 256 -- Default radar size
    local radarX = screenW - radarSize - 20
    local radarY = screenH - radarSize - 20
    local minX, minY = -3000, -3000
    local maxX, maxY = 3000, 3000
    local mapScale = radarSize / (maxX - minX)
    
    for i, turf in ipairs(allTurfs) do
        -- Get color based on owner and progress
        local r, g, b, a = 127, 127, 127, 175
        if turf.owner == "Mouri" then
            r, g, b = 255, 0, 0
        elseif turf.owner == "Evil" then
            r, g, b = 0, 0, 255
        end
        
        -- Flash if progress is between 30-50%
        if turf.progress >= 30 and turf.progress <= 50 then
            local flashSpeed = 500 -- ms
            local flashAlpha = math.sin(getTickCount() / flashSpeed) * 127 + 128
            a = flashAlpha
        end
        
        -- Draw custom turf or rectangle turf
        if turf.x and turf.y and turf.width and turf.height then
            -- Draw bounding box always for visibility
            local x1 = radarX + (turf.x - minX) * mapScale
            local y1 = radarY + (turf.y - minY) * mapScale
            local x2 = x1 + turf.width * mapScale
            local y2 = y1 + turf.height * mapScale
            dxDrawRectangle(x1, y1, x2 - x1, y2 - y1, tocolor(r, g, b, a * 0.7))
        end
        
        if turf.corners and #turf.corners >=3 then
            -- Also draw the custom polygon on top
            local corners = {}
            for _, corner in ipairs(turf.corners) do
                local sx = radarX + (corner.x - minX) * mapScale
                local sy = radarY + (corner.y - minY) * mapScale
                table.insert(corners, sx)
                table.insert(corners, sy)
            end
            if #corners >=6 then
                dxDrawPolygon(unpack(corners), tocolor(r, g, b, a))
            end
        end
    end
end

addEventHandler("onClientRender", root, function()
    drawTurfInfo()
    drawTurfs()
    drawTurfPreview()
end)

addEvent("turfwar:sendPlayerTurf", true)
addEventHandler("turfwar:sendPlayerTurf", root, function(turf)
    currentTurf = turf
end)
