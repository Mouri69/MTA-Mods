-- main.lua
-- Taxi job system with levels, progression, and peds.

local TAXI_SKIN = 100
local LEVEL_CONFIGS = {
    { level = 0, required = 5, reward = 500 },
    { level = 1, required = 15, reward = 1000 },
    { level = 2, required = 15, reward = 1500 },
    { level = 3, required = 20, reward = 2000 },
}

local jobMarkers = {}
local taxiSpawns = {
    { x = 100, y = 100, z = 5 },
    { x = 120, y = 100, z = 5 },
    { x = 140, y = 100, z = 5 },
}

local pickupLocations = {
    { x = 200, y = 150, z = 5, name = "Downtown" },
    { x = 300, y = 250, z = 5, name = "Beach" },
    { x = 150, y = 350, z = 5, name = "Airport" },
}

local dropoffLocations = {
    { x = 400, y = 100, z = 5, name = "Hospital" },
    { x = 500, y = 200, z = 5, name = "Police Station" },
    { x = 250, y = 450, z = 5, name = "Train Station" },
}

local playerJobs = {}

local function getPlayerJob(player)
    if not isElement(player) or getElementType(player) ~= "player" then return nil end
    playerJobs[player] = playerJobs[player] or {
        active = false,
        level = 0,
        progress = 0,
        taxi = nil,
        oldSkin = nil,
        pickupPed = nil,
        pickupLocation = nil,
        dropoffLocation = nil,
        passengerInTaxi = false,
    }
    return playerJobs[player]
end

local function getLevelConfig(level)
    for _, config in ipairs(LEVEL_CONFIGS) do
        if config.level == level then
            return config
        end
    end
    return LEVEL_CONFIGS[#LEVEL_CONFIGS]
end

local function givePlayerMoney(player, amount)
    local prev = getElementData(player, "money") or 0
    local now = prev + amount
    setElementData(player, "money", now)
    outputChatBox("You received $" .. amount .. ". Total money: $" .. now, player, 0, 255, 0)
end

local function getPlayerMoney(player)
    return getElementData(player, "money") or 0
end

local function spawnPickupPed(player, job)
    if not job.pickupLocation then
        job.pickupLocation = pickupLocations[math.random(#pickupLocations)]
    end
    local ped = createPed(0, job.pickupLocation.x, job.pickupLocation.y, job.pickupLocation.z)
    if ped then
        job.pickupPed = ped
        -- create a blip attached to the pickup ped visible only to the player
        local blip = createBlipAttachedTo(ped, 0, 2, 255, 255, 0, 255)
        job.pickupBlip = blip
        for _, p in ipairs(getElementsByType("player")) do
            if p == player then
                setElementVisibleTo(blip, p, true)
            else
                setElementVisibleTo(blip, p, false)
            end
        end
    end
    return ped
end

local function completeTrip(player, job)
    local levelConfig = getLevelConfig(job.level)
    local reward = levelConfig.reward
    givePlayerMoney(player, reward)
    job.progress = job.progress + 1
    job.passengerInTaxi = false

    if job.pickupPed and isElement(job.pickupPed) then
        destroyElement(job.pickupPed)
        job.pickupPed = nil
    end
    if job.pickupBlip and isElement(job.pickupBlip) then
        destroyElement(job.pickupBlip)
        job.pickupBlip = nil
    end
    if job.dropoffBlip and isElement(job.dropoffBlip) then
        destroyElement(job.dropoffBlip)
        job.dropoffBlip = nil
    end

    outputChatBox("Trip completed! You earned $" .. reward .. ". Progress: " .. job.progress .. "/" .. levelConfig.required, player, 0, 255, 0)

    if job.progress >= levelConfig.required then
        local nextConfig = getLevelConfig(job.level + 1)
        if nextConfig.level ~= job.level then
            job.level = nextConfig.level
            job.progress = 0
            outputChatBox("LEVEL UP! You are now level " .. job.level .. ". Reward: $" .. (nextConfig.reward * 5) .. "!", player, 255, 255, 0)
            givePlayerMoney(player, nextConfig.reward * 5)
        end
    end

    job.pickupLocation = nil
    job.dropoffLocation = nil
end

addEvent("taxi:startJob", true)
addEventHandler("taxi:startJob", root, function(taxiModel)
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" then return end
    local job = getPlayerJob(player)

    if job.active then
        outputChatBox("You are already on a job.", player, 255, 0, 0)
        return
    end

    job.oldSkin = getElementModel(player)
    setElementModel(player, TAXI_SKIN)
    local spawn = taxiSpawns[math.random(#taxiSpawns)]
    local taxi = createVehicle(taxiModel, spawn.x, spawn.y, spawn.z)

    if taxi then
        setElementData(taxi, "fuel", 120)
        setElementHealth(taxi, 1000)
        warpPedIntoVehicle(player, taxi)
        job.taxi = taxi
        job.active = true
        job.passengerInTaxi = false
        outputChatBox("Job started! Pick up passengers and drop them off.", player, 0, 255, 0)
        spawnPickupPed(player, job)
        triggerClientEvent(player, "taxi:updateJob", resourceRoot, job)
    end
end)

addEvent("taxi:checkPickup", true)
addEventHandler("taxi:checkPickup", root, function()
    local player = client
    local job = getPlayerJob(player)
    if not job.active or not job.pickupPed or not isElement(job.pickupPed) then return end

    local px, py, pz = getElementPosition(player)
    local pedx, pedy, pedz = getElementPosition(job.pickupPed)
    if getDistanceBetweenPoints3D(px, py, pz, pedx, pedy, pedz) < 10 then
        if job.taxi and isElement(job.taxi) then
            warpPedIntoVehicle(job.pickupPed, job.taxi, 1)
            -- remove pickup blip
            if job.pickupBlip and isElement(job.pickupBlip) then
                destroyElement(job.pickupBlip)
                job.pickupBlip = nil
            end
            job.passengerInTaxi = true
            job.dropoffLocation = dropoffLocations[math.random(#dropoffLocations)]
            -- create dropoff blip visible only to the player
            local d = job.dropoffLocation
            local dblip = createBlip(d.x, d.y, d.z, 0, 2, 0, 255, 0, 255)
            job.dropoffBlip = dblip
            for _, p in ipairs(getElementsByType("player")) do
                if p == player then
                    setElementVisibleTo(dblip, p, true)
                else
                    setElementVisibleTo(dblip, p, false)
                end
            end
            outputChatBox("Passenger picked up! Take them to " .. job.dropoffLocation.name .. ".", player, 0, 200, 255)
            triggerClientEvent(player, "taxi:updateJob", resourceRoot, job)
        end
    end
end)

addEvent("taxi:checkDropoff", true)
addEventHandler("taxi:checkDropoff", root, function()
    local player = client
    local job = getPlayerJob(player)
    if not job.active or not job.passengerInTaxi or not job.dropoffLocation then return end

    local px, py, pz = getElementPosition(player)
    local dx, dy, dz = job.dropoffLocation.x, job.dropoffLocation.y, job.dropoffLocation.z
    if getDistanceBetweenPoints3D(px, py, pz, dx, dy, dz) < 15 then
        if job.pickupPed and isElement(job.pickupPed) then
            removePedFromVehicle(job.pickupPed)
            setElementPosition(job.pickupPed, dx, dy, dz)
        end
        completeTrip(player, job)
        -- remove dropoff blip
        if job.dropoffBlip and isElement(job.dropoffBlip) then
            destroyElement(job.dropoffBlip)
            job.dropoffBlip = nil
        end
        spawnPickupPed(player, job)
        triggerClientEvent(player, "taxi:updateJob", resourceRoot, job)
    end
end)

addCommandHandler("level", function(player)
    local job = getPlayerJob(player)
    local levelConfig = getLevelConfig(job.level)
    local money = getPlayerMoney(player)
    outputChatBox("Level: " .. job.level .. " | Progress: " .. job.progress .. "/" .. levelConfig.required .. " | Money: $" .. money, player, 0, 255, 255)
end)

addCommandHandler("stopwork", function(player)
    local job = getPlayerJob(player)
    if not job.active then
        outputChatBox("You are not on a job.", player, 255, 0, 0)
        return
    end

    if job.oldSkin then
        setElementModel(player, job.oldSkin)
    end
    if job.taxi and isElement(job.taxi) then
        destroyElement(job.taxi)
    end
    if job.pickupPed and isElement(job.pickupPed) then
        destroyElement(job.pickupPed)
    end
    if job.pickupBlip and isElement(job.pickupBlip) then
        destroyElement(job.pickupBlip)
    end
    if job.dropoffBlip and isElement(job.dropoffBlip) then
        destroyElement(job.dropoffBlip)
    end

    job.active = false
    job.taxi = nil
    job.pickupPed = nil
    job.pickupLocation = nil
    job.dropoffLocation = nil
    job.passengerInTaxi = false

    outputChatBox("Job stopped. You're back to your normal skin.", player, 0, 255, 0)
    triggerClientEvent(player, "taxi:jobStopped", resourceRoot)
end)

addEventHandler("onPlayerQuit", root, function()
    local job = getPlayerJob(source)
    if job.active and job.taxi and isElement(job.taxi) then
        destroyElement(job.taxi)
    end
    if job.pickupPed and isElement(job.pickupPed) then
        destroyElement(job.pickupPed)
    end
    if job.pickupBlip and isElement(job.pickupBlip) then
        destroyElement(job.pickupBlip)
    end
    if job.dropoffBlip and isElement(job.dropoffBlip) then
        destroyElement(job.dropoffBlip)
    end
    playerJobs[source] = nil
end)

local function createTaxiJobMarkers()
    local marker1 = createMarker(100, 50, 0, "cylinder", 5, 255, 100, 0, 128)
    setElementData(marker1, "isTaxiJobMarker", true, false)
    addEventHandler("onMarkerHit", marker1, function(hitElement, matchingDimension)
        if getElementType(hitElement) == "player" then
            outputChatBox("Welcome to the Taxi Job! Go to the Taxi Selector marker (blue) nearby.", hitElement, 0, 255, 0)
        end
    end)

    local marker2 = createMarker(100, 30, 0, "cylinder", 8, 100, 200, 255, 128)
    setElementData(marker2, "isTaxiSelectMarker", true, false)
    addEventHandler("onMarkerHit", marker2, function(hitElement, matchingDimension)
        if getElementType(hitElement) == "player" then
            triggerClientEvent(hitElement, "taxi:showSelector", resourceRoot)
        end
    end)

    jobMarkers[1] = marker1
    jobMarkers[2] = marker2
end

addEventHandler("onResourceStart", resourceRoot, function()
    createTaxiJobMarkers()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, marker in ipairs(jobMarkers) do
        if isElement(marker) then
            destroyElement(marker)
        end
    end
end)
