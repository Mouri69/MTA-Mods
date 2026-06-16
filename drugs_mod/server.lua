addCommandHandler("giveplayerdrugs", function(player)
    setElementData(player, "drugs.speed", 50)
    setElementData(player, "drugs.god", 50)
    setElementData(player, "drugs.lsd", 50)
    setElementData(player, "drugs.crack", 50)
    setElementData(player, "drugs.weed", 50)
    outputChatBox("You received 50 of each drug!", player)
end)

addEvent("onDrugActivate", true)
addEventHandler("onDrugActivate", root, function(drug)
    local player = client

    outputServerLog("Drug request: " .. tostring(drug) .. " from " .. getPlayerName(player))

    local count = getElementData(player, "drugs." .. drug) or 0
    outputServerLog("Count: " .. tostring(count))

    if count <= 0 then
        triggerClientEvent(player, "onDrugDenied", resourceRoot, drug)
        return
    end

    setElementData(player, "drugs." .. drug, count - 1)
    triggerClientEvent(player, "onDrugGranted", resourceRoot, drug)  -- fix here

    outputServerLog("Granted " .. drug .. " to " .. getPlayerName(player))
end)