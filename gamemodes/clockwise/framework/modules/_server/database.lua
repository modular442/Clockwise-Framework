require('mysqloo')

---@class cw.database
---@field reconnectDB fun() @ Функция, которая пытается подключиться к базе и поддерживает соединение
cw.database = cw.database or {}

--- Попытка подключиться к базе данных MySQL через mysqloo.
--- При успешном подключении запускает периодический heartbeat для проверки статуса.
--- При потере соединения пытается переподключиться с задержкой.
function cw.database.reconnectDB()
    cw.logger.createCustomColorMsg('Database', CFG.colors.warning, 'Connecting...')
    local config = CFG.db
    if not config then
        cw.logger.createCustomColorMsg('Database', CFG.colors.error, 'DB config missing!')
        return
    end
    local db = mysqloo.CreateDatabase(config.host, config.user, config.pass, config.main, config.port, config.socket)
    --- Вызывается при успешном подключении к БД.
    function db:onConnected()
        cw.logger.createCustomColorMsg('Database', CFG.colors.complete, 'Connected.')
        cw.db = db
        -- Создаём таймер heartbeat, который каждые 30 секунд проверяет состояние соединения
        timer.Create('cw.db.heartbeat', 30, 0, function()
            local status = cw.db:status()
			local connected = mysqloo.DATABASE_CONNECTED
            local connecting = mysqloo.DATABASE_CONNECTING

            -- Если состояние БД не подключено и не подключается — пытаемся переподключиться
            if status ~= connected and status ~= connecting then
				cw.database.reconnectDB()
				timer.Remove('cw.db.heartbeat')
			end
        end)
        -- Триггер события инициализации базы
        cw.hook.Trigger('cw.db.init', db)
    end
    --- Вызывается при неудачной попытке подключения к БД.
    --- @param data string @ Ошибка подключения
    function db:onConnectionFailed(data)
        cw.logger.createCustomColorMsg('Database', CFG.colors.error, 'Connection failed: %s', data)
        cw.logger.createCustomColorMsg('Database', CFG.colors.warning, 'Reconnecting in 30 seconds...')
        -- Удаляем heartbeat, чтобы не плодить таймеры
        timer.Remove('cw.db.heartbeat')
        -- Запускаем повторную попытку подключения через 30 секунд
        timer.Simple(30, cw.database.reconnectDB)
    end
end

-- Запускаем первое подключение к базе при загрузке скрипта
cw.database.reconnectDB()