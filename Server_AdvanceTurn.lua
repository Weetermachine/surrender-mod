-- Server_AdvanceTurn.lua (CRASH DIAGNOSTIC VERSION)
-- Only crashes when a surrender is detected, so normal turns advance fine.
-- Read the crash message in Mod Development Console after surrendering.

_SRMod_transfers = {}

function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    -- Check for any player who has surrendered via Surrendered flag or state
    -- as a broad net, then report everything we know
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

    -- Also check PendingStateTransitions
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
        -- Count territories per surrendering player in the standing
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
        -- Also check PendingStateTransitions players
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

    -- Crash with details any time we see any state transition, so we can
    -- compare the state value to SurrenderAccepted
    error('SR_DIAG_ORDER | StateTransition: pid=' .. tostring(order.PlayerID)
          .. ' newState=' .. tostring(order.NewState)
          .. ' SurrenderAccepted=' .. tostring(WL.GamePlayerState.SurrenderAccepted))
end

function Server_AdvanceTurn_End(game, addNewOrder)
    -- No-op; we only care about _Start and _Order for diagnosis
end
