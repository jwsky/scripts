#!/bin/bash
#   wget -O initial.sh https://gt.theucd.com/jwsky/scripts/main/initial.sh && sh initial.sh
echo "请选择您要安装的内容: "
echo "1) 时间同步器"
echo "2) Navidrome"
echo "3) LNMP"
echo "4) 全部安装"
echo "5) 退出"
echo "-------------其他工具安装"
echo "6）更换ubuntu更新源"
echo "7）挂载数据盘，并把文件夹挂载上去"
echo "8）lnmp自动添加域名"
echo "9）安装或运行Capswriter"
echo "10）备份核心目录初始化"



read -p "请输入选项 (1, 2, 3, 4, 5, 6, 7 ,8 , 9 ): " choice

# 定义检查和升级的方法
check_and_upgrade() {
    # 参数：时间差阈值（以天为单位）
    local time_threshold=$1

    # 获取上次 apt upgrade 的时间
    local last_upgrade_time=$(grep -i "upgrade" /var/log/dpkg.log | tail -n 1 | awk '{print $1" "$2}')

    # 如果未找到上次升级的时间，设置为一个非常早的时间（如 1970-01-01）
    if [ -z "$last_upgrade_time" ]; then
        echo "未找到上次升级的记录，假设系统从未升级过。"
        last_upgrade_time="1970-01-01 00:00:00"
    fi

    # 将日志时间转换为时间戳
    local last_upgrade_timestamp=$(date -d "$last_upgrade_time" +%s)
    local current_timestamp=$(date +%s)

    # 计算时间差（以天为单位）
    local time_diff=$(( (current_timestamp - last_upgrade_timestamp) / 86400 ))

    # 如果时间差大于或等于定义的阈值，则运行 apt update 和 apt upgrade -y
    if [ $time_diff -ge $time_threshold ]; then
        echo "上次升级操作已经超过 $time_threshold 天。正在运行 apt update 和 apt upgrade -y。"
        apt update
        DEBIAN_FRONTEND=noninteractive apt upgrade -y
    else
        echo "上次升级操作还不到 $time_threshold 天。无需采取任何操作。"
    fi
}



install_time_sync() {
    echo "正在安装时间同步器..."
    wget -O time_sync.sh https://gt.theucd.com/jwsky/scripts/main/time_sync.sh && bash time_sync.sh
}

install_navidrome() {
    echo "正在安装Navidrome..."
    wget -O navidrome_install.sh https://gt.theucd.com/jwsky/scripts/main/navidrome_install.sh && bash navidrome_install.sh
}

install_lnmp() {
    echo "正在安装LNMP..."
    wget -O lnmp.sh https://gt.theucd.com/jwsky/scripts/main/lnmp.sh && bash lnmp.sh
}

install_change_source() {
    echo "正在更换源，请记得选择源的内容..."
    wget -O change_source.sh https://gt.theucd.com/jwsky/scripts/main/change_source.sh && bash change_source.sh
}

add_disk() {
    echo "正在挂载数据盘到/home，请稍等..."
    wget -O add_disk.sh https://gt.theucd.com/jwsky/scripts/main/add_disk.sh && bash add_disk.sh
}

add_domain() {
    echo "正在设置，请稍等..."
    wget -O add_domain.sh https://gt.theucd.com/jwsky/scripts/main/add_domain.sh && bash add_domain.sh
}

caps() {
    echo "正在设置，请稍等..."
    wget -O caps.sh https://gt.theucd.com/jwsky/scripts/main/caps.sh && bash caps.sh
}
backup_website_setting(){
    echo "正在设置，请稍等..."
    wget -O backup_website_setting.sh https://gt.theucd.com/jwsky/scripts/main/backup_website_setting.sh && bash backup_website_setting.sh
}
case $choice in
    1)
        # 调用方法，并传入时间差阈值（以天为单位）
        check_and_upgrade 30
        install_time_sync
        ;;
    2)
        # 调用方法，并传入时间差阈值（以天为单位）
        check_and_upgrade 30
        install_navidrome
        ;;
    3)
        # 调用方法，并传入时间差阈值（以天为单位）
        check_and_upgrade 30
        install_lnmp
        ;;
    4)
        # 调用方法，并传入时间差阈值（以天为单位）
        check_and_upgrade 30
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
    7)
        add_disk
        ;;
    8)
        add_domain
        ;; 
    9)
        caps
        ;; 
    10)
        backup_website_setting
        ;; 
    *)
        echo "无效的选择，请输入1, 2, 3, 4, 5 或 6 或 7 或 8"
        ;;
esac
