local currentTurf = nil
local lastUpdate = 0
local groupMenu = nil
local allTurfs = {}

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
end

-- Convert world coordinates to screen coordinates
function worldToScreen(x, y, z)
    local sx, sy = getScreenFromWorldPosition(x, y, z)
    return sx, sy
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
        if turf.x and turf.y and turf.width and turf.height then
            -- Convert turf coordinates to radar coordinates
            local x1 = radarX + (turf.x - minX) * mapScale
            local y1 = radarY + (turf.y - minY) * mapScale
            local x2 = x1 + turf.width * mapScale
            local y2 = y1 + turf.height * mapScale
            
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
            
            -- Draw turf on radar
            dxDrawRectangle(x1, y1, x2 - x1, y2 - y1, tocolor(r, g, b, a))
        end
    end
end

addEventHandler("onClientRender", root, function()
    drawTurfInfo()
    drawTurfs()
end)

addEvent("turfwar:sendPlayerTurf", true)
addEventHandler("turfwar:sendPlayerTurf", root, function(turf)
    currentTurf = turf
end)
