-- Server_AdvanceTurn.lua (DEBUG VERSION)
-- Verbose logging at every step to diagnose why transfers aren't working.
-- Check output in the Mod Development Console -> View Mod Output.

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
    else
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
-----------------------------------------------------------------------
_SRMod_transfers = {}

-----------------------------------------------------------------------
-- _Start
-----------------------------------------------------------------------
function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}
    print('SR_DEBUG _Start called')

    -- Log all players and their states
    print('SR_DEBUG Players:')
    for _, player in pairs(game.Players) do
        print('SR_DEBUG   player=' .. tostring(player.ID)
              .. ' state=' .. tostring(player.State)
              .. ' team=' .. tostring(player.Team)
              .. ' surrendered=' .. tostring(player.Surrendered))
    end

    -- Log PendingStateTransitions
    if game.PendingStateTransitions == nil then
        print('SR_DEBUG PendingStateTransitions is nil')
        return
    end

    local pstCount = 0
    for _, t in ipairs(game.PendingStateTransitions) do pstCount = pstCount + 1 end
    print('SR_DEBUG PendingStateTransitions count=' .. pstCount)

    for i, transition in ipairs(game.PendingStateTransitions) do
        print('SR_DEBUG   PST[' .. i .. '] playerID=' .. tostring(transition.PlayerID)
              .. ' newState=' .. tostring(transition.NewState)
              .. ' SurrenderAccepted=' .. tostring(WL.GamePlayerState.SurrenderAccepted))
    end

    local mode = (Mod.Settings.TransferMode or 'HighestIncome')
    print('SR_DEBUG TransferMode=' .. mode)

    local standing = game.LatestTurnStanding
    if standing == nil then
        print('SR_DEBUG LatestTurnStanding is nil!')
        return
    end
    print('SR_DEBUG LatestTurnStanding ok')

    for _, transition in ipairs(game.PendingStateTransitions) do
        if transition.NewState == WL.GamePlayerState.SurrenderAccepted then
            local surrenderingID = transition.PlayerID
            print('SR_DEBUG Found surrender: ' .. tostring(surrenderingID))

            local ownedTerritories = getTerritoriesOwnedBy(standing, surrenderingID)
            print('SR_DEBUG   Territories owned at _Start: ' .. #ownedTerritories)

            local teammates = getAliveTeammates(game, surrenderingID)
            print('SR_DEBUG   Alive teammates: ' .. #teammates)
            for _, tm in ipairs(teammates) do
                print('SR_DEBUG     teammate=' .. tostring(tm.ID))
            end

            if #teammates == 0 then
                print('SR_DEBUG   No teammates, skipping.')
            elseif #ownedTerritories == 0 then
                print('SR_DEBUG   No territories to transfer.')
            else
                local recipient = pickTeammate(teammates, mode, standing)
                if recipient == nil then
                    print('SR_DEBUG   pickTeammate returned nil!')
                else
                    print('SR_DEBUG   Recipient: ' .. tostring(recipient.ID))
                    _SRMod_transfers[surrenderingID] = {
                        terrIDs     = ownedTerritories,
                        recipientID = recipient.ID,
                    }
                end
            end
        end
    end

    -- Log what was stored
    local count = 0
    for _ in pairs(_SRMod_transfers) do count = count + 1 end
    print('SR_DEBUG _Start done, transfers queued: ' .. count)
end

-----------------------------------------------------------------------
-- _Order: fallback for vote-required surrenders
-----------------------------------------------------------------------
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    print('SR_DEBUG _Order: proxyType=' .. tostring(order.proxyType)
          .. ' playerID=' .. tostring(order.PlayerID))

    if order.proxyType ~= 'GameOrderStateTransition' then return end

    print('SR_DEBUG _Order StateTransition: newState=' .. tostring(order.NewState)
          .. ' SurrenderAccepted=' .. tostring(WL.GamePlayerState.SurrenderAccepted))

    if order.NewState ~= WL.GamePlayerState.SurrenderAccepted then return end

    local surrenderingID = order.PlayerID
    if _SRMod_transfers[surrenderingID] then
        print('SR_DEBUG _Order: already captured in _Start, skipping')
        return
    end

    print('SR_DEBUG _Order: handling voted surrender for ' .. tostring(surrenderingID))

    local mode     = (Mod.Settings.TransferMode or 'HighestIncome')
    local standing = game.LatestTurnStanding

    local ownedTerritories = getTerritoriesOwnedBy(standing, surrenderingID)
    print('SR_DEBUG _Order: territories owned=' .. #ownedTerritories)

    local teammates = getAliveTeammates(game, surrenderingID)
    print('SR_DEBUG _Order: alive teammates=' .. #teammates)

    if #teammates == 0 or #ownedTerritories == 0 then return end

    local recipient = pickTeammate(teammates, mode, standing)
    if recipient == nil then
        print('SR_DEBUG _Order: pickTeammate returned nil')
        return
    end

    print('SR_DEBUG _Order: recipient=' .. tostring(recipient.ID))
    _SRMod_transfers[surrenderingID] = {
        terrIDs     = ownedTerritories,
        recipientID = recipient.ID,
    }
end

-----------------------------------------------------------------------
-- _End
-----------------------------------------------------------------------
function Server_AdvanceTurn_End(game, addNewOrder)
    print('SR_DEBUG _End called')

    local count = 0
    for _ in pairs(_SRMod_transfers) do count = count + 1 end
    print('SR_DEBUG _End: transfers to apply: ' .. count)

    if not tableHasKeys(_SRMod_transfers) then
        print('SR_DEBUG _End: nothing to do')
        return
    end

    for surrenderingID, transfer in pairs(_SRMod_transfers) do
        print('SR_DEBUG _End: processing surrender of ' .. tostring(surrenderingID)
              .. ' -> ' .. tostring(transfer.recipientID)
              .. ' (' .. #transfer.terrIDs .. ' territories)')

        -- Log what those territories look like NOW (after Warzone processed surrender)
        local standing = game.LatestTurnStanding
        for _, terrID in ipairs(transfer.terrIDs) do
            local ts = standing.Territories[terrID]
            print('SR_DEBUG   terr=' .. tostring(terrID)
                  .. ' currentOwner=' .. tostring(ts.OwnerPlayerID))
        end

        local mods = {}
        for _, terrID in ipairs(transfer.terrIDs) do
            local mod = WL.TerritoryModification.Create(terrID)
            mod.SetOwnerOpt = transfer.recipientID
            mods[#mods + 1] = mod
        end

        print('SR_DEBUG _End: created ' .. #mods .. ' TerritoryModifications')

        local surrenderingName = game.Players[surrenderingID].DisplayName(nil, false)
        local recipientName    = game.Players[transfer.recipientID].DisplayName(nil, false)
        local msg = surrenderingName .. ' surrendered. Their '
                    .. #transfer.terrIDs
                    .. ' territories have been transferred to teammate '
                    .. recipientName .. '.'

        local event = WL.GameOrderEvent.Create(
            surrenderingID,
            msg,
            nil,
            mods,
            nil,
            nil
        )

        print('SR_DEBUG _End: calling addNewOrder')
        addNewOrder(event)
        print('SR_DEBUG _End: addNewOrder done')
    end

    print('SR_DEBUG _End complete')
end
