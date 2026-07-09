#!/bin/bash

# ========== 配置项 ==========
SOURCE_DIR="/data/hydro/raw"       # 源数据目录
LOG_FILE="${SOURCE_DIR}/archive_log.txt"  # 归档日志路径
RETENTION_DAYS=90                  # 文件保留天数

# ========== 前置错误检查 ==========
# 1. 源目录不存在则安全退出
if [ ! -d "$SOURCE_DIR" ]; then
    echo "[错误] 源目录 $SOURCE_DIR 不存在，脚本终止。"
    exit 1
fi

# 2. 无CSV文件则安全退出
csv_files=$(find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.csv" 2>/dev/null)
if [ -z "$csv_files" ]; then
    echo "[提示] 源目录下无CSV文件，无需归档。"
    exit 0
fi

# 3. 磁盘空间不足则安全退出
total_size_kb=$(du -sk "$SOURCE_DIR"/*.csv | awk '{sum+=$1} END {print sum}')
available_kb=$(df "$SOURCE_DIR" | awk 'NR==2 {print $4}')
if [ "$available_kb" -lt "$total_size_kb" ]; then
    echo "[错误] 磁盘空间不足，无法归档。可用:${available_kb}KB，需求:${total_size_kb}KB"
    exit 1
fi

# ========== 按站点+月份归档 ==========
echo "开始CSV文件归档..."

# 提取所有「站点_年月」分组并去重
archive_groups=$(
    for file in "$SOURCE_DIR"/*.csv; do
        filename=$(basename "$file")
        station="${filename%%_*}"          # 提取站点编号
        date_str="${filename#*_}"
        date_str="${date_str%.csv}"        # 提取日期部分
        year_month="${date_str:0:6}"       # 截取年月(YYYYMM)
        echo "${station}_${year_month}"
    done | sort -u
)

# 按分组逐个打包
for group in $archive_groups; do
    archive_name="${group}.tar.gz"
    archive_path="${SOURCE_DIR}/${archive_name}"
    match_files="${SOURCE_DIR}/${group}*.csv"
    
    file_count=$(ls -1 $match_files 2>/dev/null | wc -l)
    [ "$file_count" -eq 0 ] && continue

    # 执行压缩，失败则退出
    tar -czf "$archive_path" -C "$SOURCE_DIR" $(basename -a $match_files)
    if [ $? -ne 0 ]; then
        echo "[错误] 归档 $archive_name 失败，脚本终止。"
        exit 1
    fi

    # 写入归档日志
    archive_size=$(du -h "$archive_path" | cut -f1)
    log_time=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$log_time] 压缩包：$archive_name | 文件数量：$file_count | 大小：$archive_size" >> "$LOG_FILE"
    
    echo "完成归档：$archive_name（含 $file_count 个文件）"
done

# ========== 过期文件清理（强制用户确认） ==========
echo ""
echo "=== 过期文件清理 ==="
old_files=$(find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.csv" -mtime +$RETENTION_DAYS)

if [ -z "$old_files" ]; then
    echo "未找到超过 ${RETENTION_DAYS} 天的文件，无需清理。"
else
    echo "找到以下过期CSV文件："
    echo "$old_files"
    echo ""
    read -p "确认删除？输入 y 删除 / n 取消：" user_confirm

    case "$user_confirm" in
        y|Y)
            echo "$old_files" | xargs rm -f
            echo "已删除所有过期文件。"
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 清理过期文件：共 $(echo "$old_files" | wc -l) 个" >> "$LOG_FILE"
            ;;
        n|N|*)
            echo "已取消删除，文件保留。"
            ;;
    esac
fi

echo ""
echo "归档任务执行完成。"
exit 0

