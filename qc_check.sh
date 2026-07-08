#!/bin/bash
# 水文数据质量检查脚本
# 用法: ./qc_check.sh <输入数据文件>

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

# 核心检测逻辑（GNU Awk实现）
gawk -F ',' '
BEGIN {
    # 初始化计数器
    total_records = 0
    cnt_water_mutate = 0   # 水位突变异常
    cnt_rain_neg = 0       # 降雨量异常
    cnt_time_dup = 0       # 时间戳重复
    cnt_time_disorder = 0  # 时间戳乱序
    detail_num = 0         # 异常详情条目计数
}

# 跳过表头行
NR == 1 { next }

{
    total_records++
    line_no = NR
    raw_line = $0

    # 时间转时间戳（兼容 yyyy-MM-dd 和 yyyy/MM/dd 格式）
    time_str = $1
    gsub(/[-/:]/, " ", time_str)
    curr_ts = mktime(time_str)

    # 提取水位、降雨量数值
    curr_water = $5 + 0
    curr_rain = $7 + 0

    # 1. 降雨量异常检测（负值）
    if (curr_rain < 0) {
        cnt_rain_neg++
        detail_num++
        arr_line[detail_num] = line_no
        arr_type[detail_num] = "降雨量异常"
        arr_raw[detail_num] = raw_line
        unique_abnormal[line_no] = 1
    }

    # 相邻行对比类检测（从第二条数据开始）
    if (total_records > 1) {
        # 2. 时间戳重复检测
        if (curr_ts == prev_ts) {
            cnt_time_dup++
            detail_num++
            arr_line[detail_num] = line_no
            arr_type[detail_num] = "时间戳重复"
            arr_raw[detail_num] = raw_line
            unique_abnormal[line_no] = 1
        }

        # 3. 时间戳乱序检测
        if (curr_ts < prev_ts) {
            cnt_time_disorder++
            detail_num++
            arr_line[detail_num] = line_no
            arr_type[detail_num] = "时间戳乱序"
            arr_raw[detail_num] = raw_line
            unique_abnormal[line_no] = 1
        }

        # 4. 水位突变检测（相邻差值绝对值>3m）
        water_diff = curr_water - prev_water
        if (water_diff < 0) water_diff = -water_diff
        if (water_diff > 3) {
            cnt_water_mutate++
            detail_num++
            arr_line[detail_num] = line_no
            arr_type[detail_num] = "水位突变异常"
            arr_raw[detail_num] = raw_line
            unique_abnormal[line_no] = 1
        }
    }

    # 更新上一行状态
    prev_ts = curr_ts
    prev_water = curr_water
}

END {
    # 计算去重后异常记录总数
    abnormal_total = 0
    for (l in unique_abnormal) {
        abnormal_total++
    }

    # 计算异常率，保留两位小数
    if (total_records > 0) {
        abnormal_rate = sprintf("%.2f", (abnormal_total / total_records) * 100)
    } else {
        abnormal_rate = "0.00"
    }

    # 输出结构化报告
    print "========== 数据质量检查报告 =========="
    print "总记录数（不含表头）: " total_records
    print "水位突变异常数:      " cnt_water_mutate
    print "降雨量异常数:        " cnt_rain_neg
    print "时间戳重复数:        " cnt_time_dup
    print "时间戳乱序数:        " cnt_time_disorder
    print "异常记录总数（去重）: " abnormal_total
    print "异常率:              " abnormal_rate "%"
    print ""
    print "========== 异常明细 =========="
    printf "%-6s %-12s %s\n", "行号", "异常类型", "原始数据"
    print "----------------------------------------"
    for (i = 1; i <= detail_num; i++) {
        printf "%-6d %-12s %s\n", arr_line[i], arr_type[i], arr_raw[i]
    }
}
' "$INPUT_FILE"

