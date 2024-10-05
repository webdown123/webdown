#!/bin/bash

#导入环境变量
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

#安装前的检查
function check(){
	echo
	echo '-------------------------------------------------------------'
	if [ -e "/etc/ccaa" ]
        then
        echo "CCAA已经安装, 若需要重新安装, 请先卸载再安装!"
        echo '-------------------------------------------------------------'
        exit
	else
	        echo "检测通过, 即将开始安装"
	        echo '-------------------------------------------------------------'
	fi
}

#安装之前的准备
function setout(){
	if [ -e "/usr/bin/yum" ]
	then
		yum -y install curl gcc make bzip2 gzip wget unzip tar
	else
		#更新软件，否则可能make命令无法安装
		sudo apt-get update
		sudo apt-get install -y curl make bzip2 gzip wget unzip sudo
	fi

	#创建用户和用户组
	groupadd ccaa
	useradd -M -g ccaa ccaa -s /sbin/nologin
}

#安装Aria2
function install_aria2(){
    cd aria2/
	mkdir -p /etc/ssl/certs/
	mkdir -p /usr/share/man/man1/
	cp aria2c /usr/bin
	cp man-aria2c /usr/share/man/man1/aria2c.1
	cp ca-certificates.crt /etc/ssl/certs/
	chmod 755 /usr/bin/aria2c
	chmod 644 /usr/share/man/man1/aria2c.1
	chmod 644 /etc/ssl/certs/ca-certificates.crt
    cd ..
}

#安装File Browser文件管理器
function install_file_browser(){
	mv filebrowser /usr/sbin
    chmod +x /usr/sbin/filebrowser
}

#处理配置文件
function dealconf(){
	#复制CCAA核心目录
	mv ccaa_dir /etc/ccaa
	#创建aria2日志文件
	touch /var/log/aria2.log
	#upbt增加执行权限
	chmod +x /etc/ccaa/upbt.sh
	chmod +x ccaa
	cp ccaa /usr/sbin
}

function chk_firewall(){
	if [ -e "/etc/sysconfig/iptables" ]
	then
		iptables -I INPUT -p tcp --dport 6080 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6081 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6800 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6998 -j ACCEPT
		iptables -I INPUT -p tcp --dport 51413 -j ACCEPT
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --add-port=6080/tcp --permanent
		firewall-cmd --zone=public --add-port=6081/tcp --permanent
		firewall-cmd --zone=public --add-port=6800/tcp --permanent
		firewall-cmd --zone=public --add-port=6998/tcp --permanent
		firewall-cmd --zone=public --add-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		sudo ufw allow 6080/tcp
		sudo ufw allow 6081/tcp
		sudo ufw allow 6800/tcp
		sudo ufw allow 6998/tcp
		sudo ufw allow 51413/tcp
	fi
}

#删除端口
function del_post() {
	if [ -e "/etc/sysconfig/iptables" ]
	then
		sed -i '/^.*6080.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6081.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6800.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6998.*/'d /etc/sysconfig/iptables
		sed -i '/^.*51413.*/'d /etc/sysconfig/iptables
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --remove-port=6080/tcp --permanent
		firewall-cmd --zone=public --remove-port=6081/tcp --permanent
		firewall-cmd --zone=public --remove-port=6800/tcp --permanent
		firewall-cmd --zone=public --remove-port=6998/tcp --permanent
		firewall-cmd --zone=public --remove-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		sudo ufw delete 6080/tcp
		sudo ufw delete 6081/tcp
		sudo ufw delete 6800/tcp
		sudo ufw delete 6998/tcp
		sudo ufw delete 51413/tcp
	fi
}

#添加服务
function add_service() {
	systemctl restart aria2
	systemctl restart ccaa_web
	systemctl restart filebrowser
}

#设置账号密码
function setting(){
	downpath='/data/ccaaDown'
    secret='abc123abc'

    osip=$(curl -4s https://www.cloudflare.com/cdn-cgi/trace | grep ip= | sed -e "s/ip=//g")

    filebrowserUser='ccaa'
	
	#修改配置文件中的参数
	mkdir -p ${downpath}
	sed -i "s%dir=%dir=${downpath}%g" /etc/ccaa/aria2.conf
	sed -i "s/rpc-secret=/rpc-secret=${secret}/g" /etc/ccaa/aria2.conf
	#替换filebrowser读取路径
	sed -i "s%_ccaaDown_%${downpath}%g" /etc/ccaa/config.json
	#替换filebrowser用户名
	sed -i "s%_ccaaUser_%${filebrowserUser}%g" /etc/ccaa/config.json
	#替换AriaNg服务器链接
	sed -i "s/server_ip/${osip}/g" /etc/ccaa/AriaNg/index.html
	
	#更新tracker
	bash /etc/ccaa/upbt.sh
	
	#安装ccaa_web
	cp ccaa_web /usr/sbin/
	chmod +x /usr/sbin/ccaa_web

	#重置权限
	chown -R ccaa:ccaa /etc/ccaa/
	chown -R ccaa:ccaa ${downpath}

	#注册服务
	add_service

	echo
	echo '-------------------------------------------------------------'
	echo -e "大功告成，请访问: http://${osip}:6080/"
	echo -e "File Browser 用户名:}${filebrowserUser}"
	echo -e "File Browser 密码:admin"
	echo -e "Aria2 RPC 密钥: ${secret}"
	echo '-------------------------------------------------------------'
}

#卸载
function uninstall(){
	wget -O ccaa-uninstall.sh https://raw.githubusercontent.com/crazypeace/ccaa/master/uninstall.sh
	bash ccaa-uninstall.sh
}

#选择安装方式
echo
echo "........... Linux + File Browser + Aria2 + AriaNg一键安装脚本(CCAA) ..........."
echo
echo "1) 安装CCAA"
echo
echo "2) 卸载CCAA"
echo
echo "3) 更新bt-tracker"
echo
echo "q) 退出！"
echo
read -p ":" istype
case $istype in
    1) 
    	check
    	setout
    	chk_firewall
    	install_aria2 && \
    	install_file_browser && \
    	dealconf && \
    	setting
    ;;
    2) 
    	uninstall
    ;;
    3) 
    	bash /etc/ccaa/upbt.sh
    ;;
    q) 
    	exit
    ;;
    *) echo '参数错误！'
esac
