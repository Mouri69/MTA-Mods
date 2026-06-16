-- client.lua for vehmarker resource
loadstring("-- noop")()

local window, grid, btnSpawn, btnCancel
local isOpen = false

function createVehMarkerGUI()
    if isElement(window) then return end
    window = guiCreateWindow(0.35, 0.25, 0.3, 0.45, "Vehicle Marker", true)
    guiWindowSetSizable(window, false)

    grid = guiCreateGridList(0.03, 0.05, 0.94, 0.78, true, window)
    local col = guiGridListAddColumn(grid, "Vehicle", 0.9)
    guiGridListSetSortingEnabled(grid, false)

    for i, v in ipairs(VEHICLE_MODELS) do
        local row = guiGridListAddRow(grid)
        guiGridListSetItemText(grid, row, col, v.name, false, false)
    end

    btnSpawn = guiCreateButton(0.06, 0.86, 0.4, 0.1, "Spawn", true, window)
    btnCancel = guiCreateButton(0.54, 0.86, 0.4, 0.1, "Cancel", true, window)

    addEventHandler("onClientGUIClick", root, onGuiClick)
    isOpen = true
    showCursor(true)
end

function closeVehMarkerGUI()
    if isElement(window) then
        removeEventHandler("onClientGUIClick", root, onGuiClick)
        destroyElement(window)
        window = nil
    end
    isOpen = false
    showCursor(false)
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
        local vehName = guiGridListGetItemText(grid, row, 1)
        triggerServerEvent("vehmarker.spawn", resourceRoot, vehName)
        closeVehMarkerGUI()
    end
end

addCommandHandler("vehmarker", function()
    toggleVehMarker()
end)

-- close GUI on resource stop
addEventHandler("onClientResourceStop", resourceRoot, function()
    if isOpen then closeVehMarkerGUI() end
end)
