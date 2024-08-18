#!/bin/bash

# 查询可用的硬盘设备并显示总空间
disks=($(lsblk -dn --output NAME | grep -v "loop"))
disk_info=()

for name in "${disks[@]}"; do
    # 获取硬盘的总大小
    total_size=$(lsblk -dn -o SIZE /dev/$name | head -n 1)
    disk_info+=("Total: $total_size")
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
fs_type=$(blkid -o value -s TYPE /dev/${selected_disk})

if [ "$fs_type" == "ext4" ]; then
    echo "/dev/${selected_disk} 已经格式化为 ext4 文件系统。"
    read -p "是否要强制重新格式化这个硬盘？输入 'format' 来确认，输入 'n' 取消操作: " confirm
    if [[ "$confirm" == "format" ]]; then
        echo "正在卸载 /dev/${selected_disk}..."
        umount /dev/${selected_disk}
        if [ $? -ne 0 ]; then
            echo "卸载失败，请检查磁盘是否被使用。"
            exit 1
        fi
        echo "正在格式化 /dev/${selected_disk}..."
        mkfs.ext4 /dev/${selected_disk}
        if [ $? -ne 0 ]; then
            echo "格式化失败，请检查 /dev/${selected_disk} 分区是否正确。"
            exit 1
        fi
        echo "格式化完成。"
    elif [[ "$confirm" == "n" ]]; then
        echo "取消格式化操作。"
    else
        echo "无效输入。操作已取消。"
        exit 1
    fi
elif [ -z "$fs_type" ]; then
    read -p "你确定要格式化这个硬盘为 ext4 吗? 输入 'format' 来确认，输入 'n' 取消操作: " confirm
    if [[ "$confirm" == "format" ]]; then
        echo "正在卸载 /dev/${selected_disk}..."
        umount /dev/${selected_disk}
        if [ $? -ne 0 ]; then
            echo "卸载失败，请检查磁盘是否被使用。"
            exit 1
        fi
        echo "正在格式化 /dev/${selected_disk}..."
        mkfs.ext4 /dev/${selected_disk}
        if [ $? -ne 0 ]; then
            echo "格式化失败，请检查 /dev/${selected_disk} 分区是否正确。"
            exit 1
        fi
        echo "格式化完成。"
    elif [[ "$confirm" == "n" ]]; then
        echo "取消格式化操作。"
    else
        echo "无效输入。操作已取消。"
        exit 1
    fi
else
    echo "硬盘 /dev/${selected_disk} 当前格式为 $fs_type."
fi

# 确保需要挂载的文件夹存在
folders=(
    "/home/navidromeuser/navidrome/music-library"
    "/home/backupfile"
    "/home/wwwroot/storage.memo.ink"
)

for folder in "${folders[@]}"; do
    target_mount_point="$mount_point$(basename $folder)"
    mkdir -p $folder  # 确保挂载目标文件夹存在
    mkdir -p $target_mount_point  # 确保挂载源文件夹存在

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
    echo "$target_mount_point  $folder  none  bind  0  0" >> /etc/fstab
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
