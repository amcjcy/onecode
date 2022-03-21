#! /bin/bash
count=`iptables -nvxL OUTPUT --line-number | grep :${1} |awk '{print $1}' |cut -d: -f1 |wc -l`
for((i=1;i<=$count;i++));
do
    iptables -D OUTPUT -p tcp --sport $1 -m comment --comment xiandan${1}xiandan
    iptables -D OUTPUT -p udp --sport $1 -m comment --comment xiandan${1}xiandan
done;

count=`iptables -nvxL INPUT --line-number | grep :${1} |awk '{print $1}' |cut -d: -f1 |wc -l`
for((i=1;i<=$count;i++));
do
    iptables -D INPUT -p tcp --dport $1 -m comment --comment xiandan${1}xiandan
    iptables -D INPUT -p udp --dport $1 -m comment --comment xiandan${1}xiandan
done;
iptables -A INPUT -p tcp --dport $1 -m comment --comment xiandan${1}xiandan
iptables -A OUTPUT -p tcp --sport $1 -m comment --comment xiandan${1}xiandan
iptables -A INPUT -p udp --dport $1 -m comment --comment xiandan${1}xiandan
iptables -A OUTPUT -p udp --sport $1 -m comment --comment xiandan${1}xiandan