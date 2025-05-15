---@class cw.include
---@field prefixed fun(path: string): string @ Импортирует все cl_/sv_/sh_ файлы из директории и возвращает путь
---@field directory fun(path: string): string @ Рекурсивно импортирует все lua-файлы из директории и подпапок и возвращает путь
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
function cw.include.directory(path)
    local files, dirs = file.Find(path .. "/*", "LUA")

    -- Сначала файлы
    for _, fileName in ipairs(files) do
        local fullPath = path .. "/" .. fileName
        if string.StartsWith(fileName, "cl_") then
            cw.client(fullPath:gsub("%.lua$", ""))
        elseif string.StartsWith(fileName, "sv_") then
            cw.server(fullPath:gsub("%.lua$", ""))
        elseif string.StartsWith(fileName, "sh_") then
            cw.shared(fullPath:gsub("%.lua$", ""))
        else
            -- Без префикса считаем shared
            cw.shared(fullPath:gsub("%.lua$", ""))
        end
    end

    -- Потом папки, рекурсивно
    for _, dirName in ipairs(dirs) do
        cw.include.directory(path .. "/" .. dirName)
    end

    return path
end