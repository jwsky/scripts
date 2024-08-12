#!/bin/bash

# 定义源列表
TUNA_SOURCE="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
USTC_SOURCE="http://mirrors.ustc.edu.cn/ubuntu/"
ALIBABA_SOURCE="http://mirrors.aliyun.com/ubuntu/"
ALIBABA_INTERNAL_SOURCE="http://mirrors.cloud.aliyuncs.com/ubuntu/"
DEFAULT_SOURCE="http://archive.ubuntu.com/ubuntu/"

# 定义备份文件路径
BACKUP_FILE="/etc/apt/sources.list.backup.$(date +%F_%T)"

# 备份当前的 sources.list
cp /etc/apt/sources.list "$BACKUP_FILE"
echo "当前的 sources.list 已备份到 $BACKUP_FILE"

# 提示用户选择源
echo "请选择要使用的软件源："
echo "1) 清华源"
echo "2) 中科大源"
echo "3) 阿里云源"
echo "4) 阿里云内网源（仅适用于阿里云 ECS）"
echo "5) Ubuntu 默认源"
read -p "请输入对应的数字 [1-5]: " source_choice

# 根据用户选择更新 sources.list
case $source_choice in
    1)
        SELECTED_SOURCE=$TUNA_SOURCE
        ;;
    2)
        SELECTED_SOURCE=$USTC_SOURCE
        ;;
    3)
        SELECTED_SOURCE=$ALIBABA_SOURCE
        ;;
    4)
        SELECTED_SOURCE=$ALIBABA_INTERNAL_SOURCE
        ;;
    5)
        SELECTED_SOURCE=$DEFAULT_SOURCE
        ;;
    *)
        echo "无效的选择，请运行脚本重新选择。"
        exit 1
        ;;
esac

# 更新 sources.list
cat > /etc/apt/sources.list << EOL
deb $SELECTED_SOURCE $(lsb_release -sc) main restricted universe multiverse
deb $SELECTED_SOURCE $(lsb_release -sc)-updates main restricted universe multiverse
deb $SELECTED_SOURCE $(lsb_release -sc)-security main restricted universe multiverse
EOL

echo "sources.list 已更新为 $SELECTED_SOURCE"

# 更新软件包列表
apt update
