#!/bin/bash

# 定义颜色
Green='\033[0;32m'
Yellow='\033[0;33m'
Font='\033[0m'

# 检查是否为 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "错误: 必须使用 root 权限运行此脚本！"
    echo "请使用 'sudo $0' 或切换至 root 用户。"
    exit 1
fi

# 检测当前的IP优先级
check_ip_preference() {
    if grep -q "^precedence ::ffff:0:0/96  100" /etc/gai.conf; then
        echo -e "${Green}当前优先级: IPv4优先${Font}"
    elif grep -q "^precedence ::/0         50" /etc/gai.conf; then
        echo -e "${Yellow}当前优先级: IPv6优先${Font}"
    else
        echo "当前优先级: 默认（未手动设置）"
    fi
}

# 切换为IPv4优先
set_ipv4_preference() {
    sed -i '/^precedence ::ffff:0:0\/96/d' /etc/gai.conf
    sed -i '/^precedence ::\/0/d' /etc/gai.conf
    echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
    echo -e "${Green}已切换为IPv4优先${Font}"
}

# 切换为IPv6优先
set_ipv6_preference() {
    sed -i '/^precedence ::ffff:0:0\/96/d' /etc/gai.conf
    sed -i '/^precedence ::\/0/d' /etc/gai.conf
    echo "precedence ::/0         50" >> /etc/gai.conf
    echo -e "${Yellow}已切换为IPv6优先${Font}"
}

# 主程序执行
check_ip_preference

read -p "是否要切换优先级? (1: IPv4优先 / 2: IPv6优先 / 3: 不变): " choice

case $choice in
    1)
        set_ipv4_preference
        ;;
    2)
        set_ipv6_preference
        ;;
    3)
        echo "未做任何更改"
        ;;
    *)
        echo "无效选项，未做任何更改"
        ;;
esac
