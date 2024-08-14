#!/bin/bash

# 检查并安装crontab
if ! command -v crontab | grep -q "crontab"; then
    echo "crontab未安装，正在安装..."
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y cron
    elif [ -f /etc/redhat-release]; then
        sudo yum install -y cronie
        sudo systemctl start crond
        sudo systemctl enable crond
    else
        echo "无法确定操作系统，请手动安装crontab。"
        exit 1
    fi
else
    echo "crontab已安装。"
fi

# 下载备份脚本
curl -O https://raw.githubusercontent.com/jwsky/scripts/main/backup_website.sh -o /root/backup_website.sh

# 询问用户输入MySQL密码
read -sp "请输入MySQL密码: " MYSQL_PassWord
echo

# 替换脚本中的密码字段
sed -i "s/MYSQL_PassWord=''/MYSQL_PassWord='$MYSQL_PassWord'/g" /root/backup_website.sh

# 赋予脚本可执行权限
chmod +x /root/backup_website.sh

# 检查crontab中是否已有此脚本的执行设置，如果有则先删除
crontab -l | grep -v "backup_website.sh" | crontab -

# 设置crontab任务，每天早上9点执行备份
(crontab -l 2>/dev/null; echo "0 9 * * * /root/backup_website.sh") | crontab -

echo "备份脚本已安装，并已设置为每天早上9点定时备份。"
