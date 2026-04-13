-- Server_AdvanceTurn.lua (CRASH DIAGNOSTIC VERSION)
-- Deliberately crashes with a descriptive message to surface debug info
-- in the Mod Development Console crash report.

_SRMod_transfers = {}

function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    -- Build a status string we can read in the crash report
    local info = 'START: '

    -- Check PendingStateTransitions
    if game.PendingStateTransitions == nil then
        error('SR_DIAG | PendingStateTransitions=NIL')
    end

    local pst = game.PendingStateTransitions
    local pstCount = 0
    local pstDetails = ''
    for _, t in ipairs(pst) do
        pstCount = pstCount + 1
        pstDetails = pstDetails .. '[pid=' .. tostring(t.PlayerID)
                     .. ' state=' .. tostring(t.NewState) .. ']'
    end
    info = info .. 'PST_COUNT=' .. pstCount .. ' PST=' .. pstDetails

    -- Check player states
    local playerInfo = ''
    for _, p in pairs(game.Players) do
        playerInfo = playerInfo .. '[pid=' .. tostring(p.ID)
                     .. ' state=' .. tostring(p.State)
                     .. ' surrendered=' .. tostring(p.Surrendered)
                     .. ' team=' .. tostring(p.Team) .. ']'
    end
    info = info .. ' PLAYERS=' .. playerInfo

    -- Check SurrenderAccepted enum value
    info = info .. ' SURRENDER_ENUM=' .. tostring(WL.GamePlayerState.SurrenderAccepted)

    -- Check LatestTurnStanding
    local standing = game.LatestTurnStanding
    if standing == nil then
        error('SR_DIAG | ' .. info .. ' | LatestTurnStanding=NIL')
    end

    -- If there are any pending surrenders, report territory ownership
    local terrInfo = ''
    for _, t in ipairs(pst) do
        if t.NewState == WL.GamePlayerState.SurrenderAccepted then
            local count = 0
            for _, ts in pairs(standing.Territories) do
                if ts.OwnerPlayerID == t.PlayerID then count = count + 1 end
            end
            terrInfo = terrInfo .. '[surrendering=' .. tostring(t.PlayerID)
                       .. ' owns=' .. count .. '_territories_at_Start]'
        end
    end

    -- Always crash so we can read the output
    error('SR_DIAG | ' .. info .. ' | TERR_AT_START=' .. terrInfo)
end

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    -- Only crash if we see a StateTransition, to capture that info too
    if order.proxyType == 'GameOrderStateTransition' then
        error('SR_DIAG | ORDER StateTransition: pid=' .. tostring(order.PlayerID)
              .. ' newState=' .. tostring(order.NewState)
              .. ' SurrenderAccepted=' .. tostring(WL.GamePlayerState.SurrenderAccepted))
    end
end

function Server_AdvanceTurn_End(game, addNewOrder)
    -- Only reached if _Start didn't crash, shouldn't happen
    error('SR_DIAG | _End reached unexpectedly')
end
