#!/bin/bash

# 删除脚本文件 time_sync.sh
rm time_sync.sh

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
        yes | apt upgrade -y
    else
        echo "上次升级操作还不到 $time_threshold 天。无需采取任何操作。"
    fi
}

# 调用方法，并传入时间差阈值（以天为单位）
check_and_upgrade 30


# 检查是否安装了 chrony
if dpkg -l | grep -q chrony; then
    echo "chrony 已安装，正在检查状态..."
else
    echo "chrony 未安装，正在安装..."
    sudo apt install -y chrony

    # 安装完成后启用并启动 chrony 服务
    sudo systemctl enable chrony
    sudo systemctl start chrony
fi

# 检查 chrony 服务状态
if systemctl is-active --quiet chrony; then
    echo "chrony 正在运行。"
else
    echo "chrony 未运行，正在启动..."
    sudo systemctl start chrony
fi

# 强制同步时间
echo "正在强制同步时间..."
sudo chronyc makestep
# 时区修改
sudo timedatectl set-timezone Asia/Shanghai
timedatectl
# 检查同步状态
echo "当前时间同步状态："
chronyc tracking
