#!/bin/bash

# 检查是否在bash下运行
if [ -z "$BASH_VERSION" ]; then
  echo "脚本未在bash下运行，正在切换到bash..."
  exec /bin/bash "$0" "$@"
fi

# 检查是否以root用户运行脚本
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户权限运行此脚本。"
  exit 1
fi

# 检查是否已安装rinetd，通过判断返回结果中是否包含 'rinetd' 字符串
if ! command -v rinetd | grep -q "rinetd"; then
  echo "rinetd未安装，现在安装rinetd..."
  sudo apt update
  sudo apt install -y rinetd
else
  echo "rinetd已安装，继续执行..."
fi

# 下载加密的配置文件
config_url="https://s.theucd.com/file/rinetd.conf.enc"
config_file="/etc/rinetd.conf.enc"
wget -O "$config_file" "$config_url"

# 提示输入解密密码，并明确等待用户输入
echo
read -p "请输入解密密码: " -s decrypt_password
echo

# 解密并替换/etc/rinetd.conf
openssl enc -d -aes-256-cbc -in "$config_file" -out /etc/rinetd.conf -k "$decrypt_password" -md sha256 -pbkdf2 -iter 100000

# 检查解密是否成功
if [ $? -eq 0 ]; then
  echo "配置文件解密成功并已替换 /etc/rinetd.conf"
else
  echo "配置文件解密失败，请检查密码并重试。"
  exit 1
fi

# 重启rinetd服务以应用更改
sudo systemctl restart rinetd

# 设置rinetd开机自启
sudo systemctl enable rinetd

echo "rinetd已成功配置并重启。"
