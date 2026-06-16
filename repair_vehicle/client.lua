-- client.lua
-- Vehicle health HUD shown at the bottom-right when the local player is in a vehicle.

local showHUD = true

local function getVehicleHealthPercent(vehicle)
    if not isElement(vehicle) then return 0 end
    local health = getElementHealth(vehicle) or 0
    local pct = math.floor((health / 1000) * 100 + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct
end

local function drawVehicleHealth()
    if not showHUD then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return end

    local sw, sh = guiGetScreenSize()
    local boxW, boxH = 135, 30
    local padding = 12
    local x = sw - boxW - padding
    local y = sh - boxH - padding

    local pct = getVehicleHealthPercent(veh)

    -- background
    dxDrawRectangle(x, y, boxW, boxH, tocolor(0, 0, 0, 150))

    -- bar background
    local barX, barY = x + 8, y + 6
    local barW, barH = 120, boxH - 12
    dxDrawRectangle(barX, barY, barW, barH, tocolor(40, 40, 40, 200))

    -- bar fill
    local fillW = math.floor((pct / 100) * barW)
    local r, g, b = 200, 0, 0
    if pct > 66 then r, g, b = 0, 200, 0
    elseif pct > 33 then r, g, b = 255, 200, 0 end
    dxDrawRectangle(barX, barY, fillW, barH, tocolor(r, g, b, 220))

    -- draw colored percentage text centered on the bar with a dark outline
    local text = "Vehicle Health: " .. tostring(pct) .. "%"
    local textX1, textY1 = barX, barY
    local textX2, textY2 = barX + barW, barY + barH
    -- outline (drawn slightly offset)
    dxDrawText(text, textX1 + 1, textY1 + 1, textX2 + 1, textY2 + 1, tocolor(0, 0, 0, 200), 1, "default-bold", "center", "center", false, false, true)
    -- white text (always white for readability)
    dxDrawText(text, textX1, textY1, textX2, textY2, tocolor(255, 255, 255, 240), 1, "default-bold", "center", "center", false, false, true)
end

addEventHandler("onClientRender", root, drawVehicleHealth)

addCommandHandler("togglevehhud", function()
    showHUD = not showHUD
    outputChatBox("Vehicle HUD " .. (showHUD and "enabled" or "disabled"))
end)
