#!/bin/bash

LOCK_FILE="/tmp/run_once_daily.lock"
TODAY=$(date +"%Y%m%d")
RESULT_DIR="./results"
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/run_${TODAY}.log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 定义日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# 如果存在当日生成的文件，则退出
if ls "$RESULT_DIR"/*"$TODAY"*.csv > /dev/null 2>&1; then
  log "[INFO] 今天 ($TODAY) 已有结果文件，跳过执行。"
  exit 0
fi

# 如果有锁文件且进程仍在跑，退出
if [ -f "$LOCK_FILE" ]; then
  PID=$(cat "$LOCK_FILE")
  if ps -p $PID > /dev/null 2>&1; then
    log "[INFO] 脚本正在运行中（PID: $PID），跳过本次执行。"
    exit 0
  else
    log "[WARN] 检测到僵尸锁（PID: $PID），清理后继续执行。"
    rm -f "$LOCK_FILE"
  fi
fi

# 写入当前 PID，加锁
echo $$ > "$LOCK_FILE"

log "[INFO] 开始执行调度脚本..."

# 执行主流程并记录每个子脚本输出
./sftp_pull.sh >> "$LOG_FILE" 2>&1
./txt2csv.sh >> "$LOG_FILE" 2>&1

log "[INFO] 脚本执行完毕，释放锁。"
rm -f "$LOCK_FILE"
