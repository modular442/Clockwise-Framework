--[[
    © 2025 modular442 (Modular Content). All rights reserved. 
    Something that you will never be. --]]

local isLoad = Clockwise and true
if isLoad then
    print('[Clockwise] fsr')
else
    print('[Clockwise] fsl')
    ---@class Clockwise: GM
    Clockwise = GM
end

include('clockwise/framework/_clockwise.lua')