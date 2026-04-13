-- Client_PresentConfigureUI.lua
-- Shows radio buttons so the host can pick how surrendered territories are distributed.

function Client_PresentConfigureUI(rootParent)
    local vert = UI.CreateVerticalLayoutGroup(rootParent)

    UI.CreateLabel(vert)
        .SetText('Surrender Redistribute Mod')
        .SetColor('#FFD700')

    UI.CreateLabel(vert)
        .SetText('When a player surrenders, their territories are given to a teammate.\nChoose how the recipient teammate is selected:')

    local group = UI.CreateRadioButtonGroup(vert)

    local rb1 = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Highest Income Teammate')

    local rb2 = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Lowest Income Teammate')

    local rb3 = UI.CreateRadioButton(vert)
        .SetGroup(group)
        .SetText('Random Teammate')

    -- Default or restore saved setting
    local saved = Mod.Settings.TransferMode
    if saved == 'LowestIncome' then
        rb2.SetIsChecked(true)
    elseif saved == 'Random' then
        rb3.SetIsChecked(true)
    else
        -- Default: HighestIncome
        rb1.SetIsChecked(true)
    end

    -- Store references in globals so SaveConfigureUI can read them.
    -- Global state IS valid within a single client session (same hook chain).
    _SRMod_rb1 = rb1
    _SRMod_rb2 = rb2
    _SRMod_rb3 = rb3
end
