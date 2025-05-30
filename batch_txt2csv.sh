#!/bin/bash

# 用法: ./batch_merge_and_split.sh

DOWNLOAD_DIR="./downloads"
HEADER_DIR="./headers"
RESULT_DIR="./results"

# 创建结果目录
mkdir -p "$RESULT_DIR"

# 启用 nullglob：如果没有匹配项，glob 会展开为空数组而不是原样返回字符串
shopt -s nullglob
TXT_FILES=("$DOWNLOAD_DIR"/*.TXT)

if [ ${#TXT_FILES[@]} -eq 0 ]; then
  echo "⚠️ 未找到任何 TXT 文件在 $DOWNLOAD_DIR 目录中，已退出。"
  exit 0
fi

# 定义 BEL 分隔符（ASCII 007）
BEL=$(printf '\x07')
MAX_SIZE=$((19 * 1024 * 1024))

for TXT_FILE in "${TXT_FILES[@]}"; do
  BASENAME=$(basename "$TXT_FILE" .TXT)
  
  # 提取头文件前缀（去掉日期部分）
  HEADER_PREFIX=$(echo "$BASENAME" | sed -E 's/-[0-9]{8}$//')
  HEADER_FILE="${HEADER_DIR}/${HEADER_PREFIX}.csv"

  if [ ! -f "$HEADER_FILE" ]; then
    echo "❌ 找不到对应表头文件: $HEADER_FILE"
    continue
  fi

  echo "➡️ 处理文件: $TXT_FILE 配对头文件: $HEADER_FILE"

  # 转换 TXT 文件（GBK -> UTF-8，BEL 替换为 ,）
  TMP_BODY=$(mktemp)
  iconv -f GBK -t UTF-8 "$TXT_FILE" | sed "s/${BEL}/,/g" > "$TMP_BODY"

  # 合并 header 和数据
  FULL_CSV=$(mktemp)
  cat "$HEADER_FILE" "$TMP_BODY" > "$FULL_CSV"
  rm "$TMP_BODY"

  # 判断大小
  ACTUAL_SIZE=$(stat -c%s "$FULL_CSV")
  OUTPUT_BASE="${RESULT_DIR}/${BASENAME}"

  if [ "$ACTUAL_SIZE" -le "$MAX_SIZE" ]; then
    FINAL_OUTPUT="${OUTPUT_BASE}.csv"
    mv "$FULL_CSV" "$FINAL_OUTPUT"
    echo "✅ 转换完成：$FINAL_OUTPUT（未超过 19MB）"
    continue
  fi

  echo "⚠️ 文件超过 19MB，开始拆分..."

  HEADER_LINE=$(head -n 1 "$FULL_CSV")
  tail -n +2 "$FULL_CSV" > "${FULL_CSV}.body"

  # 拆分为 19MB 的文件块
  split -b 19m -d --additional-suffix=.part "${FULL_CSV}.body" tmp_split_

  # 添加表头并重命名为 xxx-1.csv、xxx-2.csv...
  INDEX=1
  for FILE in tmp_split_*.part; do
    OUT_FILE="${OUTPUT_BASE}-${INDEX}.csv"
    {
      echo "$HEADER_LINE"
      cat "$FILE"
    } > "$OUT_FILE"
    echo "✅ 拆分完成：$OUT_FILE"
    ((INDEX++))
  done

  # 清理
  rm tmp_split_*.part "$FULL_CSV" "${FULL_CSV}.body"

done

echo "🎉 所有文件处理完成。"
