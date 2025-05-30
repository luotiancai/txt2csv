#!/bin/bash

# 用法: ./merge_header_and_split.sh header.csv data.TXT

HEADER_FILE="$1"
TXT_FILE="$2"

if [ -z "$HEADER_FILE" ] || [ -z "$TXT_FILE" ]; then
  echo "用法: $0 header.csv data.TXT"
  exit 1
fi

# 定义 BEL 分隔符（ASCII 007）
BEL=$(printf '\x07')

# 生成基础输出文件名（去除扩展名）
BASE_NAME="${TXT_FILE%.*}"
FULL_CSV="${BASE_NAME}_full.csv"

# Step 1: 转换 TXT 文件（GBK -> UTF-8，BEL 替换为 ,）
TMP_BODY=$(mktemp)
iconv -f GBK -t UTF-8 "$TXT_FILE" | sed "s/${BEL}/,/g" > "$TMP_BODY"

# Step 2: 合并 header 和数据，生成完整 CSV
cat "$HEADER_FILE" "$TMP_BODY" > "$FULL_CSV"
rm "$TMP_BODY"

# Step 3: 判断是否超过 19MB（19 * 1024 * 1024 = 51380224 字节）
MAX_SIZE=$((19 * 1024 * 1024))
ACTUAL_SIZE=$(stat -c%s "$FULL_CSV")

if [ "$ACTUAL_SIZE" -le "$MAX_SIZE" ]; then
  FINAL_OUTPUT="${BASE_NAME}.csv"
  mv "$FULL_CSV" "$FINAL_OUTPUT"
  echo "✅ 转换完成：$FINAL_OUTPUT（未超过 19MB）"
  exit 0
fi

echo "⚠️ 文件超过 19MB，开始拆分..."

# Step 4: 使用 split 拆分正文（不含表头）
HEADER_LINE=$(head -n 1 "$FULL_CSV")
tail -n +2 "$FULL_CSV" > "${FULL_CSV}.body"

# 拆分为 19MB 的文件块，前缀为 tmp_split_
split -b 19m -d --additional-suffix=.part "${FULL_CSV}.body" tmp_split_

# 添加表头并重命名为 xxx-1.csv、xxx-2.csv...
INDEX=1
for FILE in tmp_split_*.part; do
  OUT_FILE="${BASE_NAME}-${INDEX}.csv"
  {
    echo "$HEADER_LINE"
    cat "$FILE"
  } > "$OUT_FILE"
  echo "✅ 拆分完成：$OUT_FILE"
  ((INDEX++))
done

# 清理中间文件
rm tmp_split_*.part "$FULL_CSV" "${FULL_CSV}.body"
