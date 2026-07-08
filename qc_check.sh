#!/bin/bash

# 参数校验
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <标准化CSV文件路径>"
    exit 1
fi

input_file="$1"

if [ ! -f "$input_file" ]; then
    echo "错误：文件 $input_file 不存在"
    exit 1
fi

# 核心数据质量检查逻辑
awk -F ',' '
BEGIN {
    total_records = 0          # 总数据行数（不含表头）
    cnt_water_sudden = 0       # 水位突变异常数
    cnt_rain_abnormal = 0      # 降雨量异常数
    cnt_time_dup = 0           # 时间戳重复异常数
    cnt_time_disorder = 0      # 时间戳乱序异常数
    detail_idx = 0             # 异常详情条目索引
    delete abnormal_line_set   # 去重存储异常行号
}

# 跳过表头行
NR == 1 { next }

{
    total_records++
    lineno = NR
    raw_line = $0
    cur_time = $2
    cur_water = $3 + 0   # 强制转为数值
    cur_rain = $4 + 0    # 强制转为数值

    # 1. 降雨量负值异常（行自身判断）
    if (cur_rain < 0) {
        cnt_rain_abnormal++
        detail_idx++
        abnormal_detail[detail_idx] = lineno ",降雨量异常," raw_line
        abnormal_line_set[lineno] = 1
    }

    # 2. 与上一行对比类异常（从第二行数据开始）
    if (total_records > 1) {
        # 时间戳重复
        if (cur_time == prev_time) {
            cnt_time_dup++
            detail_idx++
            abnormal_detail[detail_idx] = lineno ",时间戳重复," raw_line
            abnormal_line_set[lineno] = 1
        }

        # 时间戳乱序（后一行早于前一行）
        if (cur_time < prev_time) {
            cnt_time_disorder++
            detail_idx++
            abnormal_detail[detail_idx] = lineno ",时间戳乱序," raw_line
            abnormal_line_set[lineno] = 1
        }

        # 水位突变（相邻水位差绝对值 > 3m）
        diff = cur_water - prev_water
        if (diff > 3 || diff < -3) {
            cnt_water_sudden++
            detail_idx++
            abnormal_detail[detail_idx] = lineno ",水位突变异常," raw_line
            abnormal_line_set[lineno] = 1
        }
    }

    # 更新上一行状态
    prev_time = cur_time
    prev_water = cur_water
}

END {
    # 计算去重后异常总行数
    abnormal_total = 0
    for (line in abnormal_line_set) {
        abnormal_total++
    }

    # 计算异常率
    if (total_records > 0) {
        abnormal_rate = (abnormal_total / total_records) * 100
    } else {
        abnormal_rate = 0
    }

    # 结构化输出报告
    print "总记录数（不含表头行）:" total_records
    print "水位突变异常数量:" cnt_water_sudden
    print "降雨量异常数量:" cnt_rain_abnormal
    print "时间戳重复数量:" cnt_time_dup
    print "时间戳乱序数量:" cnt_time_disorder
    print "异常记录总数（去重后行数）:" abnormal_total
    printf "异常率: %.2f%%\n", abnormal_rate
    print "------------------------------"
    print "行号,异常类型,原始数据"
    for (i = 1; i <= detail_idx; i++) {
        print abnormal_detail[i]
    }
}
' "$input_file"

