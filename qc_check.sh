#!/bin/bash

# 参数校验
if [ $# -ne 2 ]; then
    echo "用法: $0 <输入CSV路径> <输出报告文件路径>" >&2
    exit 1
fi

input_file="$1"
output_file="$2"

# 输入文件存在性校验
if [ ! -f "$input_file" ]; then
    echo "错误：输入文件不存在" >&2
    exit 1
fi

# 执行质量检查，结果写入输出文件
awk -F ',' '
BEGIN {
    total = 0
    water_mutate = 0
    rain_neg = 0
    time_dup = 0
    time_reverse = 0
    detail_cnt = 0
}

NR == 1 { next }  # 跳过表头行

{
    total++
    line_no = NR
    time = $2
    water = $3 + 0
    rain = $4 + 0
    raw = $0
    line_has_err = 0

    # 1. 降雨量异常：降雨量为负值
    if (rain < 0) {
        rain_neg++
        detail[++detail_cnt] = line_no ",降雨量异常," raw
        line_has_err = 1
    }

    # 从第二条数据开始，与上一条记录对比
    if (NR > 2) {
        # 2. 水位突变异常：相邻水位差绝对值 > 3m
        diff = water - prev_water
        if (diff < 0) diff = -diff
        if (diff > 3) {
            water_mutate++
            detail[++detail_cnt] = line_no ",水位突变异常," raw
            line_has_err = 1
        }

        # 3. 时间戳重复：相邻时间完全相同
        if (time == prev_time) {
            time_dup++
            detail[++detail_cnt] = line_no ",时间戳重复," raw
            line_has_err = 1
        }

        # 4. 时间戳乱序：后一条时间早于前一条
        if (time < prev_time) {
            time_reverse++
            detail[++detail_cnt] = line_no ",时间戳乱序," raw
            line_has_err = 1
        }
    }

    # 标记异常行，用于去重统计
    if (line_has_err) {
        err_lines[line_no] = 1
    }

    # 保存当前值，供下一行对比
    prev_time = time
    prev_water = water
}

END {
    # 统计去重后的异常总行数
    err_total = 0
    for (k in err_lines) err_total++

    # 计算异常率，保留两位小数
    rate = total > 0 ? err_total / total * 100 : 0

    # 输出统计项
    printf "总记录数：%d\n", total
    printf "水位突变异常：%d\n", water_mutate
    printf "降雨量异常：%d\n", rain_neg
    printf "时间戳重复：%d\n", time_dup
    printf "时间戳乱序：%d\n", time_reverse
    printf "异常记录总数：%d\n", err_total
    printf "异常率：%.2f%%\n", rate

    # 输出异常明细
    for (i = 1; i <= detail_cnt; i++) {
        print detail[i]
    }
}
' "$input_file" > "$output_file"

exit 0

