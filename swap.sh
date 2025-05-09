#!/bin/bash

Green="\033[36m"
Font="\033[0m"
Red="\033[31m"

root_need(){
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}错误: 此脚本必须以root身份运行!${Font}"
        exit 1
    fi
}

ovz_no(){
    if [[ -d "/proc/vz" ]]; then
        echo -e "${Red}错误: 您的VPS基于OpenVZ, 不支持!${Font}"
        exit 1
    fi
}

show_swap(){
    echo -e "${Green}当前swap信息：${Font}"
    if swapon --show | grep -q '/swap'; then
        swapon --show
        grep SwapTotal /proc/meminfo
    else
        echo -e "${Red}当前未启用swap。${Font}"
    fi
}

add_swap(){
    echo -e "${Green}请输入需要添加的swap(建议为内存的1.5-2倍)${Font}"
    read -e -p "请输入swap数值(单位M):" swapsize
    grep -q "/swap" /etc/fstab
    if [ $? -ne 0 ]; then
        echo -e "${Green}swap未发现，正在创建swap...${Font}"
        fallocate -l ${swapsize}M /swap
        chmod 600 /swap
        mkswap /swap
        swapon /swap
        echo '/swap none swap defaults 0 0' >> /etc/fstab
        echo -e "${Green}swap创建成功，当前信息：${Font}"
        show_swap
    else
        echo -e "${Red}swap已存在，添加失败。请先删除再创建，或使用修改功能。${Font}"
    fi
}

del_swap(){
    grep -q "/swap" /etc/fstab
    if [ $? -eq 0 ]; then
        echo -e "${Green}swap已发现，正在删除...${Font}"
        sed -i '/\/swap/d' /etc/fstab
        echo 3 > /proc/sys/vm/drop_caches
        swapoff /swap
        rm -f /swap
        echo -e "${Green}swap已删除！${Font}"
    else
        echo -e "${Red}swap未发现，无法删除。${Font}"
    fi
}

modify_swap(){
    del_swap
    echo -e "${Green}请输入新的swap大小(单位M)：${Font}"
    read -e -p "请输入swap数值(单位M):" swapsize
    fallocate -l ${swapsize}M /swap
    chmod 600 /swap
    mkswap /swap
    swapon /swap
    echo '/swap none swap defaults 0 0' >> /etc/fstab
    echo -e "${Green}swap修改完成，当前信息：${Font}"
    show_swap
}

main(){
    root_need
    ovz_no
    clear
    show_swap
    echo -e "\n———————————————————————————————————————"
    echo -e "${Green}Linux VPS 一键添加/删除/修改 swap 脚本${Font}"
    echo -e "${Green}1、添加 swap${Font}"
    echo -e "${Green}2、删除 swap${Font}"
    echo -e "${Green}3、修改 swap 大小${Font}"
    echo -e "———————————————————————————————————————"
    read -p "请输入数字 [1-3]:" num
    case "$num" in
        1) add_swap ;;
        2) del_swap ;;
        3) modify_swap ;;
        *) 
            clear
            echo -e "${Red}请输入正确的数字 [1-3]${Font}"
            sleep 2s
            main
            ;;
    esac
}

main
