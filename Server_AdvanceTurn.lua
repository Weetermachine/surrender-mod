-- Server_AdvanceTurn.lua
-- Detects surrendering players via player.Surrendered flag in _Start,
-- snapshots their territories from PreviousTurnStanding (before Warzone
-- neutralizes them), picks a teammate, then reassigns in _End.

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function getAliveTeammates(players, surrenderingPlayerID, surrenderingTeam)
    local teammates = {}
    for _, player in pairs(players) do
        if player.ID ~= surrenderingPlayerID
           and player.Team == surrenderingTeam
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
    for terrID, ts in pairs(standing.Territories) do
        if ts.OwnerPlayerID == playerID then
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
-- _Start: detect surrenders and snapshot territories from previous turn
-----------------------------------------------------------------------
function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    local sg      = game.ServerGame
    local players = game.Game.Players
    local mode    = (Mod.Settings.TransferMode or 'HighestIncome')

    -- PreviousTurnStanding still has the surrendering player's territories
    -- because Warzone hasn't neutralized them yet relative to that snapshot.
    local prevStanding = sg.PreviousTurnStanding

    for _, player in pairs(players) do
        if player.Surrendered == true then
            local surrenderingID = player.ID
            local teammates = getAliveTeammates(players, surrenderingID, player.Team)

            if #teammates == 0 then
                -- No alive teammates, do nothing
            else
                local recipient        = pickTeammate(teammates, mode, prevStanding)
                local ownedTerritories = getTerritoriesOwnedBy(prevStanding, surrenderingID)

                if #ownedTerritories > 0 and recipient ~= nil then
                    _SRMod_transfers[surrenderingID] = {
                        terrIDs     = ownedTerritories,
                        recipientID = recipient.ID,
                    }
                end
            end
        end
    end
end

-----------------------------------------------------------------------
-- _Order: no-op (surrender doesn't appear as an in-turn order)
-----------------------------------------------------------------------
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
end

-----------------------------------------------------------------------
-- _End: reassign the now-neutral territories to the chosen teammate
-----------------------------------------------------------------------
function Server_AdvanceTurn_End(game, addNewOrder)
    if not tableHasKeys(_SRMod_transfers) then return end

    local players = game.Game.Players

    for surrenderingID, transfer in pairs(_SRMod_transfers) do
        local mods = {}
        for _, terrID in ipairs(transfer.terrIDs) do
            local mod = WL.TerritoryModification.Create(terrID)
            mod.SetOwnerOpt = transfer.recipientID
            mods[#mods + 1] = mod
        end

        local surrenderingName = players[surrenderingID].DisplayName(nil, false)
        local recipientName    = players[transfer.recipientID].DisplayName(nil, false)
        local msg = surrenderingName .. ' surrendered. Their '
                    .. #transfer.terrIDs
                    .. ' territories have been transferred to teammate '
                    .. recipientName .. '.'

        addNewOrder(WL.GameOrderEvent.Create(
            surrenderingID,
            msg,
            nil,  -- visible to everyone
            mods,
            nil,
            nil
        ))
    end
end
