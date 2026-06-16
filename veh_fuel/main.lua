-- main.lua
-- Vehicle fuel system with refill markers, consumption, and engine shutoff.

local FUEL_MAX = 120
local FUEL_CONSUMPTION_INTERVAL = 10000
local FUEL_CONSUMPTION_AMOUNT = 1
local FUEL_MOVE_THRESHOLD = 0.05

local fuelMarkers = {}

local function setVehicleFuel(vehicle, amount)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    local fuel = math.floor(amount + 0.5)
    if fuel < 0 then fuel = 0 end
    if fuel > FUEL_MAX then fuel = FUEL_MAX end
    setElementData(vehicle, "fuel", fuel)
    if fuel == 0 then
        setVehicleEngineState(vehicle, false)
    end

    local driver = getVehicleController(vehicle)
    if isElement(driver) and getElementType(driver) == "player" then
        triggerClientEvent(driver, "veh_fuel:updateFuel", resourceRoot, fuel)
    end

    return fuel
end

local function getVehicleFuel(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return 0 end
    local fuel = getElementData(vehicle, "fuel")
    if type(fuel) ~= "number" then
        fuel = FUEL_MAX
        setElementData(vehicle, "fuel", fuel)
    end
    return fuel
end

local function initVehicleFuel(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    if getElementData(vehicle, "fuel") == nil then
        setVehicleFuel(vehicle, FUEL_MAX)
    end
end

local function refillVehicle(vehicle, byPlayer)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    local currentFuel = getVehicleFuel(vehicle)
    if currentFuel >= FUEL_MAX then
        if isElement(byPlayer) and getElementType(byPlayer) == "player" then
            outputChatBox("Vehicle fuel is already full.", byPlayer, 255, 255, 0)
        end
        return
    end
    setVehicleFuel(vehicle, FUEL_MAX)
    if isElement(byPlayer) and getElementType(byPlayer) == "player" then
        outputChatBox("Your vehicle is now refueled.", byPlayer, 0, 255, 0)
        setVehicleEngineState(vehicle, true)
    end
end

local function getVehicleSpeed(vehicle)
    if not isElement(vehicle) then return 0 end
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.sqrt(vx * vx + vy * vy + vz * vz)
end

local function consumeFuelTick()
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        if isElement(vehicle) then
            local driver = getVehicleController(vehicle)
            if isElement(driver) and getElementType(driver) == "player" then
                local fuel = getVehicleFuel(vehicle)
                if fuel > 0 then
                    local speed = getVehicleSpeed(vehicle)
                    if speed > FUEL_MOVE_THRESHOLD then
                        local newFuel = setVehicleFuel(vehicle, fuel - FUEL_CONSUMPTION_AMOUNT)
                        if newFuel == 0 then
                            outputChatBox("Your vehicle ran out of fuel and stopped.", driver, 255, 0, 0)
                        end
                    end
                end
            end
        end
    end
end

local function isPlayerInFuelMarker(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    local veh = getPedOccupiedVehicle(player)
    for _, marker in ipairs(fuelMarkers) do
        if isElement(marker) then
            if isElement(veh) and isElementWithinMarker(veh, marker) then
                return true
            elseif isElementWithinMarker(player, marker) then
                return true
            end
        end
    end
    return false
end

local function onResourceStart()
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        initVehicleFuel(vehicle)
    end
    setTimer(consumeFuelTick, FUEL_CONSUMPTION_INTERVAL, 0)
end
addEventHandler("onResourceStart", resourceRoot, onResourceStart)

local function onVehicleStartEnter(player, seat)
    if seat ~= 0 then return end
    initVehicleFuel(source)
    if getVehicleFuel(source) > 0 then
        setVehicleEngineState(source, true)
    end
end
addEventHandler("onVehicleStartEnter", root, onVehicleStartEnter)

addEvent("veh_fuel:requestRefill", true)
addEventHandler("veh_fuel:requestRefill", root, function(vehicle)
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    local occupiedVehicle = getPedOccupiedVehicle(player)
    if occupiedVehicle ~= vehicle then return end
    if not isPlayerInFuelMarker(player) then return end
    refillVehicle(vehicle, player)
end)

addEvent("veh_fuel:requestFuelSync", true)
addEventHandler("veh_fuel:requestFuelSync", root, function(vehicle)
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    local occupiedVehicle = getPedOccupiedVehicle(player)
    if occupiedVehicle ~= vehicle then return end
    local fuel = getVehicleFuel(vehicle)
    triggerClientEvent(player, "veh_fuel:updateFuel", resourceRoot, fuel)
end)

local function createFuelMarkerAt(x, y, z)
    local marker = createMarker(x, y, z - 1, "cylinder", 3, 0, 128, 255, 128)
    setElementData(marker, "isFuelMarker", true, false)
    fuelMarkers[#fuelMarkers + 1] = marker
    return marker
end

addCommandHandler("fuelmarker", function(player)
    if not isElement(player) or getElementType(player) ~= "player" then return end
    local x, y, z = getElementPosition(player)
    createFuelMarkerAt(x, y, z)
    outputChatBox("Fuel marker created at your position.", player, 0, 255, 0)
end)

addCommandHandler("removefuelmarkers", function(player)
    if not isElement(player) or getElementType(player) ~= "player" then return end
    for _, marker in ipairs(fuelMarkers) do
        if isElement(marker) then
            destroyElement(marker)
        end
    end
    fuelMarkers = {}
    outputChatBox("All fuel markers removed.", player, 255, 0, 0)
end)
