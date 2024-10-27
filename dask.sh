#!/bin/bash

# 安装 Supervisor 和 Dask
echo "Updating system and installing required packages..."
sudo apt update
sudo apt install -y python3-pip supervisor

echo "Installing Dask..."
pip3 install dask distributed

# 获取用户输入
read -p "Please enter the Dask scheduler host (e.g., vps-public-ip:8786): " SCHEDULER_HOST
read -p "Please enter the Dask worker name (e.g., my-worker-1): " WORKER_NAME
read -p "Please enter the number of threads per worker (default is 32): " NTHREADS

# 设置默认线程数
if [[ -z "$NTHREADS" ]]; then
    NTHREADS=32
fi

# 创建 Supervisor 配置文件
SUPERVISOR_CONF_PATH="/etc/supervisor/conf.d/dask-worker.conf"

echo "Creating Supervisor configuration for Dask worker..."
sudo bash -c "cat > $SUPERVISOR_CONF_PATH" <<EOL
[program:dask-worker]
command=dask-worker $SCHEDULER_HOST --nthreads $NTHREADS --name "$WORKER_NAME"
autostart=true
autorestart=true
startretries=10
stderr_logfile=/var/log/dask-worker.err.log
stdout_logfile=/var/log/dask-worker.out.log
EOL

# 重新加载并启动 Supervisor 配置
echo "Reloading Supervisor and starting Dask worker service..."
sudo supervisorctl reread
sudo supervisorctl update

echo "Dask worker configured and running under Supervisor!"
echo "You can monitor the logs at /var/log/dask-worker.out.log and /var/log/dask-worker.err.log"
