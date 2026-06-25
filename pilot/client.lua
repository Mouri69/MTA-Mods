-- client.lua for pilot job resource
local window = nil
local isOpen = false

function createJobPanel()
    if isElement(window) then return end
    
    window = guiCreateWindow(0.65, 0.3, 0.25, 0.4, "Vehicle Marker", true)
    guiWindowSetSizable(window, false)
    
    grid = guiCreateGridList(0.05, 0.5, 0.9, 0.3, true, window)
    local descLabel = guiCreateLabel(0.05, 0.15, 0.9, 0.45, "Deliver cargo with Hydra plane\nEarn $10,000 per delivery", true, window)
    gridCol = guiGridListAddColumn(grid, "Job", 0.9)
    guiGridListSetSortingEnabled(grid, false)
    
    btnGetJob = guiCreateButton(0.01, 0.86, 0.5, 0.1, "Get Job", true, window)
    btnCancel = guiCreateButton(0.54, 0.86, 0.5, 0.1, "Cancel", true, window)
    
    addEventHandler("onClientGUIClick", window, function()
        if source == btnGetJob then
            triggerServerEvent("pilot.getJob", resourceRoot)
            closeJobPanel()
        elseif source == btnCancel then
            closeJobPanel()
        end
    end)
    
    isOpen = true
    guiSetVisible(window, true)
    guiBringToFront(window)
    showCursor(true)
end

function closeJobPanel()
    if isElement(window) then
        destroyElement(window)
        window = nil
    end
    isOpen = false
    showCursor(false)
end

addEvent("pilot.openJobPanel", true)
addEventHandler("pilot.openJobPanel", resourceRoot, createJobPanel)

-- Cleanup on resource stop
addEventHandler("onClientResourceStop", resourceRoot, function()
    if isOpen then closeJobPanel() end
end)
