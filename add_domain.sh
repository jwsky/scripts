#!/bin/bash

# 检查是否安装了expect
if ! command -v expect >/dev/null 2>&1; then
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

# 检测域名解析是否返回有效IP
domain_ip=$(ping -c 1 $domain | sed -nE 's/.*\(([^)]+)\).*/\1/p')
if [ -z "$domain_ip" ]; then
    echo "无法解析域名 $domain，脚本终止。"
    exit 1
else
    echo "$domain 的 IP 地址: $domain_ip"
fi

# 生成随机20位字母的Gmail邮箱
random_email=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 20 | head -n 1)@gmail.com
echo "生成的随机邮箱: $random_email"

# 使用 expect 自动交互
expect << EOF
set timeout 3
log_user 1  # 启用 expect 的输出日志

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
set timeout 3  # 延长超时时间至10秒
expect {
    "your email address" {
        sleep 1
        send "$random_email\r"
    }
    timeout {
        puts "No email prompt, skipping..."
    }
}
set timeout -1
expect "Press any key to start create virtul host"
send "\r"
expect eof
EOF

echo "虚拟主机添加完成。"

# 询问是否设置反向代理
read -p "是否设置反向代理？(y/N): " set_proxy
if [[ "$set_proxy" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    read -p "请输入反代域名（注意https或者http需要保留）: " proxy_domain

    # Nginx 配置文件目录
    nginx_config_dir="/usr/local/nginx/conf/vhost"
    nginx_config_file="$nginx_config_dir/${domain}.conf"

    # 代理配置内容
    proxy_config=$(cat <<EOF

        location / {
            proxy_pass $proxy_domain;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
EOF
    )

    # 在 Nginx 配置文件中插入代理配置
    sed -i "/access_log  \/home\/wwwlogs\/$domain.log;/i\\$proxy_config" $nginx_config_file

    # 测试 Nginx 配置是否正确
    nginx -t

    # 重启 Nginx 服务使配置生效
    systemctl restart nginx

    echo "反向代理已设置完成并应用。"
else
    echo "未设置反向代理，脚本结束。"
    exit 0
fi
