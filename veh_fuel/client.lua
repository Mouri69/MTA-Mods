-- client.lua
-- Vehicle fuel HUD and fuel marker interaction.

local showHUD = true
local holdingRefill = false
local refillHoldTime = 0
local REFILL_HOLD_DURATION = 1000

local function getVehicleFuelPercent(vehicle)
    if not isElement(vehicle) then return 0 end
    local fuel = getElementData(vehicle, "fuel") or 0
    if fuel < 0 then fuel = 0 end
    if fuel > 120 then fuel = 120 end
    return fuel
end

local function drawVehicleFuelHUD()
    if not showHUD then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return end

    local sw, sh = guiGetScreenSize()
    local boxW, boxH = 175, 35
    local padding = 12
    local x = sw - boxW - padding - 140
    local y = sh - boxH - padding

    local fuel = getVehicleFuelPercent(veh)

    dxDrawRectangle(x, y, boxW, boxH, tocolor(0, 0, 0, 150))

    local labelText = "Fuel: " .. tostring(fuel) .. " / 120"
    local barX, barY = x + 8, y + 10
    local barW, barH = 160, 15
    dxDrawRectangle(barX, barY, barW, barH, tocolor(40, 40, 40, 200))

    local fillW = math.floor((fuel / 120) * barW)
    local r, g, b = 255, 160, 0
    if fuel > 80 then r, g, b = 0, 200, 0
    elseif fuel <= 30 then r, g, b = 200, 0, 0 end
    dxDrawRectangle(barX, barY, fillW, barH, tocolor(r, g, b, 220))

    dxDrawText(labelText, barX + 1, barY + 1, barX + barW + 1, barY + barH + 1, tocolor(0, 0, 0, 200), 1, "default-bold", "center", "center", false, false, true)
    dxDrawText(labelText, barX, barY, barX + barW, barY + barH, tocolor(255, 255, 255, 240), 1, "default-bold", "center", "center", false, false, true)
end

local function drawFuelMarkerPrompt()
    local marker = getNearbyFuelMarker()
    local veh = getPedOccupiedVehicle(localPlayer)
    if marker and veh then
        local sw, sh = guiGetScreenSize()
        local prompt = 'Hold "SPACE" to refuel the vehicle'
        dxDrawText(prompt, 0, sh - 50, sw, sh - 30, tocolor(255, 255, 255, 220), 1, "default-bold", "center", "top", false, false, true)
    end
end

local function getNearbyFuelMarker()
    local veh = getPedOccupiedVehicle(localPlayer)
    for _, marker in ipairs(getElementsByType("marker")) do
        if getElementData(marker, "isFuelMarker") then
            if isElement(veh) and isElementWithinMarker(veh, marker) then
                return marker
            elseif isElementWithinMarker(localPlayer, marker) then
                return marker
            end
        end
    end
    return false
end

local function updateRefillHoldState(deltaTime)
    local marker = getNearbyFuelMarker()
    if marker and isPedInVehicle(localPlayer) then
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then
            if isControlPressed("space") then
                if not holdingRefill then
                    holdingRefill = true
                    refillHoldTime = 0
                end
                refillHoldTime = refillHoldTime + deltaTime
                local pct = math.min(100, math.floor((refillHoldTime / REFILL_HOLD_DURATION) * 100))
                local fuel = getVehicleFuelPercent(veh)
                local label = string.format("Refilling... %d%%", pct)
                local sw, sh = guiGetScreenSize()
                dxDrawText(label, 0, sh - 80, sw, sh - 60, tocolor(255, 255, 255, 250), 1.2, "default-bold", "center", "top", false, false, true)
                if refillHoldTime >= REFILL_HOLD_DURATION then
                    setElementData(veh, "fuel", 120)
                    triggerServerEvent("veh_fuel:requestRefill", resourceRoot, veh)
                    holdingRefill = false
                    refillHoldTime = 0
                end
                return
            end
        end
    end
    holdingRefill = false
    refillHoldTime = 0
end

local lastTick = getTickCount()

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local delta = now - lastTick
    lastTick = now
    drawVehicleFuelHUD()
    drawFuelMarkerPrompt()
    updateRefillHoldState(delta)
end)

addCommandHandler("togglevehhud", function()
    showHUD = not showHUD
    outputChatBox("Vehicle HUD " .. (showHUD and "enabled" or "disabled"))
end)

-- Sync server fuel data to client periodically and on vehicle entry
local function requestFuelSync()
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh then
        triggerServerEvent("veh_fuel:requestFuelSync", resourceRoot, veh)
    end
end

addEvent("veh_fuel:updateFuel", true)
addEventHandler("veh_fuel:updateFuel", root, function(fuel)
    if type(fuel) == "number" then
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then
            setElementData(veh, "fuel", fuel)
        end
    end
end)

addEventHandler("onClientVehicleEnter", root, function(player)
    if player == localPlayer then
        requestFuelSync()
    end
end)

setTimer(requestFuelSync, 3000, 0)
