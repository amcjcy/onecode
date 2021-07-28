#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
One For Denbian 后端一键安装

EOF
[ $(id -u) != "0" ] && { echo "错误：必须 root 权限才能运行此脚本!"; exit 1; }
ARG_NUM=$#
TEMP=`getopt -o hvV --long is_auto:,connection_method:,is_mu:,webapi_url:,webapi_token:,api_interface:,db_ip:,db_name:,db_user:,db_password:,node_id:-- "$@" 2>/dev/null`
[ $? != 0 ] && echo "错误：未知参数!" && exit 1
eval set -- "${TEMP}"
while :; do
  [ -z "$1" ] && break;
  case "$1" in
	--is_auto)
      is_auto=y; shift 1
      [ -d "/root/onecode" ] && { echo "One 后端 已经存在"; exit 1; }
      ;;
    --is_mu)
      is_mu=y; shift 1
      ;;
    --webapi_url)
      webapi_url=$2; shift 2
      ;;
    --webapi_token)
      webapi_token=$2; shift 2
      ;;
    --node_id)
      node_id=$2; shift 2
      ;;
    --)
      shift
      ;;
    *)
      echo "错误：未知参数!" && exit 1
      ;;
  esac
done
if [[ ${is_auto} != "y" ]]; then
	echo "按 Y 继续安装过程，或按其他任意键退出."
	read is_install
	if [[ ${is_install} != "y" && ${is_install} != "Y" ]]; then
    	echo -e "安装已取消..."
    	exit 0
	fi
fi
echo "检查是否已安装 One 后端..."

if [ -d "/root/onecode" ]; then
	while :; do echo
		echo -n "服务器已安装 One 后端！继续安装，之前的所有配置都将丢失！?(Y/N)"
		read is_clean_old
		if [[ ${is_clean_old} != "y" && ${is_clean_old} != "Y" && ${is_clean_old} != "N" && ${is_clean_old} != "n" ]]; then
			echo -n "Bad answer! Please only input number Y or N"
		elif [[ ${is_clean_old} == "y" || ${is_clean_old} == "Y" ]]; then
			rm -rf /root/onecode
			rm -rf /etc/systemd/system/one.service
			break
		else
			exit 0
		fi
	done
fi
echo "检查更新及安装后端..."
	apt-get update -y
	apt-get install build-essential wget -y
	apt-get install vim -y
	apt-get install lsof -y
	wget https://raw.githubusercontent.com/amcjcy/onecode/main/libsodium-1.0.18.tar.gz
	tar xf libsodium-1.0.18.tar.gz && cd libsodium-1.0.18
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
	apt-get install python-pip git -y
	pip install cymysql
	cd ../ && rm -rf libsodium*
	cd /root
	git clone -b master https://github.com/amcjcy/onecode.git
	cd /root/onecode
	pip install -r requirements.txt
	chmod +x *.sh
	cp apiconfig.py userapiconfig.py
	cp config.json user-config.json
	echo "echo 3 > /proc/sys/net/ipv4/tcp_fastopen" >> /etc/rc.local
	echo "* soft nofile 512000" >> /etc/security/limits.conf
	echo "* hard nofile 512000" >> /etc/security/limits.conf
	echo "ulimit -n 51200">>/etc/profile
	rm -rf /etc/sysctl.conf
	cp -r /root/onecode/sysctl.conf /etc/

do_modwebapi(){
		echo -n "请输入 WebAPI url:"
		read webapi_url
		echo -n "请输入 modwebapi or glzjinmod :"
		read api_interface
		echo -n "请输入 数据库IP:"
		read db_ip
		echo -n "请输入 数据库密码 :"
		read db_password
		echo -n "请输入 数据库名 :"
		read db_name
		echo -n "请输入 node ID:"
		read node_id
	echo "写入配置文件..."
	sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s%WEBAPI_URL = 'https://zhaoj.in'%WEBAPI_URL = '${webapi_url}'%g" -e "s/API_INTERFACE = 'glzjinmod'/API_INTERFACE = '${api_interface}'/g" -e "s/MYSQL_HOST = '127.0.0.1'/MYSQL_HOST = '${db_ip}'/g" -e "s/MYSQL_PASS = 'ss'/MYSQL_PASS = '${db_password}'/g" -e "s/MYSQL_DB = 'sspanel'/MYSQL_DB = '${db_name}'/g" userapiconfig.py
}
do_modwebapi
do_service(){
	echo "等待系统配置..."
	cp -r /root/onecode/one.service /etc/systemd/system/
	echo "正在启动 One 后端..."
	systemctl daemon-reload && systemctl enable one && systemctl start one
}
while :; do echo
	echo -n "是否要将 One 后端 加入开机自动启动?(Y/N)"
	read is_service
	if [[ ${is_service} != "y" && ${is_service} != "Y" && ${is_service} != "N" && ${is_service} != "n" ]]; then
		echo -n "错误！请输入 Y 或 N"
	else
		break
	fi
done
if [[ ${is_service} == "y" || ${is_service} == "Y" ]]; then
	do_service
fi
echo "系统需要重启才能完成安装，按 Y 重启，或按任意键退出."
read is_reboot
if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
  reboot
else
  echo -e "已取消重启..."
	exit 0
fi
