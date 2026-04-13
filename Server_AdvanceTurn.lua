-- Server_AdvanceTurn.lua (CRASH DIAGNOSTIC VERSION 3)
-- Only crashes when a SurrenderAccepted transition is actually detected.

_SRMod_transfers = {}

function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    local surrenderFound = false
    local playerInfo = ''
    for _, p in pairs(game.Players) do
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
    if game.PendingStateTransitions == nil then
        pstInfo = pstInfo .. 'NIL'
    else
        local pstCount = 0
        for _, t in ipairs(game.PendingStateTransitions) do
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
        local standing = game.LatestTurnStanding
        local terrInfo = ''
        for _, p in pairs(game.Players) do
            if p.Surrendered == true or p.State == WL.GamePlayerState.SurrenderAccepted then
                local count = 0
                for _, ts in pairs(standing.Territories) do
                    if ts.OwnerPlayerID == p.ID then count = count + 1 end
                end
                terrInfo = terrInfo .. '[pid=' .. tostring(p.ID) .. '_owns=' .. count .. ']'
            end
        end
        if game.PendingStateTransitions ~= nil then
            for _, t in ipairs(game.PendingStateTransitions) do
                if t.NewState == WL.GamePlayerState.SurrenderAccepted then
                    local count = 0
                    for _, ts in pairs(standing.Territories) do
                        if ts.OwnerPlayerID == t.PlayerID then count = count + 1 end
                    end
                    terrInfo = terrInfo .. '[pst_pid=' .. tostring(t.PlayerID) .. '_owns=' .. count .. ']'
                end
            end
        end

        error('SR_DIAG_START | SURRENDER_ENUM=' .. tostring(WL.GamePlayerState.SurrenderAccepted)
              .. ' | ' .. pstInfo
              .. ' | PLAYERS=' .. playerInfo
              .. ' | TERR_AT_START=' .. terrInfo)
    end
end

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if order.proxyType ~= 'GameOrderStateTransition' then return end
    -- Only crash if this is specifically a SurrenderAccepted transition
    if order.NewState ~= WL.GamePlayerState.SurrenderAccepted then return end

    error('SR_DIAG_ORDER | SurrenderAccepted transition: pid=' .. tostring(order.PlayerID)
          .. ' newState=' .. tostring(order.NewState)
          .. ' SURRENDER_ENUM=' .. tostring(WL.GamePlayerState.SurrenderAccepted))
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
