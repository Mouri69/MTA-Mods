local isCamoEnabled = false
local camoShader = nil
local screenSource = nil
local camoPlayers = {}

function initCamo()
    local sw, sh = guiGetScreenSize()
    -- Create screen source to capture the game world
    screenSource = dxCreateScreenSource(sw, sh)
    if not screenSource then
        outputDebugString("Failed to create screen source for camo.")
        return
    end

    -- Create the shader
    camoShader = dxCreateShader("camo.fx", 0, 0, false, "ped")
    if not camoShader then
        outputDebugString("Failed to create shader for camo.")
        return
    end

    dxSetShaderValue(camoShader, "ScreenTexture", screenSource)
    
    addEventHandler("onClientPreRender", root, updateScreenSource)
    addEventHandler("onClientRender", root, checkCamoStates)
end
addEventHandler("onClientResourceStart", resourceRoot, initCamo)

function updateScreenSource()
    if camoShader and screenSource then
        -- Update the screen source right before GUI is drawn
        dxUpdateScreenSource(screenSource)
    end
end

function toggleCamo()
    if isCamoEnabled then
        isCamoEnabled = false
        outputChatBox("#00FF00[Chameleon]#FFFFFF Camouflage deactivated!", 255, 255, 255, true)
        triggerServerEvent("chameleon:setCamoState", localPlayer, false)
    else
        local moveState = getPedMoveState(localPlayer)
        local vx, vy, vz = getElementVelocity(localPlayer)
        local speed = math.sqrt(vx^2 + vy^2 + vz^2)
        
        -- Only allow activation if standing still
        if (moveState == "stand" or not moveState) and speed < 0.01 then
            isCamoEnabled = true
            outputChatBox("#00FF00[Chameleon]#FFFFFF Camouflage activated! Stay completely still.", 255, 255, 255, true)
            triggerServerEvent("chameleon:setCamoState", localPlayer, true)
        else
            outputChatBox("#FF0000[Chameleon]#FFFFFF You must stand completely still against a surface to camouflage!", 255, 255, 255, true)
        end
    end
end
addCommandHandler("camo", toggleCamo)
bindKey("c", "down", toggleCamo)

function checkCamoStates()
    if not isCamoEnabled then return end
    
    local moveState = getPedMoveState(localPlayer)
    local isAiming = getPedControlState("aim_weapon") or getPedControlState("fire")
    local vx, vy, vz = getElementVelocity(localPlayer)
    local speed = math.sqrt(vx^2 + vy^2 + vz^2)
    
    local isMoving = (moveState ~= "stand" and moveState ~= false) or speed > 0.01
    
    if isMoving or isAiming then
        isCamoEnabled = false
        outputChatBox("#FF0000[Chameleon]#FFFFFF Camouflage broken due to movement/action!", 255, 255, 255, true)
        triggerServerEvent("chameleon:setCamoState", localPlayer, false)
    end
end

addEvent("chameleon:onPlayerCamoStateChange", true)
addEventHandler("chameleon:onPlayerCamoStateChange", root,
    function(state)
        camoPlayers[source] = state
        if state then
            if camoShader then
                engineApplyShaderToWorldTexture(camoShader, "*", source)
            end
        else
            if camoShader then
                engineRemoveShaderFromWorldTexture(camoShader, "*", source)
            end
        end
    end
)

addEventHandler("onClientResourceStop", resourceRoot,
    function()
        if camoShader then
            for player, state in pairs(camoPlayers) do
                if state then
                    engineRemoveShaderFromWorldTexture(camoShader, "*", player)
                end
            end
            destroyElement(camoShader)
        end
        if screenSource then
            destroyElement(screenSource)
        end
    end
)
