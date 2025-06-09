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
MAX_SIZE=$((50 * 1024 * 1024))

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

  # 判断输出目录：是否严格匹配 udc_sbzj-YYYYMMDD 格式
  if [[ "$BASENAME" =~ ^udc_sbzj-[0-9]{8}$ ]]; then
    OUTPUT_DIR="${RESULT_DIR}/user"
    mkdir -p "$OUTPUT_DIR"
  else
    OUTPUT_DIR="$RESULT_DIR"
  fi

  OUTPUT_BASE="${OUTPUT_DIR}/${BASENAME}"

  if [ "$ACTUAL_SIZE" -le "$MAX_SIZE" ]; then
    FINAL_OUTPUT="${OUTPUT_BASE}.csv"
    mv "$FULL_CSV" "$FINAL_OUTPUT"
    log "✅ 转换完成：$FINAL_OUTPUT（未超过 50MB）"
    continue
  fi

  log "⚠️ 文件超过 50MB，开始按行拆分..."

  HEADER_LINE=$(head -n 1 "$FULL_CSV")
  tail -n +2 "$FULL_CSV" > "${FULL_CSV}.body"

  TOTAL_LINES=$(wc -l < "${FULL_CSV}.body")
  LOW=1000
  HIGH=$TOTAL_LINES
  BEST_N=0

  while (( LOW <= HIGH )); do
    MID=$(( (LOW + HIGH) / 2 ))
    split -l "$MID" "${FULL_CSV}.body" tmp_estimate_

    MAX_OBSERVED_SIZE=0
    for FILE in tmp_estimate_*; do
      FILE_SIZE=$(stat -c%s "$FILE")
      (( FILE_SIZE > MAX_OBSERVED_SIZE )) && MAX_OBSERVED_SIZE=$FILE_SIZE
    done
    rm -f tmp_estimate_*

    if (( MAX_OBSERVED_SIZE < MAX_SIZE )); then
      BEST_N=$MID
      LOW=$((MID + 1))
    else
      HIGH=$((MID - 1))
    fi
  done

  if (( BEST_N == 0 )); then
    log "❌ 无法找到合适的拆分行数，跳过该文件"
    rm -f "$FULL_CSV" "${FULL_CSV}.body"
    continue
  fi

  log "ℹ️ 估算每份最大行数：$BEST_N，开始正式拆分..."

  split -l "$BEST_N" "${FULL_CSV}.body" tmp_part_

  INDEX=1
  for FILE in tmp_part_*; do
    OUT_FILE="${OUTPUT_BASE}-${INDEX}.csv"
    {
      echo "$HEADER_LINE"
      cat "$FILE"
    } > "$OUT_FILE"
    log "✅ 拆分完成：$OUT_FILE"
    ((INDEX++))
  done

  rm -f tmp_part_* "$FULL_CSV" "${FULL_CSV}.body"
done

log "🎉 所有文件处理完成。"
