---@class cw.logger
---@field msg fun(txt: string, ...) @ Простое текстовое сообщение с префиксом и временем
---@field info fun(txt: string, ...) @ Информационное сообщение в голубом цвете
---@field warning fun(txt: string, ...) @ Предупреждение в желтом цвете
---@field error fun(txt: string, ...) @ Ошибка в красном цвете
---@field complete fun(txt: string, ...) @ Успешное завершение в зеленом цвете
---@field dmsg fun(txt: string, ...) @ Отладочное сообщение, зависит от CFG.dev
---@field createMsg fun(prefix: string, includeTime?: boolean): fun(txt: string, ...) @ Создает обычный логгер
---@field createColoredMsg fun(prefix: string, color: Color, includeTime?: boolean): fun(txt: string, ...) @ Создает цветной логгер
---@field createCustomMsg fun(prefix: string, txt: string, ...) @ Печатает кастомное сообщение
---@field createCustomColorMsg fun(prefix: string, color: Color, txt: string, ...) @ Печатает кастомное цветное сообщение
cw.logger = cw.logger or {}

---Создает обычный логгер с префиксом и (опционально) временем
---@param prefix string @ Префикс сообщения
---@param includeTime boolean? @ Добавлять ли время (по умолчанию true)
---@return fun(txt: string, ...)
function cw.logger.createMsg(prefix, includeTime)
	includeTime = includeTime == nil and true or includeTime

	return function(txt, ...)
		local time = includeTime and os.date('%H:%M:%S - ', os.time()) or ''
		print('['..prefix..'] '..time..string.format(tostring(txt), ...))
	end
end

---Создает цветной логгер с префиксом и (опционально) временем
---@param prefix string @ Префикс сообщения
---@param color Color @ Цвет сообщения (Color)
---@param includeTime boolean? @ Добавлять ли время (по умолчанию true)
---@return fun(txt: string, ...)
function cw.logger.createColoredMsg(prefix, color, includeTime)
	includeTime = includeTime == nil and true or includeTime

	return function(txt, ...)
		local time = includeTime and os.date('%H:%M:%S - ', os.time()) or ''
		MsgC(color, '['..prefix..'] '..time..string.format(tostring(txt), ...)..'\n')
	end
end

---Выводит кастомное сообщение сразу
---@param prefix string @ Префикс
---@param txt string @ Текст сообщения
---@param ... any @ Аргументы для форматирования
function cw.logger.createCustomMsg(prefix, txt, ...)
    local time = os.date('%H:%M:%S - ', os.time()) or ''
	print('['..prefix..'] '..time..string.format(tostring(txt), ...))
end

---Выводит кастомное цветное сообщение сразу
---@param prefix string @ Префикс сообщения
---@param color Color @ Цвет сообщения (Color)
---@param txt string Текст сообщения
---@param ... any Аргументы для форматирования
function cw.logger.createCustomColorMsg(prefix, color, txt, ...)
    local time = os.date('%H:%M:%S - ', os.time()) or ''
	MsgC(color, '['..prefix..'] '..time..string.format(tostring(txt), ...)..'\n')
end

cw.logger.msg = cw.logger.createMsg('Clockwise')
cw.logger.info = cw.logger.createColoredMsg('Clockwise', Color(122, 198, 255))
cw.logger.warning = cw.logger.createColoredMsg('Clockwise', Color(243, 187, 27))
cw.logger.error = cw.logger.createColoredMsg('Clockwise', Color(255, 100, 100))
cw.logger.complete = cw.logger.createColoredMsg('Clockwise', Color(0, 255, 100, 255))

---Выводит отладочное сообщение, только если включён CFG.dev
---@param txt string @ Текст сообщения
---@param ... any @ Аргументы для форматирования
function cw.logger.dmsg(txt, ...)
	if CFG.dev and SERVER then
		cw.logger.createCustomColorMsg('SERVER', Color(156, 241, 255, 200), txt, ...)
	elseif CFG.dev and CLIENT then
		cw.logger.createCustomColorMsg('CLIENT', Color(255, 241, 122, 200), txt, ...)
	end
end