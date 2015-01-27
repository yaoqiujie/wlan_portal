local _M = {_VERSION = '0.1'}

-- Database related
_M.REDIS_HOST="127.0.0.1"
_M.REDIS_PORT="6379"
--_M.REDIS_NAME="radiusdesk"
--_M.REDIS_USER="rdesk"
--_M.REDIS_PASS="rdesk"
--_M.REDIS_MAX_PACKET_SIZE=10*1024*1024
_M.REDIS_TIMEOUT=2000

-- Radius
_M.RADIUS_HOST="127.0.0.1"
_M.RADIUS_PORT='8080'

-- wechat
_M.WECHAT_HOST="115.29.175.49"
_M.WECHAT_PORT="80"


_M.BINDING_DURATION=15*24*3600 -- The duration of the binding between MAC and account
_M.TOKEN_DURATION=5*60

return _M
