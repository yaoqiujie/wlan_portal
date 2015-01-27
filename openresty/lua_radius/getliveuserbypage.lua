local cjson = require "cjson"
local conf = require "radconfig"
local result = {["result"]="FAIL", ["message"]=""}

local page = 1
-- check args
if ngx.var.arg_page_no ~= nil then
	page = tonumber(ngx.var.arg_page_no)
end

if page == nil then
	page = 1
end
result["page_size"] = conf.PAGE_SIZE
result["page_no"] = page

local mysql = require "resty.mysql"

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

-- check the total count
local count_sql = "select count(*) as total from radacct where acctstoptime is NOT NULL;"
local res, err, errno, sqlstate = db:query(count_sql)
if not res then
	ngx.log(ngx.ERR, "Bad result: ", err, ": ", errno, ": ", sqlstate)

	result["message"] = "Failed to retrive the total number of the alive users due to: "..err
	ngx.say(cjson.encode(result))
	return
end

local total_page = math.ceil(res[1]["total"]/conf.PAGE_SIZE)
result["total"] = total_page

local limit=0
if page > total_page then
	limit = (total_page-1)*conf.PAGE_SIZE
else
	limit = (page-1)*conf.PAGE_SIZE
end

local sql = string.format("select username, callingstationid as mac, acctinputoctets as incoming, acctoutputoctets as outgoing from radacct where acctstoptime is NOT NULL order by radacctid limit %d, %d;", limit, conf.PAGE_SIZE)
local res, err, errno, sqlstate = db:query(sql)
if not res then
	ngx.log(ngx.ERR, "Bad result: ", err, ": ", errno, ": ", sqlstate)

	result["message"] = "Failed to retrieve the detailed info of the alive users due to: "..err
	ngx.say(cjson.encode(result))
	return
end

result["result"] = "OK"
result["message"] = string.format("Successfully retrieve the info of the specified users on page: %d", page)
result["user_infos"] = res
ngx.say(cjson.encode(result))

-- put it into the connection pool of size 100,
-- with 20 seconds max idle timeout
local ok, err = db:set_keepalive(20000, 100)
if not ok then
	ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
end
