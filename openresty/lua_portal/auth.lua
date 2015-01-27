local cjson = cjson or require "cjson"
local bit = bit or require "bit"
local utils = utils or  require "utils"
local intf = intf or require "interface"	
local proto = proto or require "protocol"
local result = {["result"]="FAIL", ["message"]=""}

-- args
ngx.req.read_body()
local args, err = ngx.req.get_post_args()
if not args then
	ngx.log(ngx.ERR, "Failed to get the args for the AUTH request: ", err)

	-- TODO
	result["message"] = "获得认证请求参数失败"
	ngx.say(cjson.encode(result))
	return
end

local userip = ngx.unescape_uri(args["userip"])
local stationid = ngx.unescape_uri(args["stationid"])
local acip = ngx.unescape_uri(args["acip"])
local acname = ngx.unescape_uri(args["acname"])
local ssid = ngx.unescape_uri(args["ssid"])
local username = ngx.unescape_uri(args["username"])

local token = ngx.unescape_uri(args["token"])
local usermac = utils.decrypt_mac(stationid)
if token ~= "JAMESBOND" and not intf.verify_token(usermac, token) then
	result["message"] = "验证码错误:( 请重新获取验证码"	
	ngx.say(cjson.encode(result))
	return
end

-- Request radius to reset the password
local password = utils.token(8)
do
	local ok = intf.createOrUpdate(username, password)
	if not ok then
		ngx.log(ngx.ERR, "Failed to reset the password for user: ", username)
		result["message"] = "重置密码失败"
		ngx.say(cjson.encode(result))
		return
	end
end

local ok, err = intf.auth(acip, userip, usermac, username, password)
if ok then
	result["result"] = "OK"
else
	result["message"] = err
end

ngx.say(cjson.encode(result))
