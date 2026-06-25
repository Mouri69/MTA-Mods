local tempObject = nil
local isEditing = false
local state1 = nil
local state2 = nil
local selectedModel = 968

outputDebugString("[GateSystem] Client script loaded!", 3)

local availableModels = {
    {id = 968, name = "Barrier Gate"},
    {id = 980, name = "Dock Gate"},
    {id = 1238, name = "Parking Barrier"},
    {id = 1459, name = "Gate"},
    {id = 1589, name = "Steel Gate"},
    {id = 1935, name = "Barrier"}
}

local guiWindow = nil
local guiList = nil
local dxButton1 = nil
local dxButton2 = nil
local dxButton3 = nil

function toggleGateEditor(cmd)
    outputChatBox("[GateSystem] /addgate command triggered!")
    if isEditing then
        closeEditor()
    else
        openEditor()
    end
end
addCommandHandler("addgate", toggleGateEditor)

function openEditor()
    isEditing = true
    showCursor(true)
    
    local x, y = guiGetScreenSize()
    guiWindow = guiCreateWindow(x/2 - 150, y/2 - 220, 300, 390, "Gate Spawner", false)
    guiSetAlpha(guiWindow, 0.9)
    
    guiList = guiCreateGridList(10, 30, 280, 200, false, guiWindow)
    guiGridListAddColumn(guiList, "Model ID", 0.3)
    guiGridListAddColumn(guiList, "Name", 0.7)
    
    for i, model in ipairs(availableModels) do
        local row = guiGridListAddRow(guiList)
        guiGridListSetItemText(guiList, row, 1, tostring(model.id), false, false)
        guiGridListSetItemText(guiList, row, 2, model.name, false, false)
    end
    
    local spawnButton = guiCreateButton(10, 240, 280, 40, "Spawn Object", false, guiWindow)
    addEventHandler("onClientGUIClick", spawnButton, onSpawnClick, false)
    
    local helpLabel = guiCreateLabel(10, 285, 280, 50, "Controls:\nArrows: Move | PgUp/Dn: Z\nQ/E: Rot Z | Z/C: Rot X | X/V: Rot Y", false, guiWindow)
    guiLabelSetHorizontalAlign(helpLabel, "center")
    local closeButton = guiCreateButton(10, 340, 280, 40, "Close", false, guiWindow)
    addEventHandler("onClientGUIClick", closeButton, closeEditor, false)
    
    bindKey("arrow_u", "both", onControlKey)
    bindKey("arrow_d", "both", onControlKey)
    bindKey("arrow_l", "both", onControlKey)
    bindKey("arrow_r", "both", onControlKey)
    bindKey("pgup", "both", onControlKey)
    bindKey("pgdn", "both", onControlKey)
    bindKey("num_4", "both", onControlKey)
    bindKey("num_6", "both", onControlKey)
    bindKey("num_8", "both", onControlKey)
    bindKey("num_2", "both", onControlKey)
    bindKey("num_1", "both", onControlKey)
    bindKey("num_3", "both", onControlKey)
    bindKey("q", "both", onControlKey)
    bindKey("e", "both", onControlKey)
    bindKey("z", "both", onControlKey)
    bindKey("c", "both", onControlKey)
    bindKey("x", "both", onControlKey)
    bindKey("v", "both", onControlKey)
    
    addEventHandler("onClientRender", root, onClientRender)
end

function onSpawnClick()
    if not isElement(guiList) then return end
    local row = guiGridListGetSelectedItem(guiList)
    if row ~= -1 then
        selectedModel = tonumber(guiGridListGetItemText(guiList, row, 1))
    end
    
    if tempObject then
        destroyElement(tempObject)
    end
    
    local x, y, z = getElementPosition(localPlayer)
    local rotX, rotY, rotZ = getElementRotation(localPlayer)
    tempObject = createObject(selectedModel, x + 2, y, z, rotX, rotY, rotZ)
    setElementCollisionsEnabled(tempObject, false)
end

function closeEditor()
    isEditing = false
    showCursor(false)
    
    if tempObject then
        destroyElement(tempObject)
        tempObject = nil
    end
    
    if guiWindow then
        destroyElement(guiWindow)
        guiWindow = nil
    end
    
    state1 = nil
    state2 = nil
    
    unbindKey("arrow_u", "both", onControlKey)
    unbindKey("arrow_d", "both", onControlKey)
    unbindKey("arrow_l", "both", onControlKey)
    unbindKey("arrow_r", "both", onControlKey)
    unbindKey("pgup", "both", onControlKey)
    unbindKey("pgdn", "both", onControlKey)
    unbindKey("num_4", "both", onControlKey)
    unbindKey("num_6", "both", onControlKey)
    unbindKey("num_8", "both", onControlKey)
    unbindKey("num_2", "both", onControlKey)
    unbindKey("num_1", "both", onControlKey)
    unbindKey("num_3", "both", onControlKey)
    unbindKey("q", "both", onControlKey)
    unbindKey("e", "both", onControlKey)
    unbindKey("z", "both", onControlKey)
    unbindKey("c", "both", onControlKey)
    unbindKey("x", "both", onControlKey)
    unbindKey("v", "both", onControlKey)
    
    removeEventHandler("onClientRender", root, onClientRender)
end

local keysDown = {}
function onControlKey(key, state)
    keysDown[key] = (state == "down")
end

function updateObjectPosition()
    if not tempObject then return end
    
    local moveSpeed = 0.1
    local rotSpeed = 1
    
    local x, y, z = getElementPosition(tempObject)
    local rx, ry, rz = getElementRotation(tempObject)
    
    if keysDown["arrow_u"] then y = y + moveSpeed end
    if keysDown["arrow_d"] then y = y - moveSpeed end
    if keysDown["arrow_l"] then x = x - moveSpeed end
    if keysDown["arrow_r"] then x = x + moveSpeed end
    if keysDown["pgup"] then z = z + moveSpeed end
    if keysDown["pgdn"] then z = z - moveSpeed end
    
    if keysDown["num_4"] or keysDown["q"] then rz = rz - rotSpeed end
    if keysDown["num_6"] or keysDown["e"] then rz = rz + rotSpeed end
    if keysDown["num_8"] or keysDown["z"] then rx = rx - rotSpeed end
    if keysDown["num_2"] or keysDown["c"] then rx = rx + rotSpeed end
    if keysDown["num_1"] or keysDown["x"] then ry = ry - rotSpeed end
    if keysDown["num_3"] or keysDown["v"] then ry = ry + rotSpeed end
    
    setElementPosition(tempObject, x, y, z)
    setElementRotation(tempObject, rx, ry, rz)
end

function dxDrawButton(x, y, w, h, text, hovered)
    local color = hovered and tocolor(80, 80, 80, 240) or tocolor(50, 50, 50, 240)
    dxDrawRectangle(x, y, w, h, color)
    dxDrawRectangle(x, y, w, 2, tocolor(100, 100, 100, 255))
    dxDrawText(text, x, y, x + w, y + h, tocolor(255, 255, 255, 255), 1, "default", "center", "center")
end

function isMouseInRect(x, y, w, h)
    local mx, my = getCursorPosition()
    if not mx then return false end
    mx = mx * guiGetScreenSize()
    my = my * guiGetScreenSize()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function onClientRender()
    updateObjectPosition()
    
    if not tempObject then return end
    
    local x, y = guiGetScreenSize()
    
    local btn1X, btn1Y, btn1W, btn1H = x - 220, 200, 200, 50
    local btn2X, btn2Y, btn2W, btn2H = x - 220, 270, 200, 50
    local btn3X, btn3Y, btn3W, btn3H = x - 220, 340, 200, 50
    
    local hover1 = isMouseInRect(btn1X, btn1Y, btn1W, btn1H)
    local hover2 = isMouseInRect(btn2X, btn2Y, btn2W, btn2H)
    local hover3 = isMouseInRect(btn3X, btn3Y, btn3W, btn3H)
    
    dxDrawButton(btn1X, btn1Y, btn1W, btn1H, "Set Position 1 (Closed)", hover1)
    dxDrawButton(btn2X, btn2Y, btn2W, btn2H, "Set Position 2 (Opened)", hover2)
    dxDrawButton(btn3X, btn3Y, btn3W, btn3H, "Confirm & Save Gate", hover3)
    
    if isCursorShowing() then
        if getKeyState("mouse1") then
            if hover1 then
                local x, y, z = getElementPosition(tempObject)
                local rx, ry, rz = getElementRotation(tempObject)
                state1 = {x = x, y = y, z = z, rx = rx, ry = ry, rz = rz}
                outputChatBox("Position 1 (Closed) set!", 0, 255, 0)
            elseif hover2 then
                local x, y, z = getElementPosition(tempObject)
                local rx, ry, rz = getElementRotation(tempObject)
                state2 = {x = x, y = y, z = z, rx = rx, ry = ry, rz = rz}
                outputChatBox("Position 2 (Opened) set!", 0, 255, 0)
            elseif hover3 then
                if state1 and state2 then
                    triggerServerEvent("onAdminSaveGate", resourceRoot, selectedModel, state1, state2)
                    outputChatBox("Gate saved successfully!", 0, 255, 0)
                    closeEditor()
                else
                    outputChatBox("Set both positions first!", 255, 0, 0)
                end
            end
            setKeyState("mouse1", false)
        end
    end
end
