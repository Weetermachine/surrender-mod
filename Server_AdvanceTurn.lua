-- Server_AdvanceTurn.lua (KEY DUMP VERSION)
-- game is a plain table - dump all its top-level keys

_SRMod_transfers = {}

function Server_AdvanceTurn_Start(game, addNewOrder)
    _SRMod_transfers = {}

    local keys = ''
    for k, v in pairs(game) do
        keys = keys .. k .. '(' .. type(v) .. '),'
    end

    error('SR_KEYS | ' .. keys)
end

function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
end

function Server_AdvanceTurn_End(game, addNewOrder)
end
