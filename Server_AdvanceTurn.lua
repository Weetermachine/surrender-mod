-- Server_AdvanceTurn.lua (CRASH DIAGNOSTIC - CORRECT PATHS)
-- Confirmed structure: game.Game.Players, game.ServerGame.PendingStateTransitions,
-- game.ServerGame.LatestTurnStanding
-- Only crashes when a surrender is detected.

_SRMod_transfers = {}

function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    local sg = game.ServerGame
    local gw = game.Game

    local surrenderFound = false
    local playerInfo = ''
    for _, p in pairs(gw.Players) do
        playerInfo = playerInfo .. '[pid=' .. tostring(p.ID)
                     .. ' state=' .. tostring(p.State)
                     .. ' surrendered=' .. tostring(p.Surrendered)
                     .. ' team=' .. tostring(p.Team) .. ']'
        if p.Surrendered == true
           or p.State == WL.GamePlayerState.SurrenderAccepted then
            surrenderFound = true
        end
    end

    local pstInfo = 'PST='
    if sg.PendingStateTransitions == nil then
        pstInfo = pstInfo .. 'NIL'
    else
        local pstCount = 0
        for _, t in ipairs(sg.PendingStateTransitions) do
            pstCount = pstCount + 1
            pstInfo = pstInfo .. '[pid=' .. tostring(t.PlayerID)
                      .. ' state=' .. tostring(t.NewState) .. ']'
            if t.NewState == WL.GamePlayerState.SurrenderAccepted then
                surrenderFound = true
            end
        end
        if pstCount == 0 then pstInfo = pstInfo .. 'EMPTY' end
    end

    if surrenderFound then
        local standing = sg.LatestTurnStanding
        local terrInfo = ''
        for _, p in pairs(gw.Players) do
            if p.Surrendered == true or p.State == WL.GamePlayerState.SurrenderAccepted then
                local count = 0
                for _, ts in pairs(standing.Territories) do
                    if ts.OwnerPlayerID == p.ID then count = count + 1 end
                end
                terrInfo = terrInfo .. '[pid=' .. tostring(p.ID) .. '_owns=' .. count .. ']'
            end
        end
        if sg.PendingStateTransitions ~= nil then
            for _, t in ipairs(sg.PendingStateTransitions) do
                if t.NewState == WL.GamePlayerState.SurrenderAccepted then
                    local count = 0
                    for _, ts in pairs(standing.Territories) do
                        if ts.OwnerPlayerID == t.PlayerID then count = count + 1 end
                    end
                    terrInfo = terrInfo .. '[pst_pid=' .. tostring(t.PlayerID) .. '_owns=' .. count .. ']'
                end
            end
        end

        error('SR_DIAG | SURRENDER_ENUM=' .. tostring(WL.GamePlayerState.SurrenderAccepted)
              .. ' | ' .. pstInfo
              .. ' | PLAYERS=' .. playerInfo
              .. ' | TERR_AT_START=' .. terrInfo)
    end
end

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderStateTransition' then return end
    if order.NewState ~= WL.GamePlayerState.SurrenderAccepted then return end

    error('SR_DIAG_ORDER | SurrenderAccepted: pid=' .. tostring(order.PlayerID)
          .. ' newState=' .. tostring(order.NewState)
          .. ' SURRENDER_ENUM=' .. tostring(WL.GamePlayerState.SurrenderAccepted))
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
