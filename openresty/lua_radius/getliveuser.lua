local cjson = require "cjson"
local result = {["result"]="FAIL", ["message"]=""}

-- check args
if ngx.var.arg_username == nil or ngx.var.arg_username == "" then
	ngx.log(ngx.ERR, "username is missing or empty")

	result["message"] = "username is missing or empty"
	ngx.say(cjson.encode(result))
	return 
end
		
local username = ngx.unescape_uri(ngx.var.arg_username)

local mysql = require "resty.mysql"
local conf = require "radconfig"

local db, err = mysql:new()
if not db then
	ngx.log(ngx.ERR, "Failed to instantiate mysql: ", err)

	result["message"] = "Failed to instantiate mysql: "..err
	ngx.say(cjson.encode(result))
	return
end

db:set_timeout(conf.DB_TIMEOUT) -- 5 seconds

local ok, err, errno, sqlstate = db:connect{
	host = conf.DB_HOST,
	port = conf.DB_PORT,
	database = conf.DB_NAME,
	user = conf.DB_USER,
	password = conf.DB_PASS,
	max_packet_size = conf.DB_MAX_PACKET_SIZE }
if not ok then
	ngx.log(ngx.ERR, "Failed to connect to the database: ", err, ": ", errno, " ", sqlstate)
	result["message"] = "Failed to connect to the database: "..err
	ngx.say(cjson.encode(result))
	return
end

local sql = "select username, callingstationid as mac, acctinputoctets as incoming, acctoutputoctets as outgoing from radacct where username ="..ngx.quote_sql_str(username).." and acctstoptime is NULL"
-- local sql = "select username, callingstationid, acctinputoctets, acctoutputoctets from radacct where username ="..ngx.quote_sql_str(username)
local res, err, errno, sqlstate = db:query(sql)
if not res then
	ngx.log(ngx.ERR, "Bad result: ", err, ": ", errno, ": ", sqlstate)

	result["message"] = "Bad result: "..err
	ngx.say(cjson.encode(result))
	return
end


result["result"] = "OK"
result["user_infos"] = res
ngx.say(cjson.encode(result))

-- put it into the connection pool of size 100,
-- with 20 seconds max idle timeout
local ok, err = db:set_keepalive(20000, 100)
if not ok then
	ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
end
