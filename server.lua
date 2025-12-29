local RSGCore = exports['rsg-core']:GetCoreObject()
local activePosters = {} -- [boardId][posterId] = bountyData
local playerBounties = {} -- [source] = bountyData

-- Inicjalizacja tablic
for boardId, _ in ipairs(Config.BountyBoards) do
    activePosters[boardId] = {}
end

-- Funkcja generowania losowych listów
local function GenerateRandomPosters()
    for boardId, _ in ipairs(Config.BountyBoards) do
        local currentPosters = 0
        for _ in pairs(activePosters[boardId]) do
            currentPosters = currentPosters + 1
        end
        
        -- Dodaj nowe listy jeśli jest miejsce
        while currentPosters < Config.MaxPostersPerBoard do
            local randomBounty = Config.Bounties[math.random(1, #Config.Bounties)]
            local posterId = currentPosters + 1
            
            activePosters[boardId][posterId] = randomBounty
            
            -- Informuj wszystkich klientów
            TriggerClientEvent('bountyboard:client:addPoster', -1, boardId, posterId, randomBounty)
            
            currentPosters = currentPosters + 1
        end
    end
end

-- Pobranie listu przez gracza
RegisterNetEvent('bountyboard:server:takePoster', function(boardId, posterId, bountyData)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Sprawdzenie czy gracz ma już zlecenie
    if playerBounties[src] then
        lib.notify(src, {
            title = 'List Gończy',
            description = 'Masz już aktywne zlecenie!',
            type = 'error'
        })
        return
    end
    
    -- Sprawdzenie czy list istnieje
    if not activePosters[boardId] or not activePosters[boardId][posterId] then
        lib.notify(src, {
            title = 'List Gończy',
            description = 'Ten list został już zabrany!',
            type = 'error'
        })
        return
    end
    
    -- Przygotowanie opisu przedmiotu
    local wantedText = Config.StatusTranslations[bountyData.wantedStatus] or bountyData.wantedStatus
    local description = string.format(
        "Imię: %s\nNazwisko: %s\nPrzewinienie: %s\nLokalizacja: %s\nStatus: %s\nNagroda: $%d",
        bountyData.firstName,
        bountyData.lastName,
        bountyData.crime,
        bountyData.location,
        wantedText,
        bountyData.reward
    )
    
    -- Dodanie przedmiotu do ekwipunku
    local metadata = {
        description = description
    }
    
    local success = exports['rsg-inventory']:AddItem(src, 'bounty_poster', 1, nil, metadata)
    
    if success then
        -- Usunięcie listu z tablicy
        activePosters[boardId][posterId] = nil
        TriggerClientEvent('bountyboard:client:removePoster', -1, boardId, posterId)
        
        -- Zapisanie aktywnego zlecenia
        playerBounties[src] = bountyData
        
        -- Rozpoczęcie zlecenia
        TriggerClientEvent('bountyboard:client:startBounty', src, bountyData)
        
        lib.notify(src, {
            title = 'List Gończy',
            description = 'Zlecenie rozpoczęte! Znajdź przestępcę i dostarcz do tablicy.',
            type = 'success'
        })
    else
        lib.notify(src, {
            title = 'List Gończy',
            description = 'Nie masz miejsca w ekwipunku!',
            type = 'error'
        })
    end
end)

-- Ukończenie zlecenia
RegisterNetEvent('bountyboard:server:completeBounty', function(bountyData, isAlive)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Sprawdzenie czy gracz ma to zlecenie
    if not playerBounties[src] then
        return
    end
    
    -- Usunięcie przedmiotu z ekwipunku
    exports['rsg-inventory']:RemoveItem(src, 'bounty_poster', 1)
    
    -- Wypłata nagrody
    Player.Functions.AddMoney('cash', bountyData.reward)
    
    -- Komunikat
    local statusText = "martwego"
    if isAlive then
        statusText = "żywego"
    end
    lib.notify(src, {
        title = 'Zlecenie Ukończone',
        description = string.format('Dostarczono %s %s! Nagroda: $%d', statusText, bountyData.firstName .. ' ' .. bountyData.lastName, bountyData.reward),
        type = 'success'
    })
    
    -- Usunięcie aktywnego zlecenia
    playerBounties[src] = nil
end)

-- Anulowanie zlecenia (np. gdy gracz wyrzuci przedmiot)
RegisterNetEvent('bountyboard:server:cancelBounty', function()
    local src = source
    playerBounties[src] = nil
end)

-- Żądanie synchronizacji posterów
RegisterNetEvent('bountyboard:server:requestPosters', function()
    local src = source
    
    for boardId, board in pairs(activePosters) do
        for posterId, bountyData in pairs(board) do
            TriggerClientEvent('bountyboard:client:addPoster', src, boardId, posterId, bountyData)
        end
    end
end)

-- Czyszczenie przy wylogowaniu
AddEventHandler('playerDropped', function()
    local src = source
    playerBounties[src] = nil
end)

-- Timer generowania nowych listów
CreateThread(function()
    -- Generuj listy przy starcie
    Wait(500)
    GenerateRandomPosters()
    
    -- Następnie generuj regularnie
    while true do
        Wait(Config.RespawnTime * 60 * 1000)
        GenerateRandomPosters()
    end
end)

-- Rejestracja przedmiotu w rsg-inventory
CreateThread(function()
    Wait(1000)
    
    -- rsg-inventory automatycznie ładuje przedmioty z pliku items.lua
    -- Upewnij się, że dodałeś przedmiot do items.lua w rsg-inventory
    
    print('^2[Bounty Board]^7 System tablic listów gończych załadowany!')
end)