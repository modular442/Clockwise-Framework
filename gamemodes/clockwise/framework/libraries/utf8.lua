---@diagnostic disable: cast-local-type
-- $Id: utf8.lua 179 2009-04-03 18:10:03Z pasta $
--
-- Provides UTF-8 aware string functions implemented in pure lua:
-- * utf8len(s)
-- * utf8sub(s, i, j)
-- * utf8reverse(s)
-- * utf8char(unicode)
-- * utf8unicode(s, i, j)
-- * utf8gensub(s, sub_len)
-- * utf8find(str, regex, init, plain)
-- * utf8match(str, regex, init)
-- * utf8gmatch(str, regex, all)
-- * utf8gsub(str, regex, repl, limit)
--
-- If utf8data.lua (containing the lower<->upper case mappings) is loaded, these
-- additional functions are available:
-- * utf8upper(s)
-- * utf8lower(s)
--
-- All functions behave as their non UTF-8 aware counterparts with the exception
-- that UTF-8 characters are used instead of bytes for all units.

--[[
Copyright (c) 2006-2007, Kyle Smith
All rights reserved.
Contributors:
	Alimov Stepan
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.
	* Neither the name of the author nor the names of its contributors may be
	  used to endorse or promote products derived from this software without
	  specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

-- ABNF from RFC 3629
--
-- UTF8-octets = *( UTF8-char )
-- UTF8-char   = UTF8-1 / UTF8-2 / UTF8-3 / UTF8-4
-- UTF8-1	  = %x00-7F
-- UTF8-2	  = %xC2-DF UTF8-tail
-- UTF8-3	  = %xE0 %xA0-BF UTF8-tail / %xE1-EC 2( UTF8-tail ) /
--			   %xED %x80-9F UTF8-tail / %xEE-EF 2( UTF8-tail )
-- UTF8-4	  = %xF0 %x90-BF 2( UTF8-tail ) / %xF1-F3 3( UTF8-tail ) /
--			   %xF4 %x80-8F 2( UTF8-tail )
-- UTF8-tail   = %x80-BF
--

local byte	= string.byte
local char	= string.char
local dump	= string.dump
local find	= string.find
local format  = string.format
local gmatch  = string.gmatch
local gsub	= string.gsub
local len	 = string.len
local lower   = string.lower
local match   = string.match
local rep	 = string.rep
local reverse = string.reverse
local sub	 = string.sub
local upper   = string.upper

-- returns the number of bytes used by the UTF-8 character at byte i in s
-- also doubles as a UTF-8 character validator
local function utf8charbytes (s, i)
	-- argument defaults
	i = i or 1

	-- argument checking
	if type(s) ~= "string" then
		error("bad argument #1 to 'utf8charbytes' (string expected, got ".. type(s).. ")")
	end
	if type(i) ~= "number" then
		error("bad argument #2 to 'utf8charbytes' (number expected, got ".. type(i).. ")")
	end

	local c = byte(s, i)

	-- determine bytes needed for character, based on RFC 3629
	-- validate byte 1
	if c > 0 and c <= 127 then
		-- UTF8-1
		return 1

	elseif c >= 194 and c <= 223 then
		-- UTF8-2
		local c2 = byte(s, i + 1)

		if not c2 then
			error("UTF-8 string terminated early")
		end

		-- validate byte 2
		if c2 < 128 or c2 > 191 then
			error("Invalid UTF-8 character")
		end

		return 2

	elseif c >= 224 and c <= 239 then
		-- UTF8-3
		local c2 = byte(s, i + 1)
		local c3 = byte(s, i + 2)

		if not c2 or not c3 then
			error("UTF-8 string terminated early")
		end

		-- validate byte 2
		if c == 224 and (c2 < 160 or c2 > 191) then
			error("Invalid UTF-8 character")
		elseif c == 237 and (c2 < 128 or c2 > 159) then
			error("Invalid UTF-8 character")
		elseif c2 < 128 or c2 > 191 then
			error("Invalid UTF-8 character")
		end

		-- validate byte 3
		if c3 < 128 or c3 > 191 then
			error("Invalid UTF-8 character")
		end

		return 3

	elseif c >= 240 and c <= 244 then
		-- UTF8-4
		local c2 = byte(s, i + 1)
		local c3 = byte(s, i + 2)
		local c4 = byte(s, i + 3)

		if not c2 or not c3 or not c4 then
			error("UTF-8 string terminated early")
		end

		-- validate byte 2
		if c == 240 and (c2 < 144 or c2 > 191) then
			error("Invalid UTF-8 character")
		elseif c == 244 and (c2 < 128 or c2 > 143) then
			error("Invalid UTF-8 character")
		elseif c2 < 128 or c2 > 191 then
			error("Invalid UTF-8 character")
		end

		-- validate byte 3
		if c3 < 128 or c3 > 191 then
			error("Invalid UTF-8 character")
		end

		-- validate byte 4
		if c4 < 128 or c4 > 191 then
			error("Invalid UTF-8 character")
		end

		return 4

	else
		error("Invalid UTF-8 character")
	end
end

-- returns the number of characters in a UTF-8 string
local function utf8len (s)
	-- argument checking
	if type(s) ~= "string" then
		for k,v in pairs(s) do print('"',tostring(k),'"',tostring(v),'"') end
		error("bad argument #1 to 'utf8len' (string expected, got ".. type(s).. ")")
	end

	local pos = 1
	local bytes = len(s)
	local len = 0

	while pos <= bytes do
		len = len + 1
		pos = pos + utf8charbytes(s, pos)
	end

	return len
end

-- functions identically to string.sub except that i and j are UTF-8 characters
-- instead of bytes
local function utf8sub (s, i, j)
	-- argument defaults
	j = j or -1

	local pos = 1
	local bytes = len(s)
	local len = 0

	-- only set l if i or j is negative
	local l = (i >= 0 and j >= 0) or utf8len(s)
	local startChar = (i >= 0) and i or l + i + 1
	local endChar   = (j >= 0) and j or l + j + 1

	-- can't have start before end!
	if startChar > endChar then
		return ""
	end

	-- byte offsets to pass to string.sub
	local startByte,endByte = 1,bytes

	while pos <= bytes do
		len = len + 1

		if len == startChar then
			startByte = pos
		end

		pos = pos + utf8charbytes(s, pos)

		if len == endChar then
			endByte = pos - 1
			break
		end
	end

	if startChar > len then startByte = bytes+1   end
	if endChar   < 1   then endByte   = 0		 end

	return sub(s, startByte, endByte)
end


-- replace UTF-8 characters based on a mapping table
local function utf8replace (s, mapping)
	-- argument checking
	if type(s) ~= "string" then
		error("bad argument #1 to 'utf8replace' (string expected, got ".. type(s).. ")")
	end
	if type(mapping) ~= "table" then
		error("bad argument #2 to 'utf8replace' (table expected, got ".. type(mapping).. ")")
	end

	local pos = 1
	local bytes = len(s)
	local charbytes
	local newstr = ""

	while pos <= bytes do
		charbytes = utf8charbytes(s, pos)
		local c = sub(s, pos, pos + charbytes - 1)

		newstr = newstr .. (mapping[c] or c)

		pos = pos + charbytes
	end

	return newstr
end


-- identical to string.upper except it knows about unicode simple case conversions
local function utf8upper (s)
	return utf8replace(s, utf8_lc_uc)
end

-- identical to string.lower except it knows about unicode simple case conversions
local function utf8lower (s)
	return utf8replace(s, utf8_uc_lc)
end

-- identical to string.reverse except that it supports UTF-8
local function utf8reverse (s)
	-- argument checking
	if type(s) ~= "string" then
		error("bad argument #1 to 'utf8reverse' (string expected, got ".. type(s).. ")")
	end

	local bytes = len(s)
	local pos = bytes
	local charbytes
	local newstr = ""

	while pos > 0 do
		c = byte(s, pos)
		while c >= 128 and c <= 191 do
			pos = pos - 1
			c = byte(s, pos)
		end

		charbytes = utf8charbytes(s, pos)

		newstr = newstr .. sub(s, pos, pos + charbytes - 1)

		pos = pos - 1
	end

	return newstr
end

-- http://en.wikipedia.org/wiki/Utf8
-- http://developer.coronalabs.com/code/utf-8-conversion-utility
local function utf8char(unicode)
	if unicode <= 0x7F then return char(unicode) end

	if (unicode <= 0x7FF) then
		local Byte0 = 0xC0 + math.floor(unicode / 0x40);
		local Byte1 = 0x80 + (unicode % 0x40);
		return char(Byte0, Byte1);
	end;

	if (unicode <= 0xFFFF) then
		local Byte0 = 0xE0 +  math.floor(unicode / 0x1000);
		local Byte1 = 0x80 + (math.floor(unicode / 0x40) % 0x40);
		local Byte2 = 0x80 + (unicode % 0x40);
		return char(Byte0, Byte1, Byte2);
	end;

	if (unicode <= 0x10FFFF) then
		local code = unicode
		local Byte3= 0x80 + (code % 0x40);
		code	   = math.floor(code / 0x40)
		local Byte2= 0x80 + (code % 0x40);
		code	   = math.floor(code / 0x40)
		local Byte1= 0x80 + (code % 0x40);
		code	   = math.floor(code / 0x40)
		local Byte0= 0xF0 + code;

		return char(Byte0, Byte1, Byte2, Byte3);
	end;

	error 'Unicode cannot be greater than U+10FFFF!'
end

local shift_6  = 2^6
local shift_12 = 2^12
local shift_18 = 2^18

local utf8unicode
utf8unicode = function(str, i, j, byte_pos)
	i = i or 1
	j = j or i

	if i > j then return end

	local char,bytes

	if byte_pos then
		bytes = utf8charbytes(str,byte_pos)
		char  = sub(str,byte_pos,byte_pos-1+bytes)
	else
		char,byte_pos = utf8sub(str,i,i), 0
		bytes		 = #char
	end

	local unicode

	if bytes == 1 then unicode = byte(char) end
	if bytes == 2 then
		local byte0,byte1 = byte(char,1,2)
		local code0,code1 = byte0-0xC0,byte1-0x80
		unicode = code0*shift_6 + code1
	end
	if bytes == 3 then
		local byte0,byte1,byte2 = byte(char,1,3)
		local code0,code1,code2 = byte0-0xE0,byte1-0x80,byte2-0x80
		unicode = code0*shift_12 + code1*shift_6 + code2
	end
	if bytes == 4 then
		local byte0,byte1,byte2,byte3 = byte(char,1,4)
		local code0,code1,code2,code3 = byte0-0xF0,byte1-0x80,byte2-0x80,byte3-0x80
		unicode = code0*shift_18 + code1*shift_12 + code2*shift_6 + code3
	end

	return unicode,utf8unicode(str, i+1, j, byte_pos+bytes)
end

-- Returns an iterator which returns the next substring and its byte interval
local function utf8gensub(str, sub_len)
	sub_len		= sub_len or 1
	local byte_pos = 1
	local len	  = #str
	return function(skip)
		if skip then byte_pos = byte_pos + skip end
		local char_count = 0
		local start	  = byte_pos
		repeat
			if byte_pos > len then return end
			char_count  = char_count + 1
			local bytes = utf8charbytes(str,byte_pos)
			byte_pos	= byte_pos+bytes

		until char_count == sub_len

		local last  = byte_pos-1
		local sub   = sub(str,start,last)
		return sub, start, last
	end
end

local function binsearch(sortedTable, item, comp)
	local head, tail = 1, #sortedTable
	local mid = math.floor((head + tail)/2)
	if not comp then
		while (tail - head) > 1 do
			if sortedTable[tonumber(mid)] > item then
				tail = mid
			else
				head = mid
			end
			mid = math.floor((head + tail)/2)
		end
	else
	end
	if sortedTable[tonumber(head)] == item then
		return true, tonumber(head)
	elseif sortedTable[tonumber(tail)] == item then
		return true, tonumber(tail)
	else
		return false
	end
end
local function classMatchGenerator(class, plain)
	local codes = {}
	local ranges = {}
	local ignore = false
	local range = false
	local firstletter = true
	local unmatch = false

	local it = utf8gensub(class)

	local skip
	for c,bs,be in it do
		skip = be
		if not ignore and not plain then
			if c == "%" then
				ignore = true
			elseif c == "-" then
				table.insert(codes, utf8unicode(c))
				range = true
			elseif c == "^" then
				if not firstletter then
					error('!!!')
				else
					unmatch = true
				end
			elseif c == ']' then
				break
			else
				if not range then
					table.insert(codes, utf8unicode(c))
				else
					table.remove(codes) -- removing '-'
					table.insert(ranges, {table.remove(codes), utf8unicode(c)})
					range = false
				end
			end
		elseif ignore and not plain then
			if c == 'a' then -- %a: represents all letters. (ONLY ASCII)
				table.insert(ranges, {65, 90}) -- A - Z
				table.insert(ranges, {97, 122}) -- a - z
			elseif c == 'c' then -- %c: represents all control characters.
				table.insert(ranges, {0, 31})
				table.insert(codes, 127)
			elseif c == 'd' then -- %d: represents all digits.
				table.insert(ranges, {48, 57}) -- 0 - 9
			elseif c == 'g' then -- %g: represents all printable characters except space.
				table.insert(ranges, {1, 8})
				table.insert(ranges, {14, 31})
				table.insert(ranges, {33, 132})
				table.insert(ranges, {134, 159})
				table.insert(ranges, {161, 5759})
				table.insert(ranges, {5761, 8191})
				table.insert(ranges, {8203, 8231})
				table.insert(ranges, {8234, 8238})
				table.insert(ranges, {8240, 8286})
				table.insert(ranges, {8288, 12287})
			elseif c == 'l' then -- %l: represents all lowercase letters. (ONLY ASCII)
				table.insert(ranges, {97, 122}) -- a - z
			elseif c == 'p' then -- %p: represents all punctuation characters. (ONLY ASCII)
				table.insert(ranges, {33, 47})
				table.insert(ranges, {58, 64})
				table.insert(ranges, {91, 96})
				table.insert(ranges, {123, 126})
			elseif c == 's' then -- %s: represents all space characters.
				table.insert(ranges, {9, 13})
				table.insert(codes, 32)
				table.insert(codes, 133)
				table.insert(codes, 160)
				table.insert(codes, 5760)
				table.insert(ranges, {8192, 8202})
				table.insert(codes, 8232)
				table.insert(codes, 8233)
				table.insert(codes, 8239)
				table.insert(codes, 8287)
				table.insert(codes, 12288)
			elseif c == 'u' then -- %u: represents all uppercase letters. (ONLY ASCII)
				table.insert(ranges, {65, 90}) -- A - Z
			elseif c == 'w' then -- %w: represents all alphanumeric characters. (ONLY ASCII)
				table.insert(ranges, {48, 57}) -- 0 - 9
				table.insert(ranges, {65, 90}) -- A - Z
				table.insert(ranges, {97, 122}) -- a - z
			elseif c == 'x' then -- %x: represents all hexadecimal digits.
				table.insert(ranges, {48, 57}) -- 0 - 9
				table.insert(ranges, {65, 70}) -- A - F
				table.insert(ranges, {97, 102}) -- a - f
			else
				if not range then
					table.insert(codes, utf8unicode(c))
				else
					table.remove(codes) -- removing '-'
					table.insert(ranges, {table.remove(codes), utf8unicode(c)})
					range = false
				end
			end
			ignore = false
		else
			if not range then
				table.insert(codes, utf8unicode(c))
			else
				table.remove(codes) -- removing '-'
				table.insert(ranges, {table.remove(codes), utf8unicode(c)})
				range = false
			end
			ignore = false
		end

		firstletter = false
	end

	table.sort(codes)

	local function inRanges(charCode)
		for _,r in ipairs(ranges) do
			if r[1] <= charCode and charCode <= r[2] then
				return true
			end
		end
		return false
	end
	if not unmatch then
		return function(charCode)
			return binsearch(codes, charCode) or inRanges(charCode)
		end, skip
	else
		return function(charCode)
			return charCode ~= -1 and not (binsearch(codes, charCode) or inRanges(charCode))
		end, skip
	end
end

-- utf8sub with extra argument, and extra result value
local function utf8subWithBytes (s, i, j, sb)
	-- argument defaults
	j = j or -1

	local pos = sb or 1
	local bytes = len(s)
	local len = 0

	-- only set l if i or j is negative
	local l = (i >= 0 and j >= 0) or utf8len(s)
	local startChar = (i >= 0) and i or l + i + 1
	local endChar   = (j >= 0) and j or l + j + 1

	-- can't have start before end!
	if startChar > endChar then
		return ""
	end

	-- byte offsets to pass to string.sub
	local startByte,endByte = 1,bytes

	while pos <= bytes do
		len = len + 1

		if len == startChar then
			startByte = pos
		end

		pos = pos + utf8charbytes(s, pos)

		if len == endChar then
			endByte = pos - 1
			break
		end
	end

	if startChar > len then startByte = bytes+1   end
	if endChar   < 1   then endByte   = 0		 end

	return sub(s, startByte, endByte), endByte + 1
end

local cache = setmetatable({},{
	__mode = 'kv'
})
local cachePlain = setmetatable({},{
	__mode = 'kv'
})
local function matcherGenerator(regex, plain)
	local matcher = {
		functions = {},
		captures = {}
	}
	if not plain then
		cache[regex] =  matcher
	else
		cachePlain[regex] = matcher
	end
	local function simple(func)
		return function(cC)
			if func(cC) then
				matcher:nextFunc()
				matcher:nextStr()
			else
				matcher:reset()
			end
		end
	end
	local function star(func)
		return function(cC)
			if func(cC) then
				matcher:fullResetOnNextFunc()
				matcher:nextStr()
			else
				matcher:nextFunc()
			end
		end
	end
	local function minus(func)
		return function(cC)
			if func(cC) then
				matcher:fullResetOnNextStr()
			end
			matcher:nextFunc()
		end
	end
	local function question(func)
		return function(cC)
			if func(cC) then
				matcher:fullResetOnNextFunc()
				matcher:nextStr()
			end
			matcher:nextFunc()
		end
	end

	local function capture(id)
		return function(cC)
			local l = matcher.captures[id][2] - matcher.captures[id][1]
			local captured = utf8sub(matcher.string, matcher.captures[id][1], matcher.captures[id][2])
			local check = utf8sub(matcher.string, matcher.str, matcher.str + l)
			if captured == check then
				for i = 0, l do
					matcher:nextStr()
				end
				matcher:nextFunc()
			else
				matcher:reset()
			end
		end
	end
	local function captureStart(id)
		return function(cC)
			matcher.captures[id][1] = matcher.str
			matcher:nextFunc()
		end
	end
	local function captureStop(id)
		return function(cC)
			matcher.captures[id][2] = matcher.str - 1
			matcher:nextFunc()
		end
	end

	local function balancer(str)
		local sum = 0
		local bc, ec = utf8sub(str, 1, 1), utf8sub(str, 2, 2)
		local skip = len(bc) + len(ec)
		bc, ec = utf8unicode(bc), utf8unicode(ec)
		return function(cC)
			if cC == ec and sum > 0 then
				sum = sum - 1
				if sum == 0 then
					matcher:nextFunc()
				end
				matcher:nextStr()
			elseif cC == bc then
				sum = sum + 1
				matcher:nextStr()
			else
				if sum == 0 or cC == -1 then
					sum = 0
					matcher:reset()
				else
					matcher:nextStr()
				end
			end
		end, skip
	end

	matcher.functions[1] = function(cC)
		matcher:fullResetOnNextStr()
		matcher.seqStart = matcher.str
		matcher:nextFunc()
		if (matcher.str > matcher.startStr and matcher.fromStart) or matcher.str >= matcher.stringLen then
			matcher.stop = true
			matcher.seqStart = nil
		end
	end

	local lastFunc
	local ignore = false
	local skip = nil
	local it = (function()
		local gen = utf8gensub(regex)
		return function()
			return gen(skip)
		end
	end)()
	local cs = {}
	for c, bs, be in it do
		skip = nil
		if plain then
			table.insert(matcher.functions, simple(classMatchGenerator(c, plain)))
		else
			if ignore then
				if find('123456789', c, 1, true) then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
						lastFunc = nil
					end
					table.insert(matcher.functions, capture(tonumber(c)))
				elseif c == 'b' then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
						lastFunc = nil
					end
					local b
					b, skip = balancer(sub(regex, be + 1, be + 9))
					table.insert(matcher.functions, b)
				else
					lastFunc = classMatchGenerator('%' .. c)
				end
				ignore = false
			else
				if c == '*' then
					if lastFunc then
						table.insert(matcher.functions, star(lastFunc))
						lastFunc = nil
					else
						error('invalid regex after ' .. sub(regex, 1, bs))
					end
				elseif c == '+' then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
						table.insert(matcher.functions, star(lastFunc))
						lastFunc = nil
					else
						error('invalid regex after ' .. sub(regex, 1, bs))
					end
				elseif c == '-' then
					if lastFunc then
						table.insert(matcher.functions, minus(lastFunc))
						lastFunc = nil
					else
						error('invalid regex after ' .. sub(regex, 1, bs))
					end
				elseif c == '?' then
					if lastFunc then
						table.insert(matcher.functions, question(lastFunc))
						lastFunc = nil
					else
						error('invalid regex after ' .. sub(regex, 1, bs))
					end
				elseif c == '^' then
					if bs == 1 then
						matcher.fromStart = true
					else
						error('invalid regex after ' .. sub(regex, 1, bs))
					end
				elseif c == '$' then
					if be == len(regex) then
						matcher.toEnd = true
					else
						error('invalid regex after ' .. sub(regex, 1, bs))
					end
				elseif c == '[' then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
					end
					lastFunc, skip = classMatchGenerator(sub(regex, be + 1))
				elseif c == '(' then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
						lastFunc = nil
					end
					table.insert(matcher.captures, {})
					table.insert(cs, #matcher.captures)
					table.insert(matcher.functions, captureStart(cs[#cs]))
					if sub(regex, be + 1, be + 1) == ')' then matcher.captures[#matcher.captures].empty = true end
				elseif c == ')' then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
						lastFunc = nil
					end
					local cap = table.remove(cs)
					if not cap then
						error('invalid capture: "(" missing')
					end
					table.insert(matcher.functions, captureStop(cap))
				elseif c == '.' then
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
					end
					lastFunc = function(cC) return cC ~= -1 end
				elseif c == '%' then
					ignore = true
				else
					if lastFunc then
						table.insert(matcher.functions, simple(lastFunc))
					end
					lastFunc = classMatchGenerator(c)
				end
			end
		end
	end
	if #cs > 0 then
		error('invalid capture: ")" missing')
	end
	if lastFunc then
		table.insert(matcher.functions, simple(lastFunc))
	end
	lastFunc = nil
	ignore = nil

	table.insert(matcher.functions, function()
		if matcher.toEnd and matcher.str ~= matcher.stringLen then
			matcher:reset()
		else
			matcher.stop = true
		end
	end)

	matcher.nextFunc = function(self)
		self.func = self.func + 1
	end
	matcher.nextStr = function(self)
		self.str = self.str + 1
	end
	matcher.strReset = function(self)
		local oldReset = self.reset
		local str = self.str
		self.reset = function(s)
			s.str = str
			s.reset = oldReset
		end
	end
	matcher.fullResetOnNextFunc = function(self)
		local oldReset = self.reset
		local func = self.func +1
		local str = self.str
		self.reset = function(s)
			s.func = func
			s.str = str
			s.reset = oldReset
		end
	end
	matcher.fullResetOnNextStr = function(self)
		local oldReset = self.reset
		local str = self.str + 1
		local func = self.func
		self.reset = function(s)
			s.func = func
			s.str = str
			s.reset = oldReset
		end
	end

	matcher.process = function(self, str, start)

		self.func = 1
		start = start or 1
		self.startStr = (start >= 0) and start or utf8len(str) + start + 1
		self.seqStart = self.startStr
		self.str = self.startStr
		self.stringLen = utf8len(str) + 1
		self.string = str
		self.stop = false

		self.reset = function(s)
			s.func = 1
		end

		local lastPos = self.str
		local lastByte
		local char
		while not self.stop do
			if self.str < self.stringLen then
				--[[ if lastPos < self.str then
					print('last byte', lastByte)
					char, lastByte = utf8subWithBytes(str, 1, self.str - lastPos - 1, lastByte)
					char, lastByte = utf8subWithBytes(str, 1, 1, lastByte)
					lastByte = lastByte - 1
				else
					char, lastByte = utf8subWithBytes(str, self.str, self.str)
				end
				lastPos = self.str ]]
				char = utf8sub(str, self.str,self.str)
				--print('char', char, utf8unicode(char))
				self.functions[self.func](utf8unicode(char))
			else
				self.functions[self.func](-1)
			end
		end

		if self.seqStart then
			local captures = {}
			for _,pair in pairs(self.captures) do
				if pair.empty then
					table.insert(captures, pair[1])
				else
					table.insert(captures, utf8sub(str, pair[1], pair[2]))
				end
			end
			return self.seqStart, self.str - 1, unpack(captures)
		end
	end

	return matcher
end

-- string.find
local function utf8find(str, regex, init, plain)
	local matcher = cache[regex] or matcherGenerator(regex, plain)
	return matcher:process(str, init)
end

-- string.match
local function utf8match(str, regex, init)
	init = init or 1
	local found = {utf8find(str, regex, init)}
	if found[1] then
		if found[3] then
			return unpack(found, 3)
		end
		return utf8sub(str, found[1], found[2])
	end
end

-- string.gmatch
local function utf8gmatch(str, regex, all)
	regex = (utf8sub(regex,1,1) ~= '^') and regex or '%' .. regex
	local lastChar = 1
	return function()
		local found = {utf8find(str, regex, lastChar)}
		if found[1] then
			lastChar = found[2] + 1
			if found[all and 1 or 3] then
				return unpack(found, all and 1 or 3)
			end
			return utf8sub(str, found[1], found[2])
		end
	end
end

local function replace(repl, args)
	local ret = ''
	if type(repl) == 'string' then
		local ignore = false
		local num = 0
		for c in utf8gensub(repl) do
			if not ignore then
				if c == '%' then
					ignore = true
				else
					ret = ret .. c
				end
			else
				num = tonumber(c)
				if num then
					ret = ret .. args[num]
				else
					ret = ret .. c
				end
				ignore = false
			end
		end
	elseif type(repl) == 'table' then
		ret = repl[args[1] or args[0]] or ''
	elseif type(repl) == 'function' then
		if #args > 0 then
			ret = repl(unpack(args, 1)) or ''
		else
			ret = repl(args[0]) or ''
		end
	end
	return ret
end
-- string.gsub
local function utf8gsub(str, regex, repl, limit)
	limit = limit or -1
	local ret = ''
	local prevEnd = 1
	local it = utf8gmatch(str, regex, true)
	local found = {it()}
	local n = 0
	while #found > 0 and limit ~= n do
		local args = {[0] = utf8sub(str, found[1], found[2]), unpack(found, 3)}
		ret = ret .. utf8sub(str, prevEnd, found[1] - 1)
		.. replace(repl, args)
		prevEnd = found[2] + 1
		n = n + 1
		found = {it()}
	end
	return ret .. utf8sub(str, prevEnd), n
end

utf8.len = utf8len
utf8.sub = utf8sub
utf8.reverse = utf8reverse
utf8.char = utf8char
utf8.unicode = utf8unicode
utf8.gensub = utf8gensub
utf8.byte = utf8unicode
utf8.find	= utf8find
utf8.match   = utf8match
utf8.gmatch  = utf8gmatch
utf8.gsub	= utf8gsub
utf8.dump	= dump
utf8.format = format
utf8.lower = utf8lower
utf8.upper = utf8upper
utf8.rep	 = rep

-- char mapping tables from https://github.com/artemshein/luv/blob/master/utf8data.lua
utf8_lc_uc={["a"]="A",["b"]="B",["c"]="C",["d"]="D",["e"]="E",["f"]="F",["g"]="G",["h"]="H",["i"]="I",["j"]="J",["k"]="K",["l"]="L",["m"]="M",["n"]="N",["o"]="O",["p"]="P",["q"]="Q",["r"]="R",["s"]="S",["t"]="T",["u"]="U",["v"]="V",["w"]="W",["x"]="X",["y"]="Y",["z"]="Z",["µ"]="Μ",["à"]="À",["á"]="Á",["â"]="Â",["ã"]="Ã",["ä"]="Ä",["å"]="Å",["æ"]="Æ",["ç"]="Ç",["è"]="È",["é"]="É",["ê"]="Ê",["ë"]="Ë",["ì"]="Ì",["í"]="Í",["î"]="Î",["ï"]="Ï",["ð"]="Ð",["ñ"]="Ñ",["ò"]="Ò",["ó"]="Ó",["ô"]="Ô",["õ"]="Õ",["ö"]="Ö",["ø"]="Ø",["ù"]="Ù",["ú"]="Ú",["û"]="Û",["ü"]="Ü",["ý"]="Ý",["þ"]="Þ",["ÿ"]="Ÿ",["ā"]="Ā",["ă"]="Ă",["ą"]="Ą",["ć"]="Ć",["ĉ"]="Ĉ",["ċ"]="Ċ",["č"]="Č",["ď"]="Ď",["đ"]="Đ",["ē"]="Ē",["ĕ"]="Ĕ",["ė"]="Ė",["ę"]="Ę",["ě"]="Ě",["ĝ"]="Ĝ",["ğ"]="Ğ",["ġ"]="Ġ",["ģ"]="Ģ",["ĥ"]="Ĥ",["ħ"]="Ħ",["ĩ"]="Ĩ",["ī"]="Ī",["ĭ"]="Ĭ",["į"]="Į",["ı"]="I",["ĳ"]="Ĳ",["ĵ"]="Ĵ",["ķ"]="Ķ",["ĺ"]="Ĺ",["ļ"]="Ļ",["ľ"]="Ľ",["ŀ"]="Ŀ",["ł"]="Ł",["ń"]="Ń",["ņ"]="Ņ",["ň"]="Ň",["ŋ"]="Ŋ",["ō"]="Ō",["ŏ"]="Ŏ",["ő"]="Ő",["œ"]="Œ",["ŕ"]="Ŕ",["ŗ"]="Ŗ",["ř"]="Ř",["ś"]="Ś",["ŝ"]="Ŝ",["ş"]="Ş",["š"]="Š",["ţ"]="Ţ",["ť"]="Ť",["ŧ"]="Ŧ",["ũ"]="Ũ",["ū"]="Ū",["ŭ"]="Ŭ",["ů"]="Ů",["ű"]="Ű",["ų"]="Ų",["ŵ"]="Ŵ",["ŷ"]="Ŷ",["ź"]="Ź",["ż"]="Ż",["ž"]="Ž",["ſ"]="S",["ƀ"]="Ƀ",["ƃ"]="Ƃ",["ƅ"]="Ƅ",["ƈ"]="Ƈ",["ƌ"]="Ƌ",["ƒ"]="Ƒ",["ƕ"]="Ƕ",["ƙ"]="Ƙ",["ƚ"]="Ƚ",["ƞ"]="Ƞ",["ơ"]="Ơ",["ƣ"]="Ƣ",["ƥ"]="Ƥ",["ƨ"]="Ƨ",["ƭ"]="Ƭ",["ư"]="Ư",["ƴ"]="Ƴ",["ƶ"]="Ƶ",["ƹ"]="Ƹ",["ƽ"]="Ƽ",["ƿ"]="Ƿ",["ǅ"]="Ǆ",["ǆ"]="Ǆ",["ǈ"]="Ǉ",["ǉ"]="Ǉ",["ǋ"]="Ǌ",["ǌ"]="Ǌ",["ǎ"]="Ǎ",["ǐ"]="Ǐ",["ǒ"]="Ǒ",["ǔ"]="Ǔ",["ǖ"]="Ǖ",["ǘ"]="Ǘ",["ǚ"]="Ǚ",["ǜ"]="Ǜ",["ǝ"]="Ǝ",["ǟ"]="Ǟ",["ǡ"]="Ǡ",["ǣ"]="Ǣ",["ǥ"]="Ǥ",["ǧ"]="Ǧ",["ǩ"]="Ǩ",["ǫ"]="Ǫ",["ǭ"]="Ǭ",["ǯ"]="Ǯ",["ǲ"]="Ǳ",["ǳ"]="Ǳ",["ǵ"]="Ǵ",["ǹ"]="Ǹ",["ǻ"]="Ǻ",["ǽ"]="Ǽ",["ǿ"]="Ǿ",["ȁ"]="Ȁ",["ȃ"]="Ȃ",["ȅ"]="Ȅ",["ȇ"]="Ȇ",["ȉ"]="Ȉ",["ȋ"]="Ȋ",["ȍ"]="Ȍ",["ȏ"]="Ȏ",["ȑ"]="Ȑ",["ȓ"]="Ȓ",["ȕ"]="Ȕ",["ȗ"]="Ȗ",["ș"]="Ș",["ț"]="Ț",["ȝ"]="Ȝ",["ȟ"]="Ȟ",["ȣ"]="Ȣ",["ȥ"]="Ȥ",["ȧ"]="Ȧ",["ȩ"]="Ȩ",["ȫ"]="Ȫ",["ȭ"]="Ȭ",["ȯ"]="Ȯ",["ȱ"]="Ȱ",["ȳ"]="Ȳ",["ȼ"]="Ȼ",["ɂ"]="Ɂ",["ɇ"]="Ɇ",["ɉ"]="Ɉ",["ɋ"]="Ɋ",["ɍ"]="Ɍ",["ɏ"]="Ɏ",["ɓ"]="Ɓ",["ɔ"]="Ɔ",["ɖ"]="Ɖ",["ɗ"]="Ɗ",["ə"]="Ə",["ɛ"]="Ɛ",["ɠ"]="Ɠ",["ɣ"]="Ɣ",["ɨ"]="Ɨ",["ɩ"]="Ɩ",["ɫ"]="Ɫ",["ɯ"]="Ɯ",["ɲ"]="Ɲ",["ɵ"]="Ɵ",["ɽ"]="Ɽ",["ʀ"]="Ʀ",["ʃ"]="Ʃ",["ʈ"]="Ʈ",["ʉ"]="Ʉ",["ʊ"]="Ʊ",["ʋ"]="Ʋ",["ʌ"]="Ʌ",["ʒ"]="Ʒ",["ͅ"]="Ι",["ͻ"]="Ͻ",["ͼ"]="Ͼ",["ͽ"]="Ͽ",["ά"]="Ά",["έ"]="Έ",["ή"]="Ή",["ί"]="Ί",["α"]="Α",["β"]="Β",["γ"]="Γ",["δ"]="Δ",["ε"]="Ε",["ζ"]="Ζ",["η"]="Η",["θ"]="Θ",["ι"]="Ι",["κ"]="Κ",["λ"]="Λ",["μ"]="Μ",["ν"]="Ν",["ξ"]="Ξ",["ο"]="Ο",["π"]="Π",["ρ"]="Ρ",["ς"]="Σ",["σ"]="Σ",["τ"]="Τ",["υ"]="Υ",["φ"]="Φ",["χ"]="Χ",["ψ"]="Ψ",["ω"]="Ω",["ϊ"]="Ϊ",["ϋ"]="Ϋ",["ό"]="Ό",["ύ"]="Ύ",["ώ"]="Ώ",["ϐ"]="Β",["ϑ"]="Θ",["ϕ"]="Φ",["ϖ"]="Π",["ϙ"]="Ϙ",["ϛ"]="Ϛ",["ϝ"]="Ϝ",["ϟ"]="Ϟ",["ϡ"]="Ϡ",["ϣ"]="Ϣ",["ϥ"]="Ϥ",["ϧ"]="Ϧ",["ϩ"]="Ϩ",["ϫ"]="Ϫ",["ϭ"]="Ϭ",["ϯ"]="Ϯ",["ϰ"]="Κ",["ϱ"]="Ρ",["ϲ"]="Ϲ",["ϵ"]="Ε",["ϸ"]="Ϸ",["ϻ"]="Ϻ",["а"]="А",["б"]="Б",["в"]="В",["г"]="Г",["д"]="Д",["е"]="Е",["ж"]="Ж",["з"]="З",["и"]="И",["й"]="Й",["к"]="К",["л"]="Л",["м"]="М",["н"]="Н",["о"]="О",["п"]="П",["р"]="Р",["с"]="С",["т"]="Т",["у"]="У",["ф"]="Ф",["х"]="Х",["ц"]="Ц",["ч"]="Ч",["ш"]="Ш",["щ"]="Щ",["ъ"]="Ъ",["ы"]="Ы",["ь"]="Ь",["э"]="Э",["ю"]="Ю",["я"]="Я",["ѐ"]="Ѐ",["ё"]="Ё",["ђ"]="Ђ",["ѓ"]="Ѓ",["є"]="Є",["ѕ"]="Ѕ",["і"]="І",["ї"]="Ї",["ј"]="Ј",["љ"]="Љ",["њ"]="Њ",["ћ"]="Ћ",["ќ"]="Ќ",["ѝ"]="Ѝ",["ў"]="Ў",["џ"]="Џ",["ѡ"]="Ѡ",["ѣ"]="Ѣ",["ѥ"]="Ѥ",["ѧ"]="Ѧ",["ѩ"]="Ѩ",["ѫ"]="Ѫ",["ѭ"]="Ѭ",["ѯ"]="Ѯ",["ѱ"]="Ѱ",["ѳ"]="Ѳ",["ѵ"]="Ѵ",["ѷ"]="Ѷ",["ѹ"]="Ѹ",["ѻ"]="Ѻ",["ѽ"]="Ѽ",["ѿ"]="Ѿ",["ҁ"]="Ҁ",["ҋ"]="Ҋ",["ҍ"]="Ҍ",["ҏ"]="Ҏ",["ґ"]="Ґ",["ғ"]="Ғ",["ҕ"]="Ҕ",["җ"]="Җ",["ҙ"]="Ҙ",["қ"]="Қ",["ҝ"]="Ҝ",["ҟ"]="Ҟ",["ҡ"]="Ҡ",["ң"]="Ң",["ҥ"]="Ҥ",["ҧ"]="Ҧ",["ҩ"]="Ҩ",["ҫ"]="Ҫ",["ҭ"]="Ҭ",["ү"]="Ү",["ұ"]="Ұ",["ҳ"]="Ҳ",["ҵ"]="Ҵ",["ҷ"]="Ҷ",["ҹ"]="Ҹ",["һ"]="Һ",["ҽ"]="Ҽ",["ҿ"]="Ҿ",["ӂ"]="Ӂ",["ӄ"]="Ӄ",["ӆ"]="Ӆ",["ӈ"]="Ӈ",["ӊ"]="Ӊ",["ӌ"]="Ӌ",["ӎ"]="Ӎ",["ӏ"]="Ӏ",["ӑ"]="Ӑ",["ӓ"]="Ӓ",["ӕ"]="Ӕ",["ӗ"]="Ӗ",["ә"]="Ә",["ӛ"]="Ӛ",["ӝ"]="Ӝ",["ӟ"]="Ӟ",["ӡ"]="Ӡ",["ӣ"]="Ӣ",["ӥ"]="Ӥ",["ӧ"]="Ӧ",["ө"]="Ө",["ӫ"]="Ӫ",["ӭ"]="Ӭ",["ӯ"]="Ӯ",["ӱ"]="Ӱ",["ӳ"]="Ӳ",["ӵ"]="Ӵ",["ӷ"]="Ӷ",["ӹ"]="Ӹ",["ӻ"]="Ӻ",["ӽ"]="Ӽ",["ӿ"]="Ӿ",["ԁ"]="Ԁ",["ԃ"]="Ԃ",["ԅ"]="Ԅ",["ԇ"]="Ԇ",["ԉ"]="Ԉ",["ԋ"]="Ԋ",["ԍ"]="Ԍ",["ԏ"]="Ԏ",["ԑ"]="Ԑ",["ԓ"]="Ԓ",["ա"]="Ա",["բ"]="Բ",["գ"]="Գ",["դ"]="Դ",["ե"]="Ե",["զ"]="Զ",["է"]="Է",["ը"]="Ը",["թ"]="Թ",["ժ"]="Ժ",["ի"]="Ի",["լ"]="Լ",["խ"]="Խ",["ծ"]="Ծ",["կ"]="Կ",["հ"]="Հ",["ձ"]="Ձ",["ղ"]="Ղ",["ճ"]="Ճ",["մ"]="Մ",["յ"]="Յ",["ն"]="Ն",["շ"]="Շ",["ո"]="Ո",["չ"]="Չ",["պ"]="Պ",["ջ"]="Ջ",["ռ"]="Ռ",["ս"]="Ս",["վ"]="Վ",["տ"]="Տ",["ր"]="Ր",["ց"]="Ց",["ւ"]="Ւ",["փ"]="Փ",["ք"]="Ք",["օ"]="Օ",["ֆ"]="Ֆ",["ᵽ"]="Ᵽ",["ḁ"]="Ḁ",["ḃ"]="Ḃ",["ḅ"]="Ḅ",["ḇ"]="Ḇ",["ḉ"]="Ḉ",["ḋ"]="Ḋ",["ḍ"]="Ḍ",["ḏ"]="Ḏ",["ḑ"]="Ḑ",["ḓ"]="Ḓ",["ḕ"]="Ḕ",["ḗ"]="Ḗ",["ḙ"]="Ḙ",["ḛ"]="Ḛ",["ḝ"]="Ḝ",["ḟ"]="Ḟ",["ḡ"]="Ḡ",["ḣ"]="Ḣ",["ḥ"]="Ḥ",["ḧ"]="Ḧ",["ḩ"]="Ḩ",["ḫ"]="Ḫ",["ḭ"]="Ḭ",["ḯ"]="Ḯ",["ḱ"]="Ḱ",["ḳ"]="Ḳ",["ḵ"]="Ḵ",["ḷ"]="Ḷ",["ḹ"]="Ḹ",["ḻ"]="Ḻ",["ḽ"]="Ḽ",["ḿ"]="Ḿ",["ṁ"]="Ṁ",["ṃ"]="Ṃ",["ṅ"]="Ṅ",["ṇ"]="Ṇ",["ṉ"]="Ṉ",["ṋ"]="Ṋ",["ṍ"]="Ṍ",["ṏ"]="Ṏ",["ṑ"]="Ṑ",["ṓ"]="Ṓ",["ṕ"]="Ṕ",["ṗ"]="Ṗ",["ṙ"]="Ṙ",["ṛ"]="Ṛ",["ṝ"]="Ṝ",["ṟ"]="Ṟ",["ṡ"]="Ṡ",["ṣ"]="Ṣ",["ṥ"]="Ṥ",["ṧ"]="Ṧ",["ṩ"]="Ṩ",["ṫ"]="Ṫ",["ṭ"]="Ṭ",["ṯ"]="Ṯ",["ṱ"]="Ṱ",["ṳ"]="Ṳ",["ṵ"]="Ṵ",["ṷ"]="Ṷ",["ṹ"]="Ṹ",["ṻ"]="Ṻ",["ṽ"]="Ṽ",["ṿ"]="Ṿ",["ẁ"]="Ẁ",["ẃ"]="Ẃ",["ẅ"]="Ẅ",["ẇ"]="Ẇ",["ẉ"]="Ẉ",["ẋ"]="Ẋ",["ẍ"]="Ẍ",["ẏ"]="Ẏ",["ẑ"]="Ẑ",["ẓ"]="Ẓ",["ẕ"]="Ẕ",["ẛ"]="Ṡ",["ạ"]="Ạ",["ả"]="Ả",["ấ"]="Ấ",["ầ"]="Ầ",["ẩ"]="Ẩ",["ẫ"]="Ẫ",["ậ"]="Ậ",["ắ"]="Ắ",["ằ"]="Ằ",["ẳ"]="Ẳ",["ẵ"]="Ẵ",["ặ"]="Ặ",["ẹ"]="Ẹ",["ẻ"]="Ẻ",["ẽ"]="Ẽ",["ế"]="Ế",["ề"]="Ề",["ể"]="Ể",["ễ"]="Ễ",["ệ"]="Ệ",["ỉ"]="Ỉ",["ị"]="Ị",["ọ"]="Ọ",["ỏ"]="Ỏ",["ố"]="Ố",["ồ"]="Ồ",["ổ"]="Ổ",["ỗ"]="Ỗ",["ộ"]="Ộ",["ớ"]="Ớ",["ờ"]="Ờ",["ở"]="Ở",["ỡ"]="Ỡ",["ợ"]="Ợ",["ụ"]="Ụ",["ủ"]="Ủ",["ứ"]="Ứ",["ừ"]="Ừ",["ử"]="Ử",["ữ"]="Ữ",["ự"]="Ự",["ỳ"]="Ỳ",["ỵ"]="Ỵ",["ỷ"]="Ỷ",["ỹ"]="Ỹ",["ἀ"]="Ἀ",["ἁ"]="Ἁ",["ἂ"]="Ἂ",["ἃ"]="Ἃ",["ἄ"]="Ἄ",["ἅ"]="Ἅ",["ἆ"]="Ἆ",["ἇ"]="Ἇ",["ἐ"]="Ἐ",["ἑ"]="Ἑ",["ἒ"]="Ἒ",["ἓ"]="Ἓ",["ἔ"]="Ἔ",["ἕ"]="Ἕ",["ἠ"]="Ἠ",["ἡ"]="Ἡ",["ἢ"]="Ἢ",["ἣ"]="Ἣ",["ἤ"]="Ἤ",["ἥ"]="Ἥ",["ἦ"]="Ἦ",["ἧ"]="Ἧ",["ἰ"]="Ἰ",["ἱ"]="Ἱ",["ἲ"]="Ἲ",["ἳ"]="Ἳ",["ἴ"]="Ἴ",["ἵ"]="Ἵ",["ἶ"]="Ἶ",["ἷ"]="Ἷ",["ὀ"]="Ὀ",["ὁ"]="Ὁ",["ὂ"]="Ὂ",["ὃ"]="Ὃ",["ὄ"]="Ὄ",["ὅ"]="Ὅ",["ὑ"]="Ὑ",["ὓ"]="Ὓ",["ὕ"]="Ὕ",["ὗ"]="Ὗ",["ὠ"]="Ὠ",["ὡ"]="Ὡ",["ὢ"]="Ὢ",["ὣ"]="Ὣ",["ὤ"]="Ὤ",["ὥ"]="Ὥ",["ὦ"]="Ὦ",["ὧ"]="Ὧ",["ὰ"]="Ὰ",["ά"]="Ά",["ὲ"]="Ὲ",["έ"]="Έ",["ὴ"]="Ὴ",["ή"]="Ή",["ὶ"]="Ὶ",["ί"]="Ί",["ὸ"]="Ὸ",["ό"]="Ό",["ὺ"]="Ὺ",["ύ"]="Ύ",["ὼ"]="Ὼ",["ώ"]="Ώ",["ᾀ"]="ᾈ",["ᾁ"]="ᾉ",["ᾂ"]="ᾊ",["ᾃ"]="ᾋ",["ᾄ"]="ᾌ",["ᾅ"]="ᾍ",["ᾆ"]="ᾎ",["ᾇ"]="ᾏ",["ᾐ"]="ᾘ",["ᾑ"]="ᾙ",["ᾒ"]="ᾚ",["ᾓ"]="ᾛ",["ᾔ"]="ᾜ",["ᾕ"]="ᾝ",["ᾖ"]="ᾞ",["ᾗ"]="ᾟ",["ᾠ"]="ᾨ",["ᾡ"]="ᾩ",["ᾢ"]="ᾪ",["ᾣ"]="ᾫ",["ᾤ"]="ᾬ",["ᾥ"]="ᾭ",["ᾦ"]="ᾮ",["ᾧ"]="ᾯ",["ᾰ"]="Ᾰ",["ᾱ"]="Ᾱ",["ᾳ"]="ᾼ",["ι"]="Ι",["ῃ"]="ῌ",["ῐ"]="Ῐ",["ῑ"]="Ῑ",["ῠ"]="Ῠ",["ῡ"]="Ῡ",["ῥ"]="Ῥ",["ῳ"]="ῼ",["ⅎ"]="Ⅎ",["ⅰ"]="Ⅰ",["ⅱ"]="Ⅱ",["ⅲ"]="Ⅲ",["ⅳ"]="Ⅳ",["ⅴ"]="Ⅴ",["ⅵ"]="Ⅵ",["ⅶ"]="Ⅶ",["ⅷ"]="Ⅷ",["ⅸ"]="Ⅸ",["ⅹ"]="Ⅹ",["ⅺ"]="Ⅺ",["ⅻ"]="Ⅻ",["ⅼ"]="Ⅼ",["ⅽ"]="Ⅽ",["ⅾ"]="Ⅾ",["ⅿ"]="Ⅿ",["ↄ"]="Ↄ",["ⓐ"]="Ⓐ",["ⓑ"]="Ⓑ",["ⓒ"]="Ⓒ",["ⓓ"]="Ⓓ",["ⓔ"]="Ⓔ",["ⓕ"]="Ⓕ",["ⓖ"]="Ⓖ",["ⓗ"]="Ⓗ",["ⓘ"]="Ⓘ",["ⓙ"]="Ⓙ",["ⓚ"]="Ⓚ",["ⓛ"]="Ⓛ",["ⓜ"]="Ⓜ",["ⓝ"]="Ⓝ",["ⓞ"]="Ⓞ",["ⓟ"]="Ⓟ",["ⓠ"]="Ⓠ",["ⓡ"]="Ⓡ",["ⓢ"]="Ⓢ",["ⓣ"]="Ⓣ",["ⓤ"]="Ⓤ",["ⓥ"]="Ⓥ",["ⓦ"]="Ⓦ",["ⓧ"]="Ⓧ",["ⓨ"]="Ⓨ",["ⓩ"]="Ⓩ",["ⰰ"]="Ⰰ",["ⰱ"]="Ⰱ",["ⰲ"]="Ⰲ",["ⰳ"]="Ⰳ",["ⰴ"]="Ⰴ",["ⰵ"]="Ⰵ",["ⰶ"]="Ⰶ",["ⰷ"]="Ⰷ",["ⰸ"]="Ⰸ",["ⰹ"]="Ⰹ",["ⰺ"]="Ⰺ",["ⰻ"]="Ⰻ",["ⰼ"]="Ⰼ",["ⰽ"]="Ⰽ",["ⰾ"]="Ⰾ",["ⰿ"]="Ⰿ",["ⱀ"]="Ⱀ",["ⱁ"]="Ⱁ",["ⱂ"]="Ⱂ",["ⱃ"]="Ⱃ",["ⱄ"]="Ⱄ",["ⱅ"]="Ⱅ",["ⱆ"]="Ⱆ",["ⱇ"]="Ⱇ",["ⱈ"]="Ⱈ",["ⱉ"]="Ⱉ",["ⱊ"]="Ⱊ",["ⱋ"]="Ⱋ",["ⱌ"]="Ⱌ",["ⱍ"]="Ⱍ",["ⱎ"]="Ⱎ",["ⱏ"]="Ⱏ",["ⱐ"]="Ⱐ",["ⱑ"]="Ⱑ",["ⱒ"]="Ⱒ",["ⱓ"]="Ⱓ",["ⱔ"]="Ⱔ",["ⱕ"]="Ⱕ",["ⱖ"]="Ⱖ",["ⱗ"]="Ⱗ",["ⱘ"]="Ⱘ",["ⱙ"]="Ⱙ",["ⱚ"]="Ⱚ",["ⱛ"]="Ⱛ",["ⱜ"]="Ⱜ",["ⱝ"]="Ⱝ",["ⱞ"]="Ⱞ",["ⱡ"]="Ⱡ",["ⱥ"]="Ⱥ",["ⱦ"]="Ⱦ",["ⱨ"]="Ⱨ",["ⱪ"]="Ⱪ",["ⱬ"]="Ⱬ",["ⱶ"]="Ⱶ",["ⲁ"]="Ⲁ",["ⲃ"]="Ⲃ",["ⲅ"]="Ⲅ",["ⲇ"]="Ⲇ",["ⲉ"]="Ⲉ",["ⲋ"]="Ⲋ",["ⲍ"]="Ⲍ",["ⲏ"]="Ⲏ",["ⲑ"]="Ⲑ",["ⲓ"]="Ⲓ",["ⲕ"]="Ⲕ",["ⲗ"]="Ⲗ",["ⲙ"]="Ⲙ",["ⲛ"]="Ⲛ",["ⲝ"]="Ⲝ",["ⲟ"]="Ⲟ",["ⲡ"]="Ⲡ",["ⲣ"]="Ⲣ",["ⲥ"]="Ⲥ",["ⲧ"]="Ⲧ",["ⲩ"]="Ⲩ",["ⲫ"]="Ⲫ",["ⲭ"]="Ⲭ",["ⲯ"]="Ⲯ",["ⲱ"]="Ⲱ",["ⲳ"]="Ⲳ",["ⲵ"]="Ⲵ",["ⲷ"]="Ⲷ",["ⲹ"]="Ⲹ",["ⲻ"]="Ⲻ",["ⲽ"]="Ⲽ",["ⲿ"]="Ⲿ",["ⳁ"]="Ⳁ",["ⳃ"]="Ⳃ",["ⳅ"]="Ⳅ",["ⳇ"]="Ⳇ",["ⳉ"]="Ⳉ",["ⳋ"]="Ⳋ",["ⳍ"]="Ⳍ",["ⳏ"]="Ⳏ",["ⳑ"]="Ⳑ",["ⳓ"]="Ⳓ",["ⳕ"]="Ⳕ",["ⳗ"]="Ⳗ",["ⳙ"]="Ⳙ",["ⳛ"]="Ⳛ",["ⳝ"]="Ⳝ",["ⳟ"]="Ⳟ",["ⳡ"]="Ⳡ",["ⳣ"]="Ⳣ",["ⴀ"]="Ⴀ",["ⴁ"]="Ⴁ",["ⴂ"]="Ⴂ",["ⴃ"]="Ⴃ",["ⴄ"]="Ⴄ",["ⴅ"]="Ⴅ",["ⴆ"]="Ⴆ",["ⴇ"]="Ⴇ",["ⴈ"]="Ⴈ",["ⴉ"]="Ⴉ",["ⴊ"]="Ⴊ",["ⴋ"]="Ⴋ",["ⴌ"]="Ⴌ",["ⴍ"]="Ⴍ",["ⴎ"]="Ⴎ",["ⴏ"]="Ⴏ",["ⴐ"]="Ⴐ",["ⴑ"]="Ⴑ",["ⴒ"]="Ⴒ",["ⴓ"]="Ⴓ",["ⴔ"]="Ⴔ",["ⴕ"]="Ⴕ",["ⴖ"]="Ⴖ",["ⴗ"]="Ⴗ",["ⴘ"]="Ⴘ",["ⴙ"]="Ⴙ",["ⴚ"]="Ⴚ",["ⴛ"]="Ⴛ",["ⴜ"]="Ⴜ",["ⴝ"]="Ⴝ",["ⴞ"]="Ⴞ",["ⴟ"]="Ⴟ",["ⴠ"]="Ⴠ",["ⴡ"]="Ⴡ",["ⴢ"]="Ⴢ",["ⴣ"]="Ⴣ",["ⴤ"]="Ⴤ",["ⴥ"]="Ⴥ",["ａ"]="Ａ",["ｂ"]="Ｂ",["ｃ"]="Ｃ",["ｄ"]="Ｄ",["ｅ"]="Ｅ",["ｆ"]="Ｆ",["ｇ"]="Ｇ",["ｈ"]="Ｈ",["ｉ"]="Ｉ",["ｊ"]="Ｊ",["ｋ"]="Ｋ",["ｌ"]="Ｌ",["ｍ"]="Ｍ",["ｎ"]="Ｎ",["ｏ"]="Ｏ",["ｐ"]="Ｐ",["ｑ"]="Ｑ",["ｒ"]="Ｒ",["ｓ"]="Ｓ",["ｔ"]="Ｔ",["ｕ"]="Ｕ",["ｖ"]="Ｖ",["ｗ"]="Ｗ",["ｘ"]="Ｘ",["ｙ"]="Ｙ",["ｚ"]="Ｚ",["𐐨"]="𐐀",["𐐩"]="𐐁",["𐐪"]="𐐂",["𐐫"]="𐐃",["𐐬"]="𐐄",["𐐭"]="𐐅",["𐐮"]="𐐆",["𐐯"]="𐐇",["𐐰"]="𐐈",["𐐱"]="𐐉",["𐐲"]="𐐊",["𐐳"]="𐐋",["𐐴"]="𐐌",["𐐵"]="𐐍",["𐐶"]="𐐎",["𐐷"]="𐐏",["𐐸"]="𐐐",["𐐹"]="𐐑",["𐐺"]="𐐒",["𐐻"]="𐐓",["𐐼"]="𐐔",["𐐽"]="𐐕",["𐐾"]="𐐖",["𐐿"]="𐐗",["𐑀"]="𐐘",["𐑁"]="𐐙",["𐑂"]="𐐚",["𐑃"]="𐐛",["𐑄"]="𐐜",["𐑅"]="𐐝",["𐑆"]="𐐞",["𐑇"]="𐐟",["𐑈"]="𐐠",["𐑉"]="𐐡",["𐑊"]="𐐢",["𐑋"]="𐐣",["𐑌"]="𐐤",["𐑍"]="𐐥",["𐑎"]="𐐦",["𐑏"]="𐐧",}
utf8_uc_lc={["A"]="a",["B"]="b",["C"]="c",["D"]="d",["E"]="e",["F"]="f",["G"]="g",["H"]="h",["I"]="i",["J"]="j",["K"]="k",["L"]="l",["M"]="m",["N"]="n",["O"]="o",["P"]="p",["Q"]="q",["R"]="r",["S"]="s",["T"]="t",["U"]="u",["V"]="v",["W"]="w",["X"]="x",["Y"]="y",["Z"]="z",["À"]="à",["Á"]="á",["Â"]="â",["Ã"]="ã",["Ä"]="ä",["Å"]="å",["Æ"]="æ",["Ç"]="ç",["È"]="è",["É"]="é",["Ê"]="ê",["Ë"]="ë",["Ì"]="ì",["Í"]="í",["Î"]="î",["Ï"]="ï",["Ð"]="ð",["Ñ"]="ñ",["Ò"]="ò",["Ó"]="ó",["Ô"]="ô",["Õ"]="õ",["Ö"]="ö",["Ø"]="ø",["Ù"]="ù",["Ú"]="ú",["Û"]="û",["Ü"]="ü",["Ý"]="ý",["Þ"]="þ",["Ā"]="ā",["Ă"]="ă",["Ą"]="ą",["Ć"]="ć",["Ĉ"]="ĉ",["Ċ"]="ċ",["Č"]="č",["Ď"]="ď",["Đ"]="đ",["Ē"]="ē",["Ĕ"]="ĕ",["Ė"]="ė",["Ę"]="ę",["Ě"]="ě",["Ĝ"]="ĝ",["Ğ"]="ğ",["Ġ"]="ġ",["Ģ"]="ģ",["Ĥ"]="ĥ",["Ħ"]="ħ",["Ĩ"]="ĩ",["Ī"]="ī",["Ĭ"]="ĭ",["Į"]="į",["İ"]="i",["Ĳ"]="ĳ",["Ĵ"]="ĵ",["Ķ"]="ķ",["Ĺ"]="ĺ",["Ļ"]="ļ",["Ľ"]="ľ",["Ŀ"]="ŀ",["Ł"]="ł",["Ń"]="ń",["Ņ"]="ņ",["Ň"]="ň",["Ŋ"]="ŋ",["Ō"]="ō",["Ŏ"]="ŏ",["Ő"]="ő",["Œ"]="œ",["Ŕ"]="ŕ",["Ŗ"]="ŗ",["Ř"]="ř",["Ś"]="ś",["Ŝ"]="ŝ",["Ş"]="ş",["Š"]="š",["Ţ"]="ţ",["Ť"]="ť",["Ŧ"]="ŧ",["Ũ"]="ũ",["Ū"]="ū",["Ŭ"]="ŭ",["Ů"]="ů",["Ű"]="ű",["Ų"]="ų",["Ŵ"]="ŵ",["Ŷ"]="ŷ",["Ÿ"]="ÿ",["Ź"]="ź",["Ż"]="ż",["Ž"]="ž",["Ɓ"]="ɓ",["Ƃ"]="ƃ",["Ƅ"]="ƅ",["Ɔ"]="ɔ",["Ƈ"]="ƈ",["Ɖ"]="ɖ",["Ɗ"]="ɗ",["Ƌ"]="ƌ",["Ǝ"]="ǝ",["Ə"]="ə",["Ɛ"]="ɛ",["Ƒ"]="ƒ",["Ɠ"]="ɠ",["Ɣ"]="ɣ",["Ɩ"]="ɩ",["Ɨ"]="ɨ",["Ƙ"]="ƙ",["Ɯ"]="ɯ",["Ɲ"]="ɲ",["Ɵ"]="ɵ",["Ơ"]="ơ",["Ƣ"]="ƣ",["Ƥ"]="ƥ",["Ʀ"]="ʀ",["Ƨ"]="ƨ",["Ʃ"]="ʃ",["Ƭ"]="ƭ",["Ʈ"]="ʈ",["Ư"]="ư",["Ʊ"]="ʊ",["Ʋ"]="ʋ",["Ƴ"]="ƴ",["Ƶ"]="ƶ",["Ʒ"]="ʒ",["Ƹ"]="ƹ",["Ƽ"]="ƽ",["Ǆ"]="ǆ",["ǅ"]="ǆ",["Ǉ"]="ǉ",["ǈ"]="ǉ",["Ǌ"]="ǌ",["ǋ"]="ǌ",["Ǎ"]="ǎ",["Ǐ"]="ǐ",["Ǒ"]="ǒ",["Ǔ"]="ǔ",["Ǖ"]="ǖ",["Ǘ"]="ǘ",["Ǚ"]="ǚ",["Ǜ"]="ǜ",["Ǟ"]="ǟ",["Ǡ"]="ǡ",["Ǣ"]="ǣ",["Ǥ"]="ǥ",["Ǧ"]="ǧ",["Ǩ"]="ǩ",["Ǫ"]="ǫ",["Ǭ"]="ǭ",["Ǯ"]="ǯ",["Ǳ"]="ǳ",["ǲ"]="ǳ",["Ǵ"]="ǵ",["Ƕ"]="ƕ",["Ƿ"]="ƿ",["Ǹ"]="ǹ",["Ǻ"]="ǻ",["Ǽ"]="ǽ",["Ǿ"]="ǿ",["Ȁ"]="ȁ",["Ȃ"]="ȃ",["Ȅ"]="ȅ",["Ȇ"]="ȇ",["Ȉ"]="ȉ",["Ȋ"]="ȋ",["Ȍ"]="ȍ",["Ȏ"]="ȏ",["Ȑ"]="ȑ",["Ȓ"]="ȓ",["Ȕ"]="ȕ",["Ȗ"]="ȗ",["Ș"]="ș",["Ț"]="ț",["Ȝ"]="ȝ",["Ȟ"]="ȟ",["Ƞ"]="ƞ",["Ȣ"]="ȣ",["Ȥ"]="ȥ",["Ȧ"]="ȧ",["Ȩ"]="ȩ",["Ȫ"]="ȫ",["Ȭ"]="ȭ",["Ȯ"]="ȯ",["Ȱ"]="ȱ",["Ȳ"]="ȳ",["Ⱥ"]="ⱥ",["Ȼ"]="ȼ",["Ƚ"]="ƚ",["Ⱦ"]="ⱦ",["Ɂ"]="ɂ",["Ƀ"]="ƀ",["Ʉ"]="ʉ",["Ʌ"]="ʌ",["Ɇ"]="ɇ",["Ɉ"]="ɉ",["Ɋ"]="ɋ",["Ɍ"]="ɍ",["Ɏ"]="ɏ",["Ά"]="ά",["Έ"]="έ",["Ή"]="ή",["Ί"]="ί",["Ό"]="ό",["Ύ"]="ύ",["Ώ"]="ώ",["Α"]="α",["Β"]="β",["Γ"]="γ",["Δ"]="δ",["Ε"]="ε",["Ζ"]="ζ",["Η"]="η",["Θ"]="θ",["Ι"]="ι",["Κ"]="κ",["Λ"]="λ",["Μ"]="μ",["Ν"]="ν",["Ξ"]="ξ",["Ο"]="ο",["Π"]="π",["Ρ"]="ρ",["Σ"]="σ",["Τ"]="τ",["Υ"]="υ",["Φ"]="φ",["Χ"]="χ",["Ψ"]="ψ",["Ω"]="ω",["Ϊ"]="ϊ",["Ϋ"]="ϋ",["Ϙ"]="ϙ",["Ϛ"]="ϛ",["Ϝ"]="ϝ",["Ϟ"]="ϟ",["Ϡ"]="ϡ",["Ϣ"]="ϣ",["Ϥ"]="ϥ",["Ϧ"]="ϧ",["Ϩ"]="ϩ",["Ϫ"]="ϫ",["Ϭ"]="ϭ",["Ϯ"]="ϯ",["ϴ"]="θ",["Ϸ"]="ϸ",["Ϲ"]="ϲ",["Ϻ"]="ϻ",["Ͻ"]="ͻ",["Ͼ"]="ͼ",["Ͽ"]="ͽ",["Ѐ"]="ѐ",["Ё"]="ё",["Ђ"]="ђ",["Ѓ"]="ѓ",["Є"]="є",["Ѕ"]="ѕ",["І"]="і",["Ї"]="ї",["Ј"]="ј",["Љ"]="љ",["Њ"]="њ",["Ћ"]="ћ",["Ќ"]="ќ",["Ѝ"]="ѝ",["Ў"]="ў",["Џ"]="џ",["А"]="а",["Б"]="б",["В"]="в",["Г"]="г",["Д"]="д",["Е"]="е",["Ж"]="ж",["З"]="з",["И"]="и",["Й"]="й",["К"]="к",["Л"]="л",["М"]="м",["Н"]="н",["О"]="о",["П"]="п",["Р"]="р",["С"]="с",["Т"]="т",["У"]="у",["Ф"]="ф",["Х"]="х",["Ц"]="ц",["Ч"]="ч",["Ш"]="ш",["Щ"]="щ",["Ъ"]="ъ",["Ы"]="ы",["Ь"]="ь",["Э"]="э",["Ю"]="ю",["Я"]="я",["Ѡ"]="ѡ",["Ѣ"]="ѣ",["Ѥ"]="ѥ",["Ѧ"]="ѧ",["Ѩ"]="ѩ",["Ѫ"]="ѫ",["Ѭ"]="ѭ",["Ѯ"]="ѯ",["Ѱ"]="ѱ",["Ѳ"]="ѳ",["Ѵ"]="ѵ",["Ѷ"]="ѷ",["Ѹ"]="ѹ",["Ѻ"]="ѻ",["Ѽ"]="ѽ",["Ѿ"]="ѿ",["Ҁ"]="ҁ",["Ҋ"]="ҋ",["Ҍ"]="ҍ",["Ҏ"]="ҏ",["Ґ"]="ґ",["Ғ"]="ғ",["Ҕ"]="ҕ",["Җ"]="җ",["Ҙ"]="ҙ",["Қ"]="қ",["Ҝ"]="ҝ",["Ҟ"]="ҟ",["Ҡ"]="ҡ",["Ң"]="ң",["Ҥ"]="ҥ",["Ҧ"]="ҧ",["Ҩ"]="ҩ",["Ҫ"]="ҫ",["Ҭ"]="ҭ",["Ү"]="ү",["Ұ"]="ұ",["Ҳ"]="ҳ",["Ҵ"]="ҵ",["Ҷ"]="ҷ",["Ҹ"]="ҹ",["Һ"]="һ",["Ҽ"]="ҽ",["Ҿ"]="ҿ",["Ӏ"]="ӏ",["Ӂ"]="ӂ",["Ӄ"]="ӄ",["Ӆ"]="ӆ",["Ӈ"]="ӈ",["Ӊ"]="ӊ",["Ӌ"]="ӌ",["Ӎ"]="ӎ",["Ӑ"]="ӑ",["Ӓ"]="ӓ",["Ӕ"]="ӕ",["Ӗ"]="ӗ",["Ә"]="ә",["Ӛ"]="ӛ",["Ӝ"]="ӝ",["Ӟ"]="ӟ",["Ӡ"]="ӡ",["Ӣ"]="ӣ",["Ӥ"]="ӥ",["Ӧ"]="ӧ",["Ө"]="ө",["Ӫ"]="ӫ",["Ӭ"]="ӭ",["Ӯ"]="ӯ",["Ӱ"]="ӱ",["Ӳ"]="ӳ",["Ӵ"]="ӵ",["Ӷ"]="ӷ",["Ӹ"]="ӹ",["Ӻ"]="ӻ",["Ӽ"]="ӽ",["Ӿ"]="ӿ",["Ԁ"]="ԁ",["Ԃ"]="ԃ",["Ԅ"]="ԅ",["Ԇ"]="ԇ",["Ԉ"]="ԉ",["Ԋ"]="ԋ",["Ԍ"]="ԍ",["Ԏ"]="ԏ",["Ԑ"]="ԑ",["Ԓ"]="ԓ",["Ա"]="ա",["Բ"]="բ",["Գ"]="գ",["Դ"]="դ",["Ե"]="ե",["Զ"]="զ",["Է"]="է",["Ը"]="ը",["Թ"]="թ",["Ժ"]="ժ",["Ի"]="ի",["Լ"]="լ",["Խ"]="խ",["Ծ"]="ծ",["Կ"]="կ",["Հ"]="հ",["Ձ"]="ձ",["Ղ"]="ղ",["Ճ"]="ճ",["Մ"]="մ",["Յ"]="յ",["Ն"]="ն",["Շ"]="շ",["Ո"]="ո",["Չ"]="չ",["Պ"]="պ",["Ջ"]="ջ",["Ռ"]="ռ",["Ս"]="ս",["Վ"]="վ",["Տ"]="տ",["Ր"]="ր",["Ց"]="ց",["Ւ"]="ւ",["Փ"]="փ",["Ք"]="ք",["Օ"]="օ",["Ֆ"]="ֆ",["Ⴀ"]="ⴀ",["Ⴁ"]="ⴁ",["Ⴂ"]="ⴂ",["Ⴃ"]="ⴃ",["Ⴄ"]="ⴄ",["Ⴅ"]="ⴅ",["Ⴆ"]="ⴆ",["Ⴇ"]="ⴇ",["Ⴈ"]="ⴈ",["Ⴉ"]="ⴉ",["Ⴊ"]="ⴊ",["Ⴋ"]="ⴋ",["Ⴌ"]="ⴌ",["Ⴍ"]="ⴍ",["Ⴎ"]="ⴎ",["Ⴏ"]="ⴏ",["Ⴐ"]="ⴐ",["Ⴑ"]="ⴑ",["Ⴒ"]="ⴒ",["Ⴓ"]="ⴓ",["Ⴔ"]="ⴔ",["Ⴕ"]="ⴕ",["Ⴖ"]="ⴖ",["Ⴗ"]="ⴗ",["Ⴘ"]="ⴘ",["Ⴙ"]="ⴙ",["Ⴚ"]="ⴚ",["Ⴛ"]="ⴛ",["Ⴜ"]="ⴜ",["Ⴝ"]="ⴝ",["Ⴞ"]="ⴞ",["Ⴟ"]="ⴟ",["Ⴠ"]="ⴠ",["Ⴡ"]="ⴡ",["Ⴢ"]="ⴢ",["Ⴣ"]="ⴣ",["Ⴤ"]="ⴤ",["Ⴥ"]="ⴥ",["Ḁ"]="ḁ",["Ḃ"]="ḃ",["Ḅ"]="ḅ",["Ḇ"]="ḇ",["Ḉ"]="ḉ",["Ḋ"]="ḋ",["Ḍ"]="ḍ",["Ḏ"]="ḏ",["Ḑ"]="ḑ",["Ḓ"]="ḓ",["Ḕ"]="ḕ",["Ḗ"]="ḗ",["Ḙ"]="ḙ",["Ḛ"]="ḛ",["Ḝ"]="ḝ",["Ḟ"]="ḟ",["Ḡ"]="ḡ",["Ḣ"]="ḣ",["Ḥ"]="ḥ",["Ḧ"]="ḧ",["Ḩ"]="ḩ",["Ḫ"]="ḫ",["Ḭ"]="ḭ",["Ḯ"]="ḯ",["Ḱ"]="ḱ",["Ḳ"]="ḳ",["Ḵ"]="ḵ",["Ḷ"]="ḷ",["Ḹ"]="ḹ",["Ḻ"]="ḻ",["Ḽ"]="ḽ",["Ḿ"]="ḿ",["Ṁ"]="ṁ",["Ṃ"]="ṃ",["Ṅ"]="ṅ",["Ṇ"]="ṇ",["Ṉ"]="ṉ",["Ṋ"]="ṋ",["Ṍ"]="ṍ",["Ṏ"]="ṏ",["Ṑ"]="ṑ",["Ṓ"]="ṓ",["Ṕ"]="ṕ",["Ṗ"]="ṗ",["Ṙ"]="ṙ",["Ṛ"]="ṛ",["Ṝ"]="ṝ",["Ṟ"]="ṟ",["Ṡ"]="ṡ",["Ṣ"]="ṣ",["Ṥ"]="ṥ",["Ṧ"]="ṧ",["Ṩ"]="ṩ",["Ṫ"]="ṫ",["Ṭ"]="ṭ",["Ṯ"]="ṯ",["Ṱ"]="ṱ",["Ṳ"]="ṳ",["Ṵ"]="ṵ",["Ṷ"]="ṷ",["Ṹ"]="ṹ",["Ṻ"]="ṻ",["Ṽ"]="ṽ",["Ṿ"]="ṿ",["Ẁ"]="ẁ",["Ẃ"]="ẃ",["Ẅ"]="ẅ",["Ẇ"]="ẇ",["Ẉ"]="ẉ",["Ẋ"]="ẋ",["Ẍ"]="ẍ",["Ẏ"]="ẏ",["Ẑ"]="ẑ",["Ẓ"]="ẓ",["Ẕ"]="ẕ",["Ạ"]="ạ",["Ả"]="ả",["Ấ"]="ấ",["Ầ"]="ầ",["Ẩ"]="ẩ",["Ẫ"]="ẫ",["Ậ"]="ậ",["Ắ"]="ắ",["Ằ"]="ằ",["Ẳ"]="ẳ",["Ẵ"]="ẵ",["Ặ"]="ặ",["Ẹ"]="ẹ",["Ẻ"]="ẻ",["Ẽ"]="ẽ",["Ế"]="ế",["Ề"]="ề",["Ể"]="ể",["Ễ"]="ễ",["Ệ"]="ệ",["Ỉ"]="ỉ",["Ị"]="ị",["Ọ"]="ọ",["Ỏ"]="ỏ",["Ố"]="ố",["Ồ"]="ồ",["Ổ"]="ổ",["Ỗ"]="ỗ",["Ộ"]="ộ",["Ớ"]="ớ",["Ờ"]="ờ",["Ở"]="ở",["Ỡ"]="ỡ",["Ợ"]="ợ",["Ụ"]="ụ",["Ủ"]="ủ",["Ứ"]="ứ",["Ừ"]="ừ",["Ử"]="ử",["Ữ"]="ữ",["Ự"]="ự",["Ỳ"]="ỳ",["Ỵ"]="ỵ",["Ỷ"]="ỷ",["Ỹ"]="ỹ",["Ἀ"]="ἀ",["Ἁ"]="ἁ",["Ἂ"]="ἂ",["Ἃ"]="ἃ",["Ἄ"]="ἄ",["Ἅ"]="ἅ",["Ἆ"]="ἆ",["Ἇ"]="ἇ",["Ἐ"]="ἐ",["Ἑ"]="ἑ",["Ἒ"]="ἒ",["Ἓ"]="ἓ",["Ἔ"]="ἔ",["Ἕ"]="ἕ",["Ἠ"]="ἠ",["Ἡ"]="ἡ",["Ἢ"]="ἢ",["Ἣ"]="ἣ",["Ἤ"]="ἤ",["Ἥ"]="ἥ",["Ἦ"]="ἦ",["Ἧ"]="ἧ",["Ἰ"]="ἰ",["Ἱ"]="ἱ",["Ἲ"]="ἲ",["Ἳ"]="ἳ",["Ἴ"]="ἴ",["Ἵ"]="ἵ",["Ἶ"]="ἶ",["Ἷ"]="ἷ",["Ὀ"]="ὀ",["Ὁ"]="ὁ",["Ὂ"]="ὂ",["Ὃ"]="ὃ",["Ὄ"]="ὄ",["Ὅ"]="ὅ",["Ὑ"]="ὑ",["Ὓ"]="ὓ",["Ὕ"]="ὕ",["Ὗ"]="ὗ",["Ὠ"]="ὠ",["Ὡ"]="ὡ",["Ὢ"]="ὢ",["Ὣ"]="ὣ",["Ὤ"]="ὤ",["Ὥ"]="ὥ",["Ὦ"]="ὦ",["Ὧ"]="ὧ",["ᾈ"]="ᾀ",["ᾉ"]="ᾁ",["ᾊ"]="ᾂ",["ᾋ"]="ᾃ",["ᾌ"]="ᾄ",["ᾍ"]="ᾅ",["ᾎ"]="ᾆ",["ᾏ"]="ᾇ",["ᾘ"]="ᾐ",["ᾙ"]="ᾑ",["ᾚ"]="ᾒ",["ᾛ"]="ᾓ",["ᾜ"]="ᾔ",["ᾝ"]="ᾕ",["ᾞ"]="ᾖ",["ᾟ"]="ᾗ",["ᾨ"]="ᾠ",["ᾩ"]="ᾡ",["ᾪ"]="ᾢ",["ᾫ"]="ᾣ",["ᾬ"]="ᾤ",["ᾭ"]="ᾥ",["ᾮ"]="ᾦ",["ᾯ"]="ᾧ",["Ᾰ"]="ᾰ",["Ᾱ"]="ᾱ",["Ὰ"]="ὰ",["Ά"]="ά",["ᾼ"]="ᾳ",["Ὲ"]="ὲ",["Έ"]="έ",["Ὴ"]="ὴ",["Ή"]="ή",["ῌ"]="ῃ",["Ῐ"]="ῐ",["Ῑ"]="ῑ",["Ὶ"]="ὶ",["Ί"]="ί",["Ῠ"]="ῠ",["Ῡ"]="ῡ",["Ὺ"]="ὺ",["Ύ"]="ύ",["Ῥ"]="ῥ",["Ὸ"]="ὸ",["Ό"]="ό",["Ὼ"]="ὼ",["Ώ"]="ώ",["ῼ"]="ῳ",["Ω"]="ω",["K"]="k",["Å"]="å",["Ⅎ"]="ⅎ",["Ⅰ"]="ⅰ",["Ⅱ"]="ⅱ",["Ⅲ"]="ⅲ",["Ⅳ"]="ⅳ",["Ⅴ"]="ⅴ",["Ⅵ"]="ⅵ",["Ⅶ"]="ⅶ",["Ⅷ"]="ⅷ",["Ⅸ"]="ⅸ",["Ⅹ"]="ⅹ",["Ⅺ"]="ⅺ",["Ⅻ"]="ⅻ",["Ⅼ"]="ⅼ",["Ⅽ"]="ⅽ",["Ⅾ"]="ⅾ",["Ⅿ"]="ⅿ",["Ↄ"]="ↄ",["Ⓐ"]="ⓐ",["Ⓑ"]="ⓑ",["Ⓒ"]="ⓒ",["Ⓓ"]="ⓓ",["Ⓔ"]="ⓔ",["Ⓕ"]="ⓕ",["Ⓖ"]="ⓖ",["Ⓗ"]="ⓗ",["Ⓘ"]="ⓘ",["Ⓙ"]="ⓙ",["Ⓚ"]="ⓚ",["Ⓛ"]="ⓛ",["Ⓜ"]="ⓜ",["Ⓝ"]="ⓝ",["Ⓞ"]="ⓞ",["Ⓟ"]="ⓟ",["Ⓠ"]="ⓠ",["Ⓡ"]="ⓡ",["Ⓢ"]="ⓢ",["Ⓣ"]="ⓣ",["Ⓤ"]="ⓤ",["Ⓥ"]="ⓥ",["Ⓦ"]="ⓦ",["Ⓧ"]="ⓧ",["Ⓨ"]="ⓨ",["Ⓩ"]="ⓩ",["Ⰰ"]="ⰰ",["Ⰱ"]="ⰱ",["Ⰲ"]="ⰲ",["Ⰳ"]="ⰳ",["Ⰴ"]="ⰴ",["Ⰵ"]="ⰵ",["Ⰶ"]="ⰶ",["Ⰷ"]="ⰷ",["Ⰸ"]="ⰸ",["Ⰹ"]="ⰹ",["Ⰺ"]="ⰺ",["Ⰻ"]="ⰻ",["Ⰼ"]="ⰼ",["Ⰽ"]="ⰽ",["Ⰾ"]="ⰾ",["Ⰿ"]="ⰿ",["Ⱀ"]="ⱀ",["Ⱁ"]="ⱁ",["Ⱂ"]="ⱂ",["Ⱃ"]="ⱃ",["Ⱄ"]="ⱄ",["Ⱅ"]="ⱅ",["Ⱆ"]="ⱆ",["Ⱇ"]="ⱇ",["Ⱈ"]="ⱈ",["Ⱉ"]="ⱉ",["Ⱊ"]="ⱊ",["Ⱋ"]="ⱋ",["Ⱌ"]="ⱌ",["Ⱍ"]="ⱍ",["Ⱎ"]="ⱎ",["Ⱏ"]="ⱏ",["Ⱐ"]="ⱐ",["Ⱑ"]="ⱑ",["Ⱒ"]="ⱒ",["Ⱓ"]="ⱓ",["Ⱔ"]="ⱔ",["Ⱕ"]="ⱕ",["Ⱖ"]="ⱖ",["Ⱗ"]="ⱗ",["Ⱘ"]="ⱘ",["Ⱙ"]="ⱙ",["Ⱚ"]="ⱚ",["Ⱛ"]="ⱛ",["Ⱜ"]="ⱜ",["Ⱝ"]="ⱝ",["Ⱞ"]="ⱞ",["Ⱡ"]="ⱡ",["Ɫ"]="ɫ",["Ᵽ"]="ᵽ",["Ɽ"]="ɽ",["Ⱨ"]="ⱨ",["Ⱪ"]="ⱪ",["Ⱬ"]="ⱬ",["Ⱶ"]="ⱶ",["Ⲁ"]="ⲁ",["Ⲃ"]="ⲃ",["Ⲅ"]="ⲅ",["Ⲇ"]="ⲇ",["Ⲉ"]="ⲉ",["Ⲋ"]="ⲋ",["Ⲍ"]="ⲍ",["Ⲏ"]="ⲏ",["Ⲑ"]="ⲑ",["Ⲓ"]="ⲓ",["Ⲕ"]="ⲕ",["Ⲗ"]="ⲗ",["Ⲙ"]="ⲙ",["Ⲛ"]="ⲛ",["Ⲝ"]="ⲝ",["Ⲟ"]="ⲟ",["Ⲡ"]="ⲡ",["Ⲣ"]="ⲣ",["Ⲥ"]="ⲥ",["Ⲧ"]="ⲧ",["Ⲩ"]="ⲩ",["Ⲫ"]="ⲫ",["Ⲭ"]="ⲭ",["Ⲯ"]="ⲯ",["Ⲱ"]="ⲱ",["Ⲳ"]="ⲳ",["Ⲵ"]="ⲵ",["Ⲷ"]="ⲷ",["Ⲹ"]="ⲹ",["Ⲻ"]="ⲻ",["Ⲽ"]="ⲽ",["Ⲿ"]="ⲿ",["Ⳁ"]="ⳁ",["Ⳃ"]="ⳃ",["Ⳅ"]="ⳅ",["Ⳇ"]="ⳇ",["Ⳉ"]="ⳉ",["Ⳋ"]="ⳋ",["Ⳍ"]="ⳍ",["Ⳏ"]="ⳏ",["Ⳑ"]="ⳑ",["Ⳓ"]="ⳓ",["Ⳕ"]="ⳕ",["Ⳗ"]="ⳗ",["Ⳙ"]="ⳙ",["Ⳛ"]="ⳛ",["Ⳝ"]="ⳝ",["Ⳟ"]="ⳟ",["Ⳡ"]="ⳡ",["Ⳣ"]="ⳣ",["Ａ"]="ａ",["Ｂ"]="ｂ",["Ｃ"]="ｃ",["Ｄ"]="ｄ",["Ｅ"]="ｅ",["Ｆ"]="ｆ",["Ｇ"]="ｇ",["Ｈ"]="ｈ",["Ｉ"]="ｉ",["Ｊ"]="ｊ",["Ｋ"]="ｋ",["Ｌ"]="ｌ",["Ｍ"]="ｍ",["Ｎ"]="ｎ",["Ｏ"]="ｏ",["Ｐ"]="ｐ",["Ｑ"]="ｑ",["Ｒ"]="ｒ",["Ｓ"]="ｓ",["Ｔ"]="ｔ",["Ｕ"]="ｕ",["Ｖ"]="ｖ",["Ｗ"]="ｗ",["Ｘ"]="ｘ",["Ｙ"]="ｙ",["Ｚ"]="ｚ",["𐐀"]="𐐨",["𐐁"]="𐐩",["𐐂"]="𐐪",["𐐃"]="𐐫",["𐐄"]="𐐬",["𐐅"]="𐐭",["𐐆"]="𐐮",["𐐇"]="𐐯",["𐐈"]="𐐰",["𐐉"]="𐐱",["𐐊"]="𐐲",["𐐋"]="𐐳",["𐐌"]="𐐴",["𐐍"]="𐐵",["𐐎"]="𐐶",["𐐏"]="𐐷",["𐐐"]="𐐸",["𐐑"]="𐐹",["𐐒"]="𐐺",["𐐓"]="𐐻",["𐐔"]="𐐼",["𐐕"]="𐐽",["𐐖"]="𐐾",["𐐗"]="𐐿",["𐐘"]="𐑀",["𐐙"]="𐑁",["𐐚"]="𐑂",["𐐛"]="𐑃",["𐐜"]="𐑄",["𐐝"]="𐑅",["𐐞"]="𐑆",["𐐟"]="𐑇",["𐐠"]="𐑈",["𐐡"]="𐑉",["𐐢"]="𐑊",["𐐣"]="𐑋",["𐐤"]="𐑌",["𐐥"]="𐑍",["𐐦"]="𐑎",["𐐧"]="𐑏",}
