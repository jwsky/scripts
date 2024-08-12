#!/bin/bash

# 删除脚本文件 time_sync.sh
rm time_sync.sh

# 检查是否安装了 chrony
if dpkg -l | grep -q chrony; then
    echo "chrony 已安装，正在检查状态..."
else
    echo "chrony 未安装，正在安装..."
    sudo apt update
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
