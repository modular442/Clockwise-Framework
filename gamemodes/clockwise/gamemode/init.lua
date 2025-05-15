--[[
    © 2025 modular442 (Modular Content). All rights reserved. 
    Something that you will never be. --]]

local startTime = os.clock()
local msgColor = Color(0, 255, 100, 255)

DeriveGamemode('sandbox')

local isReload = Clockwise and true
if isReload then
	MsgC(msgColor, '[Clockwise] Change detected! Refreshing...\n')
	table.Merge(Clockwise, GM)
else
	MsgC(msgColor, '[Clockwise] Framework is initializing...\n')
    ---@class Clockwise: GM
	Clockwise = GM
end

Clockwise.Name = 'Clockwise: HL2 RP'
Clockwise.Author = "Modular"
Clockwise.Email = "modular442@gmail.com"
Clockwise.Website = "https://discord.gg/Cenb5sSMvB"

include('clockwise/framework/_clockwise.lua')

AddCSLuaFile('cl_init.lua')
AddCSLuaFile('clockwise/framework/_clockwise.lua')

if isReload then
	Clockwise:Initialize()
	MsgC(msgColor, '[Clockwise] Server-side AutoRefresh handled in ' .. math.Round(os.clock() - startTime, 3) .. ' second(s)\n')
else
	MsgC(msgColor, '[Clockwise] Framework loading took ' .. math.Round(os.clock() - startTime, 3) .. ' second(s)\n')
end

table.Merge(GM, Clockwise)