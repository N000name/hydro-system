#!/bin/bash
if [ $# -ne 2 ]; then
    echo "用法: $0 <输入CSV> <输出报告>"
    exit 1
fi
input_file="$1"
output_file="$2"
if [ ! -f "$input_file" ]; then
    echo "错误: 输入文件 '$input_file' 不存在"
    exit 1
fi
total=0; mutate=0; neg_rain=0; duplicate=0; out_of_order=0; line_num=1
prev_time=""; prev_level=""
> "$output_file"
tail -n +2 "$input_file" | while IFS=',' read -r station datetime level rain; do
    total=$((total+1)); line_num=$((line_num+1))
    level=$(echo "$level" | sed 's/^ *//;s/ *$//')
    rain=$(echo "$rain" | sed 's/^ *//;s/ *$//')
    datetime=$(echo "$datetime" | sed 's/^ *//;s/ *$//')
    station=$(echo "$station" | sed 's/^ *//;s/ *$//')
    if (( $(echo "$rain < 0" | bc -l 2>/dev/null) )); then
        neg_rain=$((neg_rain+1))
        echo "$line_num,降雨量异常,$station,$datetime,$level,$rain" >> "$output_file"
    fi
    if [ -n "$prev_level" ] && [ -n "$level" ]; then
        diff=$(echo "$prev_level - $level" | bc | tr -d '-' 2>/dev/null)
        if (( $(echo "$diff > 3.0" | bc -l 2>/dev/null) )); then
            mutate=$((mutate+1))
            echo "$line_num,水位突变异常,$station,$datetime,$level,$rain" >> "$output_file"
        fi
    fi
    if [ -n "$prev_time" ] && [ -n "$datetime" ]; then
        if [ "$datetime" == "$prev_time" ]; then
            duplicate=$((duplicate+1))
            echo "$line_num,时间戳重复,$station,$datetime,$level,$rain" >> "$output_file"
        elif [ "$datetime" \< "$prev_time" ]; then
            out_of_order=$((out_of_order+1))
            echo "$line_num,时间戳乱序,$station,$datetime,$level,$rain" >> "$output_file"
        fi
    fi
    prev_time="$datetime"; prev_level="$level"
done
abnormal=$((mutate+neg_rain+duplicate+out_of_order))
{
    echo "总记录数：$total"
    echo "水位突变异常：$mutate"
    echo "降雨量异常：$neg_rain"
    echo "时间戳重复：$duplicate"
    echo "时间戳乱序：$out_of_order"
    echo "异常记录总数：$abnormal"
    if [ $total -gt 0 ]; then
        rate=$(echo "scale=2; $abnormal * 100 / $total" | bc 2>/dev/null)
        echo "异常率：${rate}%"
    fi
} >> "$output_file"
echo "质量检查完成: $output_file"
exit 0
