# pfSense-upgrade

[![pfSense](https://img.shields.io/badge/pfSense-CE-2.8.x--to--2.9.0-blue)](https://www.pfsense.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Language](https://img.shields.io/badge/language-Ti%E1%BA%BFng%20Vi%E1%BB%87t-blue)](README.md)

Playbook tiếng Việt để **nâng cấp pfSense CE lên phiên bản mới** (2.8.x → 2.9.0) hoặc **cài lại mới + khôi phục cấu hình** khi máy đang chạy bản cũ hơn. Mục tiêu: nâng an toàn cho cả máy đứng một mình lẫn cụm CARP, không đụng vào cài đặt mạng cơ bản (IP, WAN) đang vận hành, không để mất quyền truy cập web quản trị firewall.

## Mục lục

- [1. Playbook này dành cho ai](#1-playbook-này-dành-cho-ai)
- [2. Quyết định nhanh theo phiên bản](#2-quyết-định-nhanh-theo-phiên-bản)
- [3. Chuẩn bị trước khi nâng cấp](#3-chuẩn-bị-trước-khi-nâng-cấp)
- [4. Nâng qua giao diện web hoặc console](#4-nâng-qua-giao-diện-web-hoặc-console)
- [5. Cứu nâng bằng console với pkg-static](#5-cứu-nâng-bằng-console-với-pkg-static)
- [6. Thay đổi đáng chú ý khi lên 2.8.0](#6-thay-đổi-đáng-chú-ý-khi-lên-280)
- [7. Kiểm tra sau khi nâng](#7-kiểm-tra-sau-khi-nâng)
- [8. Khôi phục khi có sự cố](#8-khôi-phục-khi-có-sự-cố)
- [9. Kịch bản thực tế: nâng 2.7.2 lên 2.9.0 không có Internet](#9-kịch-bản-thực-tế-nâng-272-lên-290-không-có-internet)
- [10. FAQ và thuật ngữ](#10-faq-và-thuật-ngữ)
- [11. Đừng nâng PHP riêng trong pfSense](#11-đừng-nâng-php-riêng-trong-pfsense)
- [12. Cấu trúc repo, đóng góp, giấy phép](#12-cấu-trúc-repo-đóng-góp-giấy-phép)

## 1. Playbook này dành cho ai

Ai đang quản trị **pfSense CE** và cần lên phiên bản mới. Số liệu chính (cập nhật tháng 10/2026):

| Bản | Vai trò |
| --- | --- |
| 2.9.0 | Bản CE mới nhất của nhánh phát hành hiện tại |
| 2.8.1 | Bản maintenance của nhánh 2.8.x (vá lỗi) |
| 2.8.0 | Bản lớn: base FreeBSD mới + nhiều thay đổi hành vi (xem [mục 6](#6-thay-đổi-đáng-chú-ý-khi-lên-280)) |
| 25.x / 26.x | pfSense **Plus** — track phát hành riêng, tách khỏi CE, đừng nhầm khi chọn repo/branch |

Phần lớn các bước chạy trên **System → Firmware qua GUI** hoặc **console/SSH**, không cần thêm công cụ ngoài những gì pfSense sẵn có.

## 2. Quyết định nhanh theo phiên bản

Bạn đang ở đâu? Tra bảng rồi đi theo cột "hành động":

| Bạn đang chạy | Hành động khuyến nghị | Lý do |
| --- | --- | --- |
| 2.8.x (2.8.0 / 2.8.1) | Nâng qua GUI lên **2.9.0** | Cùng dòng nâng cấp hỗ trợ chính thức |
| 2.7.x | Nâng gián tiếp: lên **2.8.1 trước**, rồi 2.9.0; hoặc đi nhanh hơn: **cài lại + restore config.xml** | Bước nhảy qua base FreeBSD mới, nâng chuỗi dễ phát sinh |
| < 2.7 | **Cài lại mới bằng ISO/USB + restore config.xml** | Netgate khuyến nghị cài lại, an toàn hơn nâng chuỗi từ bản rất cũ |
| pfSense Plus 25.x / 26.x | Dừng lại, đọc tài liệu Plus riêng | Track phát hành khác CE |

## 3. Chuẩn bị trước khi nâng cấp

### 3.1. Backup config.xml (hai đường)

1. **GUI:** `Diagnostics → Backup & Restore` — tải `config.xml` về máy ngoài (chọn kèm RRD data nếu muốn giữ biểu đồ). Cất file ở nơi khác, không nằm chung ổ đĩa với firewall.
2. **Console/SSH:**
    ```sh
    cp /conf/config.xml /root/config-backup-$(date +%Y%m%d-%H%M%S).xml
    ```
    Sau đó copy file này ra ngoài firewall (scp/USB) để đề phòng.

### 3.2. AutoConfigBackup

- Bật sẵn: `System → Auto Config Backup → Settings` (cần tài khoản Netgate).
- Nếu đã bật: đếm xem ACB có bao nhiêu backup gần nhất, chụp màn hình danh sách restore để phòng trong trường hợp máy sập toàn bộ.

### 3.3. Snapshot nếu chạy trên VM

- Proxmox: snapshot VM trước khi nâng.
- ESXi: snapshot VM (chụp đủ state RAM + disk).
- Máy bare-metal không VM: hai đường backup ở mục 3.1 chính là phương án dự phòng.

### 3.4. Tải sẵn installer và tiện ích

- Tải ISO của bản đích, ghi ra USB bằng Rufus/Etcher hoặc lệnh `dd`.
- Nếu RAM dưới 2 GB: đọc trước mục ZFS (mục 6.5), cân nhắc nâng RAM trước khi lên 2.8.0.

### 3.5. Kiểm tra alias và rule overload

- Rà một lượt `Firewall → Aliases`: chú ý alias loại urltable lớn (tải được nhiều host khi rebuild).
- Ghi lại các rule dùng table + `overload` trong firewall rules; sau khi nâng cần đối soát lại xem còn hoạt động đúng.

### 3.6. Chạy script kiểm tra (nên)

```sh
chmod +x scripts/pfsense-prep-check.sh
ssh admin@pfsense
./scripts/pfsense-prep-check.sh
```

Script chỉ đọc, không sửa gì, in báo cáo ra stdout: version pfSense, tình trạng backup config.xml, ACB, dung lượng đĩa, danh sách package, alias. Tự đánh giá xem có mục nào cảnh báo trước khi bắt đầu.

## 4. Nâng qua giao diện web hoặc console

### 4.1. GUI: System → Firmware

- Vào `System → Firmware → Update`.
- Nếu máy online: chọn branch CE rồi bấm "Auto Update" — hệ thống tự tải và cài.
- Nếu muốn chỉ định tay: "Manual Update" nhận **URL tới file firmware** (`.tgz` / `.gz`) do Netgate công bố — không phải file ISO cài mới.
- Đợi 15–60 phút tùy thiết bị. **Không tắt nguồn, không reset, không rút dây mạng giữa chừng.**

### 4.2. Console: option 13

- Vào console (màn hình vật lý hoặc SSH). Chọn **13) Upgrade from console**.
- Cách này dùng repo đang cấu hình; nếu trên GUI Firmware không nhận được bản mới, option 13 vẫn là đường chính thức.
- Offline không dùng được; khi đó dùng ISO cài mới + restore config (mục 8 và mục 9).

> [!TIP]
> Nếu GUI kẹt hoặc repo metadata lỗi, pkg hư, hãy nhảy sang [mục 5](#5-cứu-nâng-bằng-console-với-pkg-static).

## 5. Cứu nâng bằng console với pkg-static

Khi GUI firmware kẹt ở màn update hoặc metadata repo hỏng, SSH vào pfSense bằng user quản trị, mở console → **option 8 (Shell)** rồi chạy:

```sh
certctl rehash && pkg-static update -f && pkg-static install -fy pkg pfSense-repo pfSense-upgrade
```

Nếu metadata của repo hỏng nặng hơn:

```sh
pkg-static clean -ay; pkg-static install -fy pkg pfSense-repo pfSense-upgrade
```

- Sau khi chạy xong, thử cập nhật lại firmware qua GUI hoặc option 13 console.
- Vẫn không được: chuyển hướng cài lại bằng ISO + restore config (mục [8. Khôi phục](#8-khôi-phục-khi-có-sự-cố)).

> [!CAUTION]
> **Tuyệt đối không dùng các lệnh trên để "cài PHP riêng".** PHP là thành phần lõi: PHP của pfSense được đóng gói cùng và được nâng cấp cùng quá trình nâng pfSense. Chi tiết: [mục 11](#11-đừng-nâng-php-riêng-trong-pfsense).

## 6. Thay đổi đáng chú ý khi lên 2.8.0

Nhảy quá base FreeBSD mới nên 2.8.0 có nhiều thay đổi. Sau nâng cần rà từng mục dưới đây:

### 6.1. State policy: mặc định đổi thành "Interface Bound"

- Trước kia mặc định là floating states; 2.8.0 đổi thành **Interface Bound** (state gắn chặt vào giao diện).
- Đa số rule hoạt động không đổi, nhưng các rule Floating phức tạp hoặc rule đánh dấu `keep state` tùy chỉnh có thể đổi hành vi.
- Muốn hoàn lại cách cũ: `System → Advanced → Firewall & NAT → State policy` — đặt lại theo ý rồi Save.

### 6.2. DHCP server: ISC → Kea

- 2.8.0 chuyển sang **Kea DHCP**; có một khoảng thời gian cho phép quay lại ISC.
- Kiểm `Services → DHCP Server` và `Status → DHCP Leases` sau khi nâng; nếu cần giữ ISC, chọn lại trong phần cấu hình DHCP.

### 6.3. PPPoE: driver mới `if_pppoe`

- Có thể chọn bật driver `if_pppoe` nếu thích; hành vi so với driver cũ có thể khác ở vài edge case (MTU/MRU, nhiều phiên PPPoE đồng thời).
- Sau khi nâng, kiểm tra lại kết nối WAN PPPoE (MTU/MRU) và reconnect thử một lần.

### 6.4. Installer mới

- Giao diện installer mới — đừng lo lắng nếu menu cài đặt trông khác các bản trước; bản chất chức năng giữ nguyên.

### 6.5. ZFS + RAM hạn chế

- Máy chạy ZFS với RAM ít sẽ chịu áp lực lớn; **dưới 2 GB RAM cộng thêm ZFS là vùng làm việc mạo hiểm**, nên nâng RAM trước khi lên 2.8.0.

## 7. Kiểm tra sau khi nâng

| # | Hạng mục | Cách kiểm tra | Kết quả kỳ vọng |
| --- | --- | --- | --- |
| 1 | Firmware version | `cat /etc/version` hoặc dashboard | khớp bản đích (2.9.0) |
| 2 | WAN ping | Diagnostics → Ping | WAN trả lời bình thường |
| 3 | DHCP LAN | Status → DHCP Leases (hoặc Kea) | client nhận đúng IP |
| 4 | DNS resolve | Diagnostics → DNS Lookup | phân giải domain được |
| 5 | VPN | Status → IPsec / OpenVPN / WireGuard | handshake chạy đủ |
| 6 | NAT | thử một kết nối từ LAN ra WAN, và một port-forward từ ngoài vào | đúng rule cũ |
| 7 | Services | Status → Services | không dịch vụ nào down |
| 8 | Alias / tables | Firewall → Aliases | alias đầy đủ, không mất entry |
| 9 | Packages | System → Package Manager | package custom được cài lại |
| 10 | pfsync (CARP) | Status → CARP / failover | state sync đúng, master/backup ổn |

Ngoài ra nên **reboot một lần nữa** sau khi mọi thứ chạy tốt, để chắc chắn trạng thái sau nâng ổn định.

## 8. Khôi phục khi có sự cố

1. **Console option 15:** "Restore recent configuration" — pfSense giữ các bản config gần nhất ở `/conf/backup`; option 15 cho chọn restore nhanh.
2. **ACB:** nếu đã bật, tải lại config cũ từ `System → Auto Config Backup → Restore` (cần mạng hoặc máy khác truy cập được dịch vụ ACB).
3. **Snapshot VM:** rollback snapshot trên Proxmox/ESXi nếu nâng trên VM — nhanh nhất.
4. **Cài lại ISO:** boot USB/ISO installer → cài mới → restore `config.xml` qua installer hoặc `Diagnostics → Backup & Restore` sau khi vào lại GUI.
5. Nếu tiếp tục có lỗi: **cài lại 2.8.1** rồi restore `config.xml` (pfSense không hỗ trợ downgrade trực tiếp qua GUI).

## 9. Kịch bản thực tế: nâng 2.7.2 lên 2.9.0 không có Internet

Một case điển hình (mạng cơ quan nhỏ, 30–50 người dùng, máy pfSense làm gateway, trong mạng không có đường ra Internet):

1. **Chuẩn bị:** chạy `scripts/pfsense-prep-check.sh` qua SSH — thấy version 2.7.2, ACB bật, đĩa còn đủ chỗ trống. Backup `config.xml` bằng GUI + `cp /conf/config.xml` (mục 3.1). Snapshot VM.
2. **Lấy media:** từ máy ngoài mang USB chứa bộ cài **ISO 2.9.0** vào site (download sẵn từ trước, hoặc nhờ admin trung gian tải).
3. **Chọn đường:** không Internet nên không dùng Auto Update hay option 13. Đi **cài lại**: boot USB → installer mới → cài 2.9.0 (ZFS) → sau đó restore `config.xml`.
4. **Sau restore:** các gói tùy chỉnh được pfSense tự cài lại theo config; kiểm lại theo bảng mục 7; hoàn State policy về mặc định cũ nếu mạng phụ thuộc cách cũ; với DHCP giữ ISC (hoặc chuyển Kea nếu test lease ok).
5. **Kết quả:** toàn bộ dịch vụ chạy lại như trước, upgrade mất khoảng 30–45 phút, mạng không gián đoạn ngoài thời gian reboot.

> [!NOTE]
> Đây là kịch bản tổng hợp từ trải nghiệm cộng đồng, không phải hướng dẫn chính thức của Netgate. Phiên bản của bạn có thể cần thêm vài bước riêng.

## 10. FAQ và thuật ngữ

### 10.1. FAQ

1. **Nâng từ 2.7.x lên 2.9.0 có cần qua 2.8.1?** Nên nâng có chặng qua 2.8.1, hoặc cài lại + restore config — đừng nhảy thẳng 2.7.2 → 2.9.0 khi hệ thống đã gắn nhiều tùy chỉnh.
2. **Mất password sau nâng?** Console option `3) Reset webConfigurator password`, hoặc option `2) Set interface(s) IP address` nếu cần thiết lập lại IP quản trị.
3. **Nâng xong mất mấy phút?** Trung bình 15–60 phút, tùy phần cứng và số package phải cài lại.
4. **Máy chạy CARP 2 node, nâng thế nào?** Nâng node dự phòng trước, kiểm tra chạy ổn, failover qua đó, rồi nâng node chính; theo dõi pfsync để state không đứt.
5. **Có phải nâng PHP riêng không?** Không bao giờ — xem [mục 11](#11-đừng-nâng-php-riêng-trong-pfsense).
6. **Không có Internet, nâng được không?** Không thể auto update; chỉ đi đường ISO cài mới + restore `config.xml` hoặc đặt máy tạm thời có đường ra mạng để update xong rồi cô lập lại.

### 10.2. Thuật ngữ

| Thuật ngữ | Giải thích |
| --- | --- |
| AutoConfigBackup (ACB) | Dịch vụ pfSense tự backup `config.xml` lên cloud Netgate, có thể restore qua GUI |
| config.xml | File cấu hình tổng hợp của pfSense, nằm ở `/conf/` — mọi cài đặt GUI/API lưu vào đây |
| pkg-static | Bản static của pkg (package manager FreeBSD) mà pfSense dùng để cài đặt/nâng cấp các package nền |
| CE vs Plus | pfSense CE: mã nguồn mở, free, track 2.x. pfSense Plus: thương mại, track 25.x/26.x, đóng gói riêng |
| Kea | DHCP server thay thế ISC DHCP từ pfSense 2.8.0; cho phép quay lại ISC trong một khoảng thời gian |
| State policy | Cách pfSense gắn state của rule — theo interface hay floating — chọn trong System → Advanced → Firewall & NAT |
| pfsync | Giao thức đồng bộ state table giữa nhiều firewall PF (dùng cùng CARP để dựng cluster HA liên tục) |

## 11. Đừng nâng PHP riêng trong pfSense

> [!CAUTION]
> **Không bao giờ `pkg install php` riêng lẻ trong pfSense.**
>
> - pfSense **đóng gói PHP riêng** cho chính mình; phiên bản PHP được cập nhật **cùng quá trình nâng cấp pfSense** (thông qua `pfSense-repo`, `pfSense-upgrade`).
> - Cài PHP riêng bằng pkg sẽ tạo một cây PHP khác cây của pfSense: file cấu hình PHP đè lẫn nhau, JSON API / GUI có thể hỏng ngay lập tức.
> - PHP là **core** của pfSense. Nếu lỡ tay cài, khôi phục bằng ACB/snapshot, hoặc cài lại ISO + restore `config.xml`; chạy `pkg remove php` không đưa hệ thống về đúng cây gốc.

## 12. Cấu trúc repo, đóng góp, giấy phép

```
pfsense-upgrade/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   ├── checklist-vn.md
│   └── quick-reference-en.md
└── scripts/
    └── pfsense-prep-check.sh
```

- **README.md** — playbook chính (bạn đang đọc).
- **docs/checklist-vn.md** — checklist tick theo mục, rút từ 2.7.2 → 2.9.0.
- **docs/quick-reference-en.md** — cheat sheet 1 trang tiếng Anh.
- **scripts/pfsense-prep-check.sh** — script bash chỉ đọc, chạy trên pfSense SSH, kiểm chuẩn bị tiền-nâng.

**Đóng góp:** Fork / Pull request chào đón. Đảm bảo tiếng Việt có dấu đầy đủ, tiêu đề section đánh số liên tục, anchor link trong mục lục khớp heading, code fence khép kín.

**Giấy phép:** MIT — xem [LICENSE](LICENSE).
