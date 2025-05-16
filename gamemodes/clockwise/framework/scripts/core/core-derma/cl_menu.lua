---@diagnostic disable: inject-field

if not cw.derma.menu then return end

cw.hook.On("ScoreboardShow", "ShowMenu", function(...)
    cw.derma.menu.showMenu()
    return true
end)

cw.hook.On("ScoreboardHide", "HideMenu", function(...)
    cw.derma.menu.hideMenu()
    return true
end)

local frameRef

function cw.derma.menu.showMenu()
    if IsValid(frameRef) then
        frameRef:SetVisible(true)
        return
    end

    ---@type DFrame
    local frame = vgui.Create('DFrame')
    frame:SetPos(ScrW() / 2, ScrH() / 2)
    frame:SetSize(300, 250)
    frame:SetTitle('Меню игрового режима')
    frame:SetDraggable(false)
    frame:ShowCloseButton(true)
    frame:MakePopup()

    ---@type DButton
    local button = vgui.Create('DButton', frame)
    button:SetText('Вывести имя локального игрока')
    button:SetPos(25, 50)
    button:SetSize(250, 30)
    button.DoClick = function()
        cw.logger.msg(LocalPlayer():Nick())
    end

    frameRef = frame
end

function cw.derma.menu.hideMenu()
    if IsValid(frameRef) then
        frameRef:SetVisible(false)
    end
end