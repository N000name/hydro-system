#!/bin/bash

# ============================================
# data_collector.sh - 模拟水文数据采集脚本
# 用法: ./data_collector.sh
# 功能: 每隔5秒向collector.log追加模拟水位数据
# ============================================

LOG_FILE="/data/hydro/collector.log"

echo "开始模拟数据采集..." | tee -a "$LOG_FILE"

# 无限循环，每隔5秒生成一条数据
while true; do
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    station="兰溪站"
    level=$(echo "scale=2; 10 + ($RANDOM % 1000) / 100" | bc)
    rain=$(echo "scale=2; ($RANDOM % 500) / 100" | bc)
    
    echo "$timestamp, $station, 水位: $level m, 降雨量: $rain mm" | tee -a "$LOG_FILE"
    sleep 5
done
