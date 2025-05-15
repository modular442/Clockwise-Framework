--[[
    © 2025 modular442 (Modular Content). All rights reserved. 
    Something that you will never be. --]]

---@class cw.include
---@field prefixed fun(path: string): string @ Импортирует все cl_/sv_/sh_ файлы из директории и возвращает путь
---@field libraries fun(path: string): string @ Рекурсивно импортирует все lua-файлы из директории и подпапок и возвращает путь
---@field modules fun(path: string, priority: string[]): string @ Импортирует все модули с возможностью задания приоритета
cw.include = cw.include or {}

---Импортирует файлы с префиксами cl_/sv_/sh_ внутри указанной директории.
---@param path string @ Путь до директории, относительно gamemodes/
---@return string @ Тот же путь, который был передан (для читаемости или логов)
function cw.include.prefixed(path)
    local files = file.Find(path .. "/*.lua", "LUA")

    for _, fileName in ipairs(files) do
        local fullPath = path .. "/" .. fileName
        if string.StartsWith(fileName, "cl_") then
            cw.client(fullPath:gsub("%.lua$", ""))
        elseif string.StartsWith(fileName, "sv_") then
            cw.server(fullPath:gsub("%.lua$", ""))
        elseif string.StartsWith(fileName, "sh_") then
            cw.shared(fullPath:gsub("%.lua$", ""))
        end
    end

    return path
end

---Рекурсивно импортирует все lua-файлы из директории и подпапок, используя префиксы cl_, sv_, sh_ и функции cw.client, cw.server, cw.shared.
---@param path string @ Путь до директории, относительно gamemodes/
---@return string @ Тот же путь, который был передан (для читаемости или логов)
function cw.include.libraries(path)
    local files, dirs = file.Find(path .. "/*", "LUA")

    -- Сначала файлы
    for _, fileName in ipairs(files) do
        local fullPath = path .. "/" .. fileName

        if string.find(path, "/server$") then
            -- Если мы уже в папке server — все файлы серверные
            cw.server(fullPath:gsub("%.lua$", ""))
        elseif string.find(path, "/client$") then
            -- Если в client — клиентские файлы
            cw.client(fullPath:gsub("%.lua$", ""))
        else
            -- Иначе по префиксам или shared
            if string.StartsWith(fileName, "cl_") then
                cw.client(fullPath:gsub("%.lua$", ""))
            elseif string.StartsWith(fileName, "sv_") then
                cw.server(fullPath:gsub("%.lua$", ""))
            elseif string.StartsWith(fileName, "sh_") then
                cw.shared(fullPath:gsub("%.lua$", ""))
            else
                cw.shared(fullPath:gsub("%.lua$", ""))
            end
        end
    end

    -- Потом папки, рекурсивно
    for _, dirName in ipairs(dirs) do
        cw.include.libraries(path .. "/" .. dirName)
    end

    return path
end


---Импортирует все файлы и папки из указанной директории согласно приоритетам,
---автоматически определяя, как их загружать: cl_ - клиент, sv_ - сервер, sh_ или без префикса - shared.
---Также учитывает файлы с именами client.lua, server.lua, shared.lua для определения типа.
---Приоритет — массив фильтров и порядок, где '!prefix' — файлы/папки, начинающиеся с prefix,
---'*' — все остальные.
---@param path string Путь до директории, относительно gamemodes/
---@param priority string[] Приоритеты загрузки
---@return string Возвращает тот же путь
function cw.include.modules(path, priority)
    local files, dirs = file.Find(path .. "/*", "LUA")
    local loaded = {}

    local function matchesPriority(name, pattern)
        if pattern:sub(1,1) == '!' then
            local prefix = pattern:sub(2)
            return name:sub(1, #prefix) == prefix
        elseif pattern == '*' then
            return false
        else
            return name == pattern
        end
    end

    local function loadItem(fullPath)
        local fileName = fullPath:match("([^/\\]+)%.lua$") or ""
        
        if string.find(fullPath, "/_client/") or string.StartsWith(fileName, "cl_") or fileName == "client" then
            cw.client(fullPath:gsub("%.lua$", ""))
        elseif string.find(fullPath, "/_server/") or string.StartsWith(fileName, "sv_") or fileName == "server" then
            cw.server(fullPath:gsub("%.lua$", ""))
        else
            -- Всё остальное — shared
            cw.shared(fullPath:gsub("%.lua$", ""))
        end
    end

    local function loadName(name)
        local fullPath = path .. "/" .. name
        if file.IsDir(fullPath, "LUA") then
            cw.include.modules(fullPath, priority)
        else
            loadItem(fullPath)
        end
        loaded[name] = true
    end

    -- 1. Сначала загружаем все, что подходит под приоритет (кроме '*')
    for _, pattern in ipairs(priority) do
        if pattern ~= '*' then
            for _, name in ipairs(files) do
                if not loaded[name] and matchesPriority(name, pattern) then
                    loadName(name)
                end
            end
            for _, name in ipairs(dirs) do
                if not loaded[name] and matchesPriority(name, pattern) then
                    loadName(name)
                end
            end
        end
    end

    -- 2. Потом грузим всё остальное, если '*' есть в приоритете
    if table.HasValue(priority, '*') then
        for _, name in ipairs(files) do
            if not loaded[name] then
                loadName(name)
            end
        end
        for _, name in ipairs(dirs) do
            if not loaded[name] then
                loadName(name)
            end
        end
    end

    return path
end