-- © 2025 modular442. All rights reserved.
require('mysqloo')

local isLoad = Clockwise and true
if isLoad then
    print('[Clockwise] fsr')
else
    print('[Clockwise] fsl')
    ---@class Clockwise: GM
    Clockwise = GM
end

AddCSLuaFile('cl_init.lua')
AddCSLuaFile('clockwise/framework/_clockwise.lua')
include('clockwise/framework/_clockwise.lua')