#!/bin/bash

# === 日志函数 ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [sftp_pull] $*"
}

# === 配置区域 ===
SFTP_USER="sftpuser1"
SFTP_PASS="123456"
SFTP_HOST="12.103.113.67"
SFTP_PORT="8822"
REMOTE_DIR="/data1"
LOCAL_DIR="./downloads"

log "准备连接到 SFTP: $SFTP_HOST:$SFTP_PORT 并下载 $REMOTE_DIR/udc_sbzj*"

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
  COUNT=$(ls "$LOCAL_DIR"/udc_sbzj* | wc -l)
  log "✅ 成功下载文件 $COUNT 个"
else
  log "❌ 没有匹配到任何 udc_sbzj 开头的文件"
  exit 1
fi
