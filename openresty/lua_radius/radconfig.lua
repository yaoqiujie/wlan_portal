local radconfig = {}

-- Database related
radconfig.DB_HOST="127.0.0.1"
radconfig.DB_PORT="3306"
radconfig.DB_NAME="radiusdesk"
radconfig.DB_USER="rdesk"
radconfig.DB_PASS="rdesk"
radconfig.DB_MAX_PACKET_SIZE=10*1024*1024
radconfig.DB_TIMEOUT=5000

-- Account related

radconfig.REALM="store"
radconfig.REALM_ID=37
radconfig.PROFILE="Time-Standard-1Hour"
radconfig.PROFILE_ID=8
radconfig.PROVIDER="cmcc_js"
radconfig.PROVIDER_ID=198
function radconfig.activation_date()
	-- This account is activated when it is created
	local activation = os.date("%d %b %Y", os.time())
	return activation
end

function radconfig.expiration_date()
	-- This account will be expired in 3 days
	local expiration = os.date("%d %b %Y", os.time() + 60*60*24*3)
	return expiration
end

-- Others
radconfig.PAGE_SIZE=100


return radconfig
