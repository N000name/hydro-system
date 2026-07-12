#!/bin/bash
if [ $# -ne 2 ]; then
    echo "用法: $0 <输入文件> <输出文件>"
    exit 1
fi
input_file="$1"
output_file="$2"
if [ ! -f "$input_file" ]; then
    echo "错误: 输入文件 '$input_file' 不存在"
    exit 1
fi
cat "$input_file" | sed '1s/^\xEF\xBB\xBF//' | sed 's/;/,/g' | sed 's/\t/,/g' | sed 's/,,*/,/g' | awk -F',' '{if(NF>=4) print $0}' | sed '/^[[:space:]]*$/d' > "$output_file"
echo "标准化完成: $output_file"
exit 0
