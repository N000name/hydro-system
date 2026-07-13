#!/bin/bash
# -*- coding: utf-8 -*-
# 水文观测数据 Shell 作业 - 节点三自动检查器
# 检查 3.1 systemd/Nginx、3.2 磁盘管理、3.3 防火墙/SSH/fail2ban
# 每个任务满分 5 分，按检查点通过比例换算。
# 用法：
#   sudo bash phase3_checker.sh [--student-dir DIR]

set -u

STUDENT_DIR="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --student-dir)
            STUDENT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: sudo bash phase3_checker.sh [--student-dir DIR]"
            echo ""
            echo "参数:"
            echo "  --student-dir DIR   学生脚本目录，用于查找 disk_alert.sh 等"
            echo ""
            echo "建议用 root 或 sudo 运行，以读取系统配置。"
            exit 0
            ;;
        *)
            echo "未知参数: $1" >&2
            exit 1
            ;;
    esac
done

STUDENT_DIR=$(cd "$STUDENT_DIR" 2>/dev/null && pwd) || {
    echo "错误：无法进入学生目录 $STUDENT_DIR" >&2
    exit 1
}

# sudo 前缀判断
SUDO=""
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        SUDO="sudo"
    else
        echo "警告：未以 root 运行且 sudo 不可用，部分系统级检查将失败。"
        echo "建议使用 sudo bash phase3_checker.sh"
    fi
fi

C_OK="\033[92m"
C_FAIL="\033[91m"
C_WARN="\033[93m"
C_INFO="\033[94m"
C_RST="\033[0m"

log_ok()   { echo -e "${C_OK}[通过]${C_RST} $*"; }
log_fail() { echo -e "${C_FAIL}[未通过]${C_RST} $*"; }
log_warn() { echo -e "${C_WARN}[人工验证]${C_RST} $*"; }
log_info() { echo -e "${C_INFO}[检查]${C_RST} $*"; }

# 评分数组：3 个任务
SCORES=(0 0 0)
TOTALS=(0 0 0)
MANUAL_HINTS=()

add_score() {
    local task="$1" passed="$2" total="$3"
    SCORES[$task]=$(( ${SCORES[$task]} + passed ))
    TOTALS[$task]=$(( ${TOTALS[$task]} + total ))
}

# ============================================================
# 任务 3.1 systemd 服务与 Nginx 配置（5 分）
# ============================================================
check_task31() {
    echo "=================================================="
    echo "任务 3.1：systemd 服务与 Nginx 配置（满分 5 分）"
    echo "=================================================="

    # --- 子任务 1：Nginx 安装与配置（5 个检查点） ---
    log_info "子任务 1：Nginx 安装与配置"

    # 1.1 Nginx 已安装且运行
    if $SUDO systemctl is-active --quiet nginx 2>/dev/null; then
        log_ok "Nginx 已安装且正在运行"
        add_score 0 1 1
    else
        log_fail "Nginx 未运行（systemctl is-active nginx 失败）"
        add_score 0 0 1
    fi

    # 1.2 虚拟主机配置文件存在
    local nginx_conf=""
    for f in /etc/nginx/conf.d/*.conf /etc/nginx/sites-enabled/*; do
        [[ -f "$f" ]] && nginx_conf="$f" && break
    done
    if [[ -n "$nginx_conf" ]]; then
        log_ok "找到 Nginx 虚拟主机配置文件：$nginx_conf"
        add_score 0 1 1
    else
        log_fail "未在 /etc/nginx/conf.d/ 或 sites-enabled/ 找到虚拟主机配置"
        add_score 0 0 1
    fi

    # 1.3 autoindex 已开启
    if [[ -n "$nginx_conf" ]] && grep -q "autoindex[[:space:]]*on" "$nginx_conf"; then
        log_ok "autoindex on 已开启"
        add_score 0 1 1
    else
        log_fail "未找到 autoindex on 配置"
        add_score 0 0 1
    fi

    # 1.4 gzip 已开启
    if grep -q "gzip[[:space:]]*on" /etc/nginx/nginx.conf "$nginx_conf" 2>/dev/null; then
        log_ok "gzip on 已开启"
        add_score 0 1 1
    else
        log_fail "未找到 gzip on 配置"
        add_score 0 0 1
    fi

    # 1.5 gzip_types 已指定文件类型
    if grep -qE "gzip_types[[:space:]]+[^;]*text" /etc/nginx/nginx.conf "$nginx_conf" 2>/dev/null; then
        log_ok "gzip_types 已指定文本类型"
        add_score 0 1 1
    else
        log_fail "未找到 gzip_types 文本类型配置"
        add_score 0 0 1
    fi

    # --- 子任务 2：systemd 服务配置（4 个检查点） ---
    echo ""
    log_info "子任务 2：systemd 服务配置"

    local svc_file="/etc/systemd/system/water-quality.service"
    [[ -f "$svc_file" ]] || svc_file="/lib/systemd/system/water-quality.service"

    # 2.1 服务文件存在
    if [[ -f "$svc_file" ]]; then
        log_ok "water-quality.service 文件存在：$svc_file"
        add_score 0 1 1

        # 2.2 语法正确（检查必需段）
        if grep -qE "^\[Unit\]" "$svc_file" && \
           grep -qE "^\[Service\]" "$svc_file" && \
           grep -qE "^\[Install\]" "$svc_file"; then
            log_ok "service 文件包含 [Unit]、[Service]、[Install] 必要段"
            add_score 0 1 1
        else
            log_fail "service 文件缺少必要段（[Unit]/[Service]/[Install]）"
            add_score 0 0 1
        fi

        # 2.3 专用用户运行
        if grep -qE "^[[:space:]]*User[[:space:]]*=" "$svc_file" && \
           ! grep -qE "^[[:space:]]*User[[:space:]]*=[[:space:]]*root" "$svc_file"; then
            log_ok "已配置低权限用户（User= 非 root）"
            add_score 0 1 1
        else
            log_fail "未配置低权限用户，或 User=root"
            add_score 0 0 1
        fi

        # 2.4 崩溃自动重启
        if grep -qE "^[[:space:]]*Restart[[:space:]]*=[[:space:]]*(on-failure|always|on-abnormal)" "$svc_file"; then
            log_ok "已配置 Restart= 自动重启策略"
            add_score 0 1 1
        else
            log_fail "未配置 Restart= on-failure/always"
            add_score 0 0 1
        fi
    else
        log_fail "未找到 water-quality.service 文件"
        add_score 0 0 4
    fi

    # 2.5 开机自启（独立检查，不依赖文件存在）
    if $SUDO systemctl is-enabled water-quality.service 2>/dev/null | grep -q "enabled"; then
        log_ok "water-quality.service 已设置开机自启"
        add_score 0 1 1
    else
        log_fail "water-quality.service 未设置开机自启"
        add_score 0 0 1
    fi

    # --- 子任务 3：日志轮转配置（3 个检查点） ---
    echo ""
    log_info "子任务 3：日志轮转配置"

    local logrotate_conf=""
    for f in /etc/logrotate.d/nginx /etc/logrotate.d/hydro*; do
        [[ -f "$f" ]] && logrotate_conf="$f" && break
    done

    # 3.1 logrotate 配置存在
    if [[ -n "$logrotate_conf" ]]; then
        log_ok "logrotate 配置存在：$logrotate_conf"
        add_score 0 1 1

        # 3.2 daily + rotate 30
        if grep -q "daily" "$logrotate_conf" && grep -qE "rotate[[:space:]]*30" "$logrotate_conf"; then
            log_ok "已配置 daily 和 rotate 30"
            add_score 0 1 1
        else
            log_fail "未同时配置 daily 和 rotate 30"
            add_score 0 0 1
        fi

        # 3.3 postrotate 中重载 Nginx
        if grep -A 5 "postrotate" "$logrotate_conf" | grep -qE "(reload|kill.*USR1|systemctl)"; then
            log_ok "postrotate 中已配置 Nginx 重载日志"
            add_score 0 1 1
        else
            log_fail "postrotate 中未配置 Nginx 重载"
            add_score 0 0 1
        fi
    else
        log_fail "未在 /etc/logrotate.d/ 找到日志轮转配置"
        add_score 0 0 3
    fi

    # 人工验证提示
    MANUAL_HINTS+=("任务 3.1：浏览器访问 http://<服务器IP> 检查 Nginx 页面可正常访问和下载文件")
    MANUAL_HINTS+=("任务 3.1：使用 systemctl kill water-quality.service 观察是否自动重启")
}

# ============================================================
# 任务 3.2 磁盘与文件系统管理（5 分）
# ============================================================
check_task32() {
    echo ""
    echo "=================================================="
    echo "任务 3.2：磁盘与文件系统管理（满分 5 分）"
    echo "=================================================="

    # --- 子任务 1：磁盘镜像与文件系统（4 个检查点） ---
    log_info "子任务 1：创建磁盘镜像与文件系统"

    # 寻找镜像文件：常见路径
    local img_file=""
    for p in /data/hydro/disk.img /data/hydro/*.img "$STUDENT_DIR"/disk.img "$STUDENT_DIR"/*.img; do
        if [[ -f "$p" ]]; then
            img_file="$p"
            break
        fi
    done

    # 1.1 镜像文件存在且 ~100MB
    if [[ -n "$img_file" ]]; then
        local size_kb
        size_kb=$(du -k "$img_file" | awk '{print $1}')
        if [[ "$size_kb" -ge 80000 && "$size_kb" -le 120000 ]]; then
            log_ok "磁盘镜像存在且大小约 100MB：$img_file (${size_kb}KB)"
            add_score 1 1 1
        else
            log_fail "镜像文件大小不符预期（~100MB）：${size_kb}KB"
            add_score 1 0 1
        fi

        # 1.2 ext4 格式化
        local fs_type
        fs_type=$($SUDO blkid -s TYPE -o value "$img_file" 2>/dev/null || true)
        if [[ "$fs_type" == "ext4" ]]; then
            log_ok "镜像已格式化为 ext4 文件系统"
            add_score 1 1 1
        else
            log_fail "镜像未格式化为 ext4（检测到：$fs_type）"
            add_score 1 0 1
        fi
    else
        log_fail "未找到磁盘镜像文件（disk.img 或 *.img）"
        add_score 1 0 2
    fi

    # 1.3 挂载点目录存在
    if [[ -d "/data/hydro/mount" ]]; then
        log_ok "挂载点 /data/hydro/mount 存在"
        add_score 1 1 1
    else
        log_fail "挂载点 /data/hydro/mount 不存在"
        add_score 1 0 1
    fi

    # 1.4 已挂载且可写
    if $SUDO mountpoint -q /data/hydro/mount 2>/dev/null; then
        if $SUDO touch /data/hydro/mount/.p3_check 2>/dev/null; then
            $SUDO rm -f /data/hydro/mount/.p3_check
            log_ok "已挂载且可写入"
            add_score 1 1 1
        else
            log_fail "已挂载但无法写入"
            add_score 1 0 1
        fi
    else
        log_fail "/data/hydro/mount 未挂载"
        add_score 1 0 1
    fi

    # --- 子任务 2：挂载与 fstab（3 个检查点） ---
    echo ""
    log_info "子任务 2：挂载与自动挂载配置"

    # 2.1 fstab 中存在相关条目
    local fstab_line=""
    fstab_line=$(grep -E "(disk\.img|hydro)" /etc/fstab 2>/dev/null | grep -v "^#" | head -1 || true)
    if [[ -n "$fstab_line" ]]; then
        log_ok "fstab 中存在磁盘挂载条目"
        add_score 1 1 1

        # 2.2 fstab 字段完整（6 字段）
        local fields
        fields=$(echo "$fstab_line" | awk '{print NF}')
        if [[ "$fields" -ge 4 ]]; then
            log_ok "fstab 条目字段完整（${fields} 列）"
            add_score 1 1 1
        else
            log_fail "fstab 条目字段不完整（仅 ${fields} 列，期望至少 4 列）"
            add_score 1 0 1
        fi
    else
        log_fail "/etc/fstab 中未找到磁盘挂载条目"
        add_score 1 0 2
    fi

    # 2.3 mount -a 测试无报错（仅在未挂载时测试）
    if ! $SUDO mountpoint -q /data/hydro/mount 2>/dev/null; then
        if $SUDO mount -a 2>/dev/null; then
            log_ok "mount -a 测试 fstab 无报错"
            add_score 1 1 1
        else
            log_fail "mount -a 返回错误，fstab 配置有误"
            add_score 1 0 1
        fi
    else
        log_ok "已挂载，跳过 mount -a 测试（视为通过）"
        add_score 1 1 1
    fi

    # --- 子任务 3：磁盘使用监控（3 个检查点） ---
    echo ""
    log_info "子任务 3：磁盘使用监控"

    local alert_script="$STUDENT_DIR/disk_alert.sh"

    # 3.1 脚本存在
    if [[ -f "$alert_script" ]]; then
        log_ok "disk_alert.sh 存在"
        add_score 1 1 1

        # 3.2 包含 df/du 调用
        if grep -qE "\bdf\b|\bdu\b" "$alert_script"; then
            log_ok "脚本中包含磁盘使用率查询命令（df 或 du）"
            add_score 1 1 1
        else
            log_fail "脚本中未检测到 df 或 du 命令"
            add_score 1 0 1
        fi

        # 3.3 阈值 80%
        if grep -qE "(80|0\.8)" "$alert_script"; then
            log_ok "检测到 80% 阈值相关配置"
            add_score 1 1 1
        else
            log_fail "未检测到 80% 阈值配置"
            add_score 1 0 1
        fi
    else
        log_fail "未找到 disk_alert.sh（在 $STUDENT_DIR 中查找）"
        add_score 1 0 3
    fi

    # 人工验证提示
    MANUAL_HINTS+=("任务 3.2：通过 dd 写满磁盘，验证 disk_alert.sh 在 80% 时触发告警")
}

# ============================================================
# 任务 3.3 防火墙与 SSH 安全加固（5 分）
# ============================================================
check_task33() {
    echo ""
    echo "=================================================="
    echo "任务 3.3：防火墙与 SSH 安全加固（满分 5 分）"
    echo "=================================================="

    # --- 子任务 1：ufw 防火墙（5 个检查点） ---
    log_info "子任务 1：防火墙配置"

    local ufw_status=""
    ufw_status=$($SUDO ufw status verbose 2>/dev/null || true)

    # 1.1 ufw 已启用
    if echo "$ufw_status" | grep -qE "Status:[[:space:]]*active"; then
        log_ok "ufw 防火墙已启用（Status: active）"
        add_score 2 1 1
    else
        log_fail "ufw 未启用"
        add_score 2 0 1
    fi

    # 1.2 默认入站策略为 deny
    if echo "$ufw_status" | grep -qE "Default:.*deny.*\(incoming\)"; then
        log_ok "默认入站策略为 deny (incoming)"
        add_score 2 1 1
    else
        log_fail "默认入站策略未设为 deny"
        add_score 2 0 1
    fi

    # 1.3 端口 2222 已放行
    if echo "$ufw_status" | grep -qE "2222([[:space:]]|/).*ALLOW"; then
        log_ok "端口 2222 (SSH) 已放行"
        add_score 2 1 1
    else
        log_fail "端口 2222 (SSH) 未放行"
        add_score 2 0 1
    fi

    # 1.4 端口 80 已放行
    if echo "$ufw_status" | grep -qE "80([[:space:]]|/).*ALLOW"; then
        log_ok "端口 80 (HTTP) 已放行"
        add_score 2 1 1
    else
        log_fail "端口 80 (HTTP) 未放行"
        add_score 2 0 1
    fi

    # 1.5 端口 443 已放行
    if echo "$ufw_status" | grep -qE "443([[:space:]]|/).*ALLOW"; then
        log_ok "端口 443 (HTTPS) 已放行"
        add_score 2 1 1
    else
        log_fail "端口 443 (HTTPS) 未放行"
        add_score 2 0 1
    fi

    # --- 子任务 2：SSH 安全加固（3 个检查点） ---
    echo ""
    log_info "子任务 2：SSH 安全加固"

    local sshd_config="/etc/ssh/sshd_config"

    # 2.1 SSH 端口 2222
    if [[ -f "$sshd_config" ]] && grep -qE "^[[:space:]]*Port[[:space:]]*2222" "$sshd_config"; then
        log_ok "SSH 端口已改为 2222"
        add_score 2 1 1
    else
        log_fail "SSH 端口未改为 2222"
        add_score 2 0 1
    fi

    # 2.2 禁用 root 密码登录
    if [[ -f "$sshd_config" ]] && grep -qE "^[[:space:]]*PermitRootLogin[[:space:]]*(no|prohibit-password)" "$sshd_config"; then
        log_ok "已禁用 root 密码登录（PermitRootLogin no/prohibit-password）"
        add_score 2 1 1
    else
        log_fail "未禁用 root 密码登录"
        add_score 2 0 1
    fi

    # 2.3 关闭密码认证 / 仅密钥
    if [[ -f "$sshd_config" ]] && grep -qE "^[[:space:]]*PasswordAuthentication[[:space:]]*no" "$sshd_config"; then
        log_ok "已关闭密码认证（PasswordAuthentication no）"
        add_score 2 1 1
    else
        log_fail "未关闭密码认证"
        add_score 2 0 1
    fi

    # --- 子任务 3：fail2ban（3 个检查点） ---
    echo ""
    log_info "子任务 3：部署防暴力破解工具"

    # 3.1 fail2ban 已安装且运行
    if $SUDO systemctl is-active --quiet fail2ban 2>/dev/null; then
        log_ok "fail2ban 已安装且正在运行"
        add_score 2 1 1
    else
        log_fail "fail2ban 未运行"
        add_score 2 0 1
    fi

    # 3.2 sshd jail 已启用
    local jail_enabled=0
    if $SUDO fail2ban-client status sshd 2>/dev/null | grep -q "Status"; then
        jail_enabled=1
    fi
    if [[ "$jail_enabled" -eq 1 ]]; then
        log_ok "fail2ban sshd jail 已启用"
        add_score 2 1 1
    else
        log_fail "fail2ban sshd jail 未启用"
        add_score 2 0 1
    fi

    # 3.3 封禁策略配置（maxretry/bantime）
    local f2b_conf=""
    for f in /etc/fail2ban/jail.local /etc/fail2ban/jail.d/*.conf; do
        [[ -f "$f" ]] && f2b_conf="$f" && break
    done
    if [[ -n "$f2b_conf" ]] && grep -qE "^[[:space:]]*maxretry" "$f2b_conf" && \
       grep -qE "^[[:space:]]*bantime" "$f2b_conf"; then
        log_ok "已配置 maxretry 和 bantime"
        add_score 2 1 1
    else
        log_fail "未检测到 maxretry/bantime 配置"
        add_score 2 0 1
    fi

    # 人工验证提示
    MANUAL_HINTS+=("任务 3.3：使用 ssh -p 2222 密钥登录测试，确认密码登录被拒绝")
    MANUAL_HINTS+=("任务 3.3：故意输入错误密码多次，观察 fail2ban 是否封禁 IP")
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo "=================================================="
    echo "节点三自动检查器"
    echo "运行目录: $(pwd)"
    echo "学生脚本目录: $STUDENT_DIR"
    echo "=================================================="
    echo ""
    echo "提示：标记为 [人工验证] 的项目不计入自动评分，"
    echo "需由学生自行演示或教师抽查确认。"
    echo ""

    check_task31
    check_task32
    check_task33

    # 输出各任务得分
    echo ""
    echo "=================================================="
    echo "自动评分汇总"
    echo "=================================================="

    local grand_passed=0 grand_total=0 grand_score=0
    local task_names=("3.1 systemd/Nginx/logrotate" "3.2 磁盘/fstab/disk_alert.sh" "3.3 ufw/SSH/fail2ban")

    for i in 0 1 2; do
        local passed=${SCORES[$i]}
        local total=${TOTALS[$i]}
        local score
        score=$(awk -v p="$passed" -v t="$total" 'BEGIN { if(t==0) print 0; else printf "%.1f", p*5.0/t }')
        local status="PASS"
        [[ "$passed" -lt "$total" ]] && status="FAIL"
        echo ""
        echo "--------------------------------------------------"
        echo -e "${C_OK}[${status}]${C_RST} 任务${task_names[$i]} 得分: ${score} / 5.0 (${passed}/${total} 检查点通过)"
        echo "--------------------------------------------------"
        grand_passed=$((grand_passed + passed))
        grand_total=$((grand_total + total))
        grand_score=$(awk -v s="$grand_score" -v v="$score" 'BEGIN { print s+v }')
    done

    echo ""
    echo "=================================================="
    echo "总成绩: ${grand_score} / 15.0"
    echo "=================================================="

    # 人工验证项
    if [[ ${#MANUAL_HINTS[@]} -gt 0 ]]; then
        echo ""
        echo "=================================================="
        echo "建议人工验证项（不计入自动评分）"
        echo "=================================================="
        for hint in "${MANUAL_HINTS[@]}"; do
            log_warn "$hint"
        done
    fi
}

main
