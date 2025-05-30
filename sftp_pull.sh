#!/bin/bash

# === 配置区域 ===
SFTP_USER="sftpuser1"              # 远程用户名
SFTP_PASS="123456"           # ✅ 明文密码（请替换）
SFTP_HOST="12.103.113.67"          # 远程服务器地址
SFTP_PORT="8822"                   # ✅ 非默认端口
REMOTE_DIR="/data1"                # 远程目录
LOCAL_DIR="./downloads"            # 本地保存目录

# === 创建本地目录 ===
mkdir -p "$LOCAL_DIR"

# === 使用 lftp 拉取文件 ===
lftp -u "$SFTP_USER","$SFTP_PASS" sftp://$SFTP_HOST:$SFTP_PORT <<EOF
cd $REMOTE_DIR
lcd $LOCAL_DIR
mget udc_sbzj*
bye
EOF

# === 检查是否下载成功 ===
if ls "$LOCAL_DIR"/udc_sbzj* 1> /dev/null 2>&1; then
  echo "✅ 成功下载文件: $(ls "$LOCAL_DIR"/udc_sbzj* | wc -l) 个"
else
  echo "❌ 没有匹配到任何 udc_sbzj 开头的文件"
  exit 1
fi
