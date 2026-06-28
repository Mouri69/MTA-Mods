local marketListings = {}
local dataFile = "market_listings.json"

-- Load listings from file
function loadListings()
    local file = fileOpen(dataFile)
    if file then
        local json = fileRead(file, fileGetSize(file))
        fileClose(file)
        marketListings = fromJSON(json) or {}
        outputDebugString("[Market] Loaded " .. #marketListings .. " listings", 3)
    else
        marketListings = {}
        outputDebugString("[Market] No listings file found, starting fresh", 3)
    end
end

-- Save listings to file
function saveListings()
    local file = fileCreate(dataFile)
    if file then
        fileWrite(file, toJSON(marketListings))
        fileClose(file)
    end
end

-- Item definitions
local items = {
    ["ammo_minigun"] = {name = "Minigun Ammo", type = "ammo", weapon = 38},
    ["ammo_ak47"] = {name = "AK47 Ammo", type = "ammo", weapon = 30},
    ["ammo_m4"] = {name = "M4 Ammo", type = "ammo", weapon = 31},
    ["ammo_deagle"] = {name = "Desert Eagle Ammo", type = "ammo", weapon = 24},
    ["parachute"] = {name = "Parachute", type = "misc"},
    ["armor"] = {name = "Armor", type = "misc"}
}

-- Send listings to client
addEvent("market:getListings", true)
addEventHandler("market:getListings", root, function()
    triggerClientEvent(source, "market:sendListings", resourceRoot, marketListings)
end)

-- List item for sale
addEvent("market:listItem", true)
addEventHandler("market:listItem", root, function(itemId, amount, pricePerUnit)
    local player = source
    if not isElement(player) then return end
    
    -- Validate inputs
    if not items[itemId] or not amount or amount <= 0 or not pricePerUnit or pricePerUnit <= 0 then
        outputChatBox("[Market] Invalid listing parameters!", player, 255, 0, 0)
        return
    end
    
    -- Check if player has the item
    if items[itemId].type == "ammo" then
        local currentAmmo = getPedTotalAmmo(player, items[itemId].weapon)
        if currentAmmo < amount then
            outputChatBox("[Market] Not enough ammo!", player, 255, 0, 0)
            return
        end
        -- Take ammo from player
        takeWeapon(player, items[itemId].weapon, amount)
    elseif items[itemId].type == "misc" then
        if itemId == "parachute" then
            if not hasPedWeapon(player, 46) then
                outputChatBox("[Market] You don't have a parachute!", player, 255, 0, 0)
                return
            end
            takeWeapon(player, 46, 1)
        elseif itemId == "armor" then
            local currentArmor = getPedArmor(player)
            if currentArmor < amount then
                outputChatBox("[Market] Not enough armor!", player, 255, 0, 0)
                return
            end
            setPedArmor(player, currentArmor - amount)
        end
    end
    
    -- Add listing
    local listing = {
        id = #marketListings + 1,
        sellerName = getPlayerName(player),
        seller = player,
        itemId = itemId,
        amount = amount,
        pricePerUnit = pricePerUnit,
        totalPrice = amount * pricePerUnit
    }
    table.insert(marketListings, listing)
    saveListings()
    
    outputChatBox("[Market] Listed " .. items[itemId].name .. " x" .. amount .. " for $" .. pricePerUnit .. "/unit!", player, 0, 255, 0)
    
    -- Send updated listings to all clients
    triggerClientEvent(root, "market:sendListings", resourceRoot, marketListings)
end)

-- Buy item
addEvent("market:buyItem", true)
addEventHandler("market:buyItem", root, function(listingId, buyAmount)
    local player = source
    if not isElement(player) then return end
    
    -- Find listing
    local listing = nil
    local listingIndex = nil
    for i, l in ipairs(marketListings) do
        if l.id == listingId then
            listing = l
            listingIndex = i
            break
        end
    end
    
    if not listing then
        outputChatBox("[Market] Listing not found!", player, 255, 0, 0)
        return
    end
    
    if buyAmount > listing.amount then
        outputChatBox("[Market] Not enough items available!", player, 255, 0, 0)
        return
    end
    
    local totalCost = buyAmount * listing.pricePerUnit
    local playerMoney = getPlayerMoney(player)
    
    if playerMoney < totalCost then
        outputChatBox("[Market] Not enough money! Need $" .. totalCost, player, 255, 0, 0)
        return
    end
    
    -- Deduct money from buyer
    takePlayerMoney(player, totalCost)
    
    -- Give money to seller (if seller is online)
    if isElement(listing.seller) then
        givePlayerMoney(listing.seller, totalCost)
        outputChatBox("[Market] Sold " .. items[listing.itemId].name .. " x" .. buyAmount .. " for $" .. totalCost, listing.seller, 0, 255, 0)
    end
    
    -- Give item to buyer
    if items[listing.itemId].type == "ammo" then
        giveWeapon(player, items[listing.itemId].weapon, buyAmount, true)
    elseif items[listing.itemId].type == "misc" then
        if listing.itemId == "parachute" then
            giveWeapon(player, 46, 1, true)
        elseif listing.itemId == "armor" then
            setPedArmor(player, getPedArmor(player) + buyAmount)
        end
    end
    
    outputChatBox("[Market] Bought " .. items[listing.itemId].name .. " x" .. buyAmount .. " for $" .. totalCost, player, 0, 255, 0)
    
    -- Update listing
    listing.amount = listing.amount - buyAmount
    if listing.amount <= 0 then
        table.remove(marketListings, listingIndex)
    end
    saveListings()
    
    -- Send updated listings to all clients
    triggerClientEvent(root, "market:sendListings", resourceRoot, marketListings)
end)

-- Cancel listing
addEvent("market:cancelListing", true)
addEventHandler("market:cancelListing", root, function(listingId)
    local player = source
    if not isElement(player) then return end
    
    -- Find listing
    local listing = nil
    local listingIndex = nil
    for i, l in ipairs(marketListings) do
        if l.id == listingId and l.seller == player then
            listing = l
            listingIndex = i
            break
        end
    end
    
    if not listing then
        outputChatBox("[Market] Listing not found or not yours!", player, 255, 0, 0)
        return
    end
    
    -- Return item to seller
    if items[listing.itemId].type == "ammo" then
        giveWeapon(player, items[listing.itemId].weapon, listing.amount, true)
    elseif items[listing.itemId].type == "misc" then
        if listing.itemId == "parachute" then
            giveWeapon(player, 46, 1, true)
        elseif listing.itemId == "armor" then
            setPedArmor(player, getPedArmor(player) + listing.amount)
        end
    end
    
    -- Remove listing
    table.remove(marketListings, listingIndex)
    saveListings()
    
    outputChatBox("[Market] Listing cancelled and items returned!", player, 0, 255, 0)
    
    -- Send updated listings to all clients
    triggerClientEvent(root, "market:sendListings", resourceRoot, marketListings)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    loadListings()
end)

outputDebugString("[Market] Server script loaded!", 3)
