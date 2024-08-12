#!/bin/bash
#wget -O add_disk.sh https://gt.theucd.com/jwsky/scripts/main/add_disk.sh && sh add_disk.sh
# 创建挂载点
mkdir -p /mnt/temp_home

# 挂载 /dev/vdb1 到临时挂载点
mount /dev/vdb1 /mnt/temp_home

# 备份现有的 /home 数据到新的挂载点
rsync -a /home/ /mnt/temp_home/

# 检查备份是否成功
if [ "$(ls -A /mnt/temp_home)" ]; then
    echo "备份成功，开始挂载新分区到 /home"
else
    echo "备份失败，脚本终止"
    exit 1
fi

# 卸载新分区
umount /mnt/temp_home

# 挂载 /dev/vdb1 到 /home
mount /dev/vdb1 /home

# 编辑 /etc/fstab 文件以确保分区自动挂载
echo "/dev/vdb1  /home  ext4  defaults  0  2" >> /etc/fstab

# 验证挂载是否成功
mount -a
if df -h | grep -q '/home'; then
    echo "/dev/vdb1 成功挂载到 /home"
else
    echo "挂载失败，请手动检查"
    exit 1
fi

# 清理旧的 /home 数据（谨慎操作）
read -p "是否删除旧的 /home 数据？这将无法恢复 [y/N]: " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    rm -rf /old_home/*
    echo "旧的 /home 数据已删除"
else
    echo "保留旧的 /home 数据"
fi

echo "脚本执行完毕"
