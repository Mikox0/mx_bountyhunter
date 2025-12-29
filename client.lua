local RSGCore = exports['rsg-core']:GetCoreObject()
local activeBounty = nil
local bountyBlip = nil
local bountyPed = nil
local boardObjects = {}
local posterObjects = {}
local capturedBounty = false
local returnBlip = nil

-- Funkcja ładowania modeli
local function LoadModel(model)
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end
    return modelHash
end

-- Funkcja ładowania animacji
local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(100)
    end
end

-- Tworzenie tablic i listów
local function CreateBountyBoards()
    for boardId, board in ipairs(Config.BountyBoards) do
        -- Tworzenie tablicy
        local boardHash = LoadModel(board.boardProp)
        local boardObj = CreateObject(boardHash, board.coords.x, board.coords.y, board.coords.z, false, false, false)
        SetEntityHeading(boardObj, board.heading)
        FreezeEntityPosition(boardObj, true)
        SetEntityAsMissionEntity(boardObj, true, true)
        boardObjects[boardId] = boardObj
        
        -- Inicjalizacja tablicy posterów
        posterObjects[boardId] = {}
    end
end

-- Tworzenie listu gończego na tablicy
local function CreatePoster(boardId, posterId, bountyData)
    local board = Config.BountyBoards[boardId]
    if not board or not boardObjects[boardId] then return end
    
    local posterHash = LoadModel(board.posterProp)
    local boardCoords = GetEntityCoords(boardObjects[boardId])
    local boardHeading = GetEntityHeading(boardObjects[boardId])
    
    -- Obliczanie pozycji plakatu
    local offsetX = board.posterOffset.x + (posterId * 0.45)
    local offsetY = board.posterOffset.y
    local offsetZ = board.posterOffset.z
    
    local rad = math.rad(boardHeading)
    local finalX = boardCoords.x + (offsetX * math.cos(rad)) - (offsetY * math.sin(rad))
    local finalY = boardCoords.y + (offsetX * math.sin(rad)) + (offsetY * math.cos(rad))
    local finalZ = boardCoords.z + offsetZ
    
    local posterObj = CreateObject(posterHash, finalX, finalY, finalZ, false, false, false)
    SetEntityHeading(posterObj, boardHeading)
    FreezeEntityPosition(posterObj, true)
    SetEntityAsMissionEntity(posterObj, true, true)
    
    posterObjects[boardId][posterId] = {
        object = posterObj,
        bountyData = bountyData
    }
    
    -- Dodawanie ox_target
    exports.ox_target:addLocalEntity(posterObj, {
        {
            name = 'take_bounty_' .. boardId .. '_' .. posterId,
            label = 'Weź List Gończy',
            icon = 'fa-solid fa-file',
            distance = 2.0,
            onSelect = function()
                TakeBountyPoster(boardId, posterId)
            end
        }
    })
end

-- Pobieranie listu gończego
function TakeBountyPoster(boardId, posterId)
    if activeBounty then
        lib.notify({
            title = 'List Gończy',
            description = 'Masz już aktywne zlecenie!',
            type = 'error'
        })
        return
    end
    
    local posterData = posterObjects[boardId][posterId]
    if not posterData then return end
    
    -- Animacja brania
    local playerPed = PlayerPedId()
    LoadAnimDict(Config.Animations.takePoster.dict)
    TaskPlayAnim(playerPed, Config.Animations.takePoster.dict, Config.Animations.takePoster.anim, 8.0, -8.0, 2000, 1, 0, false, false, false)
    Wait(2000)
    
    -- Wywołanie serwera
    TriggerServerEvent('bountyboard:server:takePoster', boardId, posterId, posterData.bountyData)
end

-- Rozpoczęcie zlecenia
RegisterNetEvent('bountyboard:client:startBounty', function(bountyData)
    activeBounty = bountyData
    capturedBounty = false
    
    -- Tworzenie blipu do celu
    local blipHash = GetHashKey("blip_ambient_bounty_target")
    bountyBlip = Citizen.InvokeNative(0x45F13B7E0A15C880, 1664425300, bountyData.coords.x, bountyData.coords.y, bountyData.coords.z)
    SetBlipSprite(bountyBlip, blipHash, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, bountyBlip, bountyData.firstName .. " " .. bountyData.lastName)
    Citizen.InvokeNative(0xD38744167B2FA257, bountyBlip, bountyData.radius)
    BlipAddModifier(bountyBlip, GetHashKey("BLIP_MODIFIER_MP_COLOR_2"))
    
    -- Tworzenie NPC gdy gracz zbliży się do lokalizacji
    CreateThread(function()
        while activeBounty and not capturedBounty do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - activeBounty.coords)
            
            if distance < activeBounty.radius and not bountyPed then
                SpawnBountyTarget()
            end
            
            Wait(1000)
        end
    end)
end)

-- Tworzenie NPC przestępcy
function SpawnBountyTarget()
    if bountyPed then return end
    
    local pedHash = LoadModel(activeBounty.pedModel)
    
    -- Losowa pozycja w promieniu
    local angle = math.random() * 2 * math.pi
    local distance = math.random(0, activeBounty.radius) -- local distance = math.random(50, activeBounty.radius - 20)
    local spawnX = activeBounty.coords.x + (math.cos(angle) * distance)
    local spawnY = activeBounty.coords.y + (math.sin(angle) * distance)
    local spawnZ = activeBounty.coords.z
    
    -- Pobieranie wysokości terenu
    local _, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, spawnZ + 100.0, false)
    
    bountyPed = CreatePed(pedHash, spawnX, spawnY, groundZ, math.random(0, 360), false, false, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, bountyPed, true)
    SetEntityAsMissionEntity(bountyPed, true, true)
    SetPedRelationshipGroupHash(bountyPed, GetHashKey("REL_CRIMINALS"))
    
    -- Ustawienie zachowania
    if activeBounty.behavior == "aggressive" then
        SetupAggressiveBehavior()
    elseif activeBounty.behavior == "flee" then
        SetupFleeBehavior()
    elseif activeBounty.behavior == "surrender" then
        SetupSurrenderBehavior()
    end
    
    -- Monitorowanie śmierci/schwytania
    CreateThread(function()
        while bountyPed and DoesEntityExist(bountyPed) and not capturedBounty do
            if IsPedDeadOrDying(bountyPed, true) then
                lib.notify({
                    title = 'Zlecenie',
                    description = 'Cel zlikwidowany! Zabierz ciało do tablicy.',
                    type = 'inform'
                })
                PrepareForTransport()
                break
            elseif IsPedHogtied(bountyPed) == 1 then
                lib.notify({
                    title = 'Zlecenie',
                    description = 'Cel związany! Zabierz go do tablicy.',
                    type = 'success'
                })
                PrepareForTransport()
                break
            end
            Wait(1000)
        end
    end)
end

-- Agresywne zachowanie
function SetupAggressiveBehavior()
    GiveWeaponToPed(bountyPed, GetHashKey("WEAPON_REVOLVER_CATTLEMAN"), 100, true, true)
    SetPedCombatAttributes(bountyPed, 46, true)
    SetPedCombatAttributes(bountyPed, 5, true)
    SetPedCombatAbility(bountyPed, Config.NpcSettings.aggressive.combatAbility)
    SetPedAccuracy(bountyPed, Config.NpcSettings.aggressive.accuracy)
    SetPedCombatRange(bountyPed, Config.NpcSettings.aggressive.combatRange)
    
    TaskCombatPed(bountyPed, PlayerPedId(), 0, 16)
end

-- Ucieczka
function SetupFleeBehavior()
    SetPedFleeAttributes(bountyPed, 0, false)
    TaskSmartFleePed(bountyPed, PlayerPedId(), Config.NpcSettings.flee.fleeDistance, -1, false, false)
    
    -- Monitorowanie ucieczki
    CreateThread(function()
        while bountyPed and activeBounty and activeBounty.behavior == "flee" and not capturedBounty do
            if not IsPedFleeing(bountyPed) and not IsPedDeadOrDying(bountyPed, true) and not IsPedHogtied(bountyPed) then
                TaskSmartFleePed(bountyPed, PlayerPedId(), Config.NpcSettings.flee.fleeDistance, -1, false, false)
            end
            Wait(2000)
        end
    end)
end

-- Poddanie się
function SetupSurrenderBehavior()
    local surrenderChance = math.random()
    
    if surrenderChance <= Config.NpcSettings.surrender.surrenderChance then
        -- NPC się poddaje
        TaskHandsUp(bountyPed, 60000, PlayerPedId(), -1, false)
        lib.notify({
            title = 'Zlecenie',
            description = 'Przestępca się poddał! Zwiąż go i dostarcz do tablicy.',
            type = 'success'
        })
    else
        -- NPC próbuje uciec
        activeBounty.behavior = "flee"
        SetupFleeBehavior()
        lib.notify({
            title = 'Zlecenie',
            description = 'Przestępca próbuje uciec!',
            type = 'error'
        })
    end
end

-- Przygotowanie do transportu
function PrepareForTransport()
    if not bountyPed or capturedBounty then return end
    
    local isDead = IsPedDeadOrDying(bountyPed, true)
    local isHogtied = IsPedHogtied(bountyPed)
    
    -- Sprawdzenie czy spełnia wymogi
    if activeBounty.wantedStatus == "alive_only" and isDead then
        lib.notify({
            title = 'Zlecenie',
            description = 'Przestępca musiał być schwytany żywy!',
            type = 'error'
        })
        -- Anulowanie zlecenia
        CancelBounty()
        return
    end
    
    if activeBounty.wantedStatus == "dead_only" and not isDead then
        lib.notify({
            title = 'Zlecenie',
            description = 'Przestępca musiał zostać zabity!',
            type = 'error'
        })
        return
    end
    
    if activeBounty.wantedStatus == "alive_only" and not isHogtied then
        lib.notify({
            title = 'Zlecenie',
            description = 'Musisz najpierw związać przestępcę lassem!',
            type = 'error'
        })
        return
    end
    
    capturedBounty = true
    
    -- Usunięcie blipu celu
    if DoesBlipExist(bountyBlip) then
        RemoveBlip(bountyBlip)
        bountyBlip = nil
    end
    
    -- Dodanie blipu powrotu do najbliższej tablicy
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestBoard = nil
    local closestDistance = math.huge
    
    for boardId, board in ipairs(Config.BountyBoards) do
        local distance = #(playerCoords - board.coords)
        if distance < closestDistance then
            closestDistance = distance
            closestBoard = board
        end
    end
    
    if closestBoard then
        local blipHash = GetHashKey("blip_wanted_poster")
        returnBlip = Citizen.InvokeNative(0x45F13B7E0A15C880, -515518185, closestBoard.coords.x, closestBoard.coords.y, closestBoard.coords.z)
        SetBlipSprite(returnBlip, blipHash, true)
        Citizen.InvokeNative(0x9CB1A1623062F402, returnBlip, "Tablica ogłoszeń")
        BlipAddModifier(returnBlip, GetHashKey("BLIP_MODIFIER_MP_COLOR_32"))
    end
    
    -- Rozpoczęcie monitorowania upuszczenia przy tablicy
    StartBoardProximityCheck()
end

-- Monitorowanie bliskości tablicy i automatyczne oddawanie
function StartBoardProximityCheck()
    CreateThread(function()
        while capturedBounty and bountyPed and DoesEntityExist(bountyPed) do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local bountyCoords = GetEntityCoords(bountyPed)
            
            -- Sprawdzenie czy zbieg jest przy graczu (niesiony/ciągnięty)
            local bountyNearPlayer = #(playerCoords - bountyCoords) < 5.0
            
            if bountyNearPlayer then
                -- Sprawdzenie odległości do każdej tablicy
                for boardId, board in ipairs(Config.BountyBoards) do
                    local distanceToBoard = #(bountyCoords - board.coords)
                    
                    -- Jeśli zbieg jest blisko tablicy (np. 3 metry)
                    if distanceToBoard < Config.DeliveryDistance then
                        local isDead = IsPedDeadOrDying(bountyPed, true)
                        
                        -- Sprawdzenie czy gracz upuścił zbiega
                        local isCarried = Citizen.InvokeNative(0xD806CD2A4F2C2996, playerPed) == bountyPed
                        --local isDragging = Citizen.InvokeNative(0xD806CD2A4F2C2996, playerPed) ~= 0
                        
                        if not isCarried then
                            -- Zbieg został upuszczony przy tablicy - automatyczne oddanie
                            DeliverBounty(isDead)
                            return
                        end
                    end
                end
            else
                -- Jeśli zbieg jest daleko od gracza (np. upuszczony wcześniej)
                for boardId, board in ipairs(Config.BountyBoards) do
                    local distanceToBoard = #(bountyCoords - board.coords)
                    
                    if distanceToBoard < Config.DeliveryDistance then
                        -- Sprawdź czy gracz też jest blisko
                        local playerDistanceToBoard = #(playerCoords - board.coords)
                        
                        if playerDistanceToBoard < Config.DeliveryDistance then
                            local isDead = IsPedDeadOrDying(bountyPed, true)
                            DeliverBounty(isDead)
                            return
                        end
                    end
                end
            end
            
            Wait(500) -- Sprawdzanie co pół sekundy
        end
    end)
end

-- Dostarczenie przestępcy
function DeliverBounty(isDead)
    if not bountyPed or not activeBounty or not capturedBounty then return end
    
    -- Animacja dostarczenia
    local playerPed = PlayerPedId()
    LoadAnimDict(Config.Animations.takePoster.dict)
    TaskPlayAnim(playerPed, Config.Animations.takePoster.dict, Config.Animations.takePoster.anim, 8.0, -8.0, 2000, 1, 0, false, false, false)
    Wait(2000)
    
    -- Usunięcie NPC
    DeleteEntity(bountyPed)
    bountyPed = nil
    
    -- Wywołanie serwera do zakończenia zlecenia
    TriggerServerEvent('bountyboard:server:completeBounty', activeBounty, not isDead)
    
    -- Czyszczenie
    if DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
        returnBlip = nil
    end
    
    activeBounty = nil
    capturedBounty = false
end

-- Anulowanie zlecenia
function CancelBounty()
    if bountyPed and DoesEntityExist(bountyPed) then
        DeleteEntity(bountyPed)
    end
    bountyPed = nil
    
    if DoesBlipExist(bountyBlip) then
        RemoveBlip(bountyBlip)
        bountyBlip = nil
    end
    
    if DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
        returnBlip = nil
    end
    
    TriggerServerEvent('bountyboard:server:cancelBounty')
    
    activeBounty = nil
    capturedBounty = false
    
    lib.notify({
        title = 'Zlecenie',
        description = 'Zlecenie anulowane.',
        type = 'error'
    })
end

-- Usuwanie listu z tablicy
RegisterNetEvent('bountyboard:client:removePoster', function(boardId, posterId)
    if posterObjects[boardId] and posterObjects[boardId][posterId] then
        local posterData = posterObjects[boardId][posterId]
        if DoesEntityExist(posterData.object) then
            exports.ox_target:removeLocalEntity(posterData.object)
            DeleteObject(posterData.object)
        end
        posterObjects[boardId][posterId] = nil
    end
end)

-- Dodawanie nowego listu
RegisterNetEvent('bountyboard:client:addPoster', function(boardId, posterId, bountyData)
    CreatePoster(boardId, posterId, bountyData)
end)

-- Inicjalizacja
CreateThread(function()
    Wait(1000)
    CreateBountyBoards()
    TriggerServerEvent('bountyboard:server:requestPosters')
end)

-- Czyszczenie przy wylogowaniu
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Usuwanie obiektów tablic
    for _, obj in pairs(boardObjects) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    
    -- Usuwanie posterów
    for _, board in pairs(posterObjects) do
        for _, poster in pairs(board) do
            if DoesEntityExist(poster.object) then
                exports.ox_target:removeLocalEntity(poster.object)
                DeleteObject(poster.object)
            end
        end
    end
    
    -- Usuwanie NPC
    if bountyPed and DoesEntityExist(bountyPed) then
        DeleteEntity(bountyPed)
    end
    
    -- Usuwanie blipów
    if DoesBlipExist(bountyBlip) then
        RemoveBlip(bountyBlip)
    end
    
    if DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
end)