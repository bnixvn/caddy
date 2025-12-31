#!/bin/bash

# Script cài đặt Caddy, PHP 8.4, MariaDB 11.4 trên Ubuntu 24
# Và thiết lập menu quản lý với lệnh 'bnix'

set -e

echo "Cập nhật hệ thống..."
sudo apt update && sudo apt upgrade -y

echo "Cài đặt Caddy..."
# Thêm repository Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy -y

echo "Cài đặt PHP 8.4..."
# Thêm repository PHP
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.4 php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-mbstring php8.4-curl php8.4-zip php8.4-gd php8.4-intl php8.4-bcmath -y

echo "Cài đặt MariaDB 11.4..."
# Thêm repository MariaDB
sudo apt install apt-transport-https curl -y
sudo mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.23m.com/mariadb/repo/11.4/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/mariadb.list
sudo apt update
sudo apt install mariadb-server -y

echo "Khởi động và kích hoạt các dịch vụ..."
sudo systemctl enable caddy
sudo systemctl start caddy
sudo systemctl enable php8.4-fpm
sudo systemctl start php8.4-fpm
sudo systemctl enable mariadb
sudo systemctl start mariadb

echo "Thiết lập MariaDB bảo mật..."
sudo mysql_secure_installation

echo "Tạo script menu bnix..."
cat << 'EOF' | sudo tee /usr/local/bin/bnix > /dev/null
#!/bin/bash

# Menu quản lý WordPress và Server toàn diện

# Biến toàn cục
CONFIG_FILE="/etc/bnix_config"
mkdir -p /etc/bnix

# Hàm tạo mật khẩu ngẫu nhiên
generate_password() {
    openssl rand -base64 12
}

# Hàm tạo salts WordPress
generate_wp_salts() {
    curl -s https://api.wordpress.org/secret-key/1.1/salt/
}

# 1. Cài đặt đầy đủ
install_all() {
    echo "Kiểm tra và cài đặt các thành phần..."
    
    # Kiểm tra và cài đặt Caddy
    if ! command -v caddy &> /dev/null; then
        echo "Cài đặt Caddy..."
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        sudo apt update && sudo apt install caddy -y
    else
        echo "Caddy đã được cài đặt."
    fi
    
    # Kiểm tra và cài đặt PHP 8.4
    if ! command -v php8.4 &> /dev/null; then
        echo "Cài đặt PHP 8.4..."
        sudo apt install software-properties-common -y
        sudo add-apt-repository ppa:ondrej/php -y
        sudo apt update
        sudo apt install php8.4 php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-mbstring php8.4-curl php8.4-zip php8.4-gd php8.4-intl php8.4-bcmath php8.4-opcache php8.4-imagick -y
    else
        echo "PHP 8.4 đã được cài đặt."
    fi
    
    # Kiểm tra và cài đặt MariaDB 11.4
    if ! command -v mariadb &> /dev/null; then
        echo "Cài đặt MariaDB 11.4..."
        sudo apt install apt-transport-https curl -y
        sudo mkdir -p /etc/apt/keyrings
        curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
        echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.23m.com/mariadb/repo/11.4/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/mariadb.list
        sudo apt update && sudo apt install mariadb-server -y
    else
        echo "MariaDB đã được cài đặt."
    fi
    
    # Tạo mật khẩu root nếu chưa có config
    if [ ! -f $CONFIG_FILE ]; then
        ROOT_PASS=$(generate_password)
        sudo mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS';"
        echo "ROOT_PASS=$ROOT_PASS" > $CONFIG_FILE
        chmod 600 $CONFIG_FILE
        echo "Mật khẩu root MariaDB: $ROOT_PASS (đã lưu trong $CONFIG_FILE)"
    else
        echo "File config đã tồn tại."
    fi
    
    # Khởi động dịch vụ
    sudo systemctl enable --now caddy php8.4-fpm mariadb
    
    # Tối ưu PHP-FPM
    optimize_php
    
    # Tối ưu MariaDB
    optimize_mariadb
    
    # Cấu hình Caddy cho PHP
    config_caddy_php
    
    echo "Cài đặt hoàn thành!"
}

# 2. Quản lý website
create_wp_site() {
    if [ ! -f $CONFIG_FILE ]; then
        echo "Chưa cài đặt đầy đủ. Vui lòng chạy 'Cài đặt đầy đủ' trước."
        return
    fi
    read -p "Nhập tên domain: " domain
    read -p "Nhập đường dẫn webroot (mặc định /var/www/$domain): " webroot
    webroot=${webroot:-/var/www/$domain}
    
    # Tạo database
    db_name="${domain//./_}"
    db_user="${domain//./_}_user"
    db_pass=$(generate_password)
    
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "CREATE DATABASE $db_name;"
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "GRANT ALL ON $db_name.* TO '$db_user'@'localhost';";
    
    # Tạo thư mục
    sudo mkdir -p $webroot
    sudo chown www-data:www-data $webroot
    
    # Cài đặt WordPress
    cd $webroot
    sudo -u www-data wget https://wordpress.org/latest.tar.gz
    sudo -u www-data tar -xzf latest.tar.gz
    sudo -u www-data mv wordpress/* .
    sudo -u www-data rm -rf wordpress latest.tar.gz
    
    # Tạo wp-config.php
    sudo -u www-data cp wp-config-sample.php wp-config.php
    sudo -u www-data sed -i "s/database_name_here/$db_name/" wp-config.php
    sudo -u www-data sed -i "s/username_here/$db_user/" wp-config.php
    sudo -u www-data sed -i "s/password_here/$db_pass/" wp-config.php
    
    # Thêm salts
    salts=$(generate_wp_salts)
    sudo -u www-data sed -i "/AUTH_KEY/r /dev/stdin" wp-config.php <<< "$salts"
    
    # Cấu hình Caddy
    sudo mkdir -p /etc/caddy/sites
    cat << CADDY_EOF | sudo tee /etc/caddy/sites/$domain > /dev/null
$domain {
    root * $webroot
    encode gzip
    php_fastcgi unix//run/php/php8.4-fpm.sock
    file_server
}
CADDY_EOF
    
    sudo systemctl reload caddy
    
    # Lưu thông tin
    echo "$domain|$webroot|$db_name|$db_user|$db_pass" >> /etc/bnix/sites.conf
    
    echo "Website $domain đã được tạo. Database: $db_name, User: $db_user, Pass: $db_pass"
}

delete_wp_site() {
    read -p "Nhập domain cần xóa: " domain
    webroot=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f2)
    db_name=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f3)
    
    if [ -z "$webroot" ]; then
        echo "Domain không tồn tại!"
        return
    fi
    
    # Xóa thư mục
    sudo rm -rf $webroot
    
    # Xóa database
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "DROP DATABASE $db_name;"
    
    # Xóa cấu hình Caddy
    sudo rm -f /etc/caddy/sites/$domain
    sudo systemctl reload caddy
    
    # Xóa khỏi file config
    sed -i "/^$domain|/d" /etc/bnix/sites.conf
    
    echo "Website $domain đã được xóa."
}

backup_website() {
    read -p "Nhập domain cần backup: " domain
    webroot=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f2)
    db_name=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f3)
    
    if [ -z "$webroot" ]; then
        echo "Domain không tồn tại!"
        return
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="/var/backups/$domain"
    sudo mkdir -p $backup_dir
    
    # Backup files
    sudo tar -czf $backup_dir/files_$timestamp.tar.gz -C $webroot .
    
    # Backup database
    sudo mysqldump -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) $db_name > $backup_dir/db_$timestamp.sql
    
    echo "Backup hoàn thành: $backup_dir"
}

restore_website() {
    read -p "Nhập domain cần restore: " domain
    read -p "Nhập đường dẫn backup: " backup_path
    
    if [ ! -d "$backup_path" ]; then
        echo "Đường dẫn backup không tồn tại!"
        return
    fi
    
    # Tìm file backup mới nhất
    files_backup=$(ls -t $backup_path/files_*.tar.gz | head -1)
    db_backup=$(ls -t $backup_path/db_*.sql | head -1)
    
    webroot=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f2)
    db_name=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f3)
    
    # Restore files
    sudo rm -rf $webroot/*
    sudo tar -xzf $files_backup -C $webroot
    
    # Restore database
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) $db_name < $db_backup
    
    echo "Restore hoàn thành."
}

show_websites() {
    echo "Danh sách website:"
    if [ -f /etc/bnix/sites.conf ]; then
        cat /etc/bnix/sites.conf | while IFS='|' read -r domain webroot db_name db_user db_pass; do
            echo "Domain: $domain"
            echo "Webroot: $webroot"
            echo "Database: $db_name"
            echo "User: $db_user"
            echo "-------------------"
        done
    else
        echo "Chưa có website nào."
    fi
}

# 3. Quản lý server
manage_service() {
    echo "1. Khởi động  2. Dừng  3. Restart"
    read -p "Chọn hành động: " action
    echo "1. Caddy  2. PHP-FPM  3. MariaDB"
    read -p "Chọn dịch vụ: " service
    
    case $service in
        1) svc="caddy" ;;
        2) svc="php8.4-fpm" ;;
        3) svc="mariadb" ;;
        *) echo "Lựa chọn không hợp lệ"; return ;;
    esac
    
    case $action in
        1) sudo systemctl start $svc ;;
        2) sudo systemctl stop $svc ;;
        3) sudo systemctl restart $svc ;;
        *) echo "Lựa chọn không hợp lệ"; return ;;
    esac
    
    echo "Hoàn thành."
}

view_logs() {
    echo "1. Caddy  2. PHP-FPM  3. MariaDB"
    read -p "Chọn dịch vụ: " service
    
    case $service in
        1) sudo journalctl -u caddy -f ;;
        2) sudo journalctl -u php8.4-fpm -f ;;
        3) sudo journalctl -u mariadb -f ;;
        *) echo "Lựa chọn không hợp lệ" ;;
    esac
}

update_system() {
    sudo apt update && sudo apt upgrade -y
    echo "Hệ thống đã được cập nhật."
}

# 4. Quản lý database
create_db() {
    if [ ! -f $CONFIG_FILE ]; then
        echo "Chưa cài đặt đầy đủ. Vui lòng chạy 'Cài đặt đầy đủ' trước."
        return
    fi
    read -p "Nhập tên database: " db_name
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "CREATE DATABASE $db_name;"
    echo "Database $db_name đã được tạo."
}

delete_db() {
    read -p "Nhập tên database: " db_name
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "DROP DATABASE $db_name;"
    echo "Database $db_name đã được xóa."
}

create_db_user() {
    read -p "Nhập tên user: " db_user
    read -p "Nhập tên database: " db_name
    db_pass=$(generate_password)
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "GRANT ALL ON $db_name.* TO '$db_user'@'localhost';"
    echo "User $db_user đã được tạo với password: $db_pass"
}

delete_db_user() {
    read -p "Nhập tên user: " db_user
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "DROP USER '$db_user'@'localhost';"
    echo "User $db_user đã được xóa."
}

change_root_pass() {
    new_pass=$(generate_password)
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$new_pass';"
    sed -i "s/ROOT_PASS=.*/ROOT_PASS=$new_pass/" $CONFIG_FILE
    echo "Mật khẩu root mới: $new_pass"
}

list_db_users() {
    sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "SELECT User, Host FROM mysql.user WHERE Host='localhost';"
}

# 5. Bảo mật & Tối ưu
config_firewall() {
    sudo apt install ufw -y
    sudo ufw allow ssh
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw --force enable
    echo "Firewall đã được cấu hình."
}

install_fail2ban() {
    sudo apt install fail2ban -y
    sudo systemctl enable fail2ban
    echo "Fail2Ban đã được cài đặt."
}

optimize_php() {
    # Tự động điều chỉnh theo RAM
    ram_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ $ram_mb -gt 2048 ]; then
        pm_max_children=50
    elif [ $ram_mb -gt 1024 ]; then
        pm_max_children=25
    else
        pm_max_children=10
    fi
    
    sudo sed -i "s/pm.max_children = .*/pm.max_children = $pm_max_children/" /etc/php/8.4/fpm/pool.d/www.conf
    sudo systemctl restart php8.4-fpm
    echo "PHP-FPM đã được tối ưu."
}

optimize_mariadb() {
    # Cấu hình cơ bản
    cat << MYSQL_EOF | sudo tee /etc/mysql/mariadb.conf.d/99-custom.cnf > /dev/null
[mysqld]
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
query_cache_size = 64M
max_connections = 100
MYSQL_EOF
    
    sudo systemctl restart mariadb
    echo "MariaDB đã được tối ưu."
}

config_ssl() {
    read -p "Nhập domain: " domain
    sudo apt install certbot python3-certbot-nginx -y
    sudo certbot --nginx -d $domain
    echo "SSL đã được cấu hình."
}

# 6. Thông tin hệ thống
show_system_info() {
    echo "=== Thông tin hệ thống ==="
    uname -a
    echo ""
    echo "=== Phiên bản dịch vụ ==="
    caddy version
    php --version | head -1
    mysql --version
    echo ""
    echo "=== Tài nguyên ==="
    free -h
    df -h
    echo ""
    echo "=== Website đang chạy ==="
    show_websites
    echo ""
    echo "=== Port đang mở ==="
    sudo netstat -tlnp | grep LISTEN
}

# 7. Kiểm tra sức khỏe
check_services() {
    echo "=== Trạng thái dịch vụ ==="
    sudo systemctl status caddy --no-pager -l | head -10
    sudo systemctl status php8.4-fpm --no-pager -l | head -10
    sudo systemctl status mariadb --no-pager -l | head -10
}

check_http() {
    read -p "Nhập domain: " domain
    curl -I https://$domain
}

check_php_version() {
    php --version
}

# 8. Xuất cấu hình backup
create_backup_script() {
    cat << BACKUP_EOF | sudo tee /usr/local/bin/bnix-backup > /dev/null
#!/bin/bash
# Script backup tự động
BACKUP_DIR="/var/backups/\$(date +%Y%m%d)"
mkdir -p \$BACKUP_DIR

# Backup tất cả website
if [ -f /etc/bnix/sites.conf ]; then
    while IFS='|' read -r domain webroot db_name db_user db_pass; do
        # Backup files
        tar -czf \$BACKUP_DIR/\${domain}_files.tar.gz -C \$webroot .
        # Backup DB
        mysqldump -u root -p\$(grep ROOT_PASS /etc/bnix_config | cut -d'=' -f2) \$db_name > \$BACKUP_DIR/\${domain}_db.sql
    done < /etc/bnix/sites.conf
fi

# Backup cấu hình
cp /etc/bnix_config \$BACKUP_DIR/
cp /etc/bnix/sites.conf \$BACKUP_DIR/

echo "Backup hoàn thành: \$BACKUP_DIR"
BACKUP_EOF
    
    sudo chmod +x /usr/local/bin/bnix-backup
    echo "Script backup đã được tạo: /usr/local/bin/bnix-backup"
}

# Hàm cấu hình Caddy cho PHP
config_caddy_php() {
    sudo mkdir -p /etc/caddy/sites
    cat << CADDY_GLOBAL | sudo tee /etc/caddy/Caddyfile > /dev/null
{
    email admin@example.com
}

import /etc/caddy/sites/*
CADDY_GLOBAL
    sudo systemctl reload caddy
}

# Menu chính
show_main_menu() {
    echo "======================================"
    echo "         MENU QUẢN LÝ SERVER"
    echo "======================================"
    echo "1. Cài đặt đầy đủ"
    echo "2. Quản lý website"
    echo "3. Quản lý server"
    echo "4. Quản lý database"
    echo "5. Bảo mật & Tối ưu"
    echo "6. Thông tin hệ thống"
    echo "7. Kiểm tra sức khỏe"
    echo "8. Xuất cấu hình backup"
    echo "9. Thoát"
    echo "======================================"
}

show_website_menu() {
    echo "=== Quản lý website ==="
    echo "1. Tạo website WordPress mới"
    echo "2. Xóa website"
    echo "3. Backup website"
    echo "4. Restore website"
    echo "5. Hiển thị thông tin website"
    echo "6. Quay lại"
}

show_server_menu() {
    echo "=== Quản lý server ==="
    echo "1. Quản lý dịch vụ"
    echo "2. Xem log real-time"
    echo "3. Cập nhật hệ thống"
    echo "4. Quay lại"
}

show_db_menu() {
    echo "=== Quản lý database ==="
    echo "1. Tạo database"
    echo "2. Xóa database"
    echo "3. Tạo user database"
    echo "4. Xóa user database"
    echo "5. Đổi mật khẩu root"
    echo "6. Xem danh sách database và user"
    echo "7. Quay lại"
}

show_security_menu() {
    echo "=== Bảo mật & Tối ưu ==="
    echo "1. Cấu hình firewall (UFW)"
    echo "2. Cài đặt Fail2Ban"
    echo "3. Tối ưu PHP-FPM"
    echo "4. Tối ưu MariaDB"
    echo "5. Cấu hình SSL với Let's Encrypt"
    echo "6. Quay lại"
}

show_info_menu() {
    echo "=== Thông tin hệ thống ==="
    echo "1. Hiển thị thông tin server"
    echo "2. Quay lại"
}

show_health_menu() {
    echo "=== Kiểm tra sức khỏe ==="
    echo "1. Kiểm tra trạng thái dịch vụ"
    echo "2. Kiểm tra kết nối HTTP"
    echo "3. Kiểm tra phiên bản PHP"
    echo "4. Quay lại"
}

# Logic menu
while true; do
    show_main_menu
    read -p "Chọn mục (1-9): " choice
    case $choice in
        1) install_all ;;
        2) 
            while true; do
                show_website_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) create_wp_site ;;
                    2) delete_wp_site ;;
                    3) backup_website ;;
                    4) restore_website ;;
                    5) show_websites ;;
                    6) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        3)
            while true; do
                show_server_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) manage_service ;;
                    2) view_logs ;;
                    3) update_system ;;
                    4) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        4)
            while true; do
                show_db_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) create_db ;;
                    2) delete_db ;;
                    3) create_db_user ;;
                    4) delete_db_user ;;
                    5) change_root_pass ;;
                    6) list_db_users ;;
                    7) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        5)
            while true; do
                show_security_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) config_firewall ;;
                    2) install_fail2ban ;;
                    3) optimize_php ;;
                    4) optimize_mariadb ;;
                    5) config_ssl ;;
                    6) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        6)
            while true; do
                show_info_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) show_system_info ;;
                    2) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        7)
            while true; do
                show_health_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) check_services ;;
                    2) check_http ;;
                    3) check_php_version ;;
                    4) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        8) create_backup_script ;;
        9) break ;;
        *) echo "Lựa chọn không hợp lệ!" ;;
    esac
    echo ""
done
EOF

sudo chmod +x /usr/local/bin/bnix

echo "Cài đặt hoàn thành! Sử dụng lệnh 'bnix' để mở menu quản lý."