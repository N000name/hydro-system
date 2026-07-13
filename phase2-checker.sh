#!/bin/bash
# -*- coding: utf-8 -*-
# 水文观测数据 Shell 作业自动检查器
# 不依赖 Python/JDK，仅需 Bash + 标准 Unix 工具（awk、sed、date、tar、crontab 等）
# 用法：
#   bash phase2_checker.sh [--student-dir DIR] [--task all|1|2|3|4|5]

set -u

STUDENT_DIR="."
TASK_ARG="all"

# ---------- 命令行参数解析 ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --student-dir)
            STUDENT_DIR="$2"
            shift 2
            ;;
        --task)
            TASK_ARG="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: bash phase2_checker.sh [--student-dir DIR] [--task all|1|2|3|4|5]"
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

# ---------- 颜色与日志 ----------
C_OK="\033[92m"
C_FAIL="\033[91m"
C_INFO="\033[94m"
C_WARN="\033[93m"
C_RST="\033[0m"

log_ok()  { echo -e "${C_OK}[PASS]${C_RST} $*"; }
log_fail(){ echo -e "${C_FAIL}[FAIL]${C_RST} $*"; }
log_info(){ echo -e "${C_INFO}[INFO]${C_RST} $*"; }
log_warn(){ echo -e "${C_WARN}[WARN]${C_RST} $*"; }

# ---------- 临时目录 ----------
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hydro_check_XXXXXX")
export WORK_DIR
STDOUT="$WORK_DIR/stdout.txt"
STDERR="$WORK_DIR/stderr.txt"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# ---------- 分数簿（使用索引数组，兼容 Bash 3.2+） ----------
SCORES=(0 0 0 0 0 0)
TOTALS=(0 0 0 0 0 0)

add_score() {
    local task="$1"
    local passed="$2"
    local total="$3"
    SCORES[$task]=$(( ${SCORES[$task]} + passed ))
    TOTALS[$task]=$(( ${TOTALS[$task]} + total ))
}

print_task_score() {
    local task="$1"
    local name="$2"
    local passed=${SCORES[$task]:-0}
    local total=${TOTALS[$task]:-0}
    local score
    score=$(awk -v p="$passed" -v t="$total" 'BEGIN { if(t==0) print 0; else printf "%.1f", p*5.0/t }')
    echo ""
    echo "--------------------------------------------------"
    if [[ "$passed" -eq "$total" ]]; then
        echo -e "${C_OK}[PASS]${C_RST} $name 得分: $score / 5.0"
    else
        echo -e "${C_FAIL}[FAIL]${C_RST} $name 得分: $score / 5.0 (${passed}/${total} 检查点通过)"
    fi
    echo "--------------------------------------------------"
}

# ---------- 通用运行辅助 ----------
run_script() {
    local script="$1"
    shift
    bash "$script" "$@" > "$STDOUT" 2> "$STDERR"
    echo $? > "$WORK_DIR/exitcode.txt"
}

get_exitcode() {
    cat "$WORK_DIR/exitcode.txt"
}

has_bom() {
    local file="$1"
    [[ $(head -c 3 "$file") == $'\xef\xbb\xbf' ]]
}

# ============================================================
# 任务1 normalize.sh
# ============================================================
check_task1() {
    local task=1
    local name="任务1 normalize.sh"
    log_info "正在检查 $name"
    local script="$STUDENT_DIR/normalize.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 $script"
        TOTALS[$task]=5
        return
    fi

    local input="$WORK_DIR/task1_input.txt"
    local output="$WORK_DIR/task1_output.csv"

    # 构造含 BOM、分号、制表符、多种时间格式、末尾空行的输入
    {
        printf '\xEF\xBB\xBF'
        echo "观测时间;站点编号;水位(m);降雨量(mm)"
        echo "2020/01/02 08:00:00;80101000;12.34;0.0"
        printf '2020-01-02 08:30:00\t80101000\t12.45\t1.2\n'
        echo "02/01/2020 09:00:00,80101000,12.56,2.5"
        echo "2020/01/02 09:30:00;80101000;12.67;0.0"
        echo ""
        echo ""
    } > "$input"

    run_script "$script" "$input" "$output"
    if [[ $(get_exitcode) -ne 0 ]]; then
        log_fail "normalize.sh 返回非零退出码"
        cat "$STDERR" >&2
        TOTALS[$task]=5
        return
    fi

    if [[ ! -f "$output" ]]; then
        log_fail "未生成输出文件"
        TOTALS[$task]=5
        return
    fi

    # 1. 无 BOM
    if has_bom "$output"; then
        log_fail "输出文件仍包含 UTF-8 BOM"
    else
        log_ok "已去除 BOM"
        add_score $task 1 1
    fi

    # 2. 分隔符统一为逗号
    if grep -qE $'[;\t]' "$output"; then
        log_fail "输出文件仍包含分号或制表符"
    else
        log_ok "分隔符已统一为逗号"
        add_score $task 1 1
    fi

    # 3. 时间格式统一
    local bad_dates
    bad_dates=$(awk -F, 'NR>1 {
        if ($1 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/) {
            print NR
            exit 1
        }
    }' "$output")
    if [[ -z "$bad_dates" ]]; then
        log_ok "时间格式已统一"
        add_score $task 1 1
    else
        log_fail "第 $bad_dates 行时间格式未统一"
    fi

    # 4. 无末尾空行
    local last_bytes
    last_bytes=$(tail -c 2 "$output" | od -An -tx1 | tr -d ' \n')
    if [[ "$last_bytes" == "0a0a" ]]; then
        log_fail "输出文件末尾仍存在多余空行"
    else
        log_ok "已去除末尾空行"
        add_score $task 1 1
    fi

    # 5. 数据行数正确（含表头 5 行）
    local lines
    lines=$(grep -c '[^[:space:]]' "$output" || true)
    if [[ "$lines" -eq 5 ]]; then
        log_ok "数据行数正确"
        add_score $task 1 1
    else
        log_fail "数据行数错误，期望 5，实际 $lines"
    fi
}

# ============================================================
# 任务2 qc_check.sh
# ============================================================
check_task2() {
    local task=2
    local name="任务2 qc_check.sh"
    log_info "正在检查 $name"
    local script="$STUDENT_DIR/qc_check.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 $script"
        TOTALS[$task]=10
        return
    fi

    local input="$WORK_DIR/task2_input.csv"
    local output="$WORK_DIR/task2_output.txt"

    {
        echo "站点编号,观测时间,水位(m),降雨量(mm)"
        echo "80101000,2020-01-01 08:00:00,12.00,0.0"
        echo "80101000,2020-01-01 08:30:00,16.50,0.0"
        echo "80101000,2020-01-01 09:00:00,16.40,-2.5"
        echo "80101000,2020-01-01 09:30:00,16.30,0.0"
        echo "80101000,2020-01-01 10:00:00,16.20,0.0"
        echo "80101000,2020-01-01 10:00:00,16.10,0.0"
        echo "80101000,2020-01-01 10:30:00,16.00,0.0"
        echo "80101000,2020-01-01 10:00:00,15.90,0.0"
        echo "80101000,2020-01-01 11:00:00,15.80,0.0"
    } > "$input"

    run_script "$script" "$input" "$output"
    if [[ $(get_exitcode) -ne 0 ]]; then
        log_fail "qc_check.sh 返回非零退出码"
        cat "$STDERR" >&2
        TOTALS[$task]=10
        return
    fi

    if [[ ! -s "$output" ]]; then
        log_fail "未生成报告文件 $output（qc_check.sh 必须将报告写入第二个参数指定的文件）"
        TOTALS[$task]=10
        return
    fi

    local report
    report=$(cat "$output")

    # 期望
    local exp_total=9
    local exp_jump=1 exp_jump_line=3
    local exp_neg=1  exp_neg_line=4
    local exp_dup=1  exp_dup_line=7
    local exp_dis=1  exp_dis_line=9
    local exp_distinct=4
    local exp_rate=44.44

    # 1. 总记录数
    local got_total
    got_total=$(echo "$report" | awk -F'[:：]' '/总记录数/ {gsub(/[^0-9]/,"",$2); print $2; exit}')
    if [[ "$got_total" == "$exp_total" ]]; then
        log_ok "总记录数正确: $got_total"
        add_score $task 1 1
    else
        log_fail "总记录数错误，期望 $exp_total，实际 ${got_total:-未识别}"
    fi

    # 辅助：提取某类异常数量
    extract_count() {
        local label="$1"
        echo "$report" | awk -v label="$label" -F'[:：]' '
        $0 ~ label { gsub(/[^0-9]/,"",$2); print $2; exit }
        '
    }

    # 辅助：提取明细行号
    extract_lines() {
        local label="$1"
        echo "$report" | awk -v label="$label" -F',' '
        /^[0-9]+/ && $2 ~ label { print $1 }
        '
    }

    check_type() {
        local label="$1"
        local exp_count="$2"
        local exp_line="$3"
        local got_count got_line
        got_count=$(extract_count "$label")
        got_line=$(extract_lines "$label" | head -n1)
        if [[ "$got_count" == "$exp_count" && "$got_line" == "$exp_line" ]]; then
            log_ok "${label} 正确: 数量=$got_count, 行号=$got_line"
            add_score $task 2 2
        else
            log_fail "${label} 错误，期望 数量=$exp_count 行号=$exp_line，实际 数量=${got_count:-未识别} 行号=${got_line:-未识别}"
        fi
    }

    check_type "水位突变异常" "$exp_jump" "$exp_jump_line"
    check_type "降雨量异常"  "$exp_neg"  "$exp_neg_line"
    check_type "时间戳重复"  "$exp_dup"  "$exp_dup_line"
    check_type "时间戳乱序"  "$exp_dis"  "$exp_dis_line"

    # 6. 异常记录总数
    local got_distinct
    got_distinct=$(echo "$report" | awk -F'[:：]' '/异常记录总数/ {gsub(/[^0-9]/,"",$2); print $2; exit}')
    if [[ "$got_distinct" == "$exp_distinct" ]]; then
        log_ok "异常记录总数正确: $got_distinct"
        add_score $task 1 1
    else
        log_fail "异常记录总数错误，期望 $exp_distinct，实际 ${got_distinct:-未识别}"
    fi

    # 7. 异常率
    local got_rate
    got_rate=$(echo "$report" | awk -F'[:：%]' '/异常率/ { gsub(/[^0-9.]/,"",$2); print $2; exit }')
    if [[ -n "$got_rate" ]]; then
        local diff
        diff=$(awk -v a="$got_rate" -v b="$exp_rate" 'BEGIN { d=a-b; if(d<0) d=-d; print d }')
        if awk -v d="$diff" 'BEGIN { exit (d<=0.01) ? 0 : 1 }'; then
            log_ok "异常率正确: ${got_rate}%"
            add_score $task 1 1
        else
            log_fail "异常率错误，期望 ${exp_rate}%，实际 ${got_rate}%"
        fi
    else
        log_fail "未识别异常率"
    fi
}

# ============================================================
# 任务3 daily_report.sh
# ============================================================
check_task3() {
    local task=3
    local name="任务3 daily_report.sh"
    log_info "正在检查 $name"
    local script="$STUDENT_DIR/daily_report.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 $script"
        TOTALS[$task]=21
        return
    fi

    local input="$WORK_DIR/task3_input.csv"
    local output="$WORK_DIR/task3_output.csv"
    local expected="$WORK_DIR/task3_expected.csv"

    # 生成测试数据：第一天24条，第二天20条，第二站点24条
    {
        echo "站点编号,观测时间,水位(m),降雨量(mm)"
        for i in $(seq 0 23); do
            local wl rain hh
            hh=$(printf "%02d" "$i")
            wl=$(awk -v i="$i" 'BEGIN { printf "%.2f", 10.0 + 0.1*i + (i==12 ? 2.0 : 0.0) }')
            rain="0.0"
            [[ "$i" == "3" || "$i" == "7" || "$i" == "15" ]] && rain="0.5"
            echo "80101000,2020-01-01 $hh:00:00,$wl,$rain"
        done
        for i in $(seq 0 19); do
            local hh
            hh=$(printf "%02d" "$i")
            wl=$(awk -v i="$i" 'BEGIN { printf "%.2f", 11.0 + 0.05*i }')
            rain="0.0"
            [[ "$i" == "5" ]] && rain="1.0"
            echo "80101000,2020-01-02 $hh:00:00,$wl,$rain"
        done
        for i in $(seq 0 23); do
            local hh
            hh=$(printf "%02d" "$i")
            wl=$(awk -v i="$i" 'BEGIN { printf "%.2f", 9.0 + 0.2*i }')
            echo "80201000,2020-01-01 $hh:00:00,$wl,0.0"
        done
    } > "$input"

    # 生成期望日报（不含表头，按站点、日期排序）
    awk -F, 'NR>1 {
        station=$1; ts=$2; wl=$3+0; rain=$4+0
        split(ts, a, " "); date=a[1]
        key=station SUBSEP date
        cnt[key]++; sumwl[key]+=wl; sumrain[key]+=rain
        if (wl>maxwl[key]) { maxwl[key]=wl; maxt[key]=ts }
        if (!(key in minwl) || wl<minwl[key]) { minwl[key]=wl; mint[key]=ts }
    }
    END {
        for (key in cnt) {
            split(key, a, SUBSEP); station=a[1]; date=a[2]
            avg=sumwl[key]/cnt[key]
            comp=cnt[key]*100.0/24
            printf "%s,%s,%.2f,%.2f,%s,%.2f,%s,%.2f,%.1f\n", station, date, avg, maxwl[key], maxt[key], minwl[key], mint[key], sumrain[key], comp
        }
    }' "$input" | sort -t, -k1,1 -k2,2 > "$expected"

    run_script "$script" "$input" "$output"
    if [[ $(get_exitcode) -ne 0 ]]; then
        log_fail "daily_report.sh 返回非零退出码"
        cat "$STDERR" >&2
        TOTALS[$task]=21
        return
    fi

    if [[ ! -s "$output" ]]; then
        log_fail "未生成日报文件 $output（daily_report.sh 必须将日报写入第二个参数指定的文件）"
        TOTALS[$task]=3
        return
    fi

    # 统一排序后逐行比较（允许数值误差）
    local actual_sorted="$WORK_DIR/task3_actual_sorted.csv"
    tail -n +2 "$output" 2>/dev/null | sort -t, -k1,1 -k2,2 > "$actual_sorted"

    local n_expected n_actual
    n_expected=$(wc -l < "$expected" | tr -d ' ')
    n_actual=$(wc -l < "$actual_sorted" | tr -d ' ')
    if [[ "$n_expected" -ne "$n_actual" ]]; then
        log_fail "日报行数错误，期望 $n_expected，实际 $n_actual"
        TOTALS[$task]=$n_expected
        return
    fi

    # 逐字段比较
    local passed=0
    while IFS=, read -r es ed eavg emax emaxt emin emint erain ecomp \
          && IFS=, read -r as ad aavg amax amaxt amin amint arain acomp <&3; do
        local ok=1
        if [[ "$es" != "$as" || "$ed" != "$ad" ]]; then
            ok=0
        fi
        if ! awk -v a="$aavg" -v b="$eavg" 'BEGIN { exit (a-b>=-0.01 && a-b<=0.01) ? 0 : 1 }'; then ok=0; fi
        if ! awk -v a="$amax" -v b="$emax" 'BEGIN { exit (a-b>=-0.01 && a-b<=0.01) ? 0 : 1 }'; then ok=0; fi
        if [[ "$amaxt" != "$emaxt" ]]; then ok=0; fi
        if ! awk -v a="$amin" -v b="$emin" 'BEGIN { exit (a-b>=-0.01 && a-b<=0.01) ? 0 : 1 }'; then ok=0; fi
        if [[ "$amint" != "$emint" ]]; then ok=0; fi
        if ! awk -v a="$arain" -v b="$erain" 'BEGIN { exit (a-b>=-0.01 && a-b<=0.01) ? 0 : 1 }'; then ok=0; fi
        if ! awk -v a="$acomp" -v b="$ecomp" 'BEGIN { exit (a-b>=-0.1 && a-b<=0.1) ? 0 : 1 }'; then ok=0; fi
        if [[ "$ok" -eq 1 ]]; then
            passed=$((passed+1))
        else
            log_fail "日报 $es $ed 不匹配"
        fi
    done < "$expected" 3< "$actual_sorted"

    TOTALS[$task]=$n_expected
    SCORES[$task]=$passed
    if [[ "$passed" -eq "$n_expected" ]]; then
        log_ok "所有日报行指标正确"
    fi
}

# ============================================================
# 任务4 archive.sh
# ============================================================
check_task4() {
    local task=4
    local name="任务4 archive.sh"
    log_info "正在检查 $name"
    local script="$STUDENT_DIR/archive.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 $script"
        TOTALS[$task]=5
        return
    fi

    local raw_dir="$WORK_DIR/hydro_raw"
    local archive_dir="$WORK_DIR/hydro_archive"
    mkdir -p "$raw_dir" "$archive_dir"

    echo "2020-01-01 content" > "$raw_dir/80101000_20200101.csv"
    echo "2020-01-02 content" > "$raw_dir/80101000_20200102.csv"
    echo "2020-02-01 content" > "$raw_dir/80101000_20200201.csv"
    echo "80201000 content"   > "$raw_dir/80201000_20200115.csv"

    # 第一次归档，对旧文件回答 n
    HYDRO_RAW_DIR="$raw_dir" HYDRO_ARCHIVE_DIR="$archive_dir" \
        run_script "$script" < <(printf 'n\n')

    if [[ $(get_exitcode) -ne 0 ]]; then
        log_fail "archive.sh 返回非零退出码"
        cat "$STDERR" >&2
        TOTALS[$task]=5
        return
    fi

    # 1. 检查 80101000_202001.tar.gz
    if [[ -f "$archive_dir/80101000_202001.tar.gz" ]]; then
        local members
        members=$(tar -tzf "$archive_dir/80101000_202001.tar.gz" | sort | tr '\n' ' ')
        if [[ "$members" == "80101000_20200101.csv 80101000_20200102.csv " ]]; then
            log_ok "202001 归档正确"
            add_score $task 1 1
        else
            log_fail "202001 归档内容错误: $members"
        fi
    else
        log_fail "未找到 80101000_202001.tar.gz"
    fi

    # 2. 检查 80101000_202002.tar.gz
    if [[ -f "$archive_dir/80101000_202002.tar.gz" ]]; then
        local members
        members=$(tar -tzf "$archive_dir/80101000_202002.tar.gz")
        if [[ "$members" == "80101000_20200201.csv" ]]; then
            log_ok "202002 归档正确"
            add_score $task 1 1
        else
            log_fail "202002 归档内容错误: $members"
        fi
    else
        log_fail "未找到 80101000_202002.tar.gz"
    fi

    # 3. 检查 80201000_202001.tar.gz
    if [[ -f "$archive_dir/80201000_202001.tar.gz" ]]; then
        local members
        members=$(tar -tzf "$archive_dir/80201000_202001.tar.gz")
        if [[ "$members" == "80201000_20200115.csv" ]]; then
            log_ok "80201000 归档正确"
            add_score $task 1 1
        else
            log_fail "80201000 归档内容错误: $members"
        fi
    else
        log_fail "未找到 80201000_202001.tar.gz"
    fi

    # 4. 检查归档清单
    if [[ -f "$archive_dir/archive_log.txt" ]] && grep -q "80101000_202001.tar.gz" "$archive_dir/archive_log.txt"; then
        log_ok "归档清单记录正确"
        add_score $task 1 1
    else
        log_fail "归档清单缺失或内容错误"
    fi

    # 5. 旧文件清理交互测试
    local old_file="$raw_dir/old_20200101.csv"
    echo "old" > "$old_file"
    touch -t 202001010000 "$old_file"
    HYDRO_RAW_DIR="$raw_dir" HYDRO_ARCHIVE_DIR="$archive_dir" \
        run_script "$script" < <(printf 'y\n')
    if [[ ! -f "$old_file" ]]; then
        log_ok "旧文件清理交互正确"
        add_score $task 1 1
    else
        log_fail "确认删除后旧文件仍存在"
    fi
}

# ============================================================
# 任务5 进程管理与定时任务
# ============================================================
check_task5() {
    local task=5
    local name="任务5 进程管理与定时任务"
    log_info "正在检查 $name"
    local script="$STUDENT_DIR/data_collector.sh"
    if [[ ! -f "$script" ]]; then
        log_fail "未找到 $script"
        TOTALS[$task]=5
        return
    fi

    local log_file="$STUDENT_DIR/collector.log"
    rm -f "$log_file"

    # 后台启动，脱离终端（在学生目录下运行，以便找到 collector.log）
    pushd "$STUDENT_DIR" >/dev/null
    nohup bash "$script" > "$WORK_DIR/collector.out" 2>&1 &
    local pid=$!
    popd >/dev/null

    sleep 4

    local still_running=0
    if kill -0 "$pid" 2>/dev/null; then
        still_running=1
    fi

    if [[ "$still_running" -eq 1 ]]; then
        log_ok "采集脚本已在后台持续运行"
        add_score $task 1 1
    else
        log_fail "采集脚本启动后很快退出"
    fi

    if [[ -s "$log_file" ]]; then
        local lines
        lines=$(grep -c '[^[:space:]]' "$log_file" || true)
        if [[ "$lines" -ge 1 ]]; then
            log_ok "collector.log 已写入数据"
            add_score $task 1 1
        else
            log_fail "collector.log 为空"
        fi
    else
        log_fail "未生成 collector.log"
    fi

    # 先 SIGTERM
    if kill -TERM "$pid" 2>/dev/null; then
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
            log_warn "SIGTERM 未终止，已使用 SIGKILL"
        else
            log_ok "SIGTERM 成功终止进程"
        fi
        add_score $task 1 1
    else
        log_fail "无法发送终止信号"
    fi

    # 检查 cron 中是否配置了 archive.sh 2:00
    local cron_out
    cron_out=$(crontab -l 2>/dev/null || true)
    local cron_ok=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue
        if [[ "$line" == *"archive.sh"* && "$line" == *"2"* ]]; then
            cron_ok=1
            break
        fi
    done <<< "$cron_out"

    if [[ "$cron_ok" -eq 1 ]]; then
        log_ok "检测到 archive.sh 定时任务"
        add_score $task 1 1
    else
        log_warn "未检测到 archive.sh 每天 2:00 的 cron 任务（请确认已配置）"
        add_score $task 0 1
    fi

    # nice 值检查：仅检查脚本中是否包含 nice 相关命令（演示性质）
    if grep -q "nice" "$script"; then
        log_ok "脚本中使用了 nice 调整优先级"
        add_score $task 1 1
    else
        log_warn "未在 data_collector.sh 中发现 nice 命令（如已手动调整可忽略）"
        add_score $task 0 1
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo "=================================================="
    echo "水文观测数据 Shell 作业自动检查器"
    echo "学生脚本目录: $STUDENT_DIR"
    echo "=================================================="
    echo ""

    local tasks
    if [[ "$TASK_ARG" == "all" ]]; then
        tasks="1 2 3 4 5"
    else
        tasks=${TASK_ARG//,/ }
    fi

    for t in $tasks; do
        case "$t" in
            1) check_task1 ;;
            2) check_task2 ;;
            3) check_task3 ;;
            4) check_task4 ;;
            5) check_task5 ;;
            *) log_warn "未知任务编号 $t" ;;
        esac
    done

    echo ""
    echo "=================================================="
    echo "                     成绩报告"
    echo "=================================================="
    local total_score=0
    for t in $tasks; do
        local task_name
        case "$t" in
            1) task_name="任务1 normalize.sh" ;;
            2) task_name="任务2 qc_check.sh" ;;
            3) task_name="任务3 daily_report.sh" ;;
            4) task_name="任务4 archive.sh" ;;
            5) task_name="任务5 进程与定时任务" ;;
            *) continue ;;
        esac
        print_task_score "$t" "$task_name"
        total_score=$(awk -v s="$total_score" -v p="${SCORES[$t]:-0}" -v tot="${TOTALS[$t]:-0}" 'BEGIN { if(tot==0) print s; else print s + p*5.0/tot }')
    done
    echo "=================================================="
    echo -e "${C_INFO}总成绩: $total_score / $(echo "$tasks" | wc -w | tr -d ' ')0.0${C_RST}"
    echo "=================================================="
}

main
