-- client.lua
-- Car shop UI and owned vehicle display.

local shopVisible = false
local ownedVisible = false
local shopCars = {}
local ownedCars = {}

local function drawShop()
    if not shopVisible then return end
    local sw, sh = guiGetScreenSize()
    local boxW, boxH = 420, 260
    local x, y = (sw - boxW) / 2, (sh - boxH) / 2
    dxDrawRectangle(x, y, boxW, boxH, tocolor(0, 0, 0, 180))
    dxDrawRectangle(x + 2, y + 2, boxW - 4, 24, tocolor(20, 20, 20, 210))
    dxDrawText("Car Shop - Press F6 to close", x + 10, y + 2, x + boxW, y + 26, tocolor(255, 255, 255, 230), 1, "default-bold", "left", "center")

    local itemY = y + 32
    for i, car in ipairs(shopCars) do
        local line = string.format("%d. %s - $%d", car.id, car.name, car.price)
        dxDrawText(line, x + 10, itemY, x + boxW, itemY + 18, tocolor(255, 255, 255, 220), 1, "default", "left", "top")
        itemY = itemY + 20
    end

    dxDrawText("Type /buycar <id> to purchase", x + 10, y + boxH - 34, x + boxW, y + boxH - 14, tocolor(200, 200, 200, 220), 1, "default", "left", "top")
end

local function drawOwned()
    if not ownedVisible then return end
    local sw, sh = guiGetScreenSize()
    local boxW, boxH = 420, 260
    local x, y = (sw - boxW) / 2, (sh - boxH) / 2
    dxDrawRectangle(x, y, boxW, boxH, tocolor(0, 0, 0, 180))
    dxDrawRectangle(x + 2, y + 2, boxW - 4, 24, tocolor(20, 20, 20, 210))
    dxDrawText("Your Vehicles - Press F5 to close", x + 10, y + 2, x + boxW, y + 26, tocolor(255, 255, 255, 230), 1, "default-bold", "left", "center")

    local itemY = y + 32
    if #ownedCars == 0 then
        dxDrawText("You do not own any vehicles.", x + 10, itemY, x + boxW, itemY + 18, tocolor(255, 255, 255, 220), 1, "default", "left", "top")
    else
        for i, car in ipairs(ownedCars) do
            local line = string.format("%d. %s - Health: %d%% Fuel: %d", car.id, car.name, car.health, car.fuel)
            dxDrawText(line, x + 10, itemY, x + boxW, itemY + 18, tocolor(255, 255, 255, 220), 1, "default", "left", "top")
            itemY = itemY + 20
        end
    end
end

addEventHandler("onClientRender", root, function()
    drawShop()
    drawOwned()
end)

addEvent("carshop:showShop", true)
addEventHandler("carshop:showShop", root, function(cars)
    if type(cars) ~= "table" then return end
    shopCars = cars
    shopVisible = true
    ownedVisible = false
end)

addEvent("carshop:buyResult", true)
addEventHandler("carshop:buyResult", root, function(success, message)
    outputChatBox(message, 255, success and 255 or 255, 255, 0)
end)

addEvent("carshop:showOwned", true)
addEventHandler("carshop:showOwned", root, function(cars)
    if type(cars) ~= "table" then return end
    ownedCars = cars
    ownedVisible = true
    shopVisible = false
end)

bindKey("F6", "down", function()
    if shopVisible then
        shopVisible = false
    end
end)

bindKey("F5", "down", function()
    if ownedVisible then
        ownedVisible = false
    else
        triggerServerEvent("carshop:requestOwned", resourceRoot)
    end
end)

addCommandHandler("openshop", function()
    triggerServerEvent("carshop:requestShop", resourceRoot)
end)

addCommandHandler("buycar", function(_, id)
    local carId = tonumber(id)
    if not carId then
        outputChatBox("Usage: /buycar <id>", 255, 255, 255, 0)
        return
    end
    triggerServerEvent("carshop:requestBuy", resourceRoot, carId)
end)
