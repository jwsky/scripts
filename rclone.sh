#!/bin/bash

# 显示选项菜单
echo "请选择一个操作："
echo "1) 加密并上传 Rclone 配置文件"
echo "2) 安装 Rclone，并从远程服务器下载并解密 Rclone 配置文件"
read -p "请输入选项 (1 或 2): " choice

config_file=~/.config/rclone/rclone.conf
encrypted_file="/tmp/rclone.conf.enc"

if [ "$choice" == "1" ]; then
    # 加密并上传 Rclone 配置文件
    read -sp "请输入加密密码: " encrypt_password
    echo
    read -p "请输入目标服务器的域名或IP地址: " server2
    read -p "请输入目标服务器的SSH端口（默认22）: " port
    port=${port:-22}
    read -p "请输入存储路径（作为密码路径的一部分）: " zzzz

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
    # 安装 Rclone 并从远程服务器下载并解密配置文件
    echo "正在安装 Rclone..."
    sudo -v
    curl https://rclone.org/install.sh | sudo bash

    # 询问用户输入相关信息
    read -p "请输入存储路径（作为密码路径的一部分）: " zzzz
    read -sp "请输入解密密码: " decrypt_password
    echo
    read -p "请输入 current_server_name: " current_server_name

    # 下载加密文件
    curl -o "$encrypted_file" https://s.theucd.com/secure/$zzzz/rclone.conf.enc

    if [ $? -eq 0 ]; then
        echo "加密文件已成功下载。"

        # 解密文件
        openssl enc -d -aes-256-cbc -in "$encrypted_file" -out "$config_file" -k "$decrypt_password" -md sha256 -pbkdf2 -iter 100000

        if [ $? -eq 0 ]; then
            echo "配置文件已成功解密并保存至 $config_file。"
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
        echo "开机启动设置成功，请重启机器以应用更改。"
    else
        echo "开机启动设置失败，请检查 /etc/crontab 文件。"
        exit 1
    fi

    echo "所有操作完成，请手动重启机器以应用更改。"
else
    echo "无效选项，请选择 1 或 2。"
    exit 1
fi
