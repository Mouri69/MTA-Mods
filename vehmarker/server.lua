-- server.lua for vehmarker resource
local playerJobVehicles = {}

addEvent("vehmarker.spawn", true)
addEventHandler("vehmarker.spawn", resourceRoot, function(vehicleName)
    local player = client
    if not isElement(player) then return end

    -- find model id from config
    local modelID
    for _, v in ipairs(VEHICLE_MODELS) do
        if v.name == vehicleName then modelID = v.id break end
    end
    if not modelID then
        outputChatBox("[vehmarker] Unknown vehicle: "..tostring(vehicleName), player)
        return
    end

    -- prevent spawning multiple job vehicles per player
    if isElement(playerJobVehicles[player]) then
        outputChatBox("[vehmarker] You already have a job vehicle. Use /djv to destroy it first.", player)
        return
    end

    local px,py,pz = getElementPosition(player)
    local rx, ry, rz = getElementRotation(player)
    local rad = math.rad(rz)
    local sx = math.cos(rad) * SPAWN_OFFSET
    local sy = math.sin(rad) * SPAWN_OFFSET
    local vx, vy, vz = px + sx, py + sy, pz

    local veh = createVehicle(modelID, vx, vy, vz)
    if not veh then
        outputChatBox("[vehmarker] Failed to create vehicle. Check model ID.", player)
        return
    end

    -- mark ownership
    playerJobVehicles[player] = veh
    setElementData(veh, "vehmarker_owner", player)

    -- warp player into vehicle
    warpPedIntoVehicle(player, veh)
    outputChatBox("[vehmarker] Vehicle spawned and you were placed inside.", player)
end)

addCommandHandler("djv", function(player, cmd)
    local veh = playerJobVehicles[player]
    if isElement(veh) then
        destroyElement(veh)
        playerJobVehicles[player] = nil
        outputChatBox("[vehmarker] Your job vehicle has been destroyed.", player)
    else
        outputChatBox("[vehmarker] You don't have a job vehicle.", player)
    end
end)

-- cleanup when player quits
addEventHandler("onPlayerQuit", root, function()
    local veh = playerJobVehicles[source]
    if isElement(veh) then destroyElement(veh) end
    playerJobVehicles[source] = nil
end)
