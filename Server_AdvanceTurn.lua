-- Server_AdvanceTurn.lua
-- When a player surrenders, transfers all their territories to a teammate
-- instead of letting them go neutral.
--
-- KEY INSIGHT: Warzone neutralizes a surrendering player's territories as part
-- of processing the surrender. By the time _End runs, the territories are
-- already owned by neutral in the standing. We must snapshot which territories
-- belonged to the surrendering player in _Start, BEFORE the surrender processes,
-- using game.LatestTurnStanding (which still reflects the previous turn at that
-- point). We then use that snapshot in _End to issue the transfer.

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function getAliveTeammates(game, surrenderingPlayerID)
    local surrenderingPlayer = game.Players[surrenderingPlayerID]
    local myTeam = surrenderingPlayer.Team
    local teammates = {}

    for _, player in pairs(game.Players) do
        if player.ID ~= surrenderingPlayerID
           and player.Team == myTeam
           and player.State == WL.GamePlayerState.Playing then
            teammates[#teammates + 1] = player
        end
    end

    return teammates
end

local function pickTeammate(teammates, mode, standing)
    if #teammates == 0 then return nil end

    if mode == 'Random' then
        return teammates[math.random(1, #teammates)]

    elseif mode == 'LowestIncome' then
        local best, bestIncome = nil, math.huge
        for _, player in ipairs(teammates) do
            local income = player.Income(0, standing, false, false).Total
            if income < bestIncome then bestIncome = income; best = player end
        end
        return best

    else -- HighestIncome (default)
        local best, bestIncome = nil, -1
        for _, player in ipairs(teammates) do
            local income = player.Income(0, standing, false, false).Total
            if income > bestIncome then bestIncome = income; best = player end
        end
        return best
    end
end

local function getTerritoriesOwnedBy(standing, playerID)
    local owned = {}
    for terrID, terrStanding in pairs(standing.Territories) do
        if terrStanding.OwnerPlayerID == playerID then
            owned[#owned + 1] = terrID
        end
    end
    return owned
end

local function tableHasKeys(t)
    for _ in pairs(t) do return true end
    return false
end

-----------------------------------------------------------------------
-- Turn-global state
-- _SRMod_transfers: table keyed by surrendering playerID, value is:
--   { terrIDs = {...}, recipientID = playerID }
-- Populated in _Start (and _Order as fallback); consumed in _End.
-----------------------------------------------------------------------
_SRMod_transfers = {}

-----------------------------------------------------------------------
-- _Start: snapshot everything while the standing is still pre-surrender
-----------------------------------------------------------------------
function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    -- PendingStateTransitions contains surrenders submitted between turns
    -- (instant surrender, the default). At _Start time, LatestTurnStanding
    -- is still the PREVIOUS turn's standing, so the surrendering player
    -- still owns their territories here — before Warzone neutralizes them.
    if game.PendingStateTransitions == nil then return end

    local mode     = (Mod.Settings.TransferMode or 'HighestIncome')
    local standing = game.LatestTurnStanding

    for _, transition in ipairs(game.PendingStateTransitions) do
        if transition.NewState == WL.GamePlayerState.SurrenderAccepted then
            local surrenderingID = transition.PlayerID

            local teammates = getAliveTeammates(game, surrenderingID)
            if #teammates == 0 then
                print('SurrenderRedistribute: ' .. tostring(surrenderingID)
                      .. ' has no alive teammates. Skipping.')
            else
                local recipient        = pickTeammate(teammates, mode, standing)
                local ownedTerritories = getTerritoriesOwnedBy(standing, surrenderingID)

                if #ownedTerritories == 0 then
                    print('SurrenderRedistribute: ' .. tostring(surrenderingID)
                          .. ' owns no territories. Skipping.')
                elseif recipient ~= nil then
                    _SRMod_transfers[surrenderingID] = {
                        terrIDs     = ownedTerritories,
                        recipientID = recipient.ID,
                    }
                    print('SurrenderRedistribute: Snapshotted '
                          .. #ownedTerritories .. ' territories from '
                          .. tostring(surrenderingID) .. ' -> '
                          .. tostring(recipient.ID))
                end
            end
        end
    end
end

-----------------------------------------------------------------------
-- _Order: fallback for vote-required surrender games.
-- In that mode the transition fires as an in-turn order rather than
-- a PendingStateTransition, so _Start won't see it. The hook docs say
-- results are computed but not yet applied when _Order fires, so the
-- territories still belong to the player at this point.
-----------------------------------------------------------------------
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderStateTransition' then return end
    if order.NewState ~= WL.GamePlayerState.SurrenderAccepted then return end

    local surrenderingID = order.PlayerID

    -- Skip if already captured in _Start (shouldn't happen, but be safe).
    if _SRMod_transfers[surrenderingID] then return end

    local mode     = (Mod.Settings.TransferMode or 'HighestIncome')
    local standing = game.LatestTurnStanding

    local teammates        = getAliveTeammates(game, surrenderingID)
    if #teammates == 0 then
        print('SurrenderRedistribute: ' .. tostring(surrenderingID)
              .. ' has no alive teammates. Skipping.')
        return
    end

    local recipient        = pickTeammate(teammates, mode, standing)
    local ownedTerritories = getTerritoriesOwnedBy(standing, surrenderingID)

    if #ownedTerritories > 0 and recipient ~= nil then
        _SRMod_transfers[surrenderingID] = {
            terrIDs     = ownedTerritories,
            recipientID = recipient.ID,
        }
        print('SurrenderRedistribute: (voted) Snapshotted '
              .. #ownedTerritories .. ' territories from '
              .. tostring(surrenderingID) .. ' -> ' .. tostring(recipient.ID))
    end
end

-----------------------------------------------------------------------
-- _End: emit a GameOrderEvent that reassigns the now-neutral territories
-- to the chosen teammate. TerritoryModification.SetOwnerOpt overrides
-- whatever owner Warzone set during the surrender (neutral).
-----------------------------------------------------------------------
function Server_AdvanceTurn_End(game, addNewOrder)
    if not tableHasKeys(_SRMod_transfers) then return end

    for surrenderingID, transfer in pairs(_SRMod_transfers) do
        local mods = {}
        for _, terrID in ipairs(transfer.terrIDs) do
            local mod = WL.TerritoryModification.Create(terrID)
            mod.SetOwnerOpt = transfer.recipientID
            mods[#mods + 1] = mod
        end

        local surrenderingName = game.Players[surrenderingID].DisplayName(nil, false)
        local recipientName    = game.Players[transfer.recipientID].DisplayName(nil, false)
        local msg = surrenderingName .. ' surrendered. Their '
                    .. #transfer.terrIDs
                    .. ' territories have been transferred to teammate '
                    .. recipientName .. '.'

        local event = WL.GameOrderEvent.Create(
            surrenderingID,
            msg,
            nil,   -- visible to everyone
            mods,
            nil,   -- no resource changes
            nil    -- no income mods
        )

        addNewOrder(event)

        print('SurrenderRedistribute: Transferred ' .. #transfer.terrIDs
              .. ' territories from ' .. surrenderingName
              .. ' to ' .. recipientName)
    end
end
