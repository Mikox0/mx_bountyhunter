Config = {}

-- Lokalizacje tablic ogłoszeń
Config.BountyBoards = {
    {
        coords = vector3(-272.519775390625, 805.2950439453125, 119.45453002929688), -- Valentine Sheriff
        heading = 9.71668148040771,
        boardProp = 'mp005_p_mp_bountyboard01x', -- Prop tablicy
        posterProp = 'p_pos_wanted01x',
        posterOffset = vector3(-0.89, -0.05, 1.35) -- Offset względem tablicy
    },
    {
        coords = vector3(2503.0, -1308.0, 48.9), -- Saint Denis Sheriff
        heading = 9.71668148040771,
        boardProp = 'mp005_p_mp_bountyboard01x',
        posterProp = 'p_pos_wanted01x',
        posterOffset = vector3(-0.89, -0.05, 1.35)
    },
    {
        coords = vector3(-1802.450439453125, -358.846923828125, 163.82289794921875), -- Strawberry Sheriff
        heading = 133.75054931640625,
        boardProp = 'mp005_p_mp_bountyboard01x',
        posterProp = 'p_pos_wanted01x',
        posterOffset = vector3(-0.89, -0.05, 1.35)
    }
}

-- Odległość od tablicy, w której można oddać zbiega (w metrach)
Config.DeliveryDistance = 5.0

-- Czas respawnu nowych listów (w minutach)
Config.RespawnTime = 30

-- Maksymalna liczba listów na tablicy jednocześnie
Config.MaxPostersPerBoard = 3

-- Lista możliwych przestępców
Config.Bounties = {
    {
        firstName = "Billy",
        lastName = "Thompson",
        crime = "Napad na bank",
        location = "Valentine",
        coords = vector3(-350.0, 700.0, 115.0),
        radius = 10.0, -- -150
        wantedStatus = "dead_or_alive", -- dead_or_alive, alive_only, dead_only
        reward = 50,
        pedModel = 'mp_u_m_m_bountytarget_001',
        behavior = "aggressive" -- aggressive, flee, surrender
    },
    {
        firstName = "Sarah",
        lastName = "McKenzie",
        crime = "Morderstwo",
        location = "Saint Denis",
        coords = vector3(2400.0, -1200.0, 47.0),
        radius = 10.0, -- 200
        wantedStatus = "alive_only",
        reward = 75,
        pedModel = 'mp_u_f_m_bountytarget_001',
        behavior = "flee"
    },
    {
        firstName = "Black Jack",
        lastName = "Morrison",
        crime = "Rabunek dyliżansu",
        location = "Strawberry",
        coords = vector3(-1700.0, -450.0, 160.0),
        radius = 10.0, -- 180
        wantedStatus = "dead_or_alive",
        reward = 100,
        pedModel = 'mp_u_m_m_bountytarget_002',
        behavior = "aggressive"
    },
    {
        firstName = "Tom",
        lastName = "Walker",
        crime = "Kradzież bydła",
        location = "Emerald Ranch",
        coords = vector3(1400.0, 300.0, 89.0),
        radius = 10.0, -- 150
        wantedStatus = "alive_only",
        reward = 35,
        pedModel = 'mp_u_m_m_bountytarget_003',
        behavior = "surrender"
    },
    {
        firstName = "Mad Dog",
        lastName = "Sullivan",
        crime = "Napad na pociąg",
        location = "Rhodes",
        coords = vector3(1200.0, -1300.0, 76.0),
        radius = 10.0, -- 200
        wantedStatus = "dead_only",
        reward = 150,
        pedModel = 'mp_u_m_m_bountytarget_005',
        behavior = "aggressive"
    }
}

-- Tłumaczenia statusu
Config.StatusTranslations = {
    dead_or_alive = "Żywy lub Martwy",
    alive_only = "Tylko Żywy",
    dead_only = "Tylko Martwy"
}

-- Tłumaczenia zachowań
Config.BehaviorTranslations = {
    aggressive = "Agresywny",
    flee = "Ucieka",
    surrender = "Poddaje się"
}

-- Animacje
Config.Animations = {
    takePoster = {
        dict = "mech_pickup@treasure@rock_pile",
        anim = "pickup"
    }
}

-- Ustawienia NPC
Config.NpcSettings = {
    aggressive = {
        accuracy = 0.3,
        combatAbility = 1,
        combatRange = 2
    },
    flee = {
        fleeDistance = 100.0
    },
    surrender = {
        surrenderChance = 0.8
    }
}