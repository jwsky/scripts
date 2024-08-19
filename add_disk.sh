#!/bin/bash

# 查询可用的硬盘设备并显示总空间
disks=($(lsblk -dn --output NAME | grep -v "loop"))
disk_info=()

for name in "${disks[@]}"; do
    # 获取硬盘的总大小
    total_size=$(lsblk -dn -o SIZE /dev/$name | head -n 1)
    disk_info+=("Total: $total_size")
    echo "$name ($total_size)"
done

# 选择硬盘设备
read -p "请输入要操作的硬盘名称（如：sdb）： " selected_disk

# 验证选择是否有效
if [[ ! " ${disks[@]} " =~ " ${selected_disk} " ]]; then
    echo "无效的选择，脚本终止。"
    exit 1
fi

# 创建挂载点
mount_point="/mnt/$selected_disk"
mkdir -p $mount_point

# 检查 /dev/$selected_disk 是否已经格式化为 ext4
fs_type=$(blkid -o value -s TYPE /dev/${selected_disk})

if [ "$fs_type" == "ext4" ]; then
    echo "/dev/${selected_disk} 已经格式化为 ext4 文件系统。"
    read -p "是否要强制重新格式化这个硬盘？输入 'format' 来确认，输入 'n' 取消操作: " confirm
    if [[ "$confirm" == "format" ]]; then
        echo "检查是否有已挂载的分区或磁盘..."
        mounted=$(grep -w "/dev/${selected_disk}" /proc/mounts)
        if [ -n "$mounted" ]; then
            echo "/dev/${selected_disk} 已挂载，正在卸载..."
            umount /dev/${selected_disk}
            if [ $? -ne 0 ]; then
                echo "卸载失败，请检查磁盘是否被使用。"
                exit 1
            fi
        fi
        
        for partition in $(lsblk -ln /dev/${selected_disk} | awk '{print $1}'); do
            if mountpoint -q /dev/$partition; then
                echo "发现挂载的分区: /dev/$partition，正在卸载..."
                umount -l /dev/$partition
                if [ $? -ne 0 ]; then
                    echo "卸载 /dev/$partition 失败，请检查分区是否被使用。"
                    exit 1
                fi
            fi
        done

        echo "没有已挂载的分区或磁盘，直接进行格式化..."
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
        echo "检查是否有已挂载的分区或磁盘..."
        mounted=$(grep -w "/dev/${selected_disk}" /proc/mounts)
        if [ -n "$mounted" ];then
            echo "/dev/${selected_disk} 已挂载，正在卸载..."
            umount /dev/${selected_disk}
            if [ $? -ne 0 ]; then
                echo "卸载失败，请检查磁盘是否被使用。"
                exit 1
            fi
        fi
        
        for partition in $(lsblk -ln /dev/${selected_disk} | awk '{print $1}'); do
            if mountpoint -q /dev/$partition; then
                echo "发现挂载的分区: /dev/$partition，正在卸载..."
                umount -l /dev/$partition
                if [ $? -ne 0 ]; then
                    echo "卸载 /dev/$partition 失败，请检查分区是否被使用。"
                    exit 1
                fi
            fi
        done

        echo "没有已挂载的分区或磁盘，直接进行格式化..."
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

# 将硬盘挂载到挂载点
echo "正在将 /dev/${selected_disk} 挂载到 $mount_point..."
mount /dev/${selected_disk} $mount_point
if [ $? -ne 0 ]; then
    echo "挂载 /dev/${selected_disk} 到 $mount_point 失败，请检查。"
    exit 1
fi

# 添加硬盘的挂载信息到 /etc/fstab
echo "添加 /dev/${selected_disk} 的挂载信息到 /etc/fstab..."
echo "/dev/${selected_disk}  $mount_point  ext4  defaults  0  2" >> /etc/fstab

# 定义需要挂载的文件夹
folders=(
    "/home/navidromeuser/navidrome/music-library"
    "/home/backupfile"
    "/home/wwwroot/storage.memo.ink"
)

# 先卸载与这些文件夹关联的已挂载项
for folder in "${folders[@]}"; do
    if mountpoint -q "$folder"; then
        echo "发现已挂载的文件夹: $folder，正在卸载..."
        echo "umount -l \"$folder\""
        umount -l "$folder"
        if [ $? -ne 0 ]; then
            echo "卸载 $folder 失败，请检查挂载状态。"
            exit 1
        fi
    fi
done

# 确保 /etc/fstab 中没有重复的挂载条目，删除可能的重复条目
for folder in "${folders[@]}"; do
    echo "检查 /etc/fstab 中的条目并删除可能的重复条目: $folder"
    echo "grep -q \"$folder\" /etc/fstab && sed -i \"\\|$folder|d\" /etc/fstab"
    grep -q "$folder" /etc/fstab && sed -i "\|$folder|d" /etc/fstab
done

# 挂载文件夹到新磁盘
for folder in "${folders[@]}"; do
    target_mount_point="${mount_point}/$(basename $folder)"
    echo "创建目标挂载点: mkdir -p $folder"
    mkdir -p $folder  # 确保挂载目标文件夹存在

    echo "创建挂载源文件夹: mkdir -p $target_mount_point"
    mkdir -p $target_mount_point  # 确保挂载源文件夹存在

    echo "尝试挂载文件夹: mount --bind $target_mount_point $folder"
    if ! mount --bind $target_mount_point $folder; then
        echo "挂载 $target_mount_point 到 $folder 失败，请检查。"
        exit 1
    else
        echo "$folder 已成功挂载到 $target_mount_point"
    fi

    # 编辑 /etc/fstab 文件以确保分区和文件夹自动挂载
    echo "编辑 /etc/fstab 文件以确保自动挂载: echo \"$target_mount_point  $folder  none  bind  0  0\" >> /etc/fstab"
    echo "$target_mount_point  $folder  none  bind  0  0" >> /etc/fstab
done

# 验证挂载是否成功
for folder in "${folders[@]}"; do
    echo "检查挂载状态: mount | grep -q \"$folder\""
    if mount | grep -q "$folder"; then
        echo "$folder 挂载成功"
    else
        echo "$folder 挂载失败，请手动检查"
        exit 1
    fi
done

echo "脚本执行完毕"
