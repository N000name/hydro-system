#!/bin/bash
# 模拟水文数据采集脚本
LOG_FILE="/data/hydro/collector.log"

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"

echo "数据采集脚本启动，日志路径：$LOG_FILE"
while true
do
    # 生成10.00~29.99m之间的随机模拟水位
    water_level=$(echo "scale=2; 10 + $RANDOM % 2000 / 100" | bc)
    # 写入时间戳+水位数据
    echo "$(date '+%Y-%m-%d %H:%M:%S') 监测水位：${water_level} m" >> "$LOG_FILE"
    # 采集间隔：3秒
    sleep 3
done

