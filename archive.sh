#!/bin/bash
raw_dir="${HYDRO_RAW_DIR:-/data/hydro/raw}"
archive_dir="${HYDRO_ARCHIVE_DIR:-$raw_dir}"
if [ ! -d "$raw_dir" ]; then
    echo "错误: 源目录 '$raw_dir' 不存在"
    exit 1
fi
mkdir -p "$archive_dir"
for file in "$raw_dir"/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        station=$(echo "$filename" | cut -d'_' -f1)
        date_part=$(echo "$filename" | cut -d'_' -f2 | cut -d'.' -f1)
        month=$(echo "$date_part" | cut -c1-6)
        archive_name="${station}_${month}.tar.gz"
        tar -czf "$archive_dir/$archive_name" -C "$raw_dir" "$filename" 2>/dev/null
    fi
done
echo "归档清单 ($(date))" >> "$archive_dir/archive_log.txt"
find "$archive_dir" -name "*.tar.gz" -type f | while read -r f; do
    echo "压缩包: $(basename "$f")" >> "$archive_dir/archive_log.txt"
done
old_files=$(find "$raw_dir" -name "*.csv" -type f -mtime +90 2>/dev/null)
if [ -n "$old_files" ]; then
    echo "找到以下旧文件:"
    echo "$old_files"
    read -p "是否删除这些文件? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "$old_files" | xargs rm -f
        echo "已删除旧文件。"
    else
        echo "已取消删除。"
    fi
else
    echo "没有找到90天前的旧文件。"
fi
exit 0
