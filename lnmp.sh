#!/bin/bash
#!/bin/bash

# Get Ubuntu version
version=$(lsb_release -r | awk '{print $2}' | cut -d '.' -f1)

# Check if version is greater than or equal to 24
if [ "$version" -ge 24 ]; then
  # Run the commands
  curl -O http://launchpadlibrarian.net/646633572/libaio1_0.3.113-4_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb
  sudo dpkg -i libaio1_0.3.113-4_amd64.deb
  sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb

else
  echo "Ubuntu version is less than 24. Skipping the commands."
fi


# 检查是否传入 MySQL 密码参数
if [ -z "$1" ]; then
    echo "MySQL 密码未作为第一个参数传入，正在自动生成密码..."
    MYSQL_PASSWORD=$(head /dev/urandom | tr -dc a-z0-9 | head -c 18)
    echo "已生成 MySQL 密码：$MYSQL_PASSWORD"
else
    MYSQL_PASSWORD=$1
fi


# 删除 lnmp2.1 文件夹
rm -rf lnmp2.1

# 删除 lnmp.sh 和 lnmp2.1.tar.gz 文件
rm -f lnmp.sh lnmp2.1.tar.gz

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

# 检查是否安装 expect
if command -v expect | grep -q 'expect'; then
    echo "expect 已安装。"
else
    echo "expect 未安装。正在安装 expect..."
    # 调用方法，并传入时间差阈值（以天为单位）
    sudo apt-get install -y expect
fi

# 下载并解压LNMP
wget https://soft.theucd.com/lnmp/lnmp2.1.tar.gz -O lnmp2.1.tar.gz
tar zxf lnmp2.1.tar.gz
cd lnmp2.1

# 更新lnmp.conf中的Download_Mirror
sed -i "s|Download_Mirror='https://soft.lnmp.com'|Download_Mirror='https://soft.theucd.com'|g" lnmp.conf

# cd到src文件夹并下载新的MySQL包
cd src
wget https://soft.theucd.com/web/mysql/mysql-8.0.37-linux-glibc2.12-x86_64.tar.xz
cd ..

# 使用expect自动化安装过程
expect <<EOF
set timeout -1

spawn ./install.sh lnmp

# 检测到 "your DataBase install" 提示符后停留 1 秒，然后输入 '5'
expect {
    "your DataBase install" {
        sleep 1
        send "5\r"
    }
}

# 检测到 "Using Generic Binaries" 提示符后停留 1 秒，然后输入 'y'
expect {
    "Using Generic Binaries" {
        sleep 1
        send "y\r"
    }
}

# 检测到 "Please setup root password of MySQL" 提示符后停留 1 秒，然后输入 MySQL 密码
expect {
    "Please setup root password of MySQL" {
        sleep 1
        send "$MYSQL_PASSWORD\r"
    }
}

# 检测到 "enable or disable the InnoDB Storage Engine" 提示符后停留 1 秒，然后输入 'y'
expect {
    "enable or disable the InnoDB Storage Engine" {
        sleep 1
        send "y\r"
    }
}

# 检测到 "options for your PHP install" 提示符后停留 1 秒，然后输入 '14'
expect {
    "options for your PHP install" {
        sleep 1
        send "14\r"
    }
}

# 检测到 "options for your Memory Allocator install" 提示符后停留 1 秒，然后输入 '1'
expect {
    "options for your Memory Allocator install" {
        sleep 1
        send "1\r"
    }
}

# 检测到 "Press any key to install" 提示符后停留 1 秒，然后输入回车
expect {
    "Press any key to install" {
        sleep 1
        send "\r"
    }
}

expect eof
EOF
#echo "已生成 MySQL 密码,请务必立刻登录系统修改：$MYSQL_PASSWORD" >> ../lnmp-install.log
[ -f "./lnmp.sh" ] && rm "./lnmp.sh" && echo "文件已删除。" || echo "文件不存在。"
[ -f "./libaio1_0.3.113-4_amd64.deb" ] && rm "./libaio1_0.3.113-4_amd64.deb" && echo "文件已删除。" || echo "文件不存在。"
[ -f "./libtinfo5_6.3-2ubuntu0.1_amd64.deb" ] && rm "./libtinfo5_6.3-2ubuntu0.1_amd64.deb" && echo "文件已删除。" || echo "文件不存在。"
[ -f "./lnmp2.1.tar.gz" ] && rm "./lnmp2.1.tar.gz" && echo "文件已删除。" || echo "文件不存在。"


