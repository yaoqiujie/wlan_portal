local _M = { _VERSION = '0.1' }

local ffi = require "ffi"
local uuid = uuid or require "resty.uuid"

ffi.cdef[[
    struct in_addr {
        uint32_t s_addr;
    };

    int inet_aton(const char *cp, struct in_addr *inp);
    uint32_t ntohl(uint32_t netlong);

    char *inet_ntoa(struct in_addr in);
    uint32_t htonl(uint32_t hostlong);
]]

local C = ffi.C

function _M.ip2long(ip)
    local inp = ffi.new("struct in_addr[1]")
    if C.inet_aton(ip, inp) ~= 0 then
        return tonumber(C.ntohl(inp[0].s_addr))
    end
    return nil
end

function _M.long2ip(long)
    if type(long) ~= "number" then
        return nil
    end
    local addr = ffi.new("struct in_addr")
    addr.s_addr = C.htonl(long)
    return ffi.string(C.inet_ntoa(addr))
end

function _M.token(len)
    local token = string.gsub(uuid.generate(), "-", "")

	if len >= 32 then
    	return token
	else
		return string.sub(token, 1, len)
	end
end

--function _M.str2hex(s)
--	local s = string.gsub(s, "(.)", function (x) return string.format("%02X",string.byte(x)) end)
--	return s
--end

function _M.hex2str(hex)
    local str, n = hex:gsub("(%x%x)[ ]?", function (word)
			return string.char(tonumber(word, 16))
		end)
	return str
end

function _M.decrypt_mac(encrypted_mac)
	local des = require "resty.nettle.des"
	local key = des.new("12345678")

	return key:decrypt(_M.hex2str(encrypted_mac))
end

function _M.trim(s)
	return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

return _M
