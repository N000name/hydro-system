#!/bin/bash

# ============================================
# daily_report.sh - 水文数据日报表生成脚本
# 用法: ./daily_report.sh 输入文件.csv
# ============================================

if [ $# -ne 1 ]; then
    echo "用法: $0 <CSV文件>"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 文件 '$INPUT_FILE' 不存在"
    exit 1
fi

echo "正在生成日报表: $INPUT_FILE"
echo "========================================="

echo "站点,日期,平均水位,最高水位,最高水位时间,最低水位,最低水位时间,累计降雨量,完整率" > daily_report.csv

# 关键修正：使用 -F';' 指定分号作为分隔符
tail -n +2 "$INPUT_FILE" | sort -t';' -k2,2 -k1,1 | awk -F';' '
{
    split($1, datetime, " ")
    date = datetime[1]
    station = $2
    level = $5
    rain = $8
    time = $1
    
    key = station "," date
    if (!(key in count)) {
        count[key] = 0
        sum_level[key] = 0
        sum_rain[key] = 0
        max_level[key] = -9999
        min_level[key] = 9999
        max_time[key] = ""
        min_time[key] = ""
    }
    
    count[key]++
    sum_level[key] += level
    sum_rain[key] += rain
    
    if (level > max_level[key]) {
        max_level[key] = level
        max_time[key] = time
    }
    if (level < min_level[key]) {
        min_level[key] = level
        min_time[key] = time
    }
}
END {
    for (key in count) {
        split(key, parts, ",")
        station = parts[1]
        date = parts[2]
        
        avg_level = sum_level[key] / count[key]
        complete_rate = (count[key] / 24) * 100
        
        printf "%s,%s,%.2f,%.2f,%s,%.2f,%s,%.2f,%.1f\n",
            station, date, avg_level,
            max_level[key], max_time[key],
            min_level[key], min_time[key],
            sum_rain[key], complete_rate
    }
}' | sort -t',' -k1,1 -k2,2 >> daily_report.csv

echo "日报表已生成: daily_report.csv"
echo "========================================="
echo "前10行预览:"
head -10 daily_report.csv
