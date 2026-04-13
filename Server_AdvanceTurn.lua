-- Server_AdvanceTurn.lua
-- Detects when a player's surrender is processed and transfers all their
-- territories to a selected teammate (highest income / lowest income / random).
-- If the surrendering player has no alive teammates, does nothing.
--
-- All three Server_AdvanceTurn_* hooks share global state within a single turn,
-- so we track surrenders found in _Order and act in _End.

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

-- Returns true if the player is still actively playing (not eliminated etc.)
local function isAlive(player)
    return player.State == WL.GamePlayerState.Playing
end

-- Collect the IDs of all alive teammates of surrenderingPlayerID (excluding themselves).
local function getAliveTeammates(game, surrenderingPlayerID)
    local surrenderingPlayer = game.Players[surrenderingPlayerID]
    local myTeam = surrenderingPlayer.Team
    local teammates = {}

    for _, player in pairs(game.Players) do
        if player.ID ~= surrenderingPlayerID
           and player.Team == myTeam
           and isAlive(player) then
            teammates[#teammates + 1] = player
        end
    end

    return teammates
end

-- Pick a teammate based on the configured mode.
local function pickTeammate(teammates, mode, game, standing)
    if #teammates == 0 then
        return nil
    end

    if mode == 'Random' then
        -- Warzone's math.random is seeded differently each turn on the server.
        local idx = math.random(1, #teammates)
        return teammates[idx]

    elseif mode == 'LowestIncome' then
        local best = nil
        local bestIncome = math.huge
        for _, player in ipairs(teammates) do
            local income = player.Income(0, standing, false, false).Total
            if income < bestIncome then
                bestIncome = income
                best = player
            end
        end
        return best

    else
        -- Default: HighestIncome
        local best = nil
        local bestIncome = -1
        for _, player in ipairs(teammates) do
            local income = player.Income(0, standing, false, false).Total
            if income > bestIncome then
                bestIncome = income
                best = player
            end
        end
        return best
    end
end

-- Collect all TerritoryIDs owned by a given player.
local function getTerritoriesOwnedBy(standing, playerID)
    local owned = {}
    for terrID, terrStanding in pairs(standing.Territories) do
        if terrStanding.OwnerPlayerID == playerID then
            owned[#owned + 1] = terrID
        end
    end
    return owned
end

-----------------------------------------------------------------------
-- Turn-global state
-----------------------------------------------------------------------
-- Set of playerIDs (keyed by ID to avoid duplicates) whose surrender
-- we detected this turn, from either source.
_SRMod_surrenderedThisTurn = {}

-----------------------------------------------------------------------
-- Hook: called once at turn start (reset state + catch instant surrenders)
-----------------------------------------------------------------------
function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_surrenderedThisTurn = {}

    -- Instant surrenders (no vote required) are processed between turns.
    -- By the time _Start fires, they are already queued in PendingStateTransitions
    -- and will NOT appear as in-turn GameOrderStateTransition orders.
    -- We catch them here so they aren't missed.
    if game.PendingStateTransitions ~= nil then
        for _, transition in ipairs(game.PendingStateTransitions) do
            if transition.NewState == WL.GamePlayerState.SurrenderAccepted then
                _SRMod_surrenderedThisTurn[transition.PlayerID] = true
            end
        end
    end
end

-----------------------------------------------------------------------
-- Hook: called for each order; detect vote-accepted surrenders
-----------------------------------------------------------------------
-- When "players must vote to accept surrenders" is enabled, opponents
-- vote during their turn and the transition appears as an in-turn
-- GameOrderStateTransition order. We catch it here.
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderStateTransition' then
        return
    end

    if order.NewState == WL.GamePlayerState.SurrenderAccepted then
        _SRMod_surrenderedThisTurn[order.PlayerID] = true
    end
end

-----------------------------------------------------------------------
-- Hook: called at turn end; perform the territory redistribution
-----------------------------------------------------------------------
function Server_AdvanceTurn_End(game, addNewOrder)
    -- Check if any surrenders were recorded (can't use # on a hash-keyed table).
    local hasSurrenders = false
    for _ in pairs(_SRMod_surrenderedThisTurn) do hasSurrenders = true; break end
    if not hasSurrenders then
        return
    end

    local mode = (Mod.Settings.TransferMode or 'HighestIncome')

    -- Use LatestTurnStanding, which reflects all orders processed so far this turn.
    local standing = game.LatestTurnStanding

    for surrenderingID, _ in pairs(_SRMod_surrenderedThisTurn) do
        local teammates = getAliveTeammates(game, surrenderingID)

        if #teammates == 0 then
            -- No alive teammates; do nothing for this player.
            print('SurrenderRedistribute: ' .. tostring(surrenderingID) .. ' surrendered with no alive teammates. Skipping.')
        else
            local recipient = pickTeammate(teammates, mode, game, standing)

            if recipient == nil then
                print('SurrenderRedistribute: Could not pick a teammate for ' .. tostring(surrenderingID))
            else
                local ownedTerritories = getTerritoriesOwnedBy(standing, surrenderingID)

                if #ownedTerritories == 0 then
                    print('SurrenderRedistribute: ' .. tostring(surrenderingID) .. ' had no territories to transfer.')
                else
                    -- Build one TerritoryModification per territory.
                    local mods = {}
                    for _, terrID in ipairs(ownedTerritories) do
                        local mod = WL.TerritoryModification.Create(terrID)
                        mod.SetOwnerOpt = recipient.ID
                        mods[#mods + 1] = mod
                    end

                    -- Create a visible GameOrderEvent describing the transfer.
                    local surrenderingName = game.Players[surrenderingID].DisplayName(nil, false)
                    local recipientName    = recipient.DisplayName(nil, false)
                    local msg = surrenderingName .. ' surrendered. Their ' .. #ownedTerritories
                                .. ' territories have been transferred to teammate ' .. recipientName .. '.'

                    local event = WL.GameOrderEvent.Create(
                        surrenderingID,  -- attributed to the surrendering player
                        msg,
                        nil,             -- visible to everyone
                        mods,
                        nil,             -- no resource changes
                        nil              -- no income mods
                    )

                    addNewOrder(event)

                    print('SurrenderRedistribute: Transferred ' .. #ownedTerritories
                          .. ' territories from ' .. surrenderingName
                          .. ' to ' .. recipientName .. ' (mode=' .. mode .. ')')
                end
            end
        end
    end
end
