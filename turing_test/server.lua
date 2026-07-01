-- ============================================================
-- THE TURING TEST - NPC Mimicry Gamemode (Server)
-- ============================================================

-- ========================
-- CONFIGURATION
-- ========================
local CONFIG = {
    ROUND_TIME          = 300,      -- Round duration in seconds (5 min)
    PREP_TIME           = 10,       -- Seconds hiders get to blend in before hunters spawn
    MIN_PLAYERS         = 2,        -- Minimum players to start
    HUNTER_RATIO        = 0.3,      -- 30% of players are hunters (min 1)
    NPC_COUNT           = 80,       -- Number of AI pedestrians to spawn
    NPC_WALK_RADIUS     = 60,       -- Radius of the NPC patrol zone
    PENALTY_HEALTH      = 30,       -- Health lost for shooting an NPC
    PENALTY_BLIND_MS    = 5000,     -- Blindness duration in ms for shooting NPC
    HUNTER_WEAPON        = 24,      -- Desert Eagle
    HUNTER_AMMO          = 100,     -- Desert Eagle ammo
    HIDER_EXPOSED_TIME   = 4,       -- Seconds a hider stays exposed after bad movement
    SPAWN_ZONE           = "plaza", -- Default zone (see ZONES table)
}

-- Predefined play zones
local ZONES = {
    plaza = {
        name  = "Pershing Square",
        center = { 1481.0, -1764.0, 18.8 },
        radius = 80,
        hunterSpawn = { 1544.0, -1675.0, 13.5 },
        npcArea = {
            min = { 1410.0, -1840.0 },
            max = { 1560.0, -1690.0 },
            z   = 13.5
        },
    },
    market = {
        name  = "Market (LS)",
        center = { 1195.0, -1760.0, 18.8 },
        radius = 80,
        hunterSpawn = { 1280.0, -1680.0, 13.5 },
        npcArea = {
            min = { 1120.0, -1840.0 },
            max = { 1280.0, -1690.0 },
            z   = 13.5
        },
    },
    casino = {
        name  = "Las Venturas Strip",
        center = { 2027.0, 1008.0, 10.8 },
        radius = 100,
        hunterSpawn = { 2100.0, 1080.0, 10.8 },
        npcArea = {
            min = { 1940.0, 920.0 },
            max = { 2120.0, 1100.0 },
            z   = 10.8
        },
    },
}

-- Civilian skin IDs (GTA:SA standard peds - no cops/army/gang)
local CIVILIAN_SKINS = {
    1, 2, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
    24, 25, 26, 27, 28, 29, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 41,
    43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
    60, 61, 62, 63, 64, 66, 67, 68, 69, 70, 71, 72, 73, 75, 76, 77, 78,
    83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99,
    100, 101, 102, 103, 104, 108, 109, 110, 111, 112, 113, 114, 115, 116,
    117, 118, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131,
    132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145,
    146, 147, 148, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174,
    175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188,
    189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202,
    203, 204, 205, 206, 207, 209, 210, 211, 212, 213, 214, 215, 216, 217,
    218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231,
    232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245,
    246, 247, 248, 249, 250, 251, 253, 254, 255
}

-- NPC idle animations for variety
local NPC_ANIMS = {
    { lib = "PED",      name = "IDLE_chat" },
    { lib = "PED",      name = "IDLE_hbhb" },
    { lib = "SMOKING",  name = "M_smk_in" },
    { lib = "SMOKING",  name = "M_smk_loop" },
    { lib = "COP_AMBIENT", name = "Coplook_loop" },
    { lib = "MISC",     name = "Plyrlean_loop" },
    { lib = "PED",      name = "SEAT_idle" },
    { lib = "GANGS",    name = "leanin" },
    { lib = "GANGS",    name = "shake_cara" },
    { lib = "PED",      name = "WOMAN_walknorm" },
}

-- NPC walking animations (for peds that patrol)
local NPC_WALK_STYLES = {
    { lib = "PED", name = "WALK_civi" },
    { lib = "PED", name = "WALK_old" },
    { lib = "PED", name = "WOMAN_walknorm" },
    { lib = "PED", name = "WALK_gang1" },
}

-- ========================
-- STATE VARIABLES
-- ========================
local gameState       = "idle"     -- idle, prep, active, ending
local roundTimer      = nil
local prepTimer       = nil
local npcWalkTimer    = nil
local countdownTimer  = nil
local spawnedNPCs     = {}
local hiders          = {}
local hunters         = {}
local hidersAlive     = 0
local huntersAlive    = 0
local currentZone     = nil
local teamHiders      = nil
local teamHunters     = nil
local roundTimeLeft   = 0
local npcWaypoints    = {}          -- Walking waypoints per NPC

-- ========================
-- UTILITY FUNCTIONS
-- ========================
local function randomSkin()
    return CIVILIAN_SKINS[math.random(#CIVILIAN_SKINS)]
end

local function randomAnim()
    return NPC_ANIMS[math.random(#NPC_ANIMS)]
end

local function randomWalkStyle()
    return NPC_WALK_STYLES[math.random(#NPC_WALK_STYLES)]
end

local function msgAll(text)
    outputChatBox("#FFAA00[TURING TEST] #FFFFFF" .. text, root, 255, 255, 255, true)
end

local function msgPlayer(player, text)
    outputChatBox("#FFAA00[TURING TEST] #FFFFFF" .. text, player, 255, 255, 255, true)
end

local function getRandomPointInZone(zone)
    local area = zone.npcArea
    local x = math.random() * (area.max[1] - area.min[1]) + area.min[1]
    local y = math.random() * (area.max[2] - area.min[2]) + area.min[2]
    local z = area.z
    -- Try to find ground level
    local gz = getGroundPosition(x, y, z + 50)
    if gz and gz > 0 then z = gz + 1 end
    return x, y, z
end

-- ========================
-- NPC MANAGEMENT
-- ========================
local function spawnNPCs(zone)
    for i = 1, CONFIG.NPC_COUNT do
        local x, y, z = getRandomPointInZone(zone)
        local skin = randomSkin()
        local rot = math.random(0, 359)

        local ped = createPed(skin, x, y, z, rot)
        if ped then
            setElementData(ped, "turing:isNPC", true)
            setElementData(ped, "turing:npcIndex", i)
            -- Freeze half to do idle anims, let the other half "walk"
            if math.random() > 0.45 then
                -- Idle NPC: plays a random idle animation
                local anim = randomAnim()
                setPedAnimation(ped, anim.lib, anim.name, -1, true, true, false, true)
            else
                -- Walking NPC: will be moved by the walk timer
                setElementData(ped, "turing:walker", true)
                local wx, wy, wz = getRandomPointInZone(zone)
                npcWaypoints[ped] = { x = wx, y = wy, z = wz }
                local walkAnim = randomWalkStyle()
                setPedAnimation(ped, walkAnim.lib, walkAnim.name, -1, true, true, false, true)
            end
            table.insert(spawnedNPCs, ped)
        end
    end
    outputDebugString("[Turing Test] Spawned " .. #spawnedNPCs .. " NPCs.")
end

local function clearNPCs()
    for _, ped in ipairs(spawnedNPCs) do
        if isElement(ped) then
            destroyElement(ped)
        end
    end
    spawnedNPCs = {}
    npcWaypoints = {}
end

-- Move walking NPCs toward their waypoints
local function updateNPCWalking()
    for _, ped in ipairs(spawnedNPCs) do
        if isElement(ped) and getElementData(ped, "turing:walker") then
            local wp = npcWaypoints[ped]
            if wp then
                local px, py, pz = getElementPosition(ped)
                local dx, dy = wp.x - px, wp.y - py
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist < 2 then
                    -- Reached waypoint, pick a new one
                    local nx, ny, nz = getRandomPointInZone(currentZone)
                    npcWaypoints[ped] = { x = nx, y = ny, z = nz }
                    -- Randomly switch animation
                    if math.random() > 0.7 then
                        local anim = randomAnim()
                        setPedAnimation(ped, anim.lib, anim.name, 4000, false, true, false, true)
                    end
                else
                    -- Face the waypoint
                    local angle = math.atan2(dy, dx)
                    local degAngle = math.deg(angle) - 90
                    setPedRotation(ped, -degAngle)
                    -- Move toward waypoint slowly (NPC pace)
                    local speed = 0.03
                    local nx = px + (dx / dist) * speed
                    local ny = py + (dy / dist) * speed
                    setElementPosition(ped, nx, ny, pz)
                end
            end
        end
    end
end

-- ========================
-- TEAM & PLAYER MANAGEMENT
-- ========================
local function assignTeams()
    local players = getElementsByType("player")
    local total = #players
    if total < CONFIG.MIN_PLAYERS then
        msgAll("Not enough players! Need at least " .. CONFIG.MIN_PLAYERS .. ".")
        return false
    end

    -- Shuffle players
    for i = #players, 2, -1 do
        local j = math.random(1, i)
        players[i], players[j] = players[j], players[i]
    end

    local hunterCount = math.max(1, math.floor(total * CONFIG.HUNTER_RATIO))

    hiders = {}
    hunters = {}

    for i, player in ipairs(players) do
        if i <= hunterCount then
            table.insert(hunters, player)
            setPlayerTeam(player, teamHunters)
            setElementData(player, "turing:role", "hunter")
        else
            table.insert(hiders, player)
            setPlayerTeam(player, teamHiders)
            setElementData(player, "turing:role", "hider")
        end
    end

    hidersAlive = #hiders
    huntersAlive = #hunters
    return true
end

local function spawnHider(player)
    local zone = currentZone
    local x, y, z = getRandomPointInZone(zone)
    local skin = randomSkin()

    spawnPlayer(player, x, y, z, math.random(0, 359), skin)
    setElementHealth(player, 100)
    setPlayerNametagShowing(player, false)
    -- No weapons for hiders
    takeAllWeapons(player)
    setCameraTarget(player, player)
    fadeCamera(player, true, 1)

    setElementData(player, "turing:exposed", false)
    setElementData(player, "turing:alive", true)
    setElementData(player, "turing:assignedSkin", skin)

    -- Tell the client they are a hider
    triggerClientEvent(player, "turing:assignRole", player, "hider", skin)

    msgPlayer(player, "#00FF00You are a HIDER! #FFFFFFBlend into the crowd. Use /anim to perform NPC animations.")
    msgPlayer(player, "#FFFF00Hotkeys: #FFFFFF1=Smoke | 2=Lean | 3=Chat | 4=Sit | 5=LookAround | 6=SlowWalk")
    msgPlayer(player, "#FF5555WARNING: #FFFFFFRunning, jumping, sprinting or rolling will EXPOSE you!")
end

local function spawnHunter(player)
    local zone = currentZone
    local sx, sy, sz = zone.hunterSpawn[1], zone.hunterSpawn[2], zone.hunterSpawn[3]

    spawnPlayer(player, sx, sy, sz, 0, 285) -- SWAT skin for hunters
    setElementHealth(player, 100)
    setPlayerNametagShowing(player, true)
    setPlayerNametagColor(player, 255, 50, 50)
    giveWeapon(player, CONFIG.HUNTER_WEAPON, CONFIG.HUNTER_AMMO, true)
    setCameraTarget(player, player)
    fadeCamera(player, true, 1)

    setElementData(player, "turing:alive", true)

    triggerClientEvent(player, "turing:assignRole", player, "hunter", 285)

    msgPlayer(player, "#FF3333You are a HUNTER! #FFFFFFFind and eliminate the hiders hiding in the crowd.")
    msgPlayer(player, "#FF5555WARNING: #FFFFFFShooting an innocent NPC will COST you 30 HP and blind you for 5 seconds!")
    msgPlayer(player, "#FFFF00TIP: #FFFFFFWatch for unnatural movements. Real NPCs don't panic.")
end

-- ========================
-- ROUND SYSTEM
-- ========================
local function endRound(reason)
    if gameState == "idle" then return end
    gameState = "ending"

    if roundTimer then killTimer(roundTimer); roundTimer = nil end
    if prepTimer then killTimer(prepTimer); prepTimer = nil end
    if npcWalkTimer then killTimer(npcWalkTimer); npcWalkTimer = nil end
    if countdownTimer then killTimer(countdownTimer); countdownTimer = nil end

    -- Announce result
    if reason == "hiders_win" then
        msgAll("#00FF00THE HIDERS WIN! #FFFFFFTime ran out and " .. hidersAlive .. " hider(s) survived the Turing Test!")
    elseif reason == "hunters_win" then
        msgAll("#FF3333THE HUNTERS WIN! #FFFFFFAll hiders have been eliminated!")
    elseif reason == "cancelled" then
        msgAll("#AAAAAA Round cancelled.")
    end

    -- Reveal all hiders
    for _, player in ipairs(getElementsByType("player")) do
        setPlayerNametagShowing(player, true)
        setPlayerNametagColor(player, 255, 255, 255)
        triggerClientEvent(player, "turing:roundEnd", player, reason)
    end

    -- Cleanup
    setTimer(function()
        clearNPCs()
        hiders = {}
        hunters = {}
        for _, player in ipairs(getElementsByType("player")) do
            removeElementData(player, "turing:role")
            removeElementData(player, "turing:exposed")
            removeElementData(player, "turing:alive")
            removeElementData(player, "turing:assignedSkin")
        end
        gameState = "idle"
        msgAll("Type #00FF00/tt start #FFFFFF to begin a new round!")
    end, 8000, 1)
end

local function roundTick()
    roundTimeLeft = roundTimeLeft - 1
    triggerClientEvent(root, "turing:updateTimer", root, roundTimeLeft)

    if roundTimeLeft <= 0 then
        endRound("hiders_win")
    elseif roundTimeLeft <= 30 then
        if roundTimeLeft % 10 == 0 then
            msgAll("#FFFF00" .. roundTimeLeft .. " seconds remaining!")
        end
    elseif roundTimeLeft <= 10 then
        msgAll("#FF5555" .. roundTimeLeft .. "...")
    end
end

local function releaseHunters()
    gameState = "active"
    msgAll("#FF3333HUNTERS RELEASED! #FFFFFFThe hunt begins NOW!")
    
    for _, player in ipairs(hunters) do
        if isElement(player) then
            spawnHunter(player)
        end
    end
    
    -- Start round countdown
    roundTimeLeft = CONFIG.ROUND_TIME
    roundTimer = setTimer(roundTick, 1000, CONFIG.ROUND_TIME + 1)
    
    -- Start NPC walking updates
    npcWalkTimer = setTimer(updateNPCWalking, 200, 0)

    triggerClientEvent(root, "turing:huntBegins", root)
end

local function startRound(zoneName)
    if gameState ~= "idle" then
        return false, "A round is already in progress!"
    end

    zoneName = zoneName or CONFIG.SPAWN_ZONE
    currentZone = ZONES[zoneName]
    if not currentZone then
        return false, "Unknown zone: " .. tostring(zoneName)
    end

    -- Create teams
    if not teamHiders then
        teamHiders = createTeam("Hiders", 0, 255, 0)
    end
    if not teamHunters then
        teamHunters = createTeam("Hunters", 255, 0, 0)
    end

    -- Assign roles
    if not assignTeams() then
        return false, "Not enough players!"
    end

    gameState = "prep"
    msgAll("=== #00FFFF THE TURING TEST #FFFFFF ===")
    msgAll("Zone: #FFFF00" .. currentZone.name)
    msgAll(#hiders .. " Hider(s) vs " .. #hunters .. " Hunter(s)")
    msgAll("#00FF00Hiders have " .. CONFIG.PREP_TIME .. " seconds to blend into the crowd!")

    -- Spawn NPCs first
    spawnNPCs(currentZone)

    -- Spawn hiders immediately
    for _, player in ipairs(hiders) do
        spawnHider(player)
    end

    -- Freeze hunters during prep
    for _, player in ipairs(hunters) do
        fadeCamera(player, false, 0)
        triggerClientEvent(player, "turing:prepCountdown", player, CONFIG.PREP_TIME)
    end

    -- Start NPC walking during prep too
    npcWalkTimer = setTimer(updateNPCWalking, 200, 0)

    -- Countdown for hunters
    local prepTimeLeft = CONFIG.PREP_TIME
    countdownTimer = setTimer(function()
        prepTimeLeft = prepTimeLeft - 1
        if prepTimeLeft > 0 then
            for _, player in ipairs(hunters) do
                if isElement(player) then
                    triggerClientEvent(player, "turing:prepTick", player, prepTimeLeft)
                end
            end
        end
    end, 1000, CONFIG.PREP_TIME - 1)

    -- Release hunters after prep
    prepTimer = setTimer(releaseHunters, CONFIG.PREP_TIME * 1000, 1)

    return true
end

-- ========================
-- COMBAT & PENALTY SYSTEM
-- ========================
addEventHandler("onPlayerDamage", root,
    function(attacker, weapon, bodypart, loss)
        if gameState ~= "active" then return end
        if not attacker or getElementType(attacker) ~= "player" then return end

        local attackerRole = getElementData(attacker, "turing:role")
        local victimRole = getElementData(source, "turing:role")

        -- Hunter shooting a Hider
        if attackerRole == "hunter" and victimRole == "hider" then
            -- Allow damage, will be handled in onPlayerWasted
            return
        end

        -- Hiders can't deal damage
        if attackerRole == "hider" then
            cancelEvent()
            return
        end

        -- Hunter shooting another hunter
        if attackerRole == "hunter" and victimRole == "hunter" then
            cancelEvent()
            msgPlayer(attacker, "#FF5555Friendly fire is disabled!")
            return
        end
    end
)

addEventHandler("onPlayerWasted", root,
    function(ammo, killer, killerWeapon, bodypart)
        if gameState ~= "active" then return end

        local victimRole = getElementData(source, "turing:role")
        if victimRole == "hider" then
            setElementData(source, "turing:alive", false)
            hidersAlive = hidersAlive - 1
            
            local skinId = getElementData(source, "turing:assignedSkin") or "?"
            msgAll("#FF3333" .. getPlayerName(source) .. " #FFFFFFwas found and eliminated! (Skin: " .. skinId .. ")")
            msgAll("#FFFF00" .. hidersAlive .. " hider(s) remaining.")
            
            -- Reveal them
            setPlayerNametagShowing(source, true)
            setPlayerNametagColor(source, 255, 100, 100)
            
            -- Make them spectate
            triggerClientEvent(source, "turing:eliminated", source)

            if hidersAlive <= 0 then
                endRound("hunters_win")
            end
        end
    end
)

-- When a hunter shoots an NPC ped
addEventHandler("onPedWasted", root,
    function(ammo, killer, weapon, bodypart)
        if gameState ~= "active" then return end
        if not getElementData(source, "turing:isNPC") then return end
        
        if killer and getElementType(killer) == "player" then
            local killerRole = getElementData(killer, "turing:role")
            if killerRole == "hunter" then
                -- PENALTY: lose health
                local currentHP = getElementHealth(killer)
                local newHP = math.max(1, currentHP - CONFIG.PENALTY_HEALTH)
                setElementHealth(killer, newHP)

                -- PENALTY: blind for 5 seconds
                triggerClientEvent(killer, "turing:penaltyBlind", killer, CONFIG.PENALTY_BLIND_MS)

                msgAll("#FF5555" .. getPlayerName(killer) .. " #FFFFFFshot an innocent civilian! (-" .. CONFIG.PENALTY_HEALTH .. " HP + 5s blind)")
                
                -- Respawn the NPC after a delay
                local skin = getElementModel(source)
                local px, py, pz = getElementPosition(source)
                setTimer(function()
                    if currentZone and gameState == "active" then
                        local nx, ny, nz = getRandomPointInZone(currentZone)
                        local ped = createPed(randomSkin(), nx, ny, nz, math.random(0, 359))
                        if ped then
                            setElementData(ped, "turing:isNPC", true)
                            local anim = randomAnim()
                            setPedAnimation(ped, anim.lib, anim.name, -1, true, true, false, true)
                            table.insert(spawnedNPCs, ped)
                        end
                    end
                end, 3000, 1)
            end
        end
    end
)

-- ========================
-- HIDER EXPOSURE SYSTEM
-- ========================
addEvent("turing:hiderExposed", true)
addEventHandler("turing:hiderExposed", root,
    function()
        if gameState ~= "active" then return end
        if not client or client ~= source then return end
        if getElementData(source, "turing:role") ~= "hider" then return end
        if getElementData(source, "turing:exposed") then return end -- already exposed

        setElementData(source, "turing:exposed", true)
        
        -- Briefly show nametag to hunters
        setPlayerNametagShowing(source, true)
        setPlayerNametagColor(source, 255, 255, 0) -- Yellow flash
        
        -- Broadcast exposure to all clients (for visual indicator)
        triggerClientEvent(root, "turing:playerExposed", source)
        
        msgPlayer(source, "#FF5555YOU'VE BEEN EXPOSED! #FFFFFFYour cover is blown for " .. CONFIG.HIDER_EXPOSED_TIME .. " seconds!")

        -- Re-hide after exposure timer
        setTimer(function()
            if isElement(source) and getElementData(source, "turing:alive") then
                setElementData(source, "turing:exposed", false)
                setPlayerNametagShowing(source, false)
                triggerClientEvent(root, "turing:playerHidden", source)
                msgPlayer(source, "#00FF00Camouflage restored. #FFFFFFBe more careful!")
            end
        end, CONFIG.HIDER_EXPOSED_TIME * 1000, 1)
    end
)

-- ========================
-- COMMANDS
-- ========================
addCommandHandler("tt",
    function(player, cmd, action, arg1)
        action = action or ""
        
        if action == "start" then
            local zone = arg1 or CONFIG.SPAWN_ZONE
            local success, err = startRound(zone)
            if not success then
                msgPlayer(player, "#FF5555" .. (err or "Failed to start round."))
            end
        elseif action == "stop" then
            endRound("cancelled")
        elseif action == "zones" then
            msgPlayer(player, "#FFFF00Available zones:")
            for k, v in pairs(ZONES) do
                msgPlayer(player, "  #00FF00" .. k .. " #FFFFFF- " .. v.name)
            end
        elseif action == "help" then
            msgPlayer(player, "#FFFF00=== The Turing Test Commands ===")
            msgPlayer(player, "#00FF00/tt start [zone] #FFFFFF- Start a round")
            msgPlayer(player, "#00FF00/tt stop          #FFFFFF- Cancel current round")
            msgPlayer(player, "#00FF00/tt zones         #FFFFFF- List available zones")
            msgPlayer(player, "#00FF00/anim [name]      #FFFFFF- Play animation (hiders)")
            msgPlayer(player, "#FFFF00Hider Hotkeys: #FFFFFF1=Smoke 2=Lean 3=Chat 4=Sit 5=Look 6=Walk")
        else
            msgPlayer(player, "Usage: /tt [start|stop|zones|help]")
        end
    end
)

-- ========================
-- LOBBY SPAWN (prevents black screen)
-- ========================
local LOBBY_SPAWN = { 1481.0, -1764.0, 18.8 } -- Pershing Square as default lobby

local function spawnInLobby(player)
    if gameState ~= "idle" then return end -- Don't interfere during a round
    spawnPlayer(player, LOBBY_SPAWN[1], LOBBY_SPAWN[2], LOBBY_SPAWN[3], 0, 0)
    fadeCamera(player, true, 1)
    setCameraTarget(player, player)
    setPlayerNametagShowing(player, true)
    msgPlayer(player, "=== #00FFFF THE TURING TEST #FFFFFF===")
    msgPlayer(player, "Type #00FF00/tt start #FFFFFFto begin a round. #FFFF00/tt help #FFFFFFfor info.")
end

addEventHandler("onPlayerJoin", root,
    function()
        -- Small delay to let the client fully load
        setTimer(spawnInLobby, 1000, 1, source)
    end
)

-- ========================
-- CLEANUP
-- ========================
addEventHandler("onPlayerQuit", root,
    function()
        if gameState == "idle" then return end

        local role = getElementData(source, "turing:role")
        if role == "hider" and getElementData(source, "turing:alive") then
            hidersAlive = hidersAlive - 1
            msgAll("#AAAAAA" .. getPlayerName(source) .. " (hider) disconnected. " .. hidersAlive .. " hider(s) left.")
            if hidersAlive <= 0 and gameState == "active" then
                endRound("hunters_win")
            end
        elseif role == "hunter" then
            huntersAlive = huntersAlive - 1
            if huntersAlive <= 0 and gameState == "active" then
                endRound("hiders_win")
            end
        end
    end
)

addEventHandler("onResourceStop", resourceRoot,
    function()
        clearNPCs()
        if teamHiders then destroyElement(teamHiders) end
        if teamHunters then destroyElement(teamHunters) end
        if roundTimer then killTimer(roundTimer) end
        if prepTimer then killTimer(prepTimer) end
        if npcWalkTimer then killTimer(npcWalkTimer) end
        if countdownTimer then killTimer(countdownTimer) end
    end
)

addEventHandler("onResourceStart", resourceRoot,
    function()
        -- Spawn all players currently on the server into the lobby
        for _, player in ipairs(getElementsByType("player")) do
            spawnInLobby(player)
        end
        msgAll("=== #00FFFF THE TURING TEST #FFFFFF=== Loaded!")
        msgAll("Type #00FF00/tt start #FFFFFFto begin a round. #FFFF00/tt help #FFFFFFfor info.")
    end
)
