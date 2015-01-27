local _M = { _VERSION = '0.1' }

local bit = require "bit"
local cjson = require "cjson"
local http = require "resty.http"
local redis = require "resty.redis"
local conf = conf or require "portalconfig"
local utils = utils or require "utils"
local proto = proto or require "protocol"

-- Generate security token
function _M.gen_token(mac)
	local red, err = redis:new()
	if not red then
		ngx.log(ngx.ERR, "Failed to instantiate redis: ", err)
		return false
	end
	
	red:set_timeout(conf.REDIS_TIMEOUT)
	local ok, err = red:connect(conf.REDIS_HOST, conf.REDIS_PORT)
	if not ok then
		ngx.log(ngx.ERR, "Failed to connect to redis server [", conf.REDIS_HOST, ":", conf.REDIS_PORT, "] due to: ", err)
		return false
	end
	
	-- security token
	local sec_token = utils.token(6) -- The length of the token is 6
	ngx.log(ngx.DEBUG, mac..":token")
	ok, err = red:set(mac..":token", sec_token)
	if not ok then
		ngx.log(ngx.ERR, "Failed to bind the security token to mac: ", mac)
		return false
	end
	ok, err = red:expire(mac..":token", conf.TOKEN_DURATION)
	if not ok then
		ngx.log(ngx.CRIT, "Failed to expire the security token")
		return false
	end

	ok, err = red:set_keepalive(200000, 100)
	if not ok then
		ngx.say("failed to set keepalive: ", err)
	end

	return true, sec_token
end

-- Verify the security token
function _M.verify_token(mac, token)
	local red, err = redis:new()
	if not red then
		ngx.log(ngx.ERR, "Failed to instantiate redis: ", err)

		return false
	end

	red:set_timeout(conf.REDIS_TIMEOUT)
	local ok, err = red:connect(conf.REDIS_HOST, conf.REDIS_PORT)
	if not ok then
		ngx.log(ngx.ERR, "Failed to connect to redis server [", conf.REDIS_HOST, ":", conf.REDIS_PORT, "] due to: ", err)
		return false
	end

	local res, err = red:get(mac..":token")
	if not res then
		ngx.log(ngx.ERR, "Failed to get the token for mac: "..mac)
		return false
	end
	if res == ngx.null then
		ngx.log(ngx.DEBUG, "The token for mac: ", mac, " is expired")
		return false
	end
	if res ~= token then
		ngx.log(ngx.DEBUG, "Token mismatch: [", token, "], [", res, "]")
		return false
	end

	ok, err = red:set_keepalive(200000, 100)
	if not ok then
		ngx.log(ngx.ERR, "failed to set keepalive: ", err)
	end

	return true
end


-- bind the given MAC address to the given account
function _M.bind_mac(mac, account)
	local red, err = redis:new()
	if not red then
		ngx.log(ngx.ERR, "Failed to instantiate redis: ", err)
		return
	end
	
	red:set_timeout(conf.REDIS_TIMEOUT)
	local ok, err = red:connect(conf.REDIS_HOST, conf.REDIS_PORT)
	if not ok then
		ngx.log(ngx.ERR, "Failed to connect to redis server [", conf.REDIS_HOST, ":", conf.REDIS_PORT, "] due to: ", err)
		return
	end
	
	ok, err = red:set(mac, account)
	if not ok then
		ngx.log(ngx.ERR, "Failed to register MAC [", mac, "] with [", account, "]")
		return
	end
	ok, err = red:expire(mac, conf.BINDING_DURATION)
	if not ok then
		ngx.log(ngx.CRIT, "Failed to expire the binding")
		return
	end
	
	ok, err = red:set_keepalive(200000, 100)
	if not ok then
		ngx.say("failed to set keepalive: ", err)
		return
	end

end

-- Check the given key existing or not
function _M.is_bound(key)
	local red, err = redis:new()
	if not red then
		ngx.log(ngx.ERR, "Failed to instantiate redis: ", err)

		return false
	end

	red:set_timeout(conf.REDIS_TIMEOUT)
	local ok, err = red:connect(conf.REDIS_HOST, conf.REDIS_PORT)
	if not ok then
		ngx.log(ngx.ERR, "Failed to connect to redis server [", conf.REDIS_HOST, ":", conf.REDIS_PORT, "] due to: ", err)
		return false
	end

	local res, err = red:get(key)
	if not res then
		ngx.log(ngx.ERR, "Failed to get [", key, "] due to: ", err)
		return false
	end
	if res == ngx.null then
		ngx.log(ngx.DEBUG, key, " is not bound")
		return false
	end

	ok, err = red:set_keepalive(200000, 100)
	if not ok then
		ngx.log(ngx.ERR, "failed to set keepalive: ", err)
	end

	return true, res
end

function _M.get_openid(tmpid)
	local httpc = http.new()
	httpc:set_timeout(5000)
	
	do
		local ok, err = httpc:connect(conf.WECHAT_HOST, conf.WECHAT_PORT)
		if not ok then
			return false, "Failed to connect to "..conf.WECHAT_HOST
		end
	end
	
	do
		local res, err = httpc:request({
			path = "/openid?tmpid="..tmpid,
			methd = "GET",
		})
	
		if not res then
			return false, err
		end
	
		local body, err = res:read_body()
		if not body then
			return false, err
		end

		do
			local ok, err = httpc:set_keepalive()
			if not ok then
				ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
			end
		end

		return true, utils.trim(body)
	end
end

function _M.createOrUpdate(username, password)
	local httpc = http.new()
	httpc:set_timeout(1000)
	
	do
		local ok, err = httpc:connect(conf.RADIUS_HOST, conf.RADIUS_PORT)
		if not ok then
			ngx.log(ngx.ERR, "Failed to connect to ", conf.RADIUS_HOST)
			return false
		end
	end
	
	do
		local res, err = httpc:request({
			path = "/createorupdateuser",
			methd = "POST",
			body = "username="..username.."&password="..password,
			headers = {["Content-Type"] = "application/x-www-form-urlencoded",
			}
		})
	
		if not res then
			ngx.log(ngx.ERR, "Failed to issue the POST request due to: ", err)
			return false
		end
	
		local body, err = res:read_body()
		if not body then
			ngx.log(ngx.ERR, "Failed to parse the result: ", err)
			return false
		end

		local result = cjson.decode(body)["result"]
		if result ~= "OK" then
			ngx.log(ngx.ERR, "Failed to createOrUpdate the user due to: ", cjson.decode(body)["message"])
			return false
		end
	end
	
	do
		local ok, err = httpc:set_keepalive()
		if not ok then
			ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
		end
	end

	return true
end

function _M.auth(acip, userip, usermac, username, password)
	-- udp socket
	local sock = ngx.socket.udp()
	local ok, err = sock:setpeername(acip, 2000)
	if not ok then
		ngx.log(ngx.ERR, "Failed to connect to the server: ", acip)
	
		return false, "连接AC失败"
	end
	
	sock:settimeout(2000) -- Two seconds timeout
	
	-- Send REQ_CHALLENGE
	local challenge_serial = proto.serial_number()
	do
		local challenge_datagram = proto.pack_req_challenge(challenge_serial, userip)
		local ok, err = sock:send(challenge_datagram)
		if not ok then
			ngx.log(ngx.ERR, "Failed to send the REQ_CHALLENGE to the server: ", acip)
		
			-- TODO
			sock:close()
			return false, "发送REQ_CHALLENGE失败"
		end
		ngx.log(ngx.INFO, "Successfully sent out the REQ_CHALLENGE to the server: ", acip)
	end
	
	-- Receive ACK_CHALLENGE
	local req_id = 0x00ff
	local challenge = 0
	do
		local challenge_resp, err = sock:receive(256)
		if not challenge_resp then
			ngx.log(ngx.ERR, "Failed to receive the ACK_CHALLENGE from the server: ", acip)
			
			-- TODO
			sock:close()
			return false, "获取ACK_CHALLENGE失败"
		end
		ngx.log(ngx.INFO, "Successfully received the ACK_CHALLENGE from the server: ", acip)
	
	-- Unpack ACK_CHALLENGE
		local ok, header, attrs = proto.unpack_response(challenge_resp)
		if not ok then
			ngx.log(ngx.ERR, "Invalid ACK_CHALLENGE response from the server: ", acip)
	
			-- TODO
			sock:close()
			return false, "非法ACK_CHALLENGE"
		end
	
		-- header: 
		-- { ver, type, chap, rsv, serial_num, req_id, 
		--   userip, user_port, err_code, attr_num }
		if header.type ~= proto.MSG.ACK_CHALLENGE then
			ngx.log(ngx.ERR, "Bad response for the REQ_CHALLENGE from the server: ", acip)
	
			-- TODO
			sock:close()
			return false, "非法ACK_CHALLENGE"
		end
	
		ngx.log(ngx.INFO, "CHALLENGE Serial: ", challenge_serial)
		ngx.log(ngx.INFO, "ACK_CHALLENGE Serial: ", header.serial_num)
		if header.serial_num ~= challenge_serial then
			ngx.log(ngx.ERR, "Unmatched serial number in the ACK_CHALLENGE from the server: ", acip)
	
			-- TODO
			sock:close()
			return false, "序列号不匹配"
		end
	
		if header.err_code ~= 0 then
			ngx.log(ngx.ERR, "ACK_CHALLENGE from server: ", acip, " returned error code: ", header.err_code)
	
			-- TODO
			sock:close()
			return false, "ACK_CHALLENGE返回错误"..header.err_code
		end
	
		-- Retrieve the req_id
		req_id = header.req_id
	
		-- TLVs
		if attrs == nil or attrs[proto.ATTRS.CHALLENGE] == nil then
			ngx.log(ngx.ERR, "No challenge in the ACK_CHALLENGE from server: ", acip)
	
			-- TODO
			sock:close()
			return false, "ACK_CHALLENGE没有包含challenge"
		end
		-- Retrieve the challenge
		challenge = attrs[proto.ATTRS.CHALLENGE]
	
		ngx.log(ngx.INFO, "REQ_ID: [", req_id, "], Challenge: [", challenge, "]")
	end
	
	do
		local chap_id = bit.band(req_id, 0xff)
		local chap_passwd = proto.chap_encrypt(chap_id, password, challenge)
	
		local auth_serial = proto.serial_number()
	
		-- Send REQ_AUTH
		do
			local auth_datagram = proto.pack_req_auth(auth_serial, req_id, userip, username, chap_passwd)
			local ok, err = sock:send(auth_datagram)
			if not ok then
				ngx.log(ngx.ERR, "Failed to send the REQ_AUTH to the server: ", acip)
			
				-- TODO
				sock:close()
				return false, "发送REQ_AUTH失败"
			end
			ngx.log(ngx.INFO, "Successfully sent out the REQ_AUTH to the server: ", acip)
	
		end
	
		-- Receive ACK_AUTH
		do
			local auth_resp, err = sock:receive(256)
			if not auth_resp then
				ngx.log(ngx.ERR, "Failed to receive the ACK_AUTH from the server: ", acip)
				
				-- TODO
				sock:close()
				return false, "获取ACK_AUTH失败"
			end
			ngx.log(ngx.INFO, "Successfully received the ACK_AUTH from the server: ", acip)
			
			-- Unpack ACK_AUTH
			local ok, header, attrs = proto.unpack_response(auth_resp)
			if not ok then
				ngx.log(ngx.ERR, "Invalid ACK_AUTH response from the server: ", acip)
		
				-- TODO
				sock:close()
				return false, "非法ACK_AUTH"
			end
		
			-- header: 
			-- { ver, type, chap, rsv, serial_num, req_id, 
			--   userip, user_port, err_code, attr_num }
			if header.type ~= proto.MSG.ACK_AUTH then -- ACK_AUTH/0x02
				ngx.log(ngx.ERR, "Bad response for the REQ_AUTH from the server: ", acip)
		
				-- TODO
				sock:close()
				return false, "非法ACK_AUTH"
			end
		
			if header.serial_num ~= auth_serial then
				ngx.log(ngx.ERR, "Unmatched serial number in the ACK_AUTH from the server: ", acip)
		
				-- TODO
				sock:close()
				return false, "ACK_AUTH 序列号不匹配"
			end
		
			if header.err_code ~= 0 then
				ngx.log(ngx.ERR, "ACK_AUTH from server: ", acip, " returned error code: ", header.err_code)
		
				-- TODO
				sock:close()
				return false, "认证失败"
			end
		end
	
	
		-- Register the MAC
		_M.bind_mac(usermac, username)
	
		-- Send AFF_ACK_AUTH
		do
			local aff_ack = proto.pack_aff_ack_auth(auth_serial, req_id, userip)
			local ok, err = sock:send(aff_ack)
			if not ok then
				ngx.log(ngx.ERR, "Failed to send the AFF_ACK_AUTH to the server: ", acip)
			
			end
			ngx.log(ngx.INFO, "Successfully sent out the AFF_ACK_AUTH to the server: ", acip)
		end

		-- TODO
		sock:close()
		return true, "Success"
	end
end

return _M
