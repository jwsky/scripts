#!/bin/bash

# 删除 lnmp2.1 文件夹
rm -rf lnmp2.1

# 删除 lnmp.sh 和 lnmp2.1.tar.gz 文件
rm -f lnmp.sh lnmp2.1.tar.gz

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

# 检测到 "your DataBase install" 提示符后停留 1 秒，然后输入 '5'
expect "your DataBase install"
sleep 1
send "5\r"

# 检测到 "Using Generic Binaries" 提示符后停留 1 秒，然后输入 'y'
expect "Using Generic Binaries"
sleep 1
send "y\r"

# 检测到 "Please setup root password of MySQL" 提示符后停留 1 秒，然后输入 MySQL 密码
expect "Please setup root password of MySQL"
sleep 1
send "$MYSQL_PASSWORD\r"

# 检测到 "enable or disable the InnoDB Storage Engine" 提示符后停留 1 秒，然后输入 'y'
expect "enable or disable the InnoDB Storage Engine"
sleep 1
send "y\r"

# 检测到 "options for your PHP install" 提示符后停留 1 秒，然后输入 '14'
expect "options for your PHP install"
sleep 1
send "14\r"

# 检测到 "options for your Memory Allocator install" 提示符后停留 1 秒，然后输入 '1'
expect "options for your Memory Allocator install"
sleep 1
send "1\r"

# 检测到 "Press any key to install" 提示符后停留 1 秒，然后输入回车
expect "Press any key to install"
sleep 1
send "\r"

expect eof
EOF
