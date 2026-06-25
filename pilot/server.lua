-- server.lua for pilot job resource
local jobMarker = nil
local playerJobs = {}

-- Create persistent job marker on resource start
function createJobMarker()
    if isElement(jobMarker) then return end
    jobMarker = createMarker(
        JOB_MARKER.pos[1], JOB_MARKER.pos[2], JOB_MARKER.pos[3],
        JOB_MARKER.type, JOB_MARKER.size,
        unpack(JOB_MARKER.color)
    )
    if isElement(jobMarker) then
        addEventHandler("onMarkerHit", jobMarker, function(hitElement, matchingDimension)
            if hitElement and getElementType(hitElement) == "player" and matchingDimension then
                if not playerJobs[hitElement] then
                    triggerClientEvent(hitElement, "pilot.openJobPanel", resourceRoot)
                end
            end
        end)
    end
end

addEventHandler("onResourceStart", resourceRoot, createJobMarker)
addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(jobMarker) then destroyElement(jobMarker) end
end)

-- Handle Get Job
addEvent("pilot.getJob", true)
addEventHandler("pilot.getJob", resourceRoot, function()
    local player = client
    if not isElement(player) then return end
    
    if playerJobs[player] then
        outputChatBox("[pilot] You already have an active job.", player)
        return
    end
    
    -- Change skin to pilot skin
    setElementModel(player, JOB_SKIN)
    
    -- Create plane marker
    local planeMarker = createMarker(
        PLANE_MARKER.pos[1], PLANE_MARKER.pos[2], PLANE_MARKER.pos[3],
        PLANE_MARKER.type, PLANE_MARKER.size,
        unpack(PLANE_MARKER.color)
    )
    
    if isElement(planeMarker) then
        addEventHandler("onMarkerHit", planeMarker, function(hitElement, matchingDimension)
            if hitElement == player and matchingDimension and playerJobs[player] then
                if playerJobs[player].plane and isElement(playerJobs[player].plane) then
                    outputChatBox("[pilot] You already have a plane.", player)
                    return
                end
                
                -- Spawn plane slightly above the marker
                local plane = createVehicle(PLANE_MODEL, PLANE_MARKER.pos[1], PLANE_MARKER.pos[2], PLANE_MARKER.pos[3] + 0.5)
                if isElement(plane) then
                    playerJobs[player].plane = plane
                    warpPedIntoVehicle(player, plane)
                    outputChatBox("[pilot] Plane spawned. Head to the first pickup location (marked on map).", player)
                    
                    -- Create first cargo marker
                    createCargoMarkerForPlayer(player, 1)
                end
            end
        end)
        
        playerJobs[player] = {
            planeMarker = planeMarker,
            plane = nil,
            cargoIndex = 1,
        }
    end
    
    outputChatBox("[pilot] Job started. Go to the plane marker to get your Hydra.", player)
end)

-- Create cargo marker for current delivery
function createCargoMarkerForPlayer(player, cargoIndex)
    if not playerJobs[player] or cargoIndex > #CARGO_LOCATIONS then return end
    
    local cargo = CARGO_LOCATIONS[cargoIndex]
    local pickupMarker = createMarker(
        cargo.pickup[1], cargo.pickup[2], cargo.pickup[3],
        "cylinder", CARGO_MARKER_SIZE,
        0, 255, 0, 128
    )
    
    addEventHandler("onMarkerHit", pickupMarker, function(hitElement, matchingDimension)
        if hitElement == player and matchingDimension and playerJobs[player] then
            if playerJobs[player].plane and isElement(playerJobs[player].plane) and getPedOccupiedVehicle(player) == playerJobs[player].plane then
                -- Player is in the plane at pickup
                local deliveryMarker = createMarker(
                    cargo.delivery[1], cargo.delivery[2], cargo.delivery[3],
                    "cylinder", CARGO_MARKER_SIZE,
                    255, 0, 0, 128
                )
                
                outputChatBox("[pilot] Cargo loaded. Head to delivery location.", player)
                
                addEventHandler("onMarkerHit", deliveryMarker, function(hitElement2, matchingDimension2)
                    if hitElement2 == player and matchingDimension2 and playerJobs[player] then
                        if playerJobs[player].plane and isElement(playerJobs[player].plane) and getPedOccupiedVehicle(player) == playerJobs[player].plane then
                            -- Delivered successfully
                            destroyElement(deliveryMarker)
                            destroyElement(pickupMarker)
                            givePlayerMoney(player, cargo.reward)
                            outputChatBox("[pilot] Cargo delivered! You earned $" .. cargo.reward, player)
                            
                            -- Move to next delivery
                            playerJobs[player].cargoIndex = cargoIndex + 1
                            if playerJobs[player].cargoIndex > #CARGO_LOCATIONS then
                                playerJobs[player].cargoIndex = 1
                            end
                            createCargoMarkerForPlayer(player, playerJobs[player].cargoIndex)
                        end
                    end
                end)
            end
        end
    end)
    
    playerJobs[player].pickupMarker = pickupMarker
end

-- Cancel job
addEvent("pilot.cancelJob", true)
addEventHandler("pilot.cancelJob", resourceRoot, function()
    local player = client
    if not isElement(player) then return end
    
    local job = playerJobs[player]
    if job then
        if isElement(job.planeMarker) then destroyElement(job.planeMarker) end
        if isElement(job.pickupMarker) then destroyElement(job.pickupMarker) end
        if isElement(job.plane) then destroyElement(job.plane) end
        playerJobs[player] = nil
        outputChatBox("[pilot] Job cancelled.", player)
    end
end)

-- Cleanup on player quit
addEventHandler("onPlayerQuit", root, function()
    if playerJobs[source] then
        local job = playerJobs[source]
        if isElement(job.planeMarker) then destroyElement(job.planeMarker) end
        if isElement(job.pickupMarker) then destroyElement(job.pickupMarker) end
        if isElement(job.plane) then destroyElement(job.plane) end
        playerJobs[source] = nil
    end
end)
