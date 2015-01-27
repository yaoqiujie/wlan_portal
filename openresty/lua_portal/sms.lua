local cjson = cjson or require "cjson"
local utils = utils or require "utils"
local intf = intf or require "interface"

local result = {["result"]="FAIL", ["message"]=""}

-- args
ngx.req.read_body()
local args, err = ngx.req.get_post_args()
if not args then
	ngx.log(ngx.ERR, "Failed to get the args for the createUser request: ", err)

	result["message"] = "获取参数失败"
	ngx.say(cjson.encode(result))
	return
end

local mobile = ngx.unescape_uri(args["mobile"])
if mobile == nil or mobile == "" then
	ngx.log(ngx.ERR, "Empty mobile")

	result["message"] = "请输入手机号码"
	ngx.say(cjson.encode(result))
	return
end
local stationid = ngx.unescape_uri(args["stationid"])
if stationid == nil or stationid == "" then
	ngx.log(ngx.ERR, "Empty stationid")

	result["message"] = "生成验证码失败，请刷新页面重试"
	ngx.say(cjson.encode(result))
	return
end

-- decrypt the MAC
local ok, token = intf.gen_token(utils.decrypt_mac(stationid))
if not ok then
	result["message"] = "生成验证码失败, 请重试"
	ngx.say(cjson.encode(result))
	return
end

result["result"] = "OK"
result["message"] = token

-- TODO
-- Send SMS to user

ngx.say(cjson.encode(result))
return
