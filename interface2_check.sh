#!/bin/bash
# -*- coding: utf-8 -*-
# 学生脚本接口预检查器
# 仅检查 5 个任务的脚本名、调用方式、参数接收、输出文件/环境变量等接口是否符合规范。
# 不做功能正确性检查，不打分。
# 用法：bash interface2_check.sh [--student-dir DIR]

set -u

STUDENT_DIR="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --student-dir)
            STUDENT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: bash interface2_check.sh [--student-dir DIR]"
            exit 0
            ;;
        *)
            echo "未知参数: $1" >&2
            exit 1
            ;;
    esac
done

STUDENT_DIR=$(cd "$STUDENT_DIR" && pwd) || {
    echo "错误：无法进入学生目录 $STUDENT_DIR" >&2
    exit 1
}

C_OK="\033[92m"
C_FAIL="\033[91m"
C_INFO="\033[94m"
C_RST="\033[0m"

log_ok()  { echo -e "${C_OK}[接口通过]${C_RST} $*"; }
log_fail(){ echo -e "${C_FAIL}[接口未通过]${C_RST} $*"; }
log_info(){ echo -e "${C_INFO}[检查]${C_RST} $*"; }

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hydro_iface_XXXXXX")
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

pass_count=0
fail_count=0

record_pass() { pass_count=$((pass_count + 1)); }
record_fail() { fail_count=$((fail_count + 1)); }

# ============================================================
# 任务1 normalize.sh
# ============================================================
check_task1_iface() {
    local script="$STUDENT_DIR/normalize.sh"
    log_info "任务1 normalize.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 normalize.sh"
        record_fail
        return
    fi

    local input="$WORK_DIR/t1_input.txt"
    local output="$WORK_DIR/t1_output.csv"
    {
        printf '\xEF\xBB\xBF'
        echo "观测时间;站点编号;水位(m);降雨量(mm)"
        echo "2020/01/02 08:00:00;80101000;12.34;0.0"
        printf '2020-01-02 08:30:00\t80101000\t12.45\t1.2\n'
        echo "02/01/2020 09:00:00,80101000,12.56,2.5"
        echo ""
    } > "$input"

    if ! bash "$script" "$input" "$output" >"$WORK_DIR/t1.out" 2>"$WORK_DIR/t1.err"; then
        log_fail "normalize.sh 执行失败或返回非零"
        record_fail
        return
    fi

    if [[ ! -f "$output" ]]; then
        log_fail "normalize.sh 未将结果写入第二个参数指定的输出文件"
        record_fail
        return
    fi

    log_ok "normalize.sh 接口正确：接收两个参数并生成输出文件"
    record_pass
}

# ============================================================
# 任务2 qc_check.sh
# ============================================================
check_task2_iface() {
    local script="$STUDENT_DIR/qc_check.sh"
    log_info "任务2 qc_check.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 qc_check.sh"
        record_fail
        return
    fi

    local input="$WORK_DIR/t2_input.csv"
    local output="$WORK_DIR/t2_output.txt"
    {
        echo "站点编号,观测时间,水位(m),降雨量(mm)"
        echo "80101000,2020-01-01 08:00:00,12.00,0.0"
        echo "80101000,2020-01-01 08:30:00,16.50,0.0"
        echo "80101000,2020-01-01 09:00:00,16.40,-2.5"
    } > "$input"

    if ! bash "$script" "$input" "$output" >"$WORK_DIR/t2.out" 2>"$WORK_DIR/t2.err"; then
        log_fail "qc_check.sh 执行失败或返回非零"
        record_fail
        return
    fi

    if [[ ! -s "$output" ]]; then
        log_fail "qc_check.sh 未将报告写入第二个参数指定的输出文件"
        record_fail
        return
    fi

    log_ok "qc_check.sh 接口正确：接收两个参数并生成报告文件"
    record_pass
}

# ============================================================
# 任务3 daily_report.sh
# ============================================================
check_task3_iface() {
    local script="$STUDENT_DIR/daily_report.sh"
    log_info "任务3 daily_report.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 daily_report.sh"
        record_fail
        return
    fi

    local input="$WORK_DIR/t3_input.csv"
    local output="$WORK_DIR/t3_output.csv"
    {
        echo "站点编号,观测时间,水位(m),降雨量(mm)"
        echo "80101000,2020-01-01 08:00:00,12.00,0.0"
        echo "80101000,2020-01-01 09:00:00,12.50,1.0"
        echo "80201000,2020-01-01 08:00:00,9.00,0.0"
    } > "$input"

    if ! bash "$script" "$input" "$output" >"$WORK_DIR/t3.out" 2>"$WORK_DIR/t3.err"; then
        log_fail "daily_report.sh 执行失败或返回非零"
        record_fail
        return
    fi

    if [[ ! -s "$output" ]]; then
        log_fail "daily_report.sh 未将日报写入第二个参数指定的输出文件"
        record_fail
        return
    fi

    log_ok "daily_report.sh 接口正确：接收两个参数并生成日报文件"
    record_pass
}

# ============================================================
# 任务4 archive.sh
# ============================================================
check_task4_iface() {
    local script="$STUDENT_DIR/archive.sh"
    log_info "任务4 archive.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 archive.sh"
        record_fail
        return
    fi

    # 检查是否通过环境变量读取路径
    if ! grep -q "HYDRO_RAW_DIR" "$script" || ! grep -q "HYDRO_ARCHIVE_DIR" "$script"; then
        log_fail "archive.sh 未使用 HYDRO_RAW_DIR / HYDRO_ARCHIVE_DIR 环境变量"
        record_fail
        return
    fi

    local raw_dir="$WORK_DIR/hydro_raw"
    local archive_dir="$WORK_DIR/hydro_archive"
    mkdir -p "$raw_dir" "$archive_dir"
    echo "content" > "$raw_dir/80101000_20200101.csv"

    if ! HYDRO_RAW_DIR="$raw_dir" HYDRO_ARCHIVE_DIR="$archive_dir" \
        bash "$script" < <(printf 'n\n') >"$WORK_DIR/t4.out" 2>"$WORK_DIR/t4.err"; then
        log_fail "archive.sh 执行失败或返回非零"
        record_fail
        return
    fi

    if ! ls "$archive_dir"/*.tar.gz >/dev/null 2>&1; then
        log_fail "archive.sh 未在归档目录生成 tar.gz 文件"
        record_fail
        return
    fi

    log_ok "archive.sh 接口正确：读取环境变量并生成归档包"
    record_pass
}

# ============================================================
# 任务5 data_collector.sh + cron
# ============================================================
check_task5_iface() {
    local script="$STUDENT_DIR/data_collector.sh"
    log_info "任务5 data_collector.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 data_collector.sh"
        record_fail
        return
    fi

    # 检查脚本中是否引用 collector.log
    if ! grep -q "collector.log" "$script"; then
        log_fail "data_collector.sh 未写入 collector.log"
        record_fail
        return
    fi

    local log_file="$STUDENT_DIR/collector.log"
    rm -f "$log_file"

    pushd "$STUDENT_DIR" >/dev/null
    nohup bash "$script" >"$WORK_DIR/t5.out" 2>&1 &
    local pid=$!
    popd >/dev/null

    sleep 3

    if ! kill -0 "$pid" 2>/dev/null; then
        log_fail "data_collector.sh 启动后很快退出，未能后台持续运行"
        record_fail
    elif [[ ! -s "$log_file" ]]; then
        log_fail "data_collector.sh 未在当前目录生成 collector.log"
        record_fail
    else
        log_ok "data_collector.sh 接口正确：后台运行并写入 collector.log"
        record_pass
    fi

    kill -TERM "$pid" 2>/dev/null
    sleep 1
    kill -KILL "$pid" 2>/dev/null

    # 检查 cron 接口
    local cron_out
    cron_out=$(crontab -l 2>/dev/null || true)
    local cron_ok=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" == *"archive.sh"* && "$line" == *"2"* ]]; then
            cron_ok=1
            break
        fi
    done <<< "$cron_out"

    if [[ "$cron_ok" -eq 1 ]]; then
        log_ok "cron 接口正确：已配置 archive.sh 定时任务"
        record_pass
    else
        log_fail "cron 接口未通过：未检测到含 archive.sh 的 2:00 定时任务"
        record_fail
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo "=================================================="
    echo "学生脚本接口预检查器"
    echo "学生脚本目录: $STUDENT_DIR"
    echo "=================================================="
    echo ""

    check_task1_iface
    echo ""
    check_task2_iface
    echo ""
    check_task3_iface
    echo ""
    check_task4_iface
    echo ""
    check_task5_iface

    echo ""
    echo "=================================================="
    echo "接口检查汇总：通过 $pass_count 项，未通过 $fail_count 项"
    echo "=================================================="

    [[ "$fail_count" -eq 0 ]]
}

main
