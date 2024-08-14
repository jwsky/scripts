#!/bin/bash

# 显示选项菜单
echo "请选择一个操作："
echo "1) 上传 Rclone 配置文件"
echo "2) 安装 Rclone，并设置自动备份"
read -p "请输入选项 (1 或 2): " choice

if [ "$choice" == "1" ]; then
    # 上传 Rclone 配置文件
    read -sp "请输入加密密码: " encrypt_password
    echo
    read -p "请输入目标服务器的域名或IP地址: " server2
    read -p "请输入目标服务器的SSH端口（默认22）: " port
    port=${port:-22}
    read -p "请输入存储路径（作为密码路径的一部分）: " zzzz

    config_file=~/.config/rclone/rclone.conf
    encrypted_file="/tmp/rclone.conf.enc"

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

    # 清理临时加密文件
    rm -f "$encrypted_file"

    exit 0

elif [ "$choice" == "2" ]; then
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

    # 安装 Rclone
    echo "正在安装 Rclone..."
    curl https://rclone.org/install.sh | sudo bash

    # 询问用户输入 Rclone 相关信息
    read -p "请输入存储路径（作为密码路径的一部分）: " zzzz
    read -sp "请输入解密密码: " decrypt_password
    echo
    read -p "请输入 current_server_name: " current_server_name

    config_file=~/.config/rclone/rclone.conf
    encrypted_file="/tmp/rclone.conf.enc"

    # 下载并解密 Rclone 配置文件
    echo "正在从远程服务器下载并解密 Rclone 配置文件..."
    curl -o "$encrypted_file" https://s.theucd.com/secure/$zzzz/rclone.conf.enc

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

    # 清理临时加密文件
    rm -f "$encrypted_file"

    # 设置 Rclone 挂载为开机启动
    echo "正在设置 Rclone 挂载为开机启动..."
    echo "@reboot root rclone mount odwebsitejava:/autobackup_sync/$current_server_name /home/autosyncbackup --copy-links --allow-other --allow-non-empty --umask 000 --daemon --vfs-cache-mode full" | sudo tee -a /etc/crontab > /dev/null

    if [ $? -eq 0 ]; then
        echo "Rclone 挂载已设置为开机启动。"
    else
        echo "Rclone 挂载设置失败，请检查 /etc/crontab 文件。"
        exit 1
    fi

    # 下载备份脚本
    echo "正在下载备份脚本..."
    curl -O https://raw.githubusercontent.com/jwsky/scripts/main/backup_website.sh -o /root/backup_website.sh

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
    (crontab -l 2>/dev/null; echo "0 9 * * * /root/backup_website.sh") | crontab -

    echo "Rclone 和备份脚本已安装，并已设置为每天早上9点定时备份。"
else
    echo "无效选项，请选择 1 或 2。"
    exit 1
fi
