-- Client_PresentSettingsUI.lua
-- Displays the currently active transfer mode in the in-game Game Settings panel.

function Client_PresentSettingsUI(rootParent)
    local mode = Mod.Settings.TransferMode or 'HighestIncome'

    local labels = {
        HighestIncome = 'Highest Income Teammate',
        LowestIncome  = 'Lowest Income Teammate',
        Random        = 'Random Teammate',
    }

    local vert = UI.CreateVerticalLayoutGroup(rootParent)

    UI.CreateLabel(vert)
        .SetText('Surrender Redistribute Mod')
        .SetColor('#FFD700')

    UI.CreateLabel(vert)
        .SetText('Surrender territories go to: ' .. (labels[mode] or mode))
end
