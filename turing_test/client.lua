-- ============================================================
-- THE TURING TEST - NPC Mimicry Gamemode (Client)
-- ============================================================

-- ========================
-- STATE
-- ========================
local myRole        = nil       -- "hider" or "hunter"
local mySkin        = nil
local isExposed     = false
local isBlinded     = false
local blindEndTime  = 0
local roundActive   = false
local roundTimeLeft = 0
local isEliminated  = false
local currentAnim   = nil
local slowWalking   = false

local sw, sh = guiGetScreenSize()

-- ========================
-- ANIMATION LIBRARY
-- Animations hiders can use to mimic NPC behavior
-- ========================
local ANIM_LIST = {
    smoke   = { lib = "SMOKING",      name = "M_smk_loop",    label = "Smoking",      loop = true,  duration = -1 },
    lean    = { lib = "MISC",         name = "Plyrlean_loop", label = "Lean on Wall",  loop = true,  duration = -1 },
    chat    = { lib = "PED",          name = "IDLE_chat",     label = "Chatting",      loop = true,  duration = -1 },
    sit     = { lib = "PED",          name = "SEAT_idle",     label = "Sitting",       loop = true,  duration = -1 },
    look    = { lib = "COP_AMBIENT",  name = "Coplook_loop",  label = "Looking Around", loop = true, duration = -1 },
    walk    = { lib = "PED",          name = "WALK_civi",     label = "Slow Walk",     loop = true,  duration = -1 },
    wave    = { lib = "ON_LOOKERS",   name = "wave_loop",     label = "Waving",        loop = true,  duration = -1 },
    drink   = { lib = "BAR",          name = "dnk_stnd_loop", label = "Drinking",      loop = true,  duration = -1 },
    cross   = { lib = "COP_AMBIENT",  name = "Coplook_loop",  label = "Arms Crossed",  loop = true,  duration = -1 },
    phone   = { lib = "PED",          name = "phone_in",      label = "Phone Call",    loop = false, duration = 4000 },
}

-- Hotkey mapping (num keys 1-6)
local HOTKEY_MAP = {
    ["1"] = "smoke",
    ["2"] = "lean",
    ["3"] = "chat",
    ["4"] = "sit",
    ["5"] = "look",
    ["6"] = "walk",
}

-- ========================
-- MOVEMENT DETECTION
-- Detects "unnatural" movement that would expose a hider
-- ========================
local lastMoveState  = "stand"
local exposeCooldown = 0

local function checkMovement()
    if myRole ~= "hider" or not roundActive or isEliminated then return end
    if isExposed then return end
    if getTickCount() < exposeCooldown then return end

    local moveState = getPedMoveState(localPlayer)
    local vx, vy, vz = getElementVelocity(localPlayer)
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)

    local exposed = false

    -- Sprinting
    if moveState == "sprint" then
        exposed = true
    end
    -- Running (jog)
    if moveState == "run" then
        exposed = true
    end
    -- Jumping (high vertical velocity)
    if vz > 0.15 then
        exposed = true
    end
    -- Rolling / diving
    if getPedControlState("walk") and (moveState == "sprint" or speed > 0.08) then
        exposed = true
    end
    -- Fast movement in general
    if speed > 0.06 and moveState ~= "stand" and not slowWalking then
        exposed = true
    end

    if exposed then
        isExposed = true
        exposeCooldown = getTickCount() + 5000 -- 5s cooldown before can be exposed again
        triggerServerEvent("turing:hiderExposed", localPlayer)
        -- Stop any animation when exposed
        setPedAnimation(localPlayer, false)
        currentAnim = nil
        slowWalking = false
    end
end
addEventHandler("onClientPreRender", root, checkMovement)

-- ========================
-- ANIMATION COMMANDS
-- ========================
local function playAnim(animKey)
    if myRole ~= "hider" or not roundActive or isEliminated then return end

    local anim = ANIM_LIST[animKey]
    if not anim then
        outputChatBox("#FF5555Unknown animation. Available: smoke, lean, chat, sit, look, walk, wave, drink, phone", 255, 255, 255, true)
        return
    end

    if animKey == "walk" then
        -- Slow walk mode: player can move at NPC pace
        slowWalking = true
        currentAnim = animKey
        setPedAnimation(localPlayer, anim.lib, anim.name, anim.duration, anim.loop, true, false, true)
        outputChatBox("#00FF00[Anim] #FFFFFFSlow walking mode. Move carefully!", 255, 255, 255, true)
    else
        slowWalking = false
        currentAnim = animKey
        setPedAnimation(localPlayer, anim.lib, anim.name, anim.duration, anim.loop, true, false, true)
        outputChatBox("#00FF00[Anim] #FFFFFFPlaying: " .. anim.label, 255, 255, 255, true)
    end
end

-- Stop animation
local function stopAnim()
    setPedAnimation(localPlayer, false)
    currentAnim = nil
    slowWalking = false
    outputChatBox("#FFFF00[Anim] #FFFFFFAnimation stopped.", 255, 255, 255, true)
end

addCommandHandler("anim", function(cmd, animName)
    if not animName or animName == "" then
        outputChatBox("#FFFF00Available animations:", 255, 255, 255, true)
        for key, anim in pairs(ANIM_LIST) do
            outputChatBox("  #00FF00/anim " .. key .. " #FFFFFF- " .. anim.label, 255, 255, 255, true)
        end
        outputChatBox("  #FF5555/anim stop #FFFFFF- Stop current animation", 255, 255, 255, true)
        return
    end
    if animName == "stop" then
        stopAnim()
    else
        playAnim(animName)
    end
end)

-- Bind hotkeys
for key, animName in pairs(HOTKEY_MAP) do
    bindKey(key, "down", function()
        if myRole == "hider" and roundActive and not isEliminated then
            if currentAnim == animName then
                stopAnim()
            else
                playAnim(animName)
            end
        end
    end)
end

-- ========================
-- HUD RENDERING
-- ========================
local function drawHUD()
    if not roundActive and not isEliminated then return end

    -- ---- Timer ----
    local minutes = math.floor(roundTimeLeft / 60)
    local seconds = roundTimeLeft % 60
    local timeStr = string.format("%02d:%02d", minutes, seconds)
    local timeColor = tocolor(255, 255, 255, 220)
    if roundTimeLeft <= 30 then
        timeColor = tocolor(255, 80, 80, 255)
    end

    -- Timer background
    dxDrawRectangle(sw / 2 - 60, 10, 120, 40, tocolor(0, 0, 0, 150), true)
    dxDrawText(timeStr, sw / 2 - 58, 12, sw / 2 + 58, 48, timeColor, 1.5, "default-bold", "center", "center", false, false, true)

    -- ---- Role indicator ----
    if myRole == "hider" and not isEliminated then
        local roleColor = tocolor(0, 255, 100, 200)
        local roleBg = tocolor(0, 0, 0, 120)
        local statusText = "HIDER"
        
        if isExposed then
            roleColor = tocolor(255, 255, 0, 255)
            roleBg = tocolor(100, 50, 0, 180)
            statusText = "!! EXPOSED !!"
        end

        dxDrawRectangle(sw / 2 - 80, 55, 160, 28, roleBg, true)
        dxDrawText(statusText, sw / 2 - 78, 57, sw / 2 + 78, 81, roleColor, 1.2, "default-bold", "center", "center", false, false, true)

        -- Current animation indicator
        if currentAnim and ANIM_LIST[currentAnim] then
            local animLabel = ANIM_LIST[currentAnim].label
            dxDrawRectangle(sw / 2 - 70, 86, 140, 22, tocolor(0, 0, 0, 100), true)
            dxDrawText("♦ " .. animLabel, sw / 2 - 68, 88, sw / 2 + 68, 106, tocolor(180, 255, 180, 200), 0.9, "default-bold", "center", "center", false, false, true)
        end

        -- Hotkey hints at bottom
        local hintY = sh - 40
        local hintBg = tocolor(0, 0, 0, 100)
        dxDrawRectangle(10, hintY - 4, 520, 30, hintBg, true)
        dxDrawText("[1]Smoke [2]Lean [3]Chat [4]Sit [5]Look [6]Walk  |  /anim stop", 15, hintY, 530, hintY + 22, tocolor(200, 200, 200, 180), 0.85, "default-bold", "left", "center", false, false, true)

    elseif myRole == "hunter" and not isEliminated then
        dxDrawRectangle(sw / 2 - 80, 55, 160, 28, tocolor(80, 0, 0, 150), true)
        dxDrawText("HUNTER", sw / 2 - 78, 57, sw / 2 + 78, 81, tocolor(255, 80, 80, 220), 1.2, "default-bold", "center", "center", false, false, true)

        -- Warning text
        dxDrawRectangle(sw / 2 - 160, 86, 320, 22, tocolor(0, 0, 0, 100), true)
        dxDrawText("⚠ Shooting innocents = -30HP + 5s blind", sw / 2 - 158, 88, sw / 2 + 158, 106, tocolor(255, 200, 100, 180), 0.85, "default-bold", "center", "center", false, false, true)
    end

    -- ---- Eliminated overlay ----
    if isEliminated then
        dxDrawRectangle(sw / 2 - 120, sh / 2 - 30, 240, 60, tocolor(0, 0, 0, 180), true)
        dxDrawText("YOU WERE FOUND", sw / 2 - 118, sh / 2 - 28, sw / 2 + 118, sh / 2 + 28, tocolor(255, 60, 60, 255), 1.5, "default-bold", "center", "center", false, false, true)
    end

    -- ---- Blindness overlay (penalty for hunters) ----
    if isBlinded then
        local now = getTickCount()
        if now < blindEndTime then
            local alpha = 255
            local remaining = blindEndTime - now
            if remaining < 1000 then
                alpha = math.floor((remaining / 1000) * 255)
            end
            dxDrawRectangle(0, 0, sw, sh, tocolor(255, 255, 255, alpha), true)
            dxDrawText("PENALTY!", sw / 2 - 100, sh / 2 - 20, sw / 2 + 100, sh / 2 + 20, tocolor(255, 0, 0, alpha), 2.0, "default-bold", "center", "center", false, false, true)
        else
            isBlinded = false
        end
    end
end
addEventHandler("onClientRender", root, drawHUD)

-- ========================
-- EVENT HANDLERS
-- ========================

-- Role assignment from server
addEvent("turing:assignRole", true)
addEventHandler("turing:assignRole", localPlayer,
    function(role, skin)
        myRole = role
        mySkin = skin
        isExposed = false
        isEliminated = false
        isBlinded = false
        roundActive = true
        currentAnim = nil
        slowWalking = false

        if role == "hider" then
            -- Hide all HUD components for maximum immersion
            showPlayerHudComponent("radar", false)
            showPlayerHudComponent("area_name", false)
            showPlayerHudComponent("health", false)
            showPlayerHudComponent("armour", false)
            showPlayerHudComponent("breath", false)
            showPlayerHudComponent("money", false)
            showPlayerHudComponent("weapon", false)
            showPlayerHudComponent("ammo", false)
            showPlayerHudComponent("wanted", false)
        elseif role == "hunter" then
            showPlayerHudComponent("radar", true)
            showPlayerHudComponent("health", true)
            showPlayerHudComponent("weapon", true)
            showPlayerHudComponent("ammo", true)
        end
    end
)

-- Timer updates
addEvent("turing:updateTimer", true)
addEventHandler("turing:updateTimer", root,
    function(timeLeft)
        roundTimeLeft = timeLeft
    end
)

-- Prep countdown for hunters
addEvent("turing:prepCountdown", true)
addEventHandler("turing:prepCountdown", localPlayer,
    function(prepTime)
        roundActive = true
        roundTimeLeft = prepTime
    end
)

addEvent("turing:prepTick", true)
addEventHandler("turing:prepTick", localPlayer,
    function(timeLeft)
        roundTimeLeft = timeLeft
    end
)

-- Hunt begins
addEvent("turing:huntBegins", true)
addEventHandler("turing:huntBegins", root,
    function()
        roundActive = true
    end
)

-- Penalty blind effect for hunters
addEvent("turing:penaltyBlind", true)
addEventHandler("turing:penaltyBlind", localPlayer,
    function(durationMs)
        isBlinded = true
        blindEndTime = getTickCount() + durationMs
    end
)

-- Player got exposed (for visual indicator on other clients)
addEvent("turing:playerExposed", true)
addEventHandler("turing:playerExposed", root,
    function()
        if source == localPlayer then
            isExposed = true
        end
        -- Flash the exposed player's marker briefly for hunters
        if myRole == "hunter" then
            if isElement(source) then
                setPlayerNametagShowing(source, true)
                setPlayerNametagColor(source, 255, 255, 0)
            end
        end
    end
)

-- Player re-hidden
addEvent("turing:playerHidden", true)
addEventHandler("turing:playerHidden", root,
    function()
        if source == localPlayer then
            isExposed = false
        end
        if myRole == "hunter" then
            if isElement(source) then
                setPlayerNametagShowing(source, false)
            end
        end
    end
)

-- Eliminated
addEvent("turing:eliminated", true)
addEventHandler("turing:eliminated", localPlayer,
    function()
        isEliminated = true
        setPedAnimation(localPlayer, false)
        currentAnim = nil
        slowWalking = false
    end
)

-- Round end
addEvent("turing:roundEnd", true)
addEventHandler("turing:roundEnd", localPlayer,
    function(reason)
        roundActive = false
        isEliminated = false
        isExposed = false
        isBlinded = false
        myRole = nil
        currentAnim = nil
        slowWalking = false

        -- Restore HUD
        showPlayerHudComponent("radar", true)
        showPlayerHudComponent("area_name", true)
        showPlayerHudComponent("health", true)
        showPlayerHudComponent("armour", true)
        showPlayerHudComponent("breath", true)
        showPlayerHudComponent("money", true)
        showPlayerHudComponent("weapon", true)
        showPlayerHudComponent("ammo", true)
        showPlayerHudComponent("wanted", true)
    end
)

-- Cleanup on resource stop
addEventHandler("onClientResourceStop", resourceRoot,
    function()
        showPlayerHudComponent("radar", true)
        showPlayerHudComponent("area_name", true)
        showPlayerHudComponent("health", true)
        showPlayerHudComponent("armour", true)
        showPlayerHudComponent("breath", true)
        showPlayerHudComponent("money", true)
        showPlayerHudComponent("weapon", true)
        showPlayerHudComponent("ammo", true)
        showPlayerHudComponent("wanted", true)
    end
)
