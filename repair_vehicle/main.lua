-- repair_vehicle main.lua
-- Creates repair markers and repairs vehicles that pass through them.

local repairMarkers = {}

local function repairVehicle(vehicle, byPlayer)
    if not isElement(vehicle) then return end
    fixVehicle(vehicle)
    local driver = getVehicleController(vehicle)
    local targetPlayer = byPlayer or driver
    if isElement(targetPlayer) and getElementType(targetPlayer) == "player" then
        outputChatBox("Your vehicle has been repaired.", targetPlayer, 0, 255, 0)
    end
end

local function onMarkerHit(hitElement, matchingDimension)
    local v
    local et = getElementType(hitElement)
    if et == "vehicle" then
        v = hitElement
    elseif et == "player" then
        v = getPedOccupiedVehicle(hitElement)
    end
    if v then
        local byPlayer = (et == "player") and hitElement or getVehicleController(v)
        repairVehicle(v, byPlayer)
    end
end

local function createRepairMarkerAt(x, y, z)
    -- gray color, 50% opacity (alpha 128), size 8
    local marker = createMarker(x, y, z - 1, "cylinder", 8, 128, 128, 128, 128)
    addEventHandler("onMarkerHit", marker, onMarkerHit)
    table.insert(repairMarkers, marker)
    return marker
end

addCommandHandler("repairmarker", function(player)
    if not isElement(player) or getElementType(player) ~= "player" then return end
    local x, y, z = getElementPosition(player)
    createRepairMarkerAt(x, y, z)
    outputChatBox("Repair marker created at your position.", player, 0, 255, 0)
end)

addCommandHandler("removerepairmarkers", function(player)
    for i, marker in ipairs(repairMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    repairMarkers = {}
    outputChatBox("All repair markers removed.", player, 255, 0, 0)
end)

-- Example: to create a marker at runtime use the in-game command /repairmarker
