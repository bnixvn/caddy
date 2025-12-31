#!/bin/bash

# Script cài đặt Caddy, PHP 8.4, MariaDB 11.4 trên Ubuntu 24
# Và thiết lập menu quản lý với lệnh 'bnix'

# URL để cập nhật script (thay thế bằng URL thực tế của bạn)
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/bnixvn/caddy/main/install.sh"

# Kiểm tra tham số update
if [ "$1" == "update" ]; then
    UPDATE_URL="${2:-$SCRIPT_UPDATE_URL}"
    echo "Đang cập nhật script từ $UPDATE_URL..."
    wget -q "$UPDATE_URL" -O /tmp/install_new.sh
    if [ $? -eq 0 ]; then
        mv /tmp/install_new.sh "$0"
        chmod +x "$0"
        echo "Script đã được cập nhật! Chạy lại '$0' để sử dụng phiên bản mới."
    else
        echo "Cập nhật thất bại. Kiểm tra URL hoặc kết nối internet."
    fi
    exit 0
fi

# Menu chính khi chạy script
if [ $# -eq 0 ]; then
    echo "======================================"
    echo "         SCRIPT CÀI ĐẶT CADDY"
    echo "======================================"
    echo "1. Cài mới (Install)"
    echo "2. Cập nhật hệ thống (Update System)"
    echo "3. Thoát"
    echo "======================================"
    read -p "Chọn tùy chọn (1-3): " choice
    case $choice in
        1)
            echo "Bắt đầu cài đặt..."
            ;;
        2)
            echo "Đang cập nhật hệ thống..."
            sudo apt update && sudo apt upgrade -y
            echo "Cập nhật hệ thống hoàn thành!"
            exit 0
            ;;
        3)
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ!"
            exit 1
            ;;
    esac
fi

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
sudo apt install php8.4 php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-mbstring php8.4-curl php8.4-zip php8.4-gd php8.4-intl php8.4-bcmath php8.4-opcache php8.4-imagick -y

echo "Cài đặt WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

echo "Cài đặt MariaDB 11.4..."
# Thêm repository MariaDB
sudo apt install apt-transport-https curl -y
sudo mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.23m.com/mariadb/repo/11.4/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/mariadb.list
sudo apt update
sudo apt install mariadb-server -y

echo "Cài đặt Redis..."
sudo apt install redis-server php8.4-redis -y

echo "Khởi động và kích hoạt các dịch vụ..."
sudo systemctl enable caddy
sudo systemctl start caddy
sudo systemctl enable php8.4-fpm
sudo systemctl start php8.4-fpm
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo systemctl enable redis-server
sudo systemctl start redis-server

echo "Thiết lập MariaDB bảo mật..."
root_pass=$(generate_password)
sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_pass';"
sudo mysql -u root -p"$root_pass" -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -u root -p"$root_pass" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -u root -p"$root_pass" -e "DROP DATABASE IF EXISTS test;"
sudo mysql -u root -p"$root_pass" -e "FLUSH PRIVILEGES;"

echo "ROOT_PASS=$root_pass" > /etc/bnix_config

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

# Hàm cập nhật script
update_script() {
    echo "Đang kiểm tra phiên bản mới..."
    wget -q "$SCRIPT_UPDATE_URL" -O /tmp/install_new.sh
    if [ $? -eq 0 ]; then
        # So sánh với phiên bản hiện tại
        if cmp -s /tmp/install_new.sh /usr/local/bin/bnix-install.sh; then
            echo "Script đã là phiên bản mới nhất."
        else
            echo "Đang cập nhật script..."
            sudo mv /tmp/install_new.sh /usr/local/bin/bnix-install.sh
            sudo chmod +x /usr/local/bin/bnix-install.sh
            echo "Script đã được cập nhật! Khởi động lại menu để áp dụng thay đổi."
        fi
    else
        echo "Không thể tải phiên bản mới. Kiểm tra kết nối internet."
    fi
}

# 2. Quản lý website
create_wp_site() {
    if [ ! -f $CONFIG_FILE ]; then
        echo "Chưa cài đặt đầy đủ. Vui lòng chạy 'Cài đặt đầy đủ' trước."
        return
    fi
    read -p "Nhập tên domain: " domain
    domain=$(echo "$domain" | sed 's|/*$||')  # remove trailing slashes
    read -p "Nhập đường dẫn webroot (mặc định /var/www/$domain): " webroot
    webroot=${webroot:-/var/www/$domain}
    
    # Tạo database
    random_suffix=$(generate_password | cut -c1-4)
    db_name="${domain//./_}_${random_suffix}"
    db_user="${domain//./_}_user_${random_suffix}"
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
    sudo -u www-data sed -i "s|database_name_here|$db_name|" wp-config.php
    sudo -u www-data sed -i "s|username_here|$db_user|" wp-config.php
    sudo -u www-data sed -i "s|password_here|$db_pass|" wp-config.php
    
    # Thêm salts
    salts=$(generate_wp_salts)
    sudo -u www-data sed -i "/AUTH_KEY/r /dev/stdin" wp-config.php <<< "$salts"
    
    # Cài đặt plugins cần thiết
    sudo -u www-data wp plugin install redis-cache wp-super-cache --activate --allow-root
    sudo -u www-data wp redis enable --allow-root
    
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
    domain=$(echo "$domain" | sed 's|/*$||')  # remove trailing slashes
    webroot=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f2)
    db_name=$(grep "^$domain|" /etc/bnix/sites.conf | cut -d'|' -f3)
    
    if [ -z "$webroot" ]; then
        echo "Domain không tồn tại!"
        return
    fi
    
    # Xóa thư mục
    sudo rm -rf $webroot
    
    # Lưu ý: Database được giữ lại để bảo toàn dữ liệu
    # sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "DROP DATABASE $db_name;"
    
    # Xóa cấu hình Caddy
    sudo rm -f /etc/caddy/sites/$domain
    sudo systemctl reload caddy
    
    # Xóa khỏi file config
    sed -i "/^$domain|/d" /etc/bnix/sites.conf
    
    echo "Website $domain đã được xóa."
}

backup_website() {
    read -p "Nhập domain cần backup: " domain
    domain=$(echo "$domain" | sed 's|/*$||')  # remove trailing slashes
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
    sudo mariadb-dump -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) $db_name > $backup_dir/db_$timestamp.sql
    
    echo "Backup hoàn thành: $backup_dir"
}

restore_website() {
    read -p "Nhập domain cần restore: " domain
    domain=$(echo "$domain" | sed 's|/*$||')  # remove trailing slashes
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

delete_all_sites() {
    if [ ! -f /etc/bnix/sites.conf ]; then
        echo "Không có website nào để xóa."
        return
    fi
    
    echo "CẢNH BÁO: Hành động này sẽ xóa TẤT CẢ website, bao gồm files và databases!"
    read -p "Bạn có chắc chắn muốn xóa tất cả? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Đã hủy."
        return
    fi
    
    while IFS='|' read -r domain webroot db_name db_user db_pass; do
        echo "Đang xóa website: $domain"
        
        # Xóa thư mục
        sudo rm -rf "$webroot"
        
        # Xóa database
        sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "DROP DATABASE $db_name;" 2>/dev/null || echo "Database $db_name không tồn tại hoặc đã xóa."
        
        # Xóa user database
        sudo mariadb -u root -p$(grep ROOT_PASS $CONFIG_FILE | cut -d'=' -f2) -e "DROP USER '$db_user'@'localhost';" 2>/dev/null || echo "User $db_user không tồn tại hoặc đã xóa."
        
        # Xóa cấu hình Caddy
        sudo rm -f /etc/caddy/sites/"$domain"
        
        echo "Đã xóa: $domain"
    done < /etc/bnix/sites.conf
    
    # Xóa file config
    sudo rm -f /etc/bnix/sites.conf
    
    # Reload Caddy
    sudo systemctl reload caddy
    
    echo "Đã xóa tất cả website."
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

update_apt() {
    sudo apt update && sudo apt upgrade -y
    echo "Hệ thống đã được cập nhật."
}

update_caddy() {
    echo "Cập nhật Caddy..."
    sudo apt update && sudo apt install --only-upgrade caddy -y
    sudo systemctl restart caddy
    echo "Caddy đã được cập nhật."
}

update_php() {
    echo "Cập nhật PHP 8.4..."
    sudo apt update && sudo apt install --only-upgrade php8.4* -y
    sudo systemctl restart php8.4-fpm
    echo "PHP đã được cập nhật."
}

update_mariadb() {
    echo "Cập nhật MariaDB..."
    sudo apt update && sudo apt install --only-upgrade mariadb-server -y
    sudo systemctl restart mariadb
    echo "MariaDB đã được cập nhật."
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
    domain=$(echo "$domain" | sed 's|/*$||')  # remove trailing slashes
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
    mariadb --version
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
    domain=$(echo "$domain" | sed 's|/*$||')  # remove trailing slashes
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
        mariadb-dump -u root -p\$(grep ROOT_PASS /etc/bnix_config | cut -d'=' -f2) \$db_name > \$BACKUP_DIR/\${domain}_db.sql
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

# 9. Cập nhật hệ thống
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
    echo "1. Quản lý website"
    echo "2. Quản lý server"
    echo "3. Quản lý database"
    echo "4. Bảo mật & Tối ưu"
    echo "5. Thông tin hệ thống"
    echo "6. Kiểm tra sức khỏe"
    echo "7. Xuất cấu hình backup"
    echo "8. Cập nhật"
    echo "9. Cập nhật script"
    echo "10. Thoát"
    echo "======================================"
}

show_website_menu() {
    echo "=== Quản lý website ==="
    echo "1. Tạo website WordPress mới"
    echo "2. Xóa website"
    echo "3. Backup website"
    echo "4. Restore website"
    echo "5. Hiển thị thông tin website"
    echo "6. Xóa tất cả website"
    echo "7. Quay lại"
}

show_server_menu() {
    echo "=== Quản lý server ==="
    echo "1. Quản lý dịch vụ"
    echo "2. Xem log real-time"
    echo "3. Cập nhật hệ thống"
    echo "4. Quay lại"
}

show_update_menu() {
    echo "=== Cập nhật ==="
    echo "1. Cập nhật hệ thống (apt)"
    echo "2. Cập nhật Caddy"
    echo "3. Cập nhật PHP"
    echo "4. Cập nhật MariaDB"
    echo "5. Quay lại"
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
    read -p "Chọn mục (1-10): " choice
    case $choice in
        1) 
            while true; do
                show_website_menu
                read -p "Chọn (1-7): " subchoice
                case $subchoice in
                    1) create_wp_site ;;
                    2) delete_wp_site ;;
                    3) backup_website ;;
                    4) restore_website ;;
                    5) show_websites ;;
                    6) delete_all_sites ;;
                    7) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        2)
            while true; do
                show_server_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) manage_service ;;
                    2) view_logs ;;
                    3) update_apt ;;
                    4) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        3)
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
        4)
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
        5)
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
        6)
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
        7) create_backup_script ;;
        8) 
            while true; do
                show_update_menu
                read -p "Chọn: " subchoice
                case $subchoice in
                    1) update_apt ;;
                    2) update_caddy ;;
                    3) update_php ;;
                    4) update_mariadb ;;
                    5) break ;;
                    *) echo "Lựa chọn không hợp lệ!" ;;
                esac
            done
            ;;
        9) update_script ;;
        10) break ;;
        *) echo "Lựa chọn không hợp lệ!" ;;
    esac
    echo ""
done
EOF

sudo chmod +x /usr/local/bin/bnix

echo "Sao chép script cài đặt..."
sudo cp "$0" /usr/local/bin/bnix-install.sh
sudo chmod +x /usr/local/bin/bnix-install.sh

echo "Cài đặt hoàn thành! Sử dụng lệnh 'bnix' để mở menu quản lý."