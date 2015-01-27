local redis = require "resty.redis"
local conf = conf or require "portalconfig"

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

ok, err = red:set("1c:4b:d6:2f:77:b8", "13867450491")
if not ok then
	ngx.log(ngx.ERR, "Failed to bind the MAC")
	return
end
ok, err = red:expire("1c:4b:d6:2f:77:b8", conf.BINDING_DURATION)
if not ok then
	ngx.log(ngx.ERR, "Failed to expire the binding")
	return
end

ok, err = red:set_keepalive(200000, 100)
if not ok then
	ngx.say("failed to set keepalive: ", err)
	return
end
