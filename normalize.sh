#!/bin/bash

if [ $# -ne 2 ]; then
    echo "用法: $0 <输入文件路径> <输出文件路径>"
    exit 1
fi

input="$1"
output="$2"

sed '1s/^\xEF\xBB\xBF//' "$input" \
| sed -e 's/;/,/g' -e 's/\t/,/g' \
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

