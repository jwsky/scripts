#!/bin/bash
#wget -O initial.sh https://gt.theucd.com/jwsky/scripts/main/initial.sh && sh initial.sh
echo "请选择您要安装的内容: "
echo "1) 时间同步器"
echo "2) Navidrome"
echo "3) LNMP"
echo "4) 全部安装"
echo "5) 退出"
echo "-------其他工具安装"
echo "6）更换ubuntu更新源"

read -p "请输入选项 (1, 2, 3, 4, 5, 6): " choice
# 定义时间差阈值（以天为单位）
time_threshold=30
# 获取上次 apt upgrade 的时间
last_upgrade_time=$(grep -i "upgrade" /var/log/dpkg.log | tail -n 1 | awk '{print $1" "$2}')
# 将日志时间转换为时间戳
last_upgrade_timestamp=$(date -d "$last_upgrade_time" +%s)
current_timestamp=$(date +%s)
# 计算时间差（以天为单位）
time_diff=$(( (current_timestamp - last_upgrade_timestamp) / 86400 ))
# 如果时间差大于或等于定义的阈值，则运行 apt update 和 apt upgrade -y
if [ $time_diff -ge $time_threshold ]; then
    echo "上次升级操作已经超过 $time_threshold 天。正在运行 apt update 和 apt upgrade -y。"
    apt update
    yes | apt upgrade -y
else
    echo "上次升级操作还不到 $time_threshold 天。无需采取任何操作。"
fi


install_time_sync() {
    echo "正在安装时间同步器..."
    wget -O time_sync.sh https://gt.theucd.com/jwsky/scripts/main/time_sync.sh && sh time_sync.sh
}

install_navidrome() {
    echo "正在安装Navidrome..."
    wget -O navidrome_install.sh https://gt.theucd.com/jwsky/scripts/main/navidrome_install.sh && sh navidrome_install.sh
}

install_lnmp() {
    echo "正在安装LNMP..."
    wget -O lnmp.sh https://gt.theucd.com/jwsky/scripts/main/lnmp.sh && sh lnmp.sh
}

install_change_source() {
    echo "正在更换源，请记得选择源的内容..."
    wget -O change_source.sh https://gt.theucd.com/jwsky/scripts/main/change_source.sh && sh change_source.sh
}

case $choice in
    1)
        install_time_sync
        ;;
    2)
        install_navidrome
        ;;
    3)
        install_lnmp
        ;;
    4)
        install_time_sync
        install_navidrome
        install_lnmp
        ;;
    5)
        echo "退出安装程序。"
        exit 0
        ;;
    6)
        install_change_source
        ;;
    *)
        echo "无效的选择，请输入1, 2, 3, 4, 5 或 6"
        ;;
esac
