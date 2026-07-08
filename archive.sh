#!/bin/bash

# ============================================
# archive.sh - 水文数据备份归档脚本
# 用法: ./archive.sh
# 功能: 按站号和月份打包CSV文件，清理90天前文件
# ============================================

SOURCE_DIR="/data/hydro/raw"
BACKUP_DIR="/data/hydro/backup"
LOG_FILE="$BACKUP_DIR/archive_log.txt"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源目录 $SOURCE_DIR 不存在"
    exit 1
fi

# 创建备份目录（如果不存在）
mkdir -p "$BACKUP_DIR"

echo "开始归档..."
echo "========================================="

# 按站点和月份分组归档
for file in "$SOURCE_DIR"/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        # 提取站点和日期（假设文件名格式为 站名_YYYYMMDD.csv）
        station=$(echo "$filename" | cut -d'_' -f1)
        date_part=$(echo "$filename" | cut -d'_' -f2 | cut -d'.' -f1)
        month=$(echo "$date_part" | cut -c1-6)
        
        # 创建归档目录
        archive_dir="$BACKUP_DIR/$station"
        mkdir -p "$archive_dir"
        
        # 移动文件到归档目录
        mv "$file" "$archive_dir/"
        echo "已归档: $filename -> $archive_dir/"
    fi
done

# 生成归档清单
echo "========================================="
echo "归档清单 ($(date))" >> "$LOG_FILE"
find "$BACKUP_DIR" -type f -name "*.csv" | while read -r f; do
    size=$(du -h "$f" | cut -f1)
    echo "文件: $(basename "$f"), 大小: $size, 位置: $f" >> "$LOG_FILE"
done
echo "归档清单已更新: $LOG_FILE"

# 清理90天前的文件（需要用户确认）
echo "========================================="
echo "查找90天前的旧文件..."
OLD_FILES=$(find "$BACKUP_DIR" -type f -name "*.csv" -mtime +90)
if [ -n "$OLD_FILES" ]; then
    echo "找到以下旧文件:"
    echo "$OLD_FILES"
    read -p "是否删除这些文件? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "$OLD_FILES" | xargs rm -f
        echo "已删除旧文件。"
    else
        echo "已取消删除。"
    fi
else
    echo "没有找到90天前的旧文件。"
fi

echo "========================================="
echo "归档完成！"
