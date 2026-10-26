#!/usr/bin/env bash
#
# pfsense-prep-check.sh — Kiểm tra tiền-nâng-cấp pfSense (CHỈ ĐỌC, không sửa gì).
#
# Chạy trên pfSense (FreeBSD base), qua SSH hoặc console (option 8) Shell:
#   chmod +x pfsense-prep-check.sh
#   ./pfsense-prep-check.sh                 # in báo cáo ra stdout
#   ./pfsense-prep-check.sh /tmp/report.txt # in stdout và lưu thêm một bản ra file
#
# Script không ghi/sửa bất kỳ cấu hình pfSense nào; chỉ đọc /etc/version,
# /conf/config.xml, /conf/backup, df, và thông tin pkg.

set -euo pipefail
export LC_ALL=C

readonly CONFIG_XML="/conf/config.xml"
readonly BACKUP_DIR="/conf/backup"
readonly VERSION_FILE="/etc/version"

warn_count=0

print_header() {
    printf '\n=== %s ===\n' "$1"
}

ok() {
    printf '[ OK ] %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1"
    warn_count=$((warn_count + 1))
}

# Trả về mtime (epoch) của file: thử GNU stat trước, sau đó BSD stat (pfSense/FreeBSD).
get_mtime_epoch() {
    local m
    m="$(stat -c '%Y' "$1" 2>/dev/null || true)"
    if [[ -z "$m" ]]; then
        m="$(stat -f '%m' "$1" 2>/dev/null || true)"
    fi
    if [[ ! "$m" =~ ^[0-9]+$ ]]; then
        m="0"
    fi
    printf '%s' "$m"
}

age_days() {
    local m=$1 now
    now="$(date +%s)"
    printf '%s' "$(( (now - m) / 86400 ))"
}

check_version() {
    print_header "1) Phiên bản pfSense"
    if [[ -r "$VERSION_FILE" ]]; then
        ok "Phiên bản hiện tại: $(head -n 1 "$VERSION_FILE")"
    else
        warn "Không đọc được $VERSION_FILE — có thể máy này không phải pfSense?"
    fi
}

check_config_backup() {
    print_header "2) config.xml và bản sao lưu"
    if [[ -s "$CONFIG_XML" ]]; then
        local m age
        m="$(get_mtime_epoch "$CONFIG_XML")"
        if [[ "$m" != "0" ]]; then
            age="$(age_days "$m")"
            ok "$CONFIG_XML tồn tại, sửa lần cuối cách đây ${age} ngày."
            if (( age >= 1 )); then
                warn "config.xml đã hơn 1 ngày — hãy tạo bản backup mới (Diagnostics → Backup & Restore) trước khi nâng."
            fi
        else
            warn "Không xác định được thời gian sửa của $CONFIG_XML."
        fi
    else
        warn "Không tìm thấy $CONFIG_XML."
    fi

    if [[ -d "$BACKUP_DIR" ]]; then
        local recent
        recent="$(find "$BACKUP_DIR" -type f -mtime -30 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "$recent" =~ ^[0-9]+$ ]] && (( recent > 0 )); then
            ok "Trong $BACKUP_DIR có ${recent} bản sao lưu mới hơn 30 ngày (console option 15 dùng được)."
        else
            warn "$BACKUP_DIR không có bản sao lưu nào trong 30 ngày — hãy tạo backup mới."
        fi
    else
        warn "Không có thư mục $BACKUP_DIR (thư mục Backup mặc định của pfSense)."
    fi
}

check_acb() {
    print_header "3) AutoConfigBackup (ACB)"
    if [[ -s "$CONFIG_XML" ]] && grep -q 'autoconfigbackup' "$CONFIG_XML"; then
        ok "Đã thấy dấu hiệu AutoConfigBackup trong config.xml (cấu hình sẽ sync với dịch vụ ACB)."
    else
        warn "Không thấy dấu hiệu ACB — nên bật System → Auto Config Backup trước khi nâng."
    fi
}

check_disk() {
    print_header "4) Dung lượng đĩa trên /"
    df -h / || warn "Không đọc được df."

    local avail
    avail="$(df -k / 2>/dev/null | awk 'NR==2 {print $4}')"
    if [[ "$avail" =~ ^[0-9]+$ ]]; then
        if (( avail >= 4096000 )); then
            ok "Còn khoảng $(( avail / 1024 )) MB trống — đủ cho quá trình tải và cài đặt."
        elif (( avail >= 2048000 )); then
            warn "Chỉ còn khoảng $(( avail / 1024 )) MB trống — hơi chật, nên dọn log/backup cũ."
        else
            warn "Dưới 2 GB trống — tuyệt đối dọn dẹp trước khi nâng."
        fi
    else
        warn "Không xác định được dung lượng trống trên /."
    fi
}

check_pfsense_packages() {
    print_header "5) Package dòng pfSense (pkg-static info -x pfSense)"
    if command -v pkg-static >/dev/null 2>&1; then
        local pslist
        pslist="$(pkg-static info -x pfSense 2>/dev/null || true)"
        if [[ -n "$pslist" ]]; then
            printf '%s\n' "$pslist"
        else
            warn "pkg-static không trả về package pfSense nào."
        fi
    else
        warn "Không tìm thấy pkg-static (máy này không phải pfSense?)."
    fi
}

check_custom_packages() {
    print_header "6) Package tùy chỉnh (ngoài dòng pfSense)"
    if command -v pkg-static >/dev/null 2>&1; then
        local custom
        custom="$(pkg-static info -q -a 2>/dev/null | grep -v '^pfSense' || true)"
        if [[ -n "$custom" ]]; then
            warn "Có package ngoài dòng pfSense — pfSense-upgrade thường tự cài lại sau nâng, hãy kiểm tra lại sau nâng:"
            printf '%s\n' "$custom"
        else
            ok "Không có package tùy chỉnh đáng chú ý."
        fi
    else
        warn "Bỏ qua mục này vì không có pkg-static."
    fi
}

check_aliases() {
    print_header "7) Alias trong config.xml"
    if [[ -s "$CONFIG_XML" ]] && grep -q '<aliases>' "$CONFIG_XML"; then
        local names count
        names="$(awk '/<aliases>/{f=1;next} /<\/aliases>/{f=0} f' "$CONFIG_XML" \
            | sed -n 's/.*<name>\([^<]*\)<\/name>.*/\1/p' \
            | sort -u | head -n 50 || true)"
        if [[ -n "$names" ]]; then
            count="$(printf '%s\n' "$names" | wc -l | tr -d ' ')"
            ok "Có ${count} alias (tối đa in 50):"
            printf '%s\n' "$names"
        else
            ok "Có phần <aliases> nhưng không đọc được tên nào."
        fi
    else
        ok "Không có phần <aliases> trong config.xml."
    fi
}

main() {
    if [[ $# -gt 0 ]]; then
        exec > >(tee "$1") 2>&1
    fi

    printf 'pfSense prep-check (chỉ đọc) — %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"

    check_version
    check_config_backup
    check_acb
    check_disk
    check_pfsense_packages
    check_custom_packages
    check_aliases

    print_header "Tổng kết"
    if (( warn_count > 0 )); then
        warn "Có ${warn_count} mục cần lưu ý — xử lý từng [WARN] phía trên trước khi nâng."
    else
        ok "Không phát hiện cảnh báo nào — có thể bắt đầu quy trình nâng theo README.md."
    fi
    printf 'Script này chỉ đọc, không thay đổi gì trên hệ thống.\n'
}

main "$@"
