#!/bin/bash

# === 配置区域 ===
SFTP_SCRIPT="./sftp_fetch.sh"                   # 你的 SFTP 拉取脚本
CONVERT_SCRIPT="./convert_and_split.sh"         # 你的 TXT 转换脚本
HEADER_FILE="./header.csv"                      # 表头文件
DOWNLOAD_DIR="./downloads"                      # 下载目录
MATCH_PREFIX="udc_sbzj"                         # 匹配文件前缀

# === 步骤 1：执行 SFTP 拉取 ===
echo "📥 [1/2] 开始执行 SFTP 拉取..."
bash "$SFTP_SCRIPT"
if [ $? -ne 0 ]; then
  echo "❌ SFTP 拉取失败，终止后续操作"
  exit 1
fi

# === 步骤 2：查找下载的 TXT 文件 ===
TXT_FILES=$(ls "$DOWNLOAD_DIR"/${MATCH_PREFIX}*.txt 2>/dev/null)
if [ -z "$TXT_FILES" ]; then
  echo "⚠️ 没有发现匹配的 TXT 文件（${MATCH_PREFIX}*.txt），跳过转换"
  exit 0
fi

# === 步骤 3：逐个执行转换脚本 ===
echo "🔄 [2/2] 开始转换文件为 CSV..."
for TXT_FILE in $TXT_FILES; do
  echo "➡️ 转换：$TXT_FILE"
  bash "$CONVERT_SCRIPT" "$HEADER_FILE" "$TXT_FILE"
done

echo "✅ 所有步骤完成！"
