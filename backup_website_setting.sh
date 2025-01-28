#!/bin/bash

# 显示选项菜单
echo "请选择一个操作："
echo "1) 上传 Rclone 配置文件"
echo "2) 安装 Rclone，并设置自动备份"
read -p "请输入选项 (1 或 2): " choice

if [ "$choice" = "1" ]; then
    # 上传 Rclone 配置文件
    read -sp "请输入加密密码: " encrypt_password
    echo
    read -p "请输入目标服务器的域名或IP地址: " server2
    read -p "请输入目标服务器的SSH端口（默认22）: " port
    port=${port:-22}
    read -p "请输入存储路径（作为密码路径的一部分）: " zzzz

    config_file=~/.config/rclone/rclone.conf
    encrypted_file="./rclone.conf.enc"

    # 加密配置文件
    openssl enc -aes-256-cbc -salt -in "$config_file" -out "$encrypted_file" -k "$encrypt_password" -md sha256 -pbkdf2 -iter 100000

    if [ $? -eq 0 ]; then
        echo "配置文件已成功加密。"

        # 上传加密文件到目标服务器
        scp -P $port "$encrypted_file" root@$server2:/home/wwwroot/s.theucd.com/secure/$zzzz/rclone.conf.enc

        if [ $? -eq 0 ]; then
            echo "加密文件已成功上传到 $server2 的 /home/wwwroot/s.theucd.com/secure/$zzzz/ 路径。"
        else
            echo "加密文件上传失败，请检查连接和路径。"
        fi
    else
        echo "加密过程失败，请检查文件路径和密码。"
    fi

    # 清理当前目录中的加密文件
    rm -f "$encrypted_file"

    exit 0

elif [ "$choice" = "2" ]; then

    # 安装 Rclone 并设置自动备份

    echo "正在检查并安装 crontab..."
    if ! command -v crontab | grep -q "crontab"; then
        echo "crontab 未安装，正在安装..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update
            sudo apt-get install -y cron
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y cronie
            sudo systemctl start crond
            sudo systemctl enable crond
        else
            echo "无法确定操作系统，请手动安装 crontab。"
            exit 1
        fi
    else
        echo "crontab 已安装。"
    fi

    # 安装 FUSE3
    echo "正在安装 FUSE3..."
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y fuse3
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y fuse3
    else
        echo "无法确定操作系统，无法自动安装 FUSE3，请手动安装。"
        exit 1
    fi

    # 下载并修改 Rclone 安装脚本
    echo "正在下载 Rclone 安装脚本..."
    wget -O rclone_install.sh https://s.theucd.com/pxy/pxy.php?des=https://rclone.org/install.sh

    if [ $? -eq 0 ]; then
        echo "正在修改 Rclone 安装脚本..."
        sed -i 's|https://downloads.rclone.org|https://s.theucd.com/pxy/pxy.php?des=https://downloads.rclone.org|g' rclone_install.sh
        sed -i '/curl -OfsS \"$download_link\"/a mv "pxy.php" "$rclone_zip"' rclone_install.sh


        echo "正在执行修改后的 Rclone 安装脚本..."
        sudo bash rclone_install.sh
    else
        echo "Rclone 安装脚本下载失败，请检查网络连接。"
        exit 1
    fi

    # 询问用户输入 Rclone 相关信息
    read -p "请输入存储路径（作为密码路径的一部分）: " zzzz
    read -sp "请输入解密密码: " decrypt_password
    echo
    read -p "请输入 current_server_name: " current_server_name

    config_file=~/.config/rclone/rclone.conf
    encrypted_file="./rclone.conf.enc"
    random_param=$(date +%s%N)

    # 确保 Rclone 配置目录存在
    if [ ! -d "$(dirname "$config_file")" ]; then
        echo "Rclone 配置目录不存在，正在创建..."
        mkdir -p "$(dirname "$config_file")"
    fi

    # 使用 wget 下载并解密 Rclone 配置文件
    echo "正在从远程服务器下载并解密 Rclone 配置文件..."
    wget "https://s.theucd.com/secure/$zzzz/rclone.conf.enc?random=$random_param" -O "$encrypted_file"

    if [ $? -eq 0 ]; then
        echo "加密文件已成功下载。"

        # 解密文件
        openssl enc -d -aes-256-cbc -in "$encrypted_file" -out "$config_file" -k "$decrypt_password" -md sha256 -pbkdf2 -iter 100000

        if [ $? -eq 0 ]; then
            echo "Rclone 配置文件已成功解密并保存至 $config_file。"
        else
            echo "解密过程失败，请检查密码。"
            exit 1
        fi
    else
        echo "文件下载失败，请检查路径。"
        exit 1
    fi

    # 清理当前目录中的加密文件
    rm -f "$encrypted_file"


    # 检查 /mnt/sdb/autosyncbackup 是否存在
    if [ -d "/mnt/sdb/autosyncbackup" ]; then
        echo "/mnt/sdb/autosyncbackup 目录存在，使用该路径作为挂载点..."
        backupfilepath="/mnt/sdb/autosyncbackup/"
    else
        echo "/mnt/sdb/autosyncbackup 目录不存在，设置默认挂载路径..."
        # 检查并创建挂载点目录
        if [ ! -d "/home/autosyncbackup" ]; then
            echo "挂载点目录不存在，正在创建..."
            sudo mkdir -p /home/autosyncbackup
        fi
        backupfilepath="/home/autosyncbackup/"
    fi

    # 设置 Rclone 挂载为开机启动
    echo "正在设置 Rclone 挂载为开机启动..."
    echo "@reboot root sleep 3 && rclone mount odwebsitejava:/autobackup_sync/$current_server_name $backupfilepath --copy-links --allow-other --allow-non-empty --umask 000 --daemon --vfs-cache-mode full" | sudo tee -a /etc/crontab > /dev/null

    if [ $? -eq 0 ]; then
        echo "Rclone 挂载已设置为开机启动。"

        # 立即执行挂载命令
        echo "正在立即挂载 Rclone..."
        rclone mount odwebsitejava:/autobackup_sync/$current_server_name $backupfilepath --copy-links --allow-other --allow-non-empty --umask 000  --daemon --vfs-cache-mode full 
        echo "如果要 debug，可以加这个参数-vv"
        if [ $? -eq 0 ]; then
            echo "Rclone 已成功挂载。"
        else
            echo "Rclone 挂载失败，请检查命令。"
            exit 1
        fi
    else
        echo "Rclone 挂载设置失败，请检查 crontab 文件。"
        exit 1
    fi

    # 下载备份脚本
    echo "正在下载备份脚本..."
    wget -O /root/backup_website.sh https://gt.theucd.com/jwsky/scripts/main/backup_website.sh

    # 替换下载的备份脚本中的默认路径为 backupfilepath 变量值
    sed -i "s|Backup_Home=\"/home/autosyncbackup/\"|Backup_Home=\"$backupfilepath\"|g" /root/backup_website.sh

    # 询问用户输入 MySQL 密码
    read -sp "请输入 MySQL 密码: " MYSQL_PassWord
    echo

    # 替换脚本中的密码字段
    sed -i "s/MYSQL_PassWord=''/MYSQL_PassWord='$MYSQL_PassWord'/g" /root/backup_website.sh

    # 赋予脚本可执行权限
    chmod +x /root/backup_website.sh

    # 检查 crontab 中是否已有此脚本的执行设置，如果有则先删除
    crontab -l | grep -v "backup_website.sh" | crontab -

    # 设置 crontab 任务，每天早上9点执行备份
    (crontab -l 2>/dev/null; echo "0 9 * * * /bin/bash /root/backup_website.sh") | crontab -

    echo "Rclone 和备份脚本已安装，并已设置为每天早上9点定时备份。"
    [ -f "./backup_website_setting.sh" ] && rm "./backup_website_setting.sh" && echo "文件已删除。" || echo "文件不存在。"

else
    echo "无效选项，请选择 1 或 2。"
    exit 1
fi
