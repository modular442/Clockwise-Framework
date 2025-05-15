--[[
    © 2025 modular442 (Modular Content). All rights reserved. 
    Something that you will never be. --]]

---@class cw
---@field client fun(path: string): string @ Импортирует файл только на клиенте и возвращает путь
---@field server fun(path: string): string @ Импортирует файл только на сервере и возвращает путь
---@field shared fun(path: string): string @ Импортирует shared файл и возвращает путь
cw = cw or {}

---Импортирует файл только на клиенте: вызывает `AddCSLuaFile` на сервере и `include` на клиенте.
---@param path string @ Путь до файла, относительно директории gamemodes/
---@return string @ Тот же путь, который был передан (для читаемости или логов)
function cw.client(path)
    path = path .. '.lua'
    if SERVER then AddCSLuaFile(path) end
    if CLIENT then include(path) end
    return path
end

---Импортирует файл только на сервере: вызывает `include`, только если это сервер.
---@param path string @ Путь до файла, относительно директории gamemodes/
---@return string @ Тот же путь, который был передан (для читаемости или логов)
function cw.server(path)
    path = path .. '.lua'
    if SERVER then include(path) end
    return path
end

---Импортирует файл в shared-режиме: вызывает `AddCSLuaFile` на сервере и `include` на обеих сторонах.
---@param path string @ Путь до файла, относительно директории gamemodes/
---@return string @ Тот же путь, который был передан (для читаемости или логов)
function cw.shared(path)
    path = path .. '.lua'
    if SERVER then AddCSLuaFile(path) end
    include(path)
    return path
end

cw.shared('clockwise/modules/include')
cw.include.directory('clockwise/modules')

cw.hook.On('clockwise.loaded', 'clockwise.loaded', function (...)
    cw.logger.complete('Фреймворк инициализирован.')
end)

cw.hook.Trigger('clockwise.loaded')