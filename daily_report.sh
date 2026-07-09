#!/bin/bash
if [ $# -ne 2 ]; then
    echo "用法: $0 <输入CSV> <输出日报>"
    exit 1
fi
input_file="$1"
output_file="$2"
if [ ! -f "$input_file" ]; then
    echo "错误: 输入文件 '$input_file' 不存在"
    exit 1
fi
echo "站点编号,日期,日平均水位,日最高水位,日最高水位时间,日最低水位,日最低水位时间,日累计降雨量,数据完整率" > "$output_file"
tail -n +2 "$input_file" | sort -t',' -k1,1 -k2,2 | awk -F',' '
{
    station=$1; datetime=$2; level=$3; rain=$4
    split(datetime, dt, " "); date=dt[1]
    key=station","date
    if(!(key in count)){count[key]=0; sum_level[key]=0; sum_rain[key]=0; max_level[key]=-9999; min_level[key]=9999; max_time[key]=""; min_time[key]=""}
    count[key]++; sum_level[key]+=level; sum_rain[key]+=rain
    if(level>max_level[key]){max_level[key]=level; max_time[key]=datetime}
    if(level<min_level[key]){min_level[key]=level; min_time[key]=datetime}
}
END{
    for(key in count){
        split(key, parts, ","); station=parts[1]; date=parts[2]
        avg=sum_level[key]/count[key]; rate=(count[key]/24)*100
        printf "%s,%s,%.2f,%.2f,%s,%.2f,%s,%.2f,%.1f\n", station, date, avg, max_level[key], max_time[key], min_level[key], min_time[key], sum_rain[key], rate
    }
}' | sort -t',' -k1,1 -k2,2 >> "$output_file"
echo "日报表生成完成: $output_file"
exit 0
