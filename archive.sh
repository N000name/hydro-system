#!/bin/bash

# 按规范通过环境变量读取目录，禁止硬编码路径
raw_dir=${HYDRO_RAW_DIR:-/data/hydro/raw}
archive_dir=${HYDRO_ARCHIVE_DIR:-$raw_dir}

# 源目录不存在时安全退出并返回非0
if [ ! -d "$raw_dir" ]; then
    echo "错误：源目录 $raw_dir 不存在" >&2
    exit 1
fi

# 确保归档目录存在
mkdir -p "$archive_dir" || {
    echo "错误：无法创建归档目录 $archive_dir" >&2
    exit 1
}

log_file="$archive_dir/archive_log.txt"
archive_time=$(date "+%Y-%m-%d %H:%M:%S")

# ============== 1. 按月分组打包 ==============
declare -A file_groups

# 遍历源目录下所有 CSV 文件，按 站点编号_年月 分组
for csv_file in "$raw_dir"/*_*.csv; do
    [ -f "$csv_file" ] || continue
    filename=$(basename "$csv_file")
    
    # 拆分文件名：站点编号_日期.csv → 提取站点和年月
    site_id="${filename%%_*}"
    date_str="${filename#*_}"
    year_month="${date_str:0:6}"
    group_key="${site_id}_${year_month}"
    
    # 归入对应分组
    file_groups[$group_key]="${file_groups[$group_key]} $filename"
done

# 逐个生成 tar.gz 压缩包
for group in "${!file_groups[@]}"; do
    tar_name="${group}.tar.gz"
    tar_path="${archive_dir}/${tar_name}"
    
    # 进入源目录打包，保证压缩包内无路径前缀
    if tar -czf "$tar_path" -C "$raw_dir" ${file_groups[$group]}; then
        # 追加归档日志（包含压缩包名称，满足最低要求）
        echo "[$archive_time] $tar_name" >> "$log_file"
    else
        echo "错误：打包 $tar_name 失败" >&2
        exit 1
    fi
done

# ============== 2. 过期文件清理（交互确认） ==============
# 查找修改时间超过 90 天的 CSV 文件
expired_list=$(find "$raw_dir" -maxdepth 1 -type f -name "*.csv" -mtime +90 2>/dev/null)

if [ -n "$expired_list" ]; then
    echo "以下文件修改时间超过90天："
    echo "$expired_list"
    read -p "确认删除？(输入y删除，其他跳过): " user_confirm

    if [ "$user_confirm" = "y" ]; then
        echo "$expired_list" | xargs rm -f
        echo "[$archive_time] 已删除过期CSV文件" >> "$log_file"
    fi
fi

exit 0

