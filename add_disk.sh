#!/bin/bash

# 查询可用的硬盘设备并显示总空间、使用空间和剩余空间
disks=($(lsblk -dn --output NAME | grep -v "loop"))
disk_info=()

for name in "${disks[@]}"; do
    size=$(lsblk -dn -o SIZE /dev/$name)
    used_space=$(df -BG --output=used /dev/$name | tail -1 | tr -d ' ')
    avail_space=$(df -BG --output=avail /dev/$name | tail -1 | tr -d ' ')
    
    if [ -z "$used_space" ]; then
        used_space="0G"
        avail_space="$size"
    fi
    
    disk_info+=("Total: $size, Used: $used_space, Avail: $avail_space")
done

echo "可用的硬盘设备列表:"
for i in "${!disks[@]}"; do
    echo "$((i+1)). ${disks[$i]} (${disk_info[$i]})"
done

# 选择硬盘设备
read -p "请选择一个硬盘设备编号（如：1）： " disk_index

# 验证选择是否有效
if [ -z "$disk_index" ] || ! [[ "$disk_index" =~ ^[0-9]+$ ]] || [ "$disk_index" -le 0 ] || [ "$disk_index" -gt "${#disks[@]}" ]; then
    echo "无效的选择，脚本终止。"
    exit 1
fi

selected_disk=${disks[$((disk_index-1))]}

# 创建挂载点
mount_point="/mnt/$selected_disk"
mkdir -p $mount_point

# 检查 /dev/$selected_disk 是否已经格式化为 ext4
if ! blkid /dev/${selected_disk} | grep -q "ext4"; then
    echo "/dev/${selected_disk} 尚未格式化为 ext4 文件系统，正在格式化..."
    mkfs.ext4 /dev/${selected_disk}
    if [ $? -ne 0 ]; then
        echo "格式化失败，请检查 /dev/${selected_disk} 分区是否正确。"
        exit 1
    fi
    echo "格式化完成。"
else
    echo "/dev/${selected_disk} 已经格式化为 ext4 文件系统。"
fi

# 挂载 /dev/$selected_disk 到挂载点
mount /dev/${selected_disk} $mount_point
if [ $? -ne 0 ]; then
    echo "无法挂载 /dev/${selected_disk} 到 $mount_point，请检查文件系统类型或设备。"
    exit 1
fi

# 确保需要挂载的文件夹存在
folders=(
    "/home/navidromeuser/navidrome/music-library"
    "/home/autosyncbackup"
    "/home/wwwroot/storage.memo.ink"
)

for folder in "${folders[@]}"; do
    if [ ! -d "$folder" ]; then
        echo "文件夹 $folder 不存在，正在创建..."
        mkdir -p $folder
    fi
    
    # 创建相应的挂载点目录
    target_mount_point="$mount_point$(basename $folder)"
    mkdir -p $target_mount_point
    
    # 挂载文件夹到硬盘
    if ! mount --bind $target_mount_point $folder; then
        echo "挂载 $target_mount_point 到 $folder 失败，请检查。"
        exit 1
    else
        echo "$folder 已成功挂载到 $target_mount_point"
    fi
done

# 编辑 /etc/fstab 文件以确保分区和文件夹自动挂载
echo "/dev/${selected_disk}  $mount_point  ext4  defaults  0  2" >> /etc/fstab
for folder in "${folders[@]}"; do
    echo "$mount_point$(basename $folder)  $folder  none  bind  0  0" >> /etc/fstab
done

# 验证挂载是否成功
mount -a
for folder in "${folders[@]}"; do
    if mount | grep -q "$folder"; then
        echo "$folder 挂载成功"
    else
        echo "$folder 挂载失败，请手动检查"
        exit 1
    fi
done

echo "脚本执行完毕"
