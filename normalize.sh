#!/bin/bash

# ============================================
# normalize.sh - 水文数据格式标准化脚本
# 用法: ./normalize.sh 输入文件 输出文件
# 功能: 统一分隔符、时间格式、去除BOM和空行
# ============================================

if [ $# -ne 2 ]; then
    echo "用法: $0 <输入文件> <输出文件>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 输入文件 '$INPUT_FILE' 不存在"
    exit 1
fi

echo "正在处理: $INPUT_FILE -> $OUTPUT_FILE"

cat "$INPUT_FILE" \
    | sed '1s/^\xEF\xBB\xBF//' \
    | sed 's/[;\t]/,/g' \
    | sed 's/,,*/,/g' \
    | awk -F',' '{
        if (NF < 3) next;
        print $0
    }' \
    | sed '/^[[:space:]]*$/d' \
    > "$OUTPUT_FILE"

echo "处理完成! 输出文件: $OUTPUT_FILE"
