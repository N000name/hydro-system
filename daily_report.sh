#!/bin/bash
# 水文数据日报表生成脚本
# 用法: ./daily_report.sh <输入数据文件>

set -e

# 参数校验
if [ $# -ne 1 ]; then
    echo "错误: 请指定输入数据文件"
    echo "用法: $0 <数据文件路径>"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 文件 $INPUT_FILE 不存在"
    exit 1
fi

# 输出CSV表头
echo "站点编号,日期,平均水位,最高水位,最高水位时间,最低水位,最低水位时间,累计降雨量,完整率"

# 核心统计逻辑 + 按站点、日期排序
gawk -F ',' '
NR == 1 { next }  # 跳过表头行

{
    datetime = $1
    site_code = $3
    water = $5 + 0
    rain = $7 + 0
    
    # 提取日期（前10位，兼容 yyyy/MM/dd 格式）
    date = substr(datetime, 1, 10)
    # 以「站点+日期」为分组键
    key = site_code SUBSEP date
    
    # 累计统计量
    sum_water[key] += water
    record_count[key]++
    sum_rain[key] += rain
    
    # 记录最高水位及对应时间
    if (record_count[key] == 1 || water > max_water[key]) {
        max_water[key] = water
        max_time[key] = datetime
    }
    
    # 记录最低水位及对应时间
    if (record_count[key] == 1 || water < min_water[key]) {
        min_water[key] = water
        min_time[key] = datetime
    }
}

END {
    # 遍历所有分组，格式化输出
    for (k in sum_water) {
        split(k, parts, SUBSEP)
        site = parts[1]
        day = parts[2]
        
        avg_water = sum_water[k] / record_count[k]
        completeness = (record_count[k] / 24) * 100
        
        printf "%s,%s,%.2f,%.2f,%s,%.2f,%s,%.2f,%.1f\n", \
            site, day, avg_water, max_water[k], max_time[k], \
            min_water[k], min_time[k], sum_rain[k], completeness
    }
}
' "$INPUT_FILE" | sort -t ',' -k1,1 -k2,2

