addEvent("chameleon:setCamoState", true)
addEventHandler("chameleon:setCamoState", root,
    function(state)
        if not client or client ~= source then return end
        
        -- Store the state
        setElementData(client, "chameleon:active", state)
        
        -- Broadcast to everyone else
        triggerClientEvent(root, "chameleon:onPlayerCamoStateChange", client, state)
        
        -- Hide nametags when camo is active to make them truly hidden
        if state then
            setPlayerNametagShowing(client, false)
        else
            setPlayerNametagShowing(client, true)
        end
    end
)

addEventHandler("onPlayerJoin", root,
    function()
        -- Sync current camo players to the newly joined player
        for _, player in ipairs(getElementsByType("player")) do
            if getElementData(player, "chameleon:active") then
                triggerClientEvent(source, "chameleon:onPlayerCamoStateChange", player, true)
            end
        end
    end
)

addEventHandler("onPlayerQuit", root,
    function()
        removeElementData(source, "chameleon:active")
    end
)

addEventHandler("onResourceStart", resourceRoot,
    function()
        -- Initialize for anyone already on the server
        for _, player in ipairs(getElementsByType("player")) do
            setElementData(player, "chameleon:active", false)
            setPlayerNametagShowing(player, true)
        end
    end
)
