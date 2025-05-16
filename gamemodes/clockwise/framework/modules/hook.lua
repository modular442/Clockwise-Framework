--[[
    © 2025 modular442 (Modular Content). All rights reserved. 
    Something that you will never be. --]]

---@class cw.hook
---@field On fun(eventName: string, id: string, callback: fun(...): any) @ Добавляет обработчик события
---@field Off fun(eventName: string, id: string) @ Убирает обработчик события
---@field Trigger fun(eventName: string, ...) : table @ Запускает событие, возвращает массив результатов
cw.hook = cw.hook or {}

local internalHooks = {} -- таблица { [hookName] = true }, чтобы подписаться один раз

local hooks = {} -- { [hookName] = { [id] = func } }

---Добавляет функцию-обработчик на указанный хук
---@param hookName string @ Имя хука, например "PlayerSpawn"
---@param id string @ Уникальный идентификатор обработчика (для удаления)
---@param func function @ Функция-обработчик, получает vararg аргументы
function cw.hook.On(hookName, id, func)
    if not hooks[hookName] then
        hooks[hookName] = {}

        -- Подписываемся на нативный хук при первом вызове для этого имени
        hook.Add(hookName, "cw_hook_"..hookName, function(...)
            -- При вызове нативного хука запускаем все обработчики
            for _, f in pairs(hooks[hookName]) do
                local ok, ret = pcall(f, ...)
                if not ok then
                    cw.logger.createCustomColorMsg('cw.hook', CFG.colors.error, "Ошибка в хук-функции '%s': %s", hookName, ret)
                else
                    if ret ~= nil then
                        return ret -- возвращаем любое значение, которое вернул обработчик, но не nil
                    end
                end
            end
        end)

        cw.logger.dmsg("Создан нативный хук для '%s'", hookName)
    end

    hooks[hookName][id] = func
    cw.logger.dmsg("Добавлен обработчик '%s' для хука '%s'", id, hookName)
end

---Удаляет функцию-обработчик из хука по ID
---@param hookName string @ Имя хука
---@param id string @ Идентификатор обработчика
function cw.hook.Off(hookName, id)
    if hooks[hookName] then
        hooks[hookName][id] = nil
        cw.logger.dmsg("Удалён обработчик '%s' из хука '%s'", id, hookName)
        -- Если пустой, можно удалить саму таблицу (опционально)
        if next(hooks[hookName]) == nil then
            hooks[hookName] = nil
            hook.Remove(hookName, "cw_hook_" .. hookName)
            cw.logger.dmsg("Удалён нативный хук '%s' — больше нет обработчиков", hookName)
        end
    end
end

---Запускает хук вручную, вызывает все подписчики, возвращает распакованный список их результатов
---@param hookName string @ Имя хука
---@vararg any @ Аргументы для передачи обработчикам
---@return any @ Распакованный список результатов всех обработчиков
function cw.hook.Trigger(hookName, ...)
    local results = {}

    -- Не логируем триггер в мусорных хукаx
    if CFG.dev and not (hookName == "Think" or hookName == "Tick" or hookName == "HUDPaint") then
        cw.logger.dmsg("Trigger: '%s' вызван с %d аргументами", hookName, select("#", ...))
    end

    if hooks[hookName] then
        for _, f in pairs(hooks[hookName]) do
            local ok, ret = pcall(f, ...)
            if ok then
                table.insert(results, ret)
            else
                cw.logger.createCustomColorMsg('cw.hook', CFG.colors.error, "Ошибка при триггере хука '%s': %s", hookName, ret)
            end
        end
    end

    return unpack(results)
end