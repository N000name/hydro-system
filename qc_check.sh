#!/bin/bash

# ============================================
# qc_check.sh - 水文数据质量检查脚本 (修复版)
# 用法: ./qc_check.sh 输入文件.csv
# 功能: 检查水位突变(>3m)、负降雨量、时间重复/乱序
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

echo "开始质量检查: $INPUT_FILE"
echo "========================================="

total=0
abnormal=0
mutate=0
neg_rain=0
duplicate=0
out_of_order=0

prev_time=""
prev_level=""

TEMP_FILE=$(mktemp)
tail -n +2 "$INPUT_FILE" > "$TEMP_FILE"

while IFS=',' read -r datetime station code device level flow ph turb rain temp ec
do
    if [ -z "$datetime" ]; then
        continue
    fi
    
    total=$((total + 1))
    
    level=$(echo "$level" | sed 's/^ *//;s/ *$//')
    rain=$(echo "$rain" | sed 's/^ *//;s/ *$//')
    datetime=$(echo "$datetime" | sed 's/^ *//;s/ *$//')
    
    if [ -n "$rain" ] && [ "$rain" != "NULL" ] && [ "$rain" != "null" ]; then
        if (( $(echo "$rain < 0" | bc -l) )); then
            echo "警告: 负降雨量! 行号: $total, 时间: $datetime, 降雨量: $rain"
            abnormal=$((abnormal + 1))
            neg_rain=$((neg_rain + 1))
        fi
    fi
    
    if [ -n "$prev_level" ] && [ -n "$level" ]; then
        diff=$(echo "$prev_level - $level" | bc | tr -d '-')
        if (( $(echo "$diff > 3.0" | bc -l) )); then
            echo "警告: 水位突变! 上一行: $prev_level, 当前行: $level, 差值: $diff"
            abnormal=$((abnormal + 1))
            mutate=$((mutate + 1))
        fi
    fi
    
    if [ -n "$prev_time" ] && [ -n "$datetime" ]; then
        if [ "$datetime" == "$prev_time" ]; then
            echo "警告: 时间重复! 时间: $datetime"
            abnormal=$((abnormal + 1))
            duplicate=$((duplicate + 1))
        elif [ "$datetime" \< "$prev_time" ]; then
            echo "警告: 时间乱序! 上一行: $prev_time, 当前行: $datetime"
            abnormal=$((abnormal + 1))
            out_of_order=$((out_of_order + 1))
        fi
    fi
    
    prev_time="$datetime"
    prev_level="$level"
    
done < "$TEMP_FILE"

rm -f "$TEMP_FILE"

echo "========================================="
echo "质量检查报告"
echo "总记录数: $total"
echo "异常总数: $abnormal"
if [ $total -gt 0 ]; then
    rate=$(echo "scale=2; $abnormal * 100 / $total" | bc)
    echo "异常率: $rate%"
fi
echo "水位突变: $mutate"
echo "负降雨量: $neg_rain"
echo "时间重复: $duplicate"
echo "时间乱序: $out_of_order"
