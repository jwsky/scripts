#!/bin/bash

# 定义源列表
sources_list=(
    "清华源"
    "中科大源"
    "阿里云源"
    "Ubuntu默认源"
)

# 定义各源的配置
declare -A sources_urls
sources_urls["清华源"]="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
sources_urls["中科大源"]="http://mirrors.ustc.edu.cn/ubuntu/"
sources_urls["阿里云源"]="http://mirrors.aliyun.com/ubuntu/"
sources_urls["Ubuntu默认源"]="http://archive.ubuntu.com/ubuntu/"

# 备份原来的配置文件
backup_sources_list() {
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup_$(date +%Y%m%d%H%M%S)
    echo "已备份原配置文件为 /etc/apt/sources.list.backup_$(date +%Y%m%d%H%M%S)"
}

# 更新配置文件
update_sources_list() {
    selected_source=$1
    sudo cp /dev/null /etc/apt/sources.list

    sudo tee /etc/apt/sources.list << EOF
deb ${sources_urls[$selected_source]} $(lsb_release -cs) main restricted universe multiverse
deb ${sources_urls[$selected_source]} $(lsb_release -cs)-updates main restricted universe multiverse
deb ${sources_urls[$selected_source]} $(lsb_release -cs)-backports main restricted universe multiverse
deb ${sources_urls[$selected_source]} $(lsb_release -cs)-security main restricted universe multiverse
EOF

    echo "源已更新为 $selected_source"
}

# 显示选择菜单
echo "请选择要使用的源："
select choice in "${sources_list[@]}"; do
    if [[ " ${sources_list[@]} " =~ " ${choice} " ]]; then
        backup_sources_list
        update_sources_list "$choice"
        sudo apt-get update
        break
    else
        echo "无效选择，请重试。"
    fi
done
