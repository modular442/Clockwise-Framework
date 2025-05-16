---@class cw.derma
cw.derma = cw.derma or {}
---@class cw.derma.menu
cw.derma.menu = cw.derma.menu or {}

if not cw.derma then return end

cw.hook.On('ScoreboardShow', 'cw.derma.menu.show', function()
    cw.derma.menu.showMenu()
end)

cw.hook.On('ScoreboardHide', 'cw.derma.menu.hide', function()
    cw.derma.menu.hideMenu()
end)