# Checklist nâng cấp pfSense CE: từ 2.7.2 lên 2.9.0

Rút ra từ README.md, dạng tick. Đường chính khi ở 2.7.2: **nâng qua 2.8.1 trước rồi 2.9.0 (GUI)**, hoặc **cài lại mới + restore config.xml**. Chấm nào chưa xong đừng sang mục kế tiếp.

## 1. Chuẩn bị (pre-flight)

- [ ] Xác nhận bản đang chạy: `cat /etc/version` (kỳ vọng 2.7.2)
- [ ] Backup `config.xml` qua GUI: Diagnostics → Backup & Restore
- [ ] Backup `config.xml` qua console: `cp /conf/config.xml /root/config-backup-$(date +%Y%m%d-%H%M%S).xml`
- [ ] Copy 1 bản `config.xml` ra ngoài firewall (scp/USB)
- [ ] ACB bật (System → Auto Config Backup), ghi lại danh sách backup gần nhất
- [ ] Snapshot VM (Proxmox/ESXi) nếu chạy ảo hóa
- [ ] Chạy `scripts/pfsense-prep-check.sh` qua SSH — 0 cảnh báo hoặc đã xử lý hết
- [ ] Đĩa trống trên `/` từ ~4 GB trở lên (`df -h /`)
- [ ] Ghi danh sách package custom (System → Package Manager) để đối soát sau nâng
- [ ] Ghi danh sách alias đặc biệt, rule có urltable/overload để đối soát
- [ ] Tải sẵn ISO/USB installer của bản đích (2.8.1 hoặc 2.9.0)
- [ ] Đã đọc mục 11 (đừng nâng PHP riêng trong pfSense)

## 2. Nâng cấp (process)

### Đường A — nâng qua GUI (có Internet)

- [ ] Nâng 2.7.2 → 2.8.1 qua System → Firmware (Auto Update), đợi xong hẳn
- [ ] Kiểm nhanh sau từng chặng: version, WAN ping, DHCP lease
- [ ] Nâng tiếp 2.8.1 → 2.9.0, không tắt nguồn giữa chừng

### Đường B — cài lại (không có Internet hoặc muốn nhanh)

- [ ] Boot USB/ISO 2.9.0
- [ ] Cài mới (chọn ZFS/UFS như cũ, đủ RAM nếu ZFS)
- [ ] Restore `config.xml` (qua installer hoặc Diagnostics → Backup & Restore sau khi vào GUI)

- [ ] Nếu firmware API kẹt ở GUI: chạy SSH rescue `certctl rehash && pkg-static update -f && pkg-static install -fy pkg pfSense-repo pfSense-upgrade`
- [ ] Nếu repo metadata hỏng nặng: `pkg-static clean -ay; pkg-static install -fy pkg pfSense-repo pfSense-upgrade`

## 3. Sau nâng (post-upgrade)

- [ ] `cat /etc/version` = bản đích (2.9.0)
- [ ] WAN ping OK (Diagnostics → Ping)
- [ ] DNS lookup OK (Diagnostics → DNS Lookup)
- [ ] DHCP client trong LAN nhận lease mới (Status → DHCP Leases)
- [ ] VPN handshake đủ (IPsec / OpenVPN / WireGuard)
- [ ] NAT/port-forward test từ trong ra ngoài và ngược lại
- [ ] Status → Services: không dịch vụ nào down
- [ ] Firewall → Aliases: đủ entry, không mất
- [ ] Package Manager: package custom đã được cài lại
- [ ] State policy: giữ mặc định mới hoặc hoàn về cũ (System → Advanced → Firewall & NAT)
- [ ] DHCP server: Kea hoặc quay lại ISC theo nhu cầu
- [ ] PPPoE WAN: kết nối lại OK (nhớ driver if_pppoe)
- [ ] CARP/pfsync (nếu có): state sync, failover OK
- [ ] Reboot thêm một lần sau khi mọi thứ ổn

## 4. Khôi phục khi lỗi (một trong các mục dưới)

- [ ] Console option 15: Restore recent configuration
- [ ] Restore từ ACB (System → Auto Config Backup → Restore)
- [ ] Rollback snapshot VM
- [ ] Boot ISO → cài lại → restore `config.xml`
- [ ] Cài lại 2.8.1 + restore `config.xml` nếu 2.9.x chưa ổn (không hạ trực tiếp qua GUI)

## 5. Ghi nhớ nhanh

- [ ] Không `pkg install php` riêng — PHP là core pfSense, nâng cùng quy trình pfSense
- [ ] Không tắt nguồn / rút dây mạng giữa chừng khi đang nâng
- [ ] Không đụng IP/WAN quản trị trong lúc nâng
