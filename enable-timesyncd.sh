#!/bin/bash

echo "🔍 检查并停止其他时间同步服务..."
apt remove ntp -y
# 尝试停止其他时间同步服务
for svc in chronyd ntpd; do
    if systemctl is-active --quiet "$svc"; then
        echo "➡️ 停止 $svc ..."
        systemctl stop "$svc"
        systemctl disable "$svc"
    fi
done

echo "✅ 启用并启动 systemd-timesyncd ..."

systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

sleep 1

echo "🕒 当前时间同步状态："
timedatectl status | grep -E 'NTP|synchronized'

echo "✅ 完成！"
