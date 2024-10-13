#!/bin/bash
# 功能: 备份网站和MySQL数据库到WebDAV
# 作者: java
# 重要提示：请设置以下值！
echo $(date) >> file.txt
Backup_Home="/home/autosyncbackup/"
MySQL_Dump="/usr/local/mysql/bin/mysqldump"
######~设置要备份的目录~######
Backup_Dir=("/home/wwwroot" "/usr/local/nginx/conf/vhost" "/home/a/nextjs")
Exclude_Dir=("wwwroot/soft.theucd.com" "wwwroot/m.theucd.com" "wwwroot/jslack.theucd.com/raw" "wwwroot/pam"  "wwwroot/default")
######~设置MySQL用户名和密码~######
MYSQL_UserName='root'
MYSQL_PassWord=''

TodayWWWBackup=www-*-$(date +"%Y%m%d").tar.gz
TodayDBBackup=db-*-$(date +"%Y%m%d").sql
Today_db_archive_name="db-$(date +"%Y%m%d").tar.gz"
OldWWWBackup=www-*-$(date -d -5day +"%Y%m%d").tar.gz
OldDB_tar_Backup=db-$(date -d -5day +"%Y%m%d").tar.gz

Backup_Dir(){
    Backup_Path="$1"
    Dir_Name=$(basename "${Backup_Path}")
    Pre_Dir=$(dirname "${Backup_Path}")

    # 检查目录是否存在
    if [ ! -d "${Backup_Path}" ]; then
        echo "目录 ${Backup_Path} 不存在，跳过备份。"
        return
    fi

    # 初始化排除参数数组
    declare -a Exclude_Params
    for exclude in "${Exclude_Dir[@]}"; do
        Exclude_Params+=(--exclude="$exclude")
    done

    echo "正在备份 ${Backup_Path}..."
    # 使用 "${Exclude_Params[@]}" 来正确展开数组元素
    tar zcf "${Backup_Home}www-${Dir_Name}-$(date +"%Y%m%d").tar.gz" -C "${Pre_Dir}" "${Exclude_Params[@]}" "${Dir_Name}"
}

Backup_All_Databases() {
    # 获取所有数据库名称，过滤掉系统数据库（如 information_schema, performance_schema, mysql, sys）
    databases=$(mysql -u$MYSQL_UserName -p$MYSQL_PassWord -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

    for db in $databases; do
        echo "正在备份数据库: $db"
        ${MySQL_Dump} -u$MYSQL_UserName -p$MYSQL_PassWord $db > ${Backup_Home}db-$db-$(date +"%Y%m%d").sql
    done
}

if [ ! -f ${MySQL_Dump} ]; then  
    echo "未找到mysqldump命令，请检查设置。"
    exit 1
fi

if [ ! -d ${Backup_Home} ]; then  
    mkdir -p ${Backup_Home}
fi

echo "正在备份网站文件..."
for dd in "${Backup_Dir[@]}"; do
    Backup_Dir "$dd"
done

echo "正在备份所有数据库..."
Backup_All_Databases

current_date=$(date +"%Y%m%d")
# 定义归档文件名
# 找到今天生成的所有 .sql 文件，打包压缩并删除原文件
Today_db_archive_name_connected="${Backup_Home}db-${current_date}.tar.gz"
find "$Backup_Home" -type f -name "*${current_date}.sql" -print0 | tar -czvf "$Today_db_archive_name_connected" --remove-files --null -T -
echo "归档 ${Today_db_archive_name_connected} 已创建，原始文件已删除。"

echo "不会删除旧的备份文件..."
#rm -f ${Backup_Home}${OldWWWBackup}
#rm -f ${Backup_Home}${OldDB_tar_Backup}
