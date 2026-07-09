#!/bin/bash

# 参数校验
if [ $# -ne 2 ]; then
    echo "用法: $0 <输入CSV路径> <输出日报文件路径>" >&2
    exit 1
fi

input_file="$1"
output_file="$2"

# 输入文件存在性校验
if [ ! -f "$input_file" ]; then
    echo "错误：输入文件不存在" >&2
    exit 1
fi

# 按站点+日期分组统计，结果写入输出文件
awk -F ',' '
NR == 1 { next }  # 跳过表头
{
    site = $1
    time = $2
    water = $3 + 0
    rain = $4 + 0
    date = substr(time, 1, 10)  # 提取日期部分 yyyy-MM-dd
    key = site "|" date        # 分组键：站点|日期

    # 分组初始化：首次出现时设置极值初始值
    if (!(key in count)) {
        count[key] = 0
        sum_water[key] = 0
        sum_rain[key] = 0
        max_water[key] = water
        max_time[key] = time
        min_water[key] = water
        min_time[key] = time
    }

    # 累计统计
    count[key]++
    sum_water[key] += water
    sum_rain[key] += rain

    # 更新最高水位：仅严格大于时更新，保证记录首次出现时间
    if (water > max_water[key]) {
        max_water[key] = water
        max_time[key] = time
    }

    # 更新最低水位：仅严格小于时更新，保证记录首次出现时间
    if (water < min_water[key]) {
        min_water[key] = water
        min_time[key] = time
    }
}

END {
    # 输出固定表头（9列，顺序不可变）
    print "站点编号,日期,日平均水位,日最高水位,日最高水位时间,日最低水位,日最低水位时间,日累计降雨量,数据完整率"

    # 收集所有分组键并排序（按站点升序、日期升序）
    n = 0
    for (k in count) {
        n++
        keys[n] = k
    }
    asort(keys)

    # 逐行输出统计结果
    for (i = 1; i <= n; i++) {
        k = keys[i]
        split(k, parts, "|")
        site = parts[1]
        date = parts[2]

        avg_water = sum_water[k] / count[k]
        completeness = count[k] / 24 * 100

        printf "%s,%s,%.2f,%.2f,%s,%.2f,%s,%.2f,%.1f%%\n", \
            site, date, avg_water, max_water[k], max_time[k], \
            min_water[k], min_time[k], sum_rain[k], completeness
    }
}
' "$input_file" > "$output_file"

exit 0

