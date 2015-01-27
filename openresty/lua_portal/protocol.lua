local _M = { _VERSION = '0.1' }

local utils = utils or require "utils"

require "pack"
local bpack = string.pack
local bunpack = string.unpack

-- UDP Message type constants
_M.MSG = {
	REQ_CHALLENGE = 0x01,
	ACK_CHALLENGE = 0x02,
	REQ_AUTH = 0x03,
	ACK_AUTH = 0x04,
	REQ_LOGOUT = 0x05,
	ACK_LOGOUT = 0x06,
	AFF_ACK_AUTH = 0x07,
	NTF_LOGOUT = 0x08,
	REQ_INFO = 0x09,
	ACK_INFO = 0x0a
}

function _M.serial_number()
	local serial = utils.token(4)
	return tonumber(serial, 16)
end

-- CHAP_PASSWORD = md5(chap_id + cleartext_password + challenge)
function _M.chap_encrypt(chap_id, cleartext_passwd, challenge)
	local seed = string.format("%s%s%s", string.char(chap_id), cleartext_passwd, challenge)
	return ngx.md5_bin(seed)
end


function _M.pack_req_cha(serial_num, ip_addr)
	local datagram = {0x01, }
end

-- Pack the datagram of the REQ_CHALLENGE request
function _M.pack_req_challenge(serial_num, ip_addr)
	-- Ver=0x01, Type=0x01, Chap=0x00, Rsv=0x00, SerialNo, ReqID=0
	-- UserIP, UserPort=0, ErrCode=0x00, AttrNum=0x00
	local datagram = bpack(">b4H2IHb2", 0x01, 0x01, 0, 0, 
		serial_num, 0, utils.ip2long(ip_addr), 0, 0, 0)

	return datagram
end

-- Pack the datagram of the REQ_AUTH request
function _M.pack_req_auth(serial_num, req_id, ip_addr, username, chap_passwd)

	-- Ver=0x01, Type=0x03, Chap=0x00, Rsv=0x00, SerialNo, ReqID
	-- UserIP, UserPort=0, ErrCode=0x00, AttrNum=0x02
	-- TLVs...
	local datagram = bpack(">b4H2IHb2b2Ab2A", 0x01, 0x03, 0, 0, 
		serial_num, req_id, utils.ip2long(ip_addr), 0, 0, 2,
		0x01, string.len(username)+2, username,
		0x04, 18, chap_passwd)

	return datagram
end

-- Pack the datagram of the AFF_ACK_AUTH request
function _M.pack_aff_ack_auth(serial_num, req_id, ip_addr)
	-- Ver=0x01, Type=0x07, Chap=0x00, Rsv=0x00, SerialNo, ReqID
	-- UserIP, UserPort=0, ErrCode=0, AttrNum=0
	local datagram = bpack(">b4H2IHb2", 0x01, 0x07, 0, 0, 
		serial_num, req_id, utils.ip2long(ip_addr), 0, 0, 0)

	return datagram
end

-- TLV Type constants
_M.ATTRS = {
	USERNAME = 0x01,
	PASSWORD = 0x02,
	CHALLENGE = 0x03,
	CHAPPASS = 0x04,
	ERRID = 0x05
}

-- Unpack the datagram of the response
function _M.unpack_response(resp)
	-- parse the header of the datagram
	local header = {}
	local pos = 1
	do
		pos, header.ver, header.type, header.chap, header.rsv, 
		header.serial_num, header.req_id, header.user_ip, header.user_port, 
		header.err_code, header.attr_num = bunpack(resp, ">b4H2IHb2")

		-- check the attributes in the header
		for key, value in pairs(header) do
			if value == nil then
				return false
			end
		end

		if header.attr_num == 0 then
			return true, header
		end
	end

	-- parse TLVs
	local attrs = {}
	while pos < #resp do
		local tlv = {}
		pos, tlv.type, tlv.len = bunpack(resp, ">b2", pos)
		pos, tlv.value = bunpack(resp, ">A"..(tlv.len-2), pos)
		attrs[tlv.type] = tlv.value
	end

	return true, header, attrs
end

return _M
