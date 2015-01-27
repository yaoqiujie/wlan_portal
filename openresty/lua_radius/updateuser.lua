local cjson = require "cjson"
local result = {["result"]="FAIL", ["message"]=""}

-- check args
ngx.req.read_body()
local args, err = ngx.req.get_post_args()
if not args then
	ngx.log(ngx.ERR, "Failed to get post args: ", err)
	result["message"] = "Failed to get post args: "..err
	ngx.say(cjson.encode(result))
	return
end

if args["username"] == nil then
	ngx.log(ngx.ERR, "username is missing")
	result["message"] = "username is missing"
	ngx.say(cjson.encode(result))
	return
end
if args["password"] == nil then
	ngx.log(ngx.ERR, "password is missing")
	result["message"] = "password is missing"
	ngx.say(cjson.encode(result))
	return
end

local username = ngx.unescape_uri(args["username"])
local password = ngx.unescape_uri(args["password"])
local md5_passwd = ngx.md5(password)

local conf = require "radconfig"
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


-- Check user exists or not
local user_exists_sql = "select count(*) as number from users where username ="..ngx.quote_sql_str(username)
local res, err, errno, sqlstate = db:query(user_exists_sql)
if not res then
	ngx.log(ngx.ERR, "Bad result of user_exists_sql: ", err, ": ", errno, ": ", sqlstate)

	result["message"] = "Query database failure. Unable to check user existing or not"
	ngx.say(cjson.encode(result))
	return
end

-- This account will be expired in 5 days
if res[1]["number"] == "0" then
-- user does not exist
-- create the user
	local insert_radcheck_sql = string.format(" \
		insert into radcheck (username, attribute, op, value) values \
		(%s, \'Rd-User-Type\', \':=\', \'user\'), \
		(%s, \'Rd-Account-Disabled\', \':=\', \'0\'), \
		(%s, \'Rd-Cap-Type-Data\', \':=\', \'hard\'), \
		(%s, \'Cleartext-Password\', \':=\', %s), \
		(%s, \'Rd-Account-Activation-Time\', \':=\', %s), \
		(%s, \'Expiration\', \':=\', %s), \
		(%s, \'Rd-Realm\', \':=\', %s), \
		(%s, \'User-Profile\', \':=\', %s); ",
		ngx.quote_sql_str(username),
		ngx.quote_sql_str(username),
		ngx.quote_sql_str(username),
		ngx.quote_sql_str(username), ngx.quote_sql_str(password),
		ngx.quote_sql_str(username), ngx.quote_sql_str(conf.activation_date()),
		ngx.quote_sql_str(username), ngx.quote_sql_str(conf.expiration_date()),
		ngx.quote_sql_str(username), ngx.quote_sql_str(conf.REALM),
		ngx.quote_sql_str(username), ngx.quote_sql_str(conf.PROFILE))

-- realm and profile are hardcoded
	local insert_users_sql = string.format(" \
		insert into users (username, password, auth_type, active, monitor, \
		group_id, parent_id, created, realm, realm_id, \
		profile, profile_id, track_auth, track_acct) values \
		(%s, %s, \'sql\', 1, 0, 10, %d, now(), %s, %d, %s, %d, 0, 1); ",
		ngx.quote_sql_str(username), ngx.quote_sql_str(md5_passwd), conf.PROVIDER_ID, 
		ngx.quote_sql_str(conf.REALM), conf.REALM_ID,
		ngx.quote_sql_str(conf.PROFILE), conf.PROFILE_ID)

	local create_user_sql = "start transaction; "..insert_radcheck_sql..insert_users_sql.."commit;"
	ngx.log(ngx.DEBUG, "create_user_sql: ", create_user_sql)

    local res, err, errno, sqlstate = db:query(create_user_sql)
    if not res then
    	ngx.log(ngx.ERR, "Bad result of create_user_sql: ", err, ": ", errno, ": ", sqlstate)
    
    	result["message"] = "Failed to create user due to: "..err
    	ngx.say(cjson.encode(result))
    	return
    end
	while err == "again" do
		res, err, errno, sqlstate = db:read_result()
		if not res then
    		ngx.log(ngx.ERR, "Bad result of create_user_sql: ", err, ": ", errno, ": ", sqlstate)
    
    		result["message"] = "Failed to create the user due to: "..err
    		ngx.say(cjson.encode(result))
    	return
		end
	end

	result["result"] = "OK"
	result["message"] = "Successfully created user: "..username
	ngx.say(cjson.encode(result))

else
-- user already exists
-- update the info of the given user in the radcheck and users tables
--	local update_user_sql = string.format(" \
--		update radcheck set value=%s where username=%s and attribute='Cleartext-Password'; \
--		update radcheck set value=%s where username=%s and attribute='Expiration';",
--		ngx.quote_sql_str(password),
--		ngx.quote_sql_str(username),
--		ngx.quote_sql_str(conf.expiration_date()),
--		ngx.quote_sql_str(username))
	
	local update_user_sql = string.format(" \
	update radcheck \
		set value = case attribute \
			when 'Cleartext-Password' then %s \
			when 'Expiration' then %s \
		end \
	where username=%s and attribute in ('Cleartext-Password', 'Expiration');",
	ngx.quote_sql_str(password),
	ngx.quote_sql_str(conf.expiration_date()),
	ngx.quote_sql_str(username))


	ngx.log(ngx.DEBUG, "update_user_sql: ", update_user_sql)

    local res, err, errno, sqlstate = db:query(update_user_sql)
    if not res then
    	ngx.log(ngx.ERR, "Bad result of update_user_sql: ", err, ": ", errno, ": ", sqlstate)
    
    	result["message"] = "Failed to update the password of the given user due to:  "..err
    	ngx.say(cjson.encode(result))
    	return
    end
	while err == "again" do
		res, err, errno, sqlstate = db:read_result()
		if not res then
    		ngx.log(ngx.ERR, "Bad result of update_user_sql: ", err, ": ", errno, ": ", sqlstate)
    
    		result["message"] = "Failed to update the password of the given user due to:  "..err
    		ngx.say(cjson.encode(result))
    		return
		end
	end

	result["result"] = "OK"
	result["message"] = "Successfully update the password of the user: "..username
	ngx.say(cjson.encode(result))
end

-- put it into the connection pool of size 100,
-- with 20 seconds max idle timeout
local ok, err = db:set_keepalive(20000, 100)
if not ok then
	ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
end
