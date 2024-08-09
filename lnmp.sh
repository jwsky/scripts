#!/bin/bash

# 检查是否安装 expect
if ! command -v expect &> /dev/null
then
    echo "expect 未安装。正在安装 expect..."
    sudo apt-get update && sudo apt-get install -y expect
else
    echo "expect 已安装。"
fi

# 下载并解压LNMP
wget https://soft.lnmp.com/lnmp/lnmp2.1.tar.gz -O lnmp2.1.tar.gz
tar zxf lnmp2.1.tar.gz
cd lnmp2.1

# 更新lnmp.conf中的Download_Mirror
sed -i "s|Download_Mirror='https://soft.lnmp.com'|Download_Mirror='https://soft.theucd.com'|g" lnmp.conf

# cd到src文件夹并下载新的MySQL包
cd src
wget https://soft.theucd.com/web/mtsql/mysql-8.0.37-linux-glibc2.12-x86_64.tar.xz
cd ..

# 使用expect自动化安装过程
expect <<EOF
set timeout -1

spawn ./install.sh lnmp

# 输入 '5' 并等待 2 秒
expect "your DataBase install"
send "5\r"
sleep 2

# 输入 'y' 并等待 2 秒
expect "Using Generic Binaries"
send "y\r"
sleep 2

# 输入 MySQL 密码 并等待 2 秒
expect "Please setup root password of MySQL"
send "$MYSQL_PASSWORD\r"
sleep 2

# 输入 'y' 并等待 2 秒
expect "enable or disable the InnoDB Storage Engine"
send "y\r"
sleep 2

# 输入 '14' 并等待 2 秒
expect "options for your PHP install"
send "14\r"
sleep 2

# 输入 '1' 并等待 2 秒
expect "options for your Memory Allocator install"
send "1\r"
sleep 2

# 输入回车
expect "Press any key to install"
send "\r"

expect eof
EOF
