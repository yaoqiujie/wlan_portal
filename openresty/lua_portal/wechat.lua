local redis = redis or require "resty.redis"
local resty_sha1 = resty_sha1 or require "resty.sha1"
local resty_str = resty_str or require "resty.string"
local uuid = uuid or require "resty.uuid"

-- bind the openid to a tmpid
function bind_openid(openid, tmpid, duration)
	local REDIS_HOST="192.168.119.11"
	local REDIS_PORT="6379"
	local REDIS_TIMEOUT=2000

	local red, err = redis:new()
	if not red then
		ngx.log(ngx.ERR, "Failed to instantiate redis: ", err)
		return false
	end
	
	red:set_timeout(REDIS_TIMEOUT)
	local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
	if not ok then
		ngx.log(ngx.ERR, "Failed to connect to redis server [", REDIS_HOST, ":", REDIS_PORT, "] due to: ", err)
		return false
	end
	
	ok, err = red:set(tmpid, openid)
	if not ok then
		ngx.log(ngx.ERR, "Failed to register OpenID [", openid, "] with [", tmpid, "]")
		return false
	end
	ok, err = red:expire(tmpid, duration)
	if not ok then
		ngx.log(ngx.ERR, "Failed to expire the binding")
		return false
	end
	
	ok, err = red:set_keepalive(200000, 100)
	if not ok then
		ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
	end

	return true
end

function checkSign()
	local sha1 = resty_sha1:new()
	if not sha1 then
	    ngx.log(ngx.ERR, "failed to create the sha1 object")
	    return false
	end
	
	local signature = ngx.var.arg_signature
	local timestamp = ngx.var.arg_timestamp
	local nonce = ngx.var.arg_nonce
	local token = "yaoqiujie"
	if signature == nil or timestamp == nil or nonce == nil then
		ngx.log(ngx.ERR, "Null input value")
		return false
	end

	ngx.log(ngx.DEBUG, "signature:[", signature, "], timestamp:[", timestamp, "], nonce:[", nonce, "]")

	-- Sort the timestamp, nonce, token
	if timestamp < nonce then
		token = timestamp..nonce..token
	else
		token = nonce..timestamp..token
	end
	local ok = sha1:update(token)
	if not ok then
	    ngx.log(ngx.ERR, "failed to add data")
	    return false
	end

	local digest = sha1:final()
	if signature ~= resty_str.to_hex(digest) then
		return false
	else
		return true
	end
end

function register_openid(openid)
	local tmpid = string.gsub(uuid.generate(), "-", "")
	tmpid = string.sub(tmpid, 1, 16)
	
	if bind_openid(openid, tmpid, 10*60) then
		return tmpid
	else
		return ""
	end
end

--
-- Main routine starts here
--

-- verify the message
if not checkSign() then
	ngx.log(ngx.ERR, "Invalid message")
	ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- Parse the data
do
	ngx.req.read_body()
	local data = ngx.req.get_body_data()
	ngx.log(ngx.DEBUG, "Received Data:[", data, "]")

	local toUserName, fromUserName, msgType, content = string.match(data, "<ToUserName><!%[CDATA%[(.*)%]%]></ToUserName>.*<FromUserName><!%[CDATA%[(.*)%]%]></FromUserName>.*<MsgType><!%[CDATA%[(.*)%]%]></MsgType>.*<Content><!%[CDATA%[(.*)%]%]></Content>")
	if toUserName == nil or fromUserName == nil or msgType == nil or content == nil or msgType ~= "text" or string.lower(content) ~= "wifi" then
		ngx.say("")
		ngx.exit(ngx.HTTP_OK)
	end

	local resp = string.format("<xml><ToUserName><![CDATA[%s]]></ToUserName><FromUserName><![CDATA[%s]]></FromUserName>	<CreateTime>%s</CreateTime>	<MsgType><![CDATA[text]]></MsgType>	<Content><![CDATA[http://gscopetech.com/%s]]></Content>	</xml>", fromUserName, toUserName, tostring(os.time()), register_openid(fromUserName))
	ngx.say(resp)
end
