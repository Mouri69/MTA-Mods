-- main.lua
-- Car shop server logic: shop list, purchases, and owned vehicle tracking.

local shopCars = {
    { id = 1, model = 411, name = "Infernus", price = 50000 },
    { id = 2, model = 429, name = "Super GT", price = 42000 },
    { id = 3, model = 415, name = "Cheetah", price = 45000 },
    { id = 4, model = 470, name = "Bullet", price = 48000 },
    { id = 5, model = 495, name = "Sultan", price = 36000 },
}

local ownedVehicles = {}

local function getPlayerOwnedTable(player)
    if not isElement(player) or getElementType(player) ~= "player" then return nil end
    ownedVehicles[player] = ownedVehicles[player] or {}
    return ownedVehicles[player]
end

local function cleanupOwnedVehicles(player)
    local list = getPlayerOwnedTable(player)
    if not list then return end
    for i = #list, 1, -1 do
        local entry = list[i]
        if not isElement(entry.vehicle) then
            table.remove(list, i)
        end
    end
end

local function getOwnedVehicleInfo(player)
    cleanupOwnedVehicles(player)
    local result = {}
    local list = getPlayerOwnedTable(player)
    if not list then return result end
    for _, entry in ipairs(list) do
        if isElement(entry.vehicle) then
            local fuel = getElementData(entry.vehicle, "fuel") or 0
            local health = math.floor((getElementHealth(entry.vehicle) / 1000) * 100 + 0.5)
            if health < 0 then health = 0 end
            if health > 100 then health = 100 end
            result[#result + 1] = {
                id = entry.id,
                name = entry.name,
                model = entry.model,
                health = health,
                fuel = fuel,
            }
        end
    end
    return result
end

addEvent("carshop:requestShop", true)
addEventHandler("carshop:requestShop", root, function()
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" then return end
    triggerClientEvent(player, "carshop:showShop", resourceRoot, shopCars)
end)

addEvent("carshop:requestBuy", true)
addEventHandler("carshop:requestBuy", root, function(carId)
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if type(carId) ~= "number" then return end
    local carData
    for _, car in ipairs(shopCars) do
        if car.id == carId then
            carData = car
            break
        end
    end
    if not carData then
        triggerClientEvent(player, "carshop:buyResult", resourceRoot, false, "Invalid car ID.")
        return
    end

    local x, y, z = getElementPosition(player)
    local vx, vy, vz = getElementVelocity(player)
    local spawnX, spawnY, spawnZ = x + 5, y, z
    local vehicle = createVehicle(carData.model, spawnX, spawnY, spawnZ)
    if not isElement(vehicle) then
        triggerClientEvent(player, "carshop:buyResult", resourceRoot, false, "Unable to spawn vehicle.")
        return
    end

    warpPedIntoVehicle(player, vehicle)
    setElementData(vehicle, "fuel", 120)
    setElementHealth(vehicle, 1000)
    setElementData(vehicle, "carshop_owner", true, false)

    local list = getPlayerOwnedTable(player)
    list[#list + 1] = {
        id = carData.id,
        name = carData.name,
        model = carData.model,
        vehicle = vehicle,
    }

    triggerClientEvent(player, "carshop:buyResult", resourceRoot, true, "You bought " .. carData.name .. ".")
end)

addEvent("carshop:requestOwned", true)
addEventHandler("carshop:requestOwned", root, function()
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" then return end
    local owned = getOwnedVehicleInfo(player)
    triggerClientEvent(player, "carshop:showOwned", resourceRoot, owned)
end)

addEventHandler("onPlayerQuit", root, function()
    ownedVehicles[source] = nil
end)
