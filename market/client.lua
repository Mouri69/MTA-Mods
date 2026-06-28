local marketWindow = nil
local listingsGrid = nil
local sellableGrid = nil
local tabPanel = nil
local buyTab = nil
local sellTab = nil
local amountEdit = nil
local priceEdit = nil
local buyAmountEdit = nil
local selectedListing = nil
local selectedSellable = nil
local listings = {}
local refreshTimer = nil

-- Item definitions (must match server)
local items = {
    ["ammo_minigun"] = {name = "Minigun Ammo", type = "ammo", weapon = 38},
    ["ammo_ak47"] = {name = "AK47 Ammo", type = "ammo", weapon = 30},
    ["ammo_m4"] = {name = "M4 Ammo", type = "ammo", weapon = 31},
    ["ammo_deagle"] = {name = "Desert Eagle Ammo", type = "ammo", weapon = 24},
    ["parachute"] = {name = "Parachute", type = "misc"},
    ["armor"] = {name = "Armor", type = "misc"}
}

-- Get player's sellable items
function getSellableItems()
    local sellable = {}
    
    for itemId, itemData in pairs(items) do
        local amount = 0
        if itemData.type == "ammo" then
            amount = getPedTotalAmmo(localPlayer, itemData.weapon)
        elseif itemData.type == "misc" then
            if itemId == "parachute" then
                if hasPedWeapon(localPlayer, 46) then
                    amount = 1
                end
            elseif itemId == "armor" then
                amount = math.floor(getPedArmor(localPlayer))
            end
        end
        if amount > 0 then
            table.insert(sellable, {
                itemId = itemId,
                name = itemData.name,
                amount = amount
            })
        end
    end
    return sellable
end

-- Open market GUI
function openMarket()
    if marketWindow and isElement(marketWindow) then
        closeMarket()
        return
    end
    
    showCursor(true)
    
    local screenW, screenH = guiGetScreenSize()
    marketWindow = guiCreateWindow(screenW/2 - 400, screenH/2 - 300, 800, 600, "Market - Press F7 or /market to close", false)
    guiWindowSetSizable(marketWindow, false)
    
    -- Tab panel
    tabPanel = guiCreateTabPanel(20, 30, 760, 480, false, marketWindow)
    
    -- Buy tab
    buyTab = guiCreateTab("Buy Items", tabPanel)
    listingsGrid = guiCreateGridList(10, 10, 740, 350, false, buyTab)
    guiGridListAddColumn(listingsGrid, "Item", 0.25)
    guiGridListAddColumn(listingsGrid, "Seller", 0.2)
    guiGridListAddColumn(listingsGrid, "Amount", 0.15)
    guiGridListAddColumn(listingsGrid, "Price/Unit", 0.15)
    guiGridListAddColumn(listingsGrid, "Total", 0.15)
    guiGridListSetSortingEnabled(listingsGrid, false)
    
    -- Buy section in buy tab
    local buyLabel = guiCreateLabel(10, 370, 740, 20, "Buy Selected Item", false, buyTab)
    guiLabelSetHorizontalAlign(buyLabel, "center", true)
    
    local buyAmountLabel = guiCreateLabel(10, 400, 100, 20, "Amount:", false, buyTab)
    buyAmountEdit = guiCreateEdit(120, 400, 100, 30, "1", false, buyTab)
    
    local buyButton = guiCreateButton(230, 400, 200, 30, "Buy", false, buyTab)
    addEventHandler("onClientGUIClick", buyButton, function()
        if selectedListing then
            local amount = tonumber(guiGetText(buyAmountEdit)) or 1
            if amount > 0 and amount <= selectedListing.amount then
                triggerServerEvent("market:buyItem", localPlayer, selectedListing.id, amount)
            end
        end
    end, false)
    
    local cancelListingButton = guiCreateButton(440, 400, 310, 30, "Cancel Selected Listing", false, buyTab)
    addEventHandler("onClientGUIClick", cancelListingButton, function()
        if selectedListing then
            triggerServerEvent("market:cancelListing", localPlayer, selectedListing.id)
        end
    end, false)
    
    -- Sell tab
    sellTab = guiCreateTab("Sell Items", tabPanel)
    sellableGrid = guiCreateGridList(10, 10, 740, 350, false, sellTab)
    guiGridListAddColumn(sellableGrid, "Item", 0.5)
    guiGridListAddColumn(sellableGrid, "Amount You Have", 0.5)
    guiGridListSetSortingEnabled(sellableGrid, false)
    
    -- List section in sell tab
    local listLabel = guiCreateLabel(10, 370, 740, 20, "List Selected Item For Sale", false, sellTab)
    guiLabelSetHorizontalAlign(listLabel, "center", true)
    
    local amountLabel = guiCreateLabel(10, 400, 100, 20, "Amount:", false, sellTab)
    amountEdit = guiCreateEdit(120, 400, 100, 30, "1", false, sellTab)
    
    local priceLabel = guiCreateLabel(230, 400, 100, 20, "Price/Unit:", false, sellTab)
    priceEdit = guiCreateEdit(340, 400, 100, 30, "1", false, sellTab)
    
    local listButton = guiCreateButton(450, 400, 300, 30, "List Item", false, sellTab)
    addEventHandler("onClientGUIClick", listButton, function()
        if selectedSellable then
            local amount = tonumber(guiGetText(amountEdit)) or 1
            local pricePerUnit = tonumber(guiGetText(priceEdit)) or 1
            
            if selectedSellable.itemId and items[selectedSellable.itemId] and amount > 0 and pricePerUnit > 0 and amount <= selectedSellable.amount then
                triggerServerEvent("market:listItem", localPlayer, selectedSellable.itemId, amount, pricePerUnit)
            end
        end
    end, false)
    
    -- Close button at bottom of window (not in tabs)
    local closeButton = guiCreateButton(20, 520, 760, 40, "Close", false, marketWindow)
    addEventHandler("onClientGUIClick", closeButton, closeMarket, false)
    
    -- Add click handler to listings grid
    addEventHandler("onClientGUIClick", listingsGrid, function()
        local row = guiGridListGetSelectedItem(listingsGrid)
        if row ~= -1 and listings[row + 1] then
            selectedListing = listings[row + 1]
            guiSetText(buyAmountEdit, tostring(selectedListing.amount))
        end
    end, false)
    
    -- Add click handler to sellable grid
    addEventHandler("onClientGUIClick", sellableGrid, function()
        local row = guiGridListGetSelectedItem(sellableGrid)
        local sellableItems = getSellableItems()
        if row ~= -1 and sellableItems[row + 1] then
            selectedSellable = sellableItems[row + 1]
            guiSetText(amountEdit, tostring(selectedSellable.amount))
        end
    end, false)
    
    -- Add tab change handler
    addEventHandler("onClientGUITabChanged", tabPanel, function()
        updateSellableGrid()
    end)
    
    -- Initial update
    updateSellableGrid()
    
    -- Refresh sell tab every 500ms
    refreshTimer = setTimer(function()
        if sellTab and guiGetSelectedTab(tabPanel) == sellTab then
            updateSellableGrid()
        end
    end, 500, 0)
    
    -- Request listings
    triggerServerEvent("market:getListings", localPlayer)
end
addCommandHandler("market", openMarket)
bindKey("F7", "down", "market")

-- Close market GUI
function closeMarket()
    if refreshTimer and isTimer(refreshTimer) then
        killTimer(refreshTimer)
        refreshTimer = nil
    end
    if marketWindow and isElement(marketWindow) then
        destroyElement(marketWindow)
        marketWindow = nil
        listingsGrid = nil
        sellableGrid = nil
        tabPanel = nil
        buyTab = nil
        sellTab = nil
        amountEdit = nil
        priceEdit = nil
        buyAmountEdit = nil
        selectedListing = nil
        selectedSellable = nil
        showCursor(false)
    end
end

-- Receive listings from server
addEvent("market:sendListings", true)
addEventHandler("market:sendListings", root, function(receivedListings)
    listings = receivedListings
    updateListingsGrid()
    updateSellableGrid()
end)

-- Update listings grid
function updateListingsGrid()
    if not listingsGrid or not isElement(listingsGrid) then return end
    
    -- Clear existing rows
    guiGridListClear(listingsGrid)
    
    -- Add all listings
    for i, listing in ipairs(listings) do
        local itemData = items[listing.itemId] or {name = listing.itemId}
        local row = guiGridListAddRow(listingsGrid)
        guiGridListSetItemText(listingsGrid, row, 1, itemData.name, false, false)
        guiGridListSetItemText(listingsGrid, row, 2, listing.sellerName, false, false)
        guiGridListSetItemText(listingsGrid, row, 3, tostring(listing.amount), false, false)
        guiGridListSetItemText(listingsGrid, row, 4, "$" .. tostring(listing.pricePerUnit), false, false)
        guiGridListSetItemText(listingsGrid, row, 5, "$" .. tostring(listing.totalPrice), false, false)
    end
end

-- Update sellable grid
function updateSellableGrid()
    if not sellableGrid or not isElement(sellableGrid) then return end
    
    -- Clear existing rows
    guiGridListClear(sellableGrid)
    
    -- Add all sellable items
    local sellableItems = getSellableItems()
    for i, item in ipairs(sellableItems) do
        local row = guiGridListAddRow(sellableGrid)
        guiGridListSetItemText(sellableGrid, row, 1, item.name, false, false)
        guiGridListSetItemText(sellableGrid, row, 2, tostring(item.amount), false, false)
    end
end

outputDebugString("[Market] Client script loaded!", 3)
