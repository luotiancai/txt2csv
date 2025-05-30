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
MAX_SIZE=$((19 * 1024 * 1024))

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
  iconv -f GBK -t UTF-8 "$TXT_FILE" | sed "s/${BEL}/,/g" > "$TMP_BODY"

  FULL_CSV=$(mktemp)
  cat "$HEADER_FILE" "$TMP_BODY" > "$FULL_CSV"
  rm "$TMP_BODY"

  ACTUAL_SIZE=$(stat -c%s "$FULL_CSV")
  OUTPUT_BASE="${RESULT_DIR}/${BASENAME}"

  if [ "$ACTUAL_SIZE" -le "$MAX_SIZE" ]; then
    FINAL_OUTPUT="${OUTPUT_BASE}.csv"
    mv "$FULL_CSV" "$FINAL_OUTPUT"
    log "✅ 转换完成：$FINAL_OUTPUT（未超过 19MB）"
    continue
  fi

  log "⚠️ 文件超过 19MB，开始拆分..."

  HEADER_LINE=$(head -n 1 "$FULL_CSV")
  tail -n +2 "$FULL_CSV" > "${FULL_CSV}.body"
  split -b 19m -d --additional-suffix=.part "${FULL_CSV}.body" tmp_split_

  INDEX=1
  for FILE in tmp_split_*.part; do
    OUT_FILE="${OUTPUT_BASE}-${INDEX}.csv"
    {
      echo "$HEADER_LINE"
      cat "$FILE"
    } > "$OUT_FILE"
    log "✅ 拆分完成：$OUT_FILE"
    ((INDEX++))
  done

  rm tmp_split_*.part "$FULL_CSV" "${FULL_CSV}.body"
done

log "🎉 所有文件处理完成。"
