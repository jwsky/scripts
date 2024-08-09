#!/bin/bash

# 检查是否安装了expect
if ! command -v expect &> /dev/null
then
    echo "expect 未安装，正在安装..."
    sudo apt-get update
    sudo apt-get install -y expect
fi

# 检测本机外网IP
external_ip=$(curl -s ifconfig.me)
echo "本机外网IP: $external_ip"

# 检查是否有公开服务
nc -z -v -w5 $external_ip 80
if [ $? -ne 0 ]; then
    echo "未检测到公开的80端口服务，脚本终止。"
    exit 1
fi

# 获取传递的域名参数
domain=$1
if [ -z "$domain" ]; then
    echo "请提供域名参数。"
    exit 1
fi

# 检测域名解析是否指向本机外网IP
domain_ip=$(ping -c 1 $domain | sed -nE 's/.*\(([^)]+)\).*/\1/p')
echo "$domain 的 IP 地址: $domain_ip"

if [ "$domain_ip" != "$external_ip" ]; then
    echo "域名 IP 与本机外网 IP 不匹配，脚本终止。"
    exit 1
fi

# 生成随机20位字母的Gmail邮箱
random_email=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 20 | head -n 1)@gmail.com
echo "生成的随机邮箱: $random_email"

# 使用 expect 自动交互
expect << EOF
set timeout -1  # 全局设置为不超时

spawn lnmp vhost add
expect "Please enter domain"
sleep 1
send "$domain\r"
expect "Enter more domain name"
sleep 1
send "\r"
expect "Default directory"
sleep 1
send "\r"
expect "Allow Rewrite rule"
sleep 1
send "n\r"
expect "Enable PHP Pathinfo"
sleep 1
send "n\r"
expect "Allow access log"
sleep 1
send "y\r"
expect "Enter access log filename"
sleep 1
send "\r"
expect "Enable IPv6"
sleep 1
send "n\r"
expect "Create database"
sleep 1
send "n\r"
expect "Add SSL Certificate"
sleep 1
send "y\r"
expect "Enter 1, 2, 3"
sleep 1
send "2\r"
expect "Using 301 to Redirect HTTP to HTTPS"
sleep 1
send "y\r"
set timeout 1  # 针对邮箱部分设置1秒超时
expect {
    "Please enter your email address" {
        sleep 1
        send "$random_email\r"
    }
    timeout {
        puts "No email prompt, skipping..."
    }
}
set timeout -1  # 恢复为不超时
expect "Press any key to start create virtul host"
send "\r"
expect eof
EOF

echo "虚拟主机添加完成。"
