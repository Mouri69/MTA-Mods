local gates = {}

outputDebugString("[GateSystem] Server script loaded!", 3)

function loadGates()
    local file = fileOpen("gates.json")
    if file then
        local json = fileRead(file, fileGetSize(file))
        fileClose(file)
        gates = fromJSON(json) or {}
        outputDebugString("[GateSystem] Loaded " .. #gates .. " gates")
    else
        gates = {}
        outputDebugString("[GateSystem] No gates.json found, starting fresh")
    end
end

function saveGates()
    local file = fileCreate("gates.json")
    if file then
        fileWrite(file, toJSON(gates))
        fileClose(file)
        outputDebugString("[GateSystem] Saved gates")
    end
end

function spawnGates()
    for i, gateData in ipairs(gates) do
        local object = createObject(gateData.model, gateData.state1.x, gateData.state1.y, gateData.state1.z, gateData.state1.rx, gateData.state1.ry, gateData.state1.rz)
        local colShape = createColSphere(gateData.state1.x, gateData.state1.y, gateData.state1.z, 8)
        
        setElementData(colShape, "gateObject", object)
        setElementData(colShape, "gateData", gateData)
        setElementData(colShape, "gateOpen", false)
        setElementData(colShape, "gateMoving", false)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    loadGates()
    spawnGates()
end)

addEvent("onAdminSaveGate", true)
addEventHandler("onAdminSaveGate", resourceRoot, function(model, state1, state2)
    local newGate = {
        model = model,
        state1 = state1,
        state2 = state2
    }
    table.insert(gates, newGate)
    saveGates()
    
    local object = createObject(model, state1.x, state1.y, state1.z, state1.rx, state1.ry, state1.rz)
    local colShape = createColSphere(state1.x, state1.y, state1.z, 8)
    
    setElementData(colShape, "gateObject", object)
    setElementData(colShape, "gateData", newGate)
    setElementData(colShape, "gateOpen", false)
    setElementData(colShape, "gateMoving", false)
end)

addEventHandler("onColShapeHit", root, function(element, matchingDimension)
    if not matchingDimension then return end
    if getElementType(element) ~= "player" and getElementType(element) ~= "vehicle" then return end
    
    local gateObject = getElementData(source, "gateObject")
    local gateData = getElementData(source, "gateData")
    local gateOpen = getElementData(source, "gateOpen")
    local gateMoving = getElementData(source, "gateMoving")
    
    if not gateObject or not gateData or gateOpen or gateMoving then return end
    
    outputDebugString("[GateSystem] Opening gate!")
    setElementData(source, "gateMoving", true)
    moveObject(gateObject, 2500, gateData.state2.x, gateData.state2.y, gateData.state2.z, gateData.state2.rx, gateData.state2.ry, gateData.state2.rz, "InQuad")
    
    setTimer(function()
        setElementData(source, "gateOpen", true)
        setElementData(source, "gateMoving", false)
    end, 2500, 1)
end)

addEventHandler("onColShapeLeave", root, function(element, matchingDimension)
    if not matchingDimension then return end
    if getElementType(element) ~= "player" and getElementType(element) ~= "vehicle" then return end
    
    local gateObject = getElementData(source, "gateObject")
    local gateData = getElementData(source, "gateData")
    local gateOpen = getElementData(source, "gateOpen")
    local gateMoving = getElementData(source, "gateMoving")
    
    if not gateObject or not gateData or not gateOpen or gateMoving then return end
    
    outputDebugString("[GateSystem] Entity left gate area")
    
    -- Check again after a 1 second delay to make sure they really left
    setTimer(function()
        local elementsInside = getElementsWithinColShape(source)
        local hasEntities = false
        for i, el in ipairs(elementsInside) do
            if getElementType(el) == "player" or getElementType(el) == "vehicle" then
                hasEntities = true
                break
            end
        end
        
        if hasEntities then
            outputDebugString("[GateSystem] Still entities inside, not closing")
            return
        end
        
        -- Double-check state before moving
        if not getElementData(source, "gateOpen") or getElementData(source, "gateMoving") then
            outputDebugString("[GateSystem] Gate state changed, not closing")
            return
        end
        
        outputDebugString("[GateSystem] Closing gate!")
        setElementData(source, "gateMoving", true)
        moveObject(gateObject, 2500, gateData.state1.x, gateData.state1.y, gateData.state1.z, gateData.state1.rx, gateData.state1.ry, gateData.state1.rz, "InQuad")
        
        setTimer(function()
            setElementData(source, "gateOpen", false)
            setElementData(source, "gateMoving", false)
        end, 2500, 1)
    end, 1000, 1)
end)
