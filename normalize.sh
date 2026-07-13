#!/bin/bash

if [ $# -ne 2 ]; then
    echo "用法: $0 <输入文件路径> <输出文件路径>" >&2
    exit 1
fi

input="$1"
output="$2"

# 校验输入文件合法性
if [ ! -f "$input" ] || [ ! -r "$input" ]; then
    echo "错误：输入文件不存在或不可读" >&2
    exit 1
fi

# 流程：去BOM → 统一分隔符 → 转换时间格式 → 清理空行
sed '1s/^\xEF\xBB\xBF//' "$input" \
| sed -e 's/;/,/g' -e "s/$(printf '\t')/,/g" \
| awk -F ',' '
NR == 1 { print; next }
{
    split($1, dt, " ")
    date = dt[1]
    time = dt[2] ? dt[2] : "00:00:00"
    
    if (date ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/) {
        gsub(/\//, "-", date)
    } else if (date ~ /^[0-9]{2}\/[0-9]{2}\/[0-9]{4}$/) {
        split(date, d, "/")
        date = d[3] "-" d[2] "-" d[1]
    }
    
    $1 = date " " time
    print
}
' OFS=',' \
| sed '/^$/d' > "$output"

exit 0

