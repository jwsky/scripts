#!/bin/bash
#wget -O navidrome_install.sh https://gt.theucd.com/jwsky/scripts/main/navidrome_install.sh&& sh navidrome_install.sh

# 定义用户名、用户组和下载文件名
USER="navidromeuser"
GROUP="navidromegroup"
VERSION="0.52.5"
FILENAME="navidrome_${VERSION}_linux_amd64.tar.gz"

#DOWNLOAD_URL="https://github.com/navidrome/navidrome/releases/download/v${VERSION}/${FILENAME}"
DOWNLOAD_URL="https://s.theucd.com/file/${FILENAME}"

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

# 调用方法，并传入时间差阈值（以天为单位）
check_and_upgrade 30


sudo apt install vim ffmpeg -y

# 创建目录结构
HOME_DIR="/home/$USER"
NAVIDROME_DIR="$HOME_DIR/navidrome"
sudo mkdir -p $NAVIDROME_DIR
sudo mkdir -p $NAVIDROME_DIR/bin
mkdir -p $NAVIDROME_DIR/config

# 设置音乐文件夹路径
MUSIC_FOLDER_PATH="/mnt/sdb/music-library"

if [ -d "$MUSIC_FOLDER_PATH" ]; then
    sudo chown -R $USER:$GROUP "$MUSIC_FOLDER_PATH"
else
    mkdir -p $NAVIDROME_DIR/music-library
    MUSIC_FOLDER_PATH="$NAVIDROME_DIR/music-library"
fi

# 赋予文件夹适当的权限
sudo chown -R $USER:$GROUP $NAVIDROME_DIR

# 检查文件是否存在于当前脚本执行的目录下
if [ ! -f "./$FILENAME" ]; then
    echo "文件 $FILENAME 不存在于当前目录下，正在下载..."
    wget $DOWNLOAD_URL -O $FILENAME
fi

# 复制文件到 bin 目录
echo "复制文件到 $NAVIDROME_DIR/bin/"
ls -l /root/$FILENAME
sudo cp -n /root/$FILENAME $NAVIDROME_DIR/bin/

# 解压文件
cd $NAVIDROME_DIR/bin
if [ ! -d "navidrome" ]; then
    echo "解压文件 $FILENAME ..."
    sudo tar -xvzf $FILENAME
fi

# 创建配置文件
echo "MusicFolder = \"$MUSIC_FOLDER_PATH\"" | sudo tee $NAVIDROME_DIR/config/navidrome.toml

# 创建 Systemd 服务单元
SERVICE_FILE="/etc/systemd/system/navidrome.service"
echo "[Unit]
Description=Navidrome Music Server and Streamer
After=remote-fs.target network.target
AssertPathExists=$NAVIDROME_DIR

[Service]
User=$USER
Group=$GROUP
Type=simple
ExecStart=$NAVIDROME_DIR/bin/navidrome --configfile \"$NAVIDROME_DIR/config/navidrome.toml\"
WorkingDirectory=$NAVIDROME_DIR
Restart=on-failure

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_FILE

# 启动 Navidrome 服务
sudo systemctl daemon-reload
sudo systemctl start navidrome.service
sudo systemctl enable navidrome.service
