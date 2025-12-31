# Caddy Script

Script tự động cài đặt Caddy, PHP 8.4, MariaDB 11.4 trên Ubuntu 24 và cung cấp menu quản lý WordPress toàn diện.

## Cách sử dụng

### Download và chạy
```bash
wget https://raw.githubusercontent.com/yourusername/caddy-script/main/install.sh
sudo bash install.sh
```

### Mở menu quản lý
Sau khi cài đặt, sử dụng lệnh:
```bash
bnix
```

## Tính năng chính

### 1. Cài đặt đầy đủ
- Caddy web server
- PHP 8.4 với extensions cần thiết
- MariaDB 11.4
- Tự động tạo mật khẩu root ngẫu nhiên
- Tối ưu cấu hình tự động

### 2. Quản lý website
- Tạo website WordPress mới (tự động tạo DB, cài WP, cấu hình Caddy)
- Xóa website và dọn dẹp
- Backup website (file + database)
- Restore từ backup
- Hiển thị danh sách website

### 3. Quản lý server
- Khởi động/dừng/restart dịch vụ (Caddy, PHP-FPM, MariaDB)
- Xem log real-time
- Cập nhật hệ thống

### 4. Quản lý database
- Tạo/xóa database
- Tạo/xóa user database
- Đổi mật khẩu root MariaDB
- Xem danh sách database và user

### 5. Bảo mật & Tối ưu
- Cấu hình UFW firewall
- Cài đặt Fail2Ban
- Tối ưu PHP-FPM (tự động theo RAM)
- Tối ưu MariaDB
- Cấu hình SSL tự động với Let's Encrypt

### 6. Thông tin hệ thống
- Hiển thị thông tin server
- Phiên bản các dịch vụ
- Tài nguyên hệ thống (RAM, CPU, Disk)
- Website đang chạy
- Port đang mở

### 7. Kiểm tra sức khỏe
- Trạng thái dịch vụ
- Kiểm tra kết nối HTTP
- Kiểm tra phiên bản PHP

### 8. Xuất cấu hình backup
- Tạo script backup tự động cho tất cả website

### 9. Cập nhật hệ thống
- Update và upgrade packages

## Cấu trúc file
```
/etc/bnix_config          # Chứa mật khẩu root MariaDB
/etc/bnix/sites.conf      # Danh sách website đã tạo
/etc/caddy/sites/         # Cấu hình Caddy cho từng site
/usr/local/bin/bnix       # Script menu chính
/usr/local/bin/bnix-install.sh  # Script cài đặt
/var/backups/             # Thư mục backup
```

## Yêu cầu hệ thống
- Ubuntu 24.04 LTS
- Quyền root/sudo
- Kết nối internet

## Bảo mật
- Mật khẩu database được tạo ngẫu nhiên mạnh
- File config được bảo vệ (chmod 600)
- Tự động cấu hình firewall
- Fail2Ban chống brute force

## Update script
Script hỗ trợ tự update từ GitHub. Khi có phiên bản mới:
```bash
./install.sh
# Chọn 2: Cập nhật hệ thống
# Hoặc trong menu bnix: 9. Cập nhật hệ thống
```

## Troubleshooting
- Nếu gặp lỗi "No such file or directory" khi tạo site, chạy "Cài đặt đầy đủ" trước.
- Đảm bảo port 80/443 không bị chiếm.
- Kiểm tra log với `journalctl -u caddy` hoặc `journalctl -u php8.4-fpm`.

## License
MIT License - Sử dụng tự do cho mục đích cá nhân và thương mại.

## Contributing
Contributions welcome! Fork repo và tạo Pull Request.