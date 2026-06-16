-- client.lua
-- Taxi job UI and interaction.

local jobActive = false
local jobData = {}
local showTaxiSelector = false
local selectedTaxiIndex = 1
local taxiModels = { 426, 427, 429 }

local function drawTaxiSelector()
    if not showTaxiSelector then return end
    local sw, sh = guiGetScreenSize()
    local boxW, boxH = 400, 280
    local x, y = (sw - boxW) / 2, (sh - boxH) / 2

    dxDrawRectangle(x, y, boxW, boxH, tocolor(0, 0, 0, 200))
    dxDrawRectangle(x + 2, y + 2, boxW - 4, 24, tocolor(50, 50, 50, 220))
    dxDrawText("Select Taxi - Press F7 to close", x + 10, y + 2, x + boxW, y + 26, tocolor(255, 255, 255, 240), 1, "default-bold", "left", "center")

    local itemY = y + 32
    for i, model in ipairs(taxiModels) do
local bg = selectedTaxiIndex == i and tocolor(100, 150, 255, 150) or tocolor(30, 30, 30, 200)
        dxDrawRectangle(x + 10, itemY, boxW - 20, 30, bg)
        dxDrawText(i .. ". Taxi Model " .. model, x + 20, itemY, x + boxW - 20, itemY + 30, tocolor(255, 255, 255, 230), 1, "default", "left", "center")
        itemY = itemY + 35
    end

    local spawnBtnY = y + boxH - 40
    dxDrawRectangle(x + 10, spawnBtnY, boxW - 20, 30, tocolor(0, 180, 0, 200))
    dxDrawText("Press ENTER to Spawn", x + 10, spawnBtnY, x + boxW - 10, spawnBtnY + 30, tocolor(255, 255, 255, 240), 1, "default-bold", "center", "center")
end

local function drawJobHUD()
    if not jobActive then return end
    local sw, sh = guiGetScreenSize()
    dxDrawRectangle(10, sh - 150, 350, 140, tocolor(0, 0, 0, 180))

    local level = jobData.level or 0
    local progress = jobData.progress or 0
    local levelConfig = { required = 5, reward = 500 }
    if level == 1 then levelConfig = { required = 15, reward = 1000 }
    elseif level == 2 then levelConfig = { required = 15, reward = 1500 }
    elseif level == 3 then levelConfig = { required = 20, reward = 2000 } end

    dxDrawText("TAXI JOB", 15, sh - 145, 350, sh - 125, tocolor(100, 200, 255, 240), 1, "default-bold", "left", "top")
    dxDrawText("Level: " .. level, 15, sh - 125, 350, sh - 105, tocolor(255, 255, 255, 230), 1, "default", "left", "top")
    dxDrawText("Progress: " .. progress .. "/" .. levelConfig.required, 15, sh - 105, 350, sh - 85, tocolor(255, 255, 255, 230), 1, "default", "left", "top")
    dxDrawText("Reward per trip: $" .. levelConfig.reward, 15, sh - 85, 350, sh - 65, tocolor(0, 255, 100, 230), 1, "default", "left", "top")

    local status = jobData.passengerInTaxi and "Passenger In Taxi" or (jobData.pickupLocation and "Go to pickup" or "Waiting...")
    dxDrawText("Status: " .. status, 15, sh - 65, 350, sh - 45, tocolor(255, 200, 100, 230), 1, "default", "left", "top")
    dxDrawText("Type /stopwork to quit", 15, sh - 45, 350, sh - 15, tocolor(200, 100, 100, 200), 1, "default", "left", "top")
end

addEventHandler("onClientRender", root, function()
    drawTaxiSelector()
    drawJobHUD()
end)

bindKey("F7", "down", function()
    showTaxiSelector = false
    showCursor(false)
end)

bindKey("Up", "down", function()
    if not showTaxiSelector then return end
    selectedTaxiIndex = selectedTaxiIndex - 1
    if selectedTaxiIndex < 1 then selectedTaxiIndex = #taxiModels end
end)

bindKey("Down", "down", function()
    if not showTaxiSelector then return end
    selectedTaxiIndex = selectedTaxiIndex + 1
    if selectedTaxiIndex > #taxiModels then selectedTaxiIndex = 1 end
end)

bindKey("Return", "down", function()
    if not showTaxiSelector then return end
    triggerServerEvent("taxi:startJob", resourceRoot, taxiModels[selectedTaxiIndex])
    showTaxiSelector = false
    showCursor(false)
end)

addEventHandler("onClientMarkerHit", root, function(hitElement, matchingDimension)
    if getElementType(hitElement) ~= "player" then return end
    if hitElement ~= localPlayer then return end

    if getElementData(source, "isTaxiJobMarker") then
        outputChatBox("You are at the Taxi Job marker. Go to the Taxi selector marker.", 0, 255, 0)
    elseif getElementData(source, "isTaxiSelectMarker") then
        if not jobActive then
            selectedTaxiIndex = 1
            showTaxiSelector = true
            showCursor(true)
            outputChatBox("Select a taxi and press ENTER to spawn.", 100, 200, 255)
        end
    end
end)

addEvent("taxi:showSelector", true)
addEventHandler("taxi:showSelector", root, function()
    if not jobActive then
        selectedTaxiIndex = 1
        showTaxiSelector = true
        showCursor(true)
        outputChatBox("Select a taxi model with UP/DOWN, then press ENTER to spawn.", 100, 200, 255)
    end
end)

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not showTaxiSelector then return end
    if button ~= "left" or state ~= "down" then return end

    local sw, sh = guiGetScreenSize()
    local boxW, boxH = 400, 280
    local x, y = (sw - boxW) / 2, (sh - boxH) / 2

    local function inside(rx, ry, rw, rh, mx, my)
        return mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh
    end

    -- check items
    for i, _ in ipairs(taxiModels) do
        local itemY = y + 32 + (i - 1) * 35
        if inside(x + 10, itemY, boxW - 20, 30, absX, absY) then
            selectedTaxiIndex = i
            return
        end
    end

    -- check spawn button
    local spawnBtnY = y + boxH - 40
    if inside(x + 10, spawnBtnY, boxW - 20, 30, absX, absY) then
        triggerServerEvent("taxi:startJob", resourceRoot, taxiModels[selectedTaxiIndex])
        showTaxiSelector = false
        showCursor(false)
        return
    end
end)

addEvent("taxi:updateJob", true)
addEventHandler("taxi:updateJob", root, function(data)
    jobData = data
    jobActive = true
end)

addEvent("taxi:jobStopped", true)
addEventHandler("taxi:jobStopped", root, function()
    jobActive = false
    jobData = {}
end)

setTimer(function()
    if jobActive then
        triggerServerEvent("taxi:checkPickup", resourceRoot)
        triggerServerEvent("taxi:checkDropoff", resourceRoot)
    end
end, 500, 0)
