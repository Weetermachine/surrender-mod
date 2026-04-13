-- Client_SaveConfigureUI.lua
-- Persists the chosen surrender redistribution mode into Mod.Settings.

function Client_SaveConfigureUI(alert, addCard)
    if _SRMod_rb2 ~= nil and _SRMod_rb2.GetIsChecked() then
        Mod.Settings.TransferMode = 'LowestIncome'
    elseif _SRMod_rb3 ~= nil and _SRMod_rb3.GetIsChecked() then
        Mod.Settings.TransferMode = 'Random'
    else
        Mod.Settings.TransferMode = 'HighestIncome'
    end
end
