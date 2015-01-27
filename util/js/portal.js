function getUrl(){
	var pos, str, para, parastr; 
	var array = {}

	str = location.href; 
	parastr = str.split("?")[1]; 
	var arr = parastr.split("&");
	for (var i=0; i<arr.length; i++){
		array[arr[i].split("=")[0]] = arr[i].split("=")[1];
	}

	return array;
}

function getQueryString(name) {
	var reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)", "i");
	var r = window.location.search.substr(1).match(reg);
	if (r != null) 
		return unescape(r[2]); 
	return null;
}

function createToken(mobile)
{
	var stationid = getQueryString("stationid");
    $.ajax({
        type:"POST",
        url:"/createToken",
        data: {"mobile":mobile, "stationid":stationid},
        datatype:"json",
        beforeSend:function(){
            $("#msg").html("获取动态验证码");
        },
        success:function(data){
            var msg = eval("(" + data + ")");
            if(msg.result == 'OK')
            {
                alert("动态验证码: " + msg.message);
            }
            else
            {
                alert("获取动态验证码失败，请重试");
            }
        },
        error: function(){
            alert("发送认证请求失败，请重试")
        }
    });
}

function auth(params)
{
	$.ajax({
		type:"POST",
		url:"/auth",
		data:params,
		datatype:"json",
		beforeSend:function(){
			$("#msg").html("开始认证");
		},
		success:function(data){
			var msg = eval("(" + data + ")");	
			if(msg.result == 'OK')
			{
				window.location.href="http://m.baidu.com";
			}
			else
			{
				alert("认证失败，请重新获取动态密码");
			}
		},
		error: function(){
			alert("发送认证请求失败，请重试")
		}
	});
}

function auth_with_input(username, token)
{
	var params = {}

	// Check username and token
	if(username == null || username == '')
	{
		alert("请输入用户名");
		return;
	}
	params["username"] = username;

	if(token == null || token == '')
	{
		alert("请输入短信验证码");
		return;
	}
	params["token"] = token;

	// Fetch the params
	var pos, str, para, parastr; 
	str = location.href; 
	parastr = str.split("?")[1]; 
	var arr = parastr.split("&");
	for (var i=0; i<arr.length; i++){
		params[arr[i].split("=")[0]] = arr[i].split("=")[1];
	}
	
	auth(params);
}
