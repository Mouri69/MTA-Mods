local activeDrugs = {}
local drugTimers = {}
local drugChecked = {}
local menuOpen = false
local screenW, screenH = guiGetScreenSize()
local debugFrame = 0

-- safe caller to avoid runtime errors if a native is missing
local function safeCall(fn, ...)
    if type(fn) == "function" then
        return fn(...)
    end
end
local DEFAULT_WALK_SPEED = 1.34
local DEFAULT_SPRINT_SPEED = 4.5
local DEFAULT_GRAVITY = 0.008
-- double the default speeds for clearer effect
local BOOSTED_WALK_SPEED = DEFAULT_WALK_SPEED * 2.0
local BOOSTED_SPRINT_SPEED = DEFAULT_SPRINT_SPEED * 2.0
local WEED_GRAVITY = DEFAULT_GRAVITY * 0.4
local GOD_HEALTH = 1000
local GOD_FINAL_HEALTH = 500

local drugs = {
    { name = "speed", label = "Speed",  color = {255, 200, 0}  },
    { name = "god",   label = "God",    color = {0, 200, 255}  },
    { name = "lsd",   label = "LSD",    color = {200, 0, 255}  },
    { name = "crack", label = "Crack",  color = {255, 100, 0}  },
    { name = "weed",  label = "Weed",   color = {0, 200, 50}   },
}

-- =====================
-- APPLY EFFECTS
-- =====================
local function applyDrug(drug)

    if drug == "speed" then
        -- simply increase walk/sprint speeds; do NOT force sprint control or animation
        safeCall(setPedWalkSpeed, localPlayer, BOOSTED_WALK_SPEED)
        safeCall(setPedSprintSpeed, localPlayer, BOOSTED_SPRINT_SPEED)

    elseif drug == "god" then
        setElementHealth(localPlayer, GOD_HEALTH)

    elseif drug == "weed" then
        safeCall(setPedGravity, localPlayer, WEED_GRAVITY)

    elseif drug == "crack" then

    elseif drug == "lsd" then
    end
end

-- =====================
-- REMOVE EFFECTS
-- =====================
local function removeDrug(drug)

    if drug == "speed" then
        safeCall(setPedWalkSpeed, localPlayer, DEFAULT_WALK_SPEED)
        safeCall(setPedSprintSpeed, localPlayer, DEFAULT_SPRINT_SPEED)

    elseif drug == "weed" then
        safeCall(setPedGravity, localPlayer, DEFAULT_GRAVITY)

    elseif drug == "god" then
        local currentHealth = getElementHealth(localPlayer)
        if currentHealth > GOD_FINAL_HEALTH then
            setElementHealth(localPlayer, GOD_FINAL_HEALTH)
        else
        end
    end
end

-- =====================
-- TIMER LOGIC
-- =====================
local function startDrugTimer(drugName)

    -- prevent restarting the timer if already active (server may re-send grants)
    if activeDrugs[drugName] then
        return
    end

    if drugTimers[drugName] then
        killTimer(drugTimers[drugName])
        drugTimers[drugName] = nil
    end

    activeDrugs[drugName] = { timeLeft = 60 }

    applyDrug(drugName)

    drugTimers[drugName] = setTimer(function()
        if activeDrugs[drugName] then
            activeDrugs[drugName].timeLeft = activeDrugs[drugName].timeLeft - 1
            if activeDrugs[drugName].timeLeft <= 0 then
                killTimer(drugTimers[drugName])
                drugTimers[drugName] = nil
                activeDrugs[drugName] = nil
                drugChecked[drugName] = false
                removeDrug(drugName)
            end
        end
    end, 1000, 60)

end

-- =====================
-- SERVER EVENTS
-- =====================
addEvent("onDrugGranted", true)
addEventHandler("onDrugGranted", resourceRoot, function(drug)
    startDrugTimer(drug)
end)

addEvent("onDrugDenied", true)
addEventHandler("onDrugDenied", resourceRoot, function(drug)
    drugChecked[drug] = false
end)

-- =====================
-- TOGGLE
-- =====================
local function toggleDrug(drugName)
    drugChecked[drugName] = not drugChecked[drugName]
    if drugChecked[drugName] then
        triggerServerEvent("onDrugActivate", localPlayer, drugName)
    end
end

-- =====================
-- CRACK: regen tracking
-- =====================
local lastHp = 200
local regenActive = false
-- dash impulse for speed drug
local DASH_IMPULSE = 2.0 -- tune this value for desired forward velocity
local DASH_COOLDOWN = 500 -- ms between dashes
local lastDash = 0

-- =====================
-- MAIN RENDER LOOP
-- =====================
addEventHandler("onClientRender", root, function()

    -- debug every 120 frames (~2 seconds)
    debugFrame = debugFrame + 1
    if debugFrame % 120 == 0 then
        local activeCount = 0
        for k, v in pairs(activeDrugs) do
            activeCount = activeCount + 1
        end
        if activeCount == 0 then
        end
    end

    -- SPEED
    if activeDrugs["speed"] then
        safeCall(setPedWalkSpeed, localPlayer, BOOSTED_WALK_SPEED)
        safeCall(setPedSprintSpeed, localPlayer, BOOSTED_SPRINT_SPEED)
    end

    -- GOD
    if activeDrugs["god"] then
        if getElementHealth(localPlayer) < GOD_HEALTH then
            setElementHealth(localPlayer, GOD_HEALTH)
        end
    end

    -- CRACK
    if activeDrugs["crack"] then
        local hp = getElementHealth(localPlayer)
        if hp < lastHp and not regenActive then
            regenActive = true
            for i = 1, 8 do
                setTimer(function()
                    local cur = getElementHealth(localPlayer)
                    if cur < 200 then
                        setElementHealth(localPlayer, math.min(cur + 8, 200))
                    end
                end, i * 400, 1)
            end
            setTimer(function() regenActive = false end, 3500, 1)
        end
        lastHp = hp
    else
        lastHp = getElementHealth(localPlayer)
    end

    -- WEED
    if activeDrugs["weed"] then
        safeCall(setPedGravity, localPlayer, WEED_GRAVITY)
    end
        -- simple forward impulse dash when player presses sprint or jump
        local now = getTickCount()
        if (getControlState("sprint") or getControlState("jump")) and (now - lastDash >= DASH_COOLDOWN) then
            lastDash = now
            local rot = math.rad(getPedRotation(localPlayer))
            local vx = math.sin(rot) * DASH_IMPULSE
            local vy = -math.cos(rot) * DASH_IMPULSE
            safeCall(setElementVelocity, localPlayer, vx, vy, 0)
            -- short timer to reduce sustained velocity
            setTimer(function() safeCall(setElementVelocity, localPlayer, 0, 0, 0) end, 150, 1)
        end
    -- LSD
    if activeDrugs["lsd"] then
        for _, p in ipairs(getElementsByType("player")) do
            if p ~= localPlayer then
                local x, y, z = getElementPosition(p)
                local sx, sy = getScreenFromWorldPosition(x, y, z + 1)
                if sx and sy then
                    dxDrawRectangle(sx - 20, sy, 40, 7, tocolor(255, 0, 0, 220))
                    dxDrawText(getPlayerName(p), sx, sy - 18, sx, sy, tocolor(255, 80, 80, 255), 1.0, "default-bold", "center")
                end
            end
        end
    end

    -- =====================
    -- ACTIVE DRUGS HUD
    -- =====================
    local activeList = {}
    for _, drug in ipairs(drugs) do
        if activeDrugs[drug.name] then
            table.insert(activeList, { drug = drug, timeLeft = activeDrugs[drug.name].timeLeft })
        end
    end

    if #activeList > 0 then
        local boxW = 120
        local boxH = 44
        local padding = 8
        local totalW = (#activeList * (boxW + padding)) - padding
        local startX = (screenW - totalW) / 2
        local baseY = screenH - 70

        for i, entry in ipairs(activeList) do
            local drug = entry.drug
            local timeLeft = entry.timeLeft
            local r, g, b = unpack(drug.color)
            local bX = startX + (i - 1) * (boxW + padding)

            dxDrawRectangle(bX, baseY, boxW, boxH, tocolor(10, 10, 10, 200))
            dxDrawRectangle(bX, baseY, boxW, 4, tocolor(r, g, b, 255))
            local barW = math.floor((timeLeft / 60) * boxW)
            dxDrawRectangle(bX, baseY + boxH - 4, barW, 4, tocolor(r, g, b, 180))
            dxDrawText(drug.label, bX, baseY + 6, bX + boxW, baseY + 26, tocolor(r, g, b, 255), 1.05, "default-bold", "center")
            dxDrawText(timeLeft .. "s", bX, baseY + 24, bX + boxW, baseY + 42, tocolor(220, 220, 220, 255), 0.95, "default", "center")
        end
    end

    -- =====================
    -- MENU
    -- =====================
    if menuOpen then
        local W, H = 300, 370
        local X = (screenW - W) / 2
        local Y = (screenH - H) / 2

        dxDrawRectangle(X, Y, W, H, tocolor(10, 10, 10, 220))
        dxDrawRectangle(X, Y, W, 42, tocolor(30, 30, 30, 255))
        dxDrawText("DRUGS MENU", X, Y + 10, X + W, Y + 42, tocolor(255, 255, 255, 255), 1.3, "default-bold", "center")

        for i, drug in ipairs(drugs) do
            local bY = Y + 52 + (i - 1) * 58
            local checked = drugChecked[drug.name]
            local active = activeDrugs[drug.name]
            local timeLeft = active and active.timeLeft or 0
            local count = getElementData(localPlayer, "drugs." .. drug.name) or 0
            local r, g, b = unpack(drug.color)

            dxDrawRectangle(X + 10, bY, W - 20, 50, tocolor(30, 30, 30, 200))
            local cbColor = checked and tocolor(r, g, b, 255) or tocolor(70, 70, 70, 255)
            dxDrawRectangle(X + 18, bY + 15, 20, 20, cbColor)
            if checked then
                dxDrawText("v", X + 18, bY + 13, X + 38, bY + 35, tocolor(0, 0, 0, 255), 1.1, "default-bold", "center", "center")
            end
            dxDrawText(drug.label, X + 48, bY + 7, X + W - 10, bY + 28, tocolor(r, g, b, 255), 1.1, "default-bold")
            local status = "Stock: " .. count
            if active then status = status .. "   Timer: " .. timeLeft .. "s" end
            dxDrawText(status, X + 48, bY + 28, X + W - 10, bY + 48, tocolor(180, 180, 180, 255), 0.9, "default")
        end

        dxDrawText("F4 to close  |  Click to toggle", X, Y + H - 22, X + W, Y + H, tocolor(120, 120, 120, 200), 0.85, "default", "center")
    end
end)

-- =====================
-- F4 TOGGLE
-- =====================
bindKey("F4", "down", function()
    menuOpen = not menuOpen
    showCursor(menuOpen)
end)

-- =====================
-- CLICK HANDLER
-- =====================
addEventHandler("onClientClick", root, function(button, state, ax, ay)
    if not menuOpen or button ~= "left" or state ~= "down" then return end

    local W, H = 300, 370
    local X = (screenW - W) / 2
    local Y = (screenH - H) / 2

    for i, drug in ipairs(drugs) do
        local bY = Y + 52 + (i - 1) * 58
        if ax >= X + 10 and ax <= X + W - 10 and ay >= bY and ay <= bY + 50 then
            toggleDrug(drug.name)
            break
        end
    end
end)

-- =====================
-- DEBUG COMMAND
-- =====================
addCommandHandler("checkdrugs", function()
    for _, drug in ipairs(drugs) do
        local count = getElementData(localPlayer, "drugs." .. drug.name) or 0
    end
end)