#!/bin/bash

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [txt2csv] $*"
}

DOWNLOAD_DIR="./downloads"
HEADER_DIR="./headers"
RESULT_DIR="./results"
mkdir -p "$RESULT_DIR"

shopt -s nullglob
TXT_FILES=("$DOWNLOAD_DIR"/*.TXT)

if [ ${#TXT_FILES[@]} -eq 0 ]; then
  log "⚠️ 未找到任何 TXT 文件在 $DOWNLOAD_DIR 目录中，已退出。"
  exit 0
fi

BEL=$(printf '\x07')

for TXT_FILE in "${TXT_FILES[@]}"; do
  BASENAME=$(basename "$TXT_FILE" .TXT)
  HEADER_PREFIX=$(echo "$BASENAME" | sed -E 's/-[0-9]{8}$//')
  HEADER_FILE="${HEADER_DIR}/${HEADER_PREFIX}.csv"

  if [ ! -f "$HEADER_FILE" ]; then
    log "❌ 找不到对应表头文件: $HEADER_FILE"
    continue
  fi

  log "➡️ 处理文件: $TXT_FILE 配对头文件: $HEADER_FILE"

  TMP_BODY=$(mktemp)
  # 提取前 100 行（去除换行符和 BEL 替换为逗号）
  iconv -f GBK -t UTF-8 "$TXT_FILE" | sed "s/${BEL}/,/g" | head -n 100 > "$TMP_BODY"

  FINAL_OUTPUT="${RESULT_DIR}/${BASENAME}.csv"
  {
    cat "$HEADER_FILE"
    cat "$TMP_BODY"
  } > "$FINAL_OUTPUT"

  rm "$TMP_BODY"

  log "✅ 提取完成：$FINAL_OUTPUT（仅前100行）"
done

log "🎉 所有文件处理完成。"
