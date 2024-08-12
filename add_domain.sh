#!/bin/bash

# 定义检查和升级的方法
check_and_upgrade() {
    # 参数：时间差阈值（以天为单位）
    local time_threshold=$1

    # 获取上次 apt upgrade 的时间
    local last_upgrade_time=$(grep -i "upgrade" /var/log/dpkg.log | tail -n 1 | awk '{print $1" "$2}')

    # 如果未找到上次升级的时间，设置为一个非常早的时间（如 1970-01-01）
    if [ -z "$last_upgrade_time" ]; then
        echo "未找到上次升级的记录，假设系统从未升级过。"
        last_upgrade_time="1970-01-01 00:00:00"
    fi

    # 将日志时间转换为时间戳
    local last_upgrade_timestamp=$(date -d "$last_upgrade_time" +%s)
    local current_timestamp=$(date +%s)

    # 计算时间差（以天为单位）
    local time_diff=$(( (current_timestamp - last_upgrade_timestamp) / 86400 ))

    # 如果时间差大于或等于定义的阈值，则运行 apt update 和 apt upgrade -y
    if [ $time_diff -ge $time_threshold ]; then
        echo "上次升级操作已经超过 $time_threshold 天。正在运行 apt update 和 apt upgrade -y。"
        apt update
        DEBIAN_FRONTEND=noninteractive apt upgrade -y
    else
        echo "上次升级操作还不到 $time_threshold 天。无需采取任何操作。"
    fi
}

# 调用方法，并传入时间差阈值（以天为单位）
check_and_upgrade 30
# 检查是否安装了expect
if ! command -v expect >/dev/null 2>&1; then
    echo "expect 未安装，正在安装..."
    sudo apt install -y expect
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

# 检测是否传递了域名参数，如果没有，则提示用户输入
if [ -z "$domain" ]; then
    read -p "请提供域名参数：" domain
    if [ -z "$domain" ]; then
        echo "未提供有效的域名参数，脚本退出。"
        exit 1
    fi
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
set timeout 60

spawn lnmp vhost add
expect "Please enter domain"
sleep 0.3
send "$domain\r"
expect "Enter more domain name"
sleep 0.3
send "\r"
expect "Default directory"
sleep 0.3
send "\r"
expect "Allow Rewrite rule"
sleep 0.3
send "n\r"
expect "Enable PHP Pathinfo"
sleep 0.3
send "n\r"
expect "Allow access log"
sleep 0.3
send "y\r"
expect "Enter access log filename"
sleep 0.3
send "\r"
expect "Enable IPv6"
sleep 0.3
send "n\r"
expect "Create database"
sleep 0.3
send "n\r"
expect "Add SSL Certificate"
sleep 0.3
send "y\r"
expect "Enter 1, 2, 3"
sleep 0.3
send "2\r"
set timeout 1
expect {
    "Please enter your email address" {
        sleep 0.3
        send "$random_email\r"
    }
    timeout {
        puts "No email prompt, skipping..."
    }
}
expect "Using 301 to Redirect HTTP to HTTPS"
sleep 0.3
send "y\r"
set timeout 60
expect "Press any key to start create virtul host"
send "\r"
expect eof
EOF

echo "虚拟主机添加完成。"

# 询问是否设置反向代理
# 定义Nginx配置文件目录和域名
nginx_config_dir="/usr/local/nginx/conf/vhost"
domain=$1
nginx_config_file="${nginx_config_dir}/${domain}.conf"

echo "配置文件路径：$nginx_config_file"

echo "是否设置反向代理？(y/n)"
read setup_proxy

if [ "$setup_proxy" = "y" ]; then
    echo "请输入反向代理域名（包含http://或https://）:"
    read reverse_domain

    if [ ! -f "$nginx_config_file" ]; then
        echo "错误：域名配置文件不存在!"
        exit 1
    fi

    # 使用awk插入反向代理配置并删除特定行
    awk -v rev_domain="$reverse_domain" -v OFS="\n" '
    /}/ { last_brace_line = NR } # Track the last } line
    /jpg/ { jpg_line = NR } # Track the line number with jpg
    { lines[NR] = $0 } # Save all lines in an array
    END {
        # Print all lines before the last brace
        for (i = 1; i < last_brace_line; i++) {
            if (i == jpg_line) {
                # Skip jpg line and the following 9 lines
                i += 9;
                continue;
            }
            print lines[i]
        }
        # Insert reverse proxy configuration
        print "    location / {"
        print "        proxy_pass " rev_domain ";"
        print "        proxy_http_version 1.1;"
        print "        proxy_set_header Upgrade $http_upgrade;"
        print "        proxy_set_header Connection '\''upgrade'\'';"
        print "        proxy_set_header X-Real-IP $remote_addr;"
        print "        proxy_set_header Host $host;"
        print "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
        print "        proxy_set_header X-Forwarded-Proto $scheme;"
        print "        proxy_set_header X-Forwarded-Host $host;"
        print "        proxy_cache_bypass $http_upgrade;"
        print "    }"
        # Print the last brace
        print lines[last_brace_line]
    }' $nginx_config_file > temp_file

    # Replace the old configuration file with the new one
    mv temp_file $nginx_config_file

    echo "正在重启nginx..."
    lnmp nginx restart
else
    echo "未设置反向代理。"
fi

