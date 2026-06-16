-- client.lua for vehmarker resource
loadstring("-- noop")()

local window, grid, btnSpawn, btnCancel, gridCol
local isOpen = false
local currentMarker = nil
local markerHitHandler = nil

function createVehMarkerGUI()
    if isElement(window) then return end
    window = guiCreateWindow(0.35, 0.25, 0.3, 0.45, "Vehicle Marker", true)
    guiWindowSetSizable(window, false)

    grid = guiCreateGridList(0.03, 0.05, 0.94, 0.78, true, window)
    gridCol = guiGridListAddColumn(grid, "Vehicle", 0.9)
    guiGridListSetSortingEnabled(grid, false)

    if not VEHICLE_MODELS then
        guiGridListAddRow(grid)
        guiGridListSetItemText(grid, 0, gridCol, "(no vehicles configured)", false, false)
    else
        for i, v in ipairs(VEHICLE_MODELS) do
            local row = guiGridListAddRow(grid)
            guiGridListSetItemText(grid, row, gridCol, v.name, false, false)
        end
    end

    btnSpawn = guiCreateButton(0.06, 0.86, 0.4, 0.1, "Spawn", true, window)
    btnCancel = guiCreateButton(0.54, 0.86, 0.4, 0.1, "Cancel", true, window)

    addEventHandler("onClientGUIClick", window, onGuiClick)
    isOpen = true
    guiSetVisible(window, true)
    guiBringToFront(window)
    showCursor(true)
end

function createMarkerAtPlayer()
    if isElement(currentMarker) then
        outputChatBox("You already have an open vehmarker.")
        return
    end
    local px,py,pz = getElementPosition(localPlayer)
    -- place marker slightly in front of player
    local rx, ry, rz = getElementRotation(localPlayer)
    local rad = math.rad(rz)
    local sx = math.cos(rad) * 1.5
    local sy = math.sin(rad) * 1.5
    local mx, my, mz = px + sx, py + sy, pz - 1

    currentMarker = createMarker(mx, my, mz, "cylinder", 1.5, 0, 150, 255, 150)

    markerHitHandler = function(hitElement, matchingDimension)
        if hitElement == localPlayer then
            createVehMarkerGUI()
        end
    end
    addEventHandler("onClientMarkerHit", currentMarker, markerHitHandler)
    outputChatBox("Vehmarker created: enter the marker to open the panel.")
end

function closeVehMarkerGUI()
    if isElement(window) then
        removeEventHandler("onClientGUIClick", window, onGuiClick)
        destroyElement(window)
        window = nil
    end
    isOpen = false
    showCursor(false)
    -- destroy marker when GUI closed (cancel)
    if isElement(currentMarker) then
        if markerHitHandler then
            removeEventHandler("onClientMarkerHit", currentMarker, markerHitHandler)
            markerHitHandler = nil
        end
        destroyElement(currentMarker)
        currentMarker = nil
    end
end

function toggleVehMarker()
    if isOpen then
        closeVehMarkerGUI()
    else
        createVehMarkerGUI()
    end
end

function onGuiClick(button)
    if source == btnCancel then
        closeVehMarkerGUI()
        return
    elseif source == btnSpawn then
        local row, col = guiGridListGetSelectedItem(grid)
        if row == -1 then
            outputChatBox("Select a vehicle first.")
            return
        end
        local vehName = guiGridListGetItemText(grid, row, gridCol)
        triggerServerEvent("vehmarker.spawn", resourceRoot, vehName)
        -- destroy marker as vehicle is spawned
        if isElement(currentMarker) then
            if markerHitHandler then
                removeEventHandler("onClientMarkerHit", currentMarker, markerHitHandler)
                markerHitHandler = nil
            end
            destroyElement(currentMarker)
            currentMarker = nil
        end
        closeVehMarkerGUI()
    end
end

addCommandHandler("vehmarker", function()
    -- create a client-side marker that opens the GUI when entered
    createMarkerAtPlayer()
end)

-- close GUI on resource stop
addEventHandler("onClientResourceStop", resourceRoot, function()
    if isOpen then closeVehMarkerGUI() end
end)
