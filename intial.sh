#!/bin/bash
#wget -O intial.sh https://gt.theucd.com/jwsky/scripts/main/intial.sh && sh intial.sh
echo "请选择您要安装的内容: "
echo "1) 时间同步器"
echo "2) Navidrome"
echo "3) LNMP"
echo "4) 全部安装"
echo "5) 退出"
read -p "请输入选项 (1, 2, 3, 4, 5): " choice
apt update
apt upgrade -y
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
    *)
        echo "无效的选择，请输入1, 2, 3, 4 或 5"
        ;;
esac
