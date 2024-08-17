#!/bin/bash

# 检查是否在 screen 环境中运行
if [ -z "$STY" ]; then
  echo "Error: 该脚本必须在 screen 环境中运行。请先进入 screen 会话后再重新运行脚本。"
  exit 1
fi

# 提供安装和运行的选项
echo "请选择操作: "
echo "1) 安装"
echo "2) 运行"
read -p "请输入选项 [1-2]: " choice

case $choice in
  1)
    # 安装过程
    echo "开始安装..."

    # 1. 下载 capswriter.zip，如果已有则替换
    wget -O capswriter.zip https://s.theucd.com/file/capswriter.zip

    # 2. 下载 models.zip，如果已有则替换
    wget -O models.zip https://s.theucd.com/file/models.zip

    # 3. 解压 capswriter.zip
    apt install unzip -y
    unzip -o capswriter.zip

    # 4. 重命名文件夹 CapsWriter-Offline-master 为 capswriter
    mv -f CapsWriter-Offline-master capswriter

    # 5. 解压 models.zip 到 capswriter/目录下，如果已有文件则自动替换
    unzip -o models.zip -d capswriter/models/

    # 6. 修改 capswriter/config.py 中的服务端和客户端端口号以及是否保存录音文件的配置
    sed -i '/class ServerConfig/{n;n;s/port = '\''6016'\''/port = '\''6688'\''/}' capswriter/config.py
    sed -i '/class ClientConfig/{n;n;s/port = '\''6016'\''/port = '\''6688'\''/}' capswriter/config.py
    sed -i 's/save_audio = True/save_audio = False/' capswriter/config.py

    # 7. 安装依赖，使用清华源
    apt install python3-pip -y
    pip3 install -r requirements-server.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    ;;
  2)
    # 仅运行服务器
    echo "运行服务器..."
    ;;
  *)
    echo "无效的选项，退出。"
    exit 1
    ;;
esac

# 8. 运行 start_server.py
python3 capswriter/start_server.py
