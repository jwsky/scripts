#!/bin/bash

# 定义用户名、用户组和下载文件名
USER="navidromeuser"
GROUP="navidromegroup"
VERSION="0.52.5"
FILENAME="navidrome_${VERSION}_linux_amd64.tar.gz"

#DOWNLOAD_URL="https://github.com/navidrome/navidrome/releases/download/v${VERSION}/${FILENAME}"
DOWNLOAD_URL="https://s.theucd.com/file/${FILENAME}"


# 检查用户是否存在，如果不存在则创建用户和用户组
if ! id "$USER" &>/dev/null; then
	    echo "用户 $USER 不存在，正在创建..."
	        sudo groupadd -f $GROUP
		    sudo useradd -m -g $GROUP $USER
	    else
		        echo "用户 $USER 已存在，无需创建。"
fi

# 更新系统并安装必需软件
sudo apt update
# sudo apt upgrade -y
sudo apt install vim ffmpeg -y

# 创建目录结构
HOME_DIR="/home/$USER"
NAVIDROME_DIR="$HOME_DIR/navidrome"
# sudo mkdir -p $NAVIDROME_DIR/{music-library,bin,config}
sudo chown -R $USER:$GROUP $NAVIDROME_DIR

# 检查文件是否存在于当前脚本执行的目录下
if [ ! -f "./$FILENAME" ]; then
	    echo "文件 $FILENAME 不存在于当前目录下，正在下载..."
	        wget $DOWNLOAD_URL -O $FILENAME
fi

# 复制文件到 bin 目录
mkdir -p $NAVIDROME_DIR/bin
echo "复制文件到 $NAVIDROME_DIR/bin/"
ls -l /root/$FILENAME
sudo cp -n /root/$FILENAME $NAVIDROME_DIR/bin/

# 解压文件
cd $NAVIDROME_DIR/bin
if [ ! -d "navidrome" ]; then
	    echo "解压文件 $FILENAME ..."
	        sudo tar -xvzf $FILENAME
fi
cd -

# 赋予文件夹适当的权限
sudo chown -R $USER:$GROUP $NAVIDROME_DIR/bin

# 创建配置文件
mkdir -p $NAVIDROME_DIR/music-library
mkdir -p $NAVIDROME_DIR/config
echo "MusicFolder = \"$NAVIDROME_DIR/music-library\"" | sudo tee $NAVIDROME_DIR/config/navidrome.toml

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
