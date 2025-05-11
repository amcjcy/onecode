#!/bin/bash

[ $(id -u) != "0" ] && { echo "错误：必须 root 权限才能运行此脚本!"; exit 1; }
if ! dpkg -s jq >/dev/null 2>&1; then
  apt-get update && apt-get install -y jq
fi

latest_release=$(curl -s https://api.github.com/repos/zhboner/realm/releases/latest)
if [[ "$latest_release" == *"Not Found"* ]]; then
  echo "获取最新版本失败"
  exit 1
fi
realm_version=$(echo "$latest_release" | grep -o '"tag_name": "[^"]*' | awk -F'"' '{print $4}')
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
  realm_package="realm-x86_64-unknown-linux-musl.tar.gz"
elif [[ "$arch" == "aarch64" ]]; then
  realm_package="realm-aarch64-unknown-linux-musl.tar.gz"
else
  echo "$arch 架构不支持"
  exit 1
fi

check_realm() {
  status=$(systemctl is-active realm)
  realm_json=$(cat /etc/realm/realm.json 2>/dev/null)
  listen=$(echo "$realm_json" | grep -Po '(?<="listen":")[^"]*' | head -n 1)
  remote=$(echo "$realm_json" | grep -Po '(?<="remote":")[^"]*' | head -n 1)
}

install() {
  if [ -d "/etc/realm" ]; then
    echo -e "\033[31m服务器已安装 Realm！\033[0m"
    read -p "按Y继续，任意键取消！ " choice
    if [ "$choice" != "y" ]; then
      echo "已取消。"
      exit 0
    fi
    systemctl stop realm
    systemctl disable realm
    rm -rf /etc/systemd/system/realm.service
    rm -rf /etc/realm
    systemctl daemon-reload
  fi

  read -e -p "请输入监听端口: " listening_port
  read -e -p "请输入远程IP地址: " remote_ip
  read -e -p "请输入远程端口号: " remote_port

  mkdir -p /etc/realm
  wget --no-check-certificate -P /etc/realm https://github.com/zhboner/realm/releases/download/"$realm_version"/"$realm_package"
  tar -zxvf /etc/realm/"$realm_package" -C /etc/realm
  rm -f /etc/realm/"$realm_package"
  chmod +x /etc/realm/realm

  cat > /etc/realm/realm.json <<EOF
{
  "log": {
    "level": "warn"
  },
  "dns": {
    "mode": "ipv4_and_ipv6",
    "protocol": "tcp_and_udp",
    "min_ttl": 0,
    "max_ttl": 60,
    "cache_size": 5
  },
  "network": {
    "use_udp": true,
    "zero_copy": true,
    "fast_open": true,
    "tcp_timeout": 300,
    "udp_timeout": 30,
    "send_proxy": false,
    "send_proxy_version": 2,
    "accept_proxy": false,
    "accept_proxy_timeout": 5
  },
  "endpoints": [
    {
      "listen":"[::]:$listening_port",
      "remote":"$remote_ip:$remote_port"
    }
  ]
}
EOF

  cat > /etc/systemd/system/realm.service <<EOF
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
ExecStart=/etc/realm/realm -u -c /etc/realm/realm.json

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl start realm.service
  systemctl enable realm.service

  echo "Realm安装完成！"
}

update() {
  echo "开始更新Realm..."
  rm -f /etc/realm/realm
  wget --no-check-certificate https://github.com/zhboner/realm/releases/download/"$realm_version"/"$realm_package"
  tar -zxvf "$realm_package"
  rm -f "$realm_package"
  mv realm /etc/realm
  chmod +x /etc/realm/realm
  systemctl restart realm
  echo -e "\033[32m已更新至最新版本：$realm_version\033[0m"
}

restart() {
  systemctl restart realm
  echo "Realm 已重启"
}

status() {
  systemctl status realm
}

uninstall() {
  echo "开始卸载Realm..."
  systemctl stop realm
  systemctl disable realm
  rm -rf /etc/systemd/system/realm.service
  rm -rf /etc/realm
  systemctl daemon-reload
  echo -e "\033[32m 卸载完成 \033[0m"
}

add_rule() {
  read -p "请输入监听端口（默认监听地址为 [::]）: " port
  read -p "请输入远程地址（支持 IPv4、IPv6、域名）: " remote_ip
  read -p "请输入远程端口: " remote_port

  listen="[::]:$port"

  if [[ "$remote_ip" == *:* ]]; then
    remote="[$remote_ip]:$remote_port"
  else
    remote="$remote_ip:$remote_port"
  fi

  jq --arg listen "$listen" --arg remote "$remote" \
    '.endpoints += [{"listen":$listen,"remote":$remote}]' /etc/realm/realm.json > /etc/realm/realm_tmp.json \
    && mv /etc/realm/realm_tmp.json /etc/realm/realm.json

  echo "规则已添加: $port -> $remote"
  systemctl restart realm
}

delete_rule() {
  echo -e "\n当前规则："
  jq -r '.endpoints[] | 
    .listen as $listen | .remote as $remote | 
    ($listen | split(":")[-1]) + " -> " + $remote' /etc/realm/realm.json | nl -w2 -s'. '
  read -p "请输入要删除的规则编号: " index
  index=$((index - 1))
  jq "del(.endpoints[$index])" /etc/realm/realm.json > /etc/realm/realm_tmp.json \
    && mv /etc/realm/realm_tmp.json /etc/realm/realm.json
  echo "规则已删除"
  systemctl restart realm
}

main_menu() {
  if [[ -e /etc/realm ]]; then
    check_realm
    if [[ "$status" == "active" ]]; then
      echo -e "Realm：\033[32m已安装\033[0m 并 \033[32m已启动\033[0m 
版本号：\033[32m$realm_version\033[0m"
    else
      echo -e "Realm：\033[32m已安装\033[0m 但 \033[31m未启动\033[0m"
    fi
  else
    echo -e "Realm：\033[31m未安装\033[0m"
  fi

  if [[ -f /etc/realm/realm.json ]]; then
    echo -e "\n当前转发规则："
    jq -r '.endpoints[] | 
      .listen as $listen | .remote as $remote | 
      ($listen | split(":")[-1]) + " -> " + $remote' /etc/realm/realm.json | nl -w2 -s'. '
    echo ""
  fi

  echo "请选择操作:"
  echo "1. 安装Realm"
  echo "2. 添加转发规则"
  echo "3. 删除转发规则"
  echo "4. 更新Realm"
  echo "5. 重启Realm"
  echo "6. Realm状态"
  echo "7. 卸载Realm"
  echo "8. 退出"

  read -p "请输入选项: " choice
  case $choice in
    1) install ;;
    2) add_rule ;;
    3) delete_rule ;;
    4) update ;;
    5) restart ;;
    6) status ;;
    7) uninstall ;;
    8) echo "退出程序"; exit 0 ;;
    *) echo "无效的选项，请重新输入";;
  esac

  main_menu
}

main_menu
