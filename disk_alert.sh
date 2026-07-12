#!/bin/bash
MONITOR_PATH="/data/hydro/mount"
usage=$(df "$MONITOR_PATH" | awk 'NR==2 {print $5}' | tr -d '%')

if [ "$usage" -gt 80 ]; then
    echo "告警：$MONITOR_PATH 磁盘使用率已达 ${usage}%，超过80%阈值，请及时清理空间！"
else
    echo "正常：$MONITOR_PATH 磁盘使用率为 ${usage}%，处于安全范围。"
fi

