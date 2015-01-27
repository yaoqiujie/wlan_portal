local bit = require "bit"
local str = require "resty.string"
local uuid = require "resty.uuid"
local proto = proto or require "protocol"
local utils = require "utils"


--local token = uuid.generate()
--ngx.say(token)
ngx.say(utils.token(8))
ngx.say(utils.token(6))
ngx.say(utils.token(4))
ngx.say("\n")
--ngx.say(uuid.generate_random())




--require "pack"
--local bpack=string.pack
--local bunpack=string.unpack

ngx.say(utils.token(5))
ngx.say("\n")
ngx.say(utils.token(10))
ngx.say("\n")
ngx.say(utils.token(20))
--function hex(s)
--	s=string.gsub(s,"(.)",function (x) return string.format("%02X:",string.byte(x)) end)
--	return s
--end
--
--ngx.say(proto.ATTRS.CHALLENGE)
--ngx.say("\n")
--local serial = proto.serial_number()
----local datagram = proto.pack_req_challenge(serial, "10.77.0.5")
--local datagram = proto.pack_req_auth(serial,  0x8e6c, "10.77.0.5", "yaoqiujie&%$/", "8d34f06a7349e1cc")
--
--ngx.say(hex(datagram))
--
--local ok, header, attrs = proto.unpack_response(datagram)
--ngx.say(ok)
--ngx.say(utils.long2ip(header.user_ip))
--ngx.say(string.format("%04x",header.serial_num))
--ngx.say(string.format("%04x", header.req_id))
--ngx.say(attrs[0x01])
--ngx.say(attrs[0x04])






ngx.say(ngx.md5("HelloWorld"))
--local seed = string.format("%s%s%s", string.char(0xa3), "penny", "aeec9bfeb7b6383d")
--local chap_passwd = string.sub(ngx.md5(seed), 9, 24)
--local chap_passwd = ngx.md5_bin(seed)
--ngx.say(hex(chap_passwd))

--ngx.say(0x1234)
--ngx.say(bit.band(0x1234, 0xff))
--ngx.say(seed)
--ngx.say(chap_passwd)
--ngx.say(string.len(chap_passwd))
