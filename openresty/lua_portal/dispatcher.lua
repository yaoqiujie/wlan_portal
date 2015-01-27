local conf = conf or require "portalconfig"
local intf = intf or require "interface"
local utils = utils or require "utils"

-- check args
local userip = ngx.var.arg_wlanuserip
if userip == nil or userip == "" then
	ngx.log(ngx.ERR, "The [wlanuserip] param is missing")
	ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- The device's MAC
local stationid = ngx.var.arg_wlanparameter
if stationid == nil or stationid == "" then
	ngx.log(ngx.ERR, "The [wlanparameter] param is missing")
	ngx.exit(ngx.HTTP_BAD_REQUEST)
end
local usermac = utils.decrypt_mac(stationid)

local acname = ngx.var.arg_wlanacname
if acname == nil or acname == "" then
	ngx.log(ngx.ERR, "The [wlanacname] param is missing")
	ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local acip = ngx.var.arg_wlanacip
if acip == nil or acip == "" then
   ngx.log(ngx.ERR, "The [acip] param is missing")
   ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local ssid = ngx.var.arg_ssid
if ssid == nil or ssid == "" then
	ngx.log(ngx.ERR, "The [ssid] param is missing")
	ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local userurl = ngx.var.arg_wlanuserfirsturl
if userurl == nil or urserurl == "" then
	userurl = "http://gscopetech.com"
end


local params = "userip="..userip.."&acip="..acip.."&acname="..acname.."&ssid="..ssid.."&stationid="..stationid.."&userurl="..userurl
ngx.log(ngx.CRIT, params)
--
-- Parse POST params END
--

-- Check if the auth is from wechat or not
do
	local tmpid = string.match(userurl, "^http://gscopetech.com/(%w+)$")
	ngx.log(ngx.CRIT, "tmpid: ", tmpid)
	if tmpid ~= nil then
		local is_registered, openid = intf.get_openid(tmpid)
		if is_registered then
			local password = utils.token(8)
			do
				local ok = intf.createOrUpdate(openid, password)
				if not ok then
					ngx.log(ngx.ERR, "Failed to create or reset password for user: ", openid)
				end
				local ok, err = intf.auth(acip, userip, usermac, openid, password)
				if ok then
					ngx.log(ngx.CRIT, "Successfully Auth from wechat")
					ngx.exit(200)
				else
					ngx.log(ngx.ERR, "wechat auth failed: ", err)
				end

			end
		end
	end
end

-- Check the MAC is registered or not
do
	local is_registered, account = intf.is_bound(usermac) 
	if is_registered then
		ngx.log(ngx.DEBUG, usermac, " is bound to ", account)
		
		params = params.."&username="..account.."&token=JAMESBOND"
		local portal_url = "/default/login-bound.html?"..params
		return ngx.redirect(portal_url)
	else
		ngx.log(ngx.DEBUG, usermac, " is not registered")
		local portal_url = "/default/login.html?"..params
		return ngx.redirect(portal_url)
	end
end
