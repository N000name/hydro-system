#!/bin/bash

# 模拟水文数据采集脚本
# 持续向当前目录 collector.log 追加水位数据

while true
do
    # 生成标准格式时间戳
    log_time=$(date "+%Y-%m-%d %H:%M:%S")
    # 生成 12.00~18.00 之间的随机水位，保留两位小数
    water_level=$(awk 'BEGIN{srand(); printf "%.2f", 12 + rand() * 6}')

    # 追加写入日志文件
    echo "${log_time} water_level=${water_level}" >> collector.log

    # 间隔3秒采集一次，使用nice调整休眠进程优先级
    nice -n 10 sleep 3
done

