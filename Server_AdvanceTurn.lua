-- Server_AdvanceTurn.lua (OBJECT DUMP VERSION)
-- Crashes immediately to show us exactly what the game argument contains.

_SRMod_transfers = {}

function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    local info = 'game_type=' .. type(game)

    -- If it's a proxy object, read its metadata
    if type(game) == 'table' then
        local pt = game.proxyType
        info = info .. ' proxyType=' .. tostring(pt)

        local rk = game.readableKeys
        if rk ~= nil then
            local keys = ''
            for _, k in ipairs(rk) do keys = keys .. k .. ',' end
            info = info .. ' readableKeys=[' .. keys .. ']'
        else
            info = info .. ' readableKeys=NIL'
        end
    end

    error('SR_DUMP | ' .. info)
end

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
