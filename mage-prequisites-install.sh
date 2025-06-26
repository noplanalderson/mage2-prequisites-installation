#!/bin/bash

# Script untuk menginstal software pendukung Magento pada Ubuntu 24.04
# Menggunakan Nginx, PHP-FPM, MySQL 8.0, ElasticSearch, Redis, dan Composer
# Author: Muhammad Ridwan Na'im (Powered by Grok)
# Date: 2025-05-08
# Version: 1.0

# Exit on error
set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Magento DB Password (HARAP DIUBAH!)
MAGEDB_NAME=magentodb
MAGEDB_USER=magentouser
MAGEDB_PASSWD=_Ch4n93M3e_

# Magento Domain/URL (SESUAIKAN)
MAGE_SERVER_NAME=www.your-commerce.com

# Fungsi untuk mencetak pesan
print_message() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Periksa apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    print_error "Script harus dijalankan sebagai root (gunakan sudo)"
fi

# Perbarui sistem
print_message "Memperbarui sistem..."
apt update && apt upgrade -y

# Instal Nginx
print_message "Menginstal Nginx..."
apt install -y nginx
systemctl start nginx
systemctl enable nginx

# Instal MySQL 8.0
print_message "Menginstal MySQL Server 8.0..."
apt install -y mysql-server
# Amankan instalasi MySQL
mysql_secure_installation <<EOF

y
0
y
y
y
y
EOF

# Buat database dan pengguna untuk Magento
print_message "Mengatur database Magento..."
mysql -e "CREATE DATABASE $MAGEDB_NAME;"
mysql -e "CREATE USER '$MAGEDB_USER'@'%' IDENTIFIED BY '$MAGEDB_PASSWD';"
mysql -e "GRANT ALL ON $MAGEDB_NAME.* TO '$MAGEDB_USER'@'%';"
mysql -e "FLUSH PRIVILEGES;"

# Instal PHP 8.3 dan ekstensi yang diperlukan
print_message "Menginstal PHP 8.3 dan ekstensi..."
apt install -y php8.3-fpm php8.3-bcmath php8.3-curl php8.3-xml php8.3-gd \
               php8.3-intl php8.3-mbstring php8.3-mysql php8.3-soap php8.3-zip \
               php8.3-common php8.3-ssh2 php8.3-mysql php8.3-opcache php8.3-imagick

# Konfigurasi PHP
print_message "Mengkonfigurasi PHP..."
PHP_INI="/etc/php/8.3/fpm/php.ini"
sed -i 's/short_open_tag = Off/short_open_tag = On/' $PHP_INI
sed -i 's/memory_limit = 128M/memory_limit = 512M/' $PHP_INI
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 25M/' $PHP_INI
sed -i 's/post_max_size = 8M/post_max_size = 30M/' $PHP_INI
sed -i 's/max_execution_time = 30/max_execution_time = 3600/' $PHP_INI

print_message "Mengkonfigurasi PHP-FPM untuk Magento..."
cat <<EOF > /etc/php/8.3/fpm/pool.d/magento.conf
[magento]
user = www-data
group = www-data
listen = /run/php/php-magento.sock
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

php_flag[display_errors] = off
php_admin_value[error_log] = /var/log/fpm-php-magento.log
php_admin_value[memory_limit] = 512M
EOF

# Restart PHP-FPM
systemctl restart php8.3-fpm

# Instal Redis
echo "Menginstal Redis..."
apt install -y redis-server
systemctl start redis
systemctl enable redis-server

# Instal Elasticsearch 7.17 (versi yang didukung Magento 2.4.x)
echo "Menginstal Elasticsearch..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
apt update
apt install -y elasticsearch
systemctl start elasticsearch
systemctl enable elasticsearch

# Tunggu hingga Elasticsearch aktif
print_message "Menunggu ElasticSearch aktif..."
sleep 10
curl -X GET "localhost:9200/" || print_error "Gagal memverifikasi ElasticSearch"

# Instal alat tambahan (opsional)
echo "Menginstal alat tambahan..."
apt install -y unzip git

# Instal Composer
print_message "Menginstal Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Buat pengguna sistem untuk Magento
print_message "Membuat pengguna sistem magento..."
useradd -m -d /opt/magento -s /bin/bash magento
usermod -aG sudo magento

# Buat direktori Magento
print_message "Mengatur direktori Magento..."
mkdir -p /usr/share/nginx/html/magento2
chown -R www-data:www-data /usr/share/nginx/html/magento2
chmod -R 755 /usr/share/nginx/html/magento2

print_message "Mengkonfigurasi Nginx client_max_body_size sebesar 30MB..."
NGINX_CONF="/etc/nginx/nginx.conf"
if ! grep -q "client_max_body_size" $NGINX_CONF; then
    sed -i '/http {/a \    client_max_body_size 30M;' $NGINX_CONF
else
    sed -i 's/client_max_body_size.*/client_max_body_size 50M;/' $NGINX_CONF
fi

# Konfigurasi Nginx untuk Magento
print_message "Mengkonfigurasi Nginx untuk Magento..."
cat <<EOF > /etc/nginx/sites-available/magento2
server {
    listen 80;
    server_name $MAGE_SERVER_NAME;
    set \$MAGE_ROOT /usr/share/nginx/html/magento2;
    set \$MAGE_MODE production;

    root \$MAGE_ROOT/pub;
    index index.php;
    autoindex off;
    charset UTF-8;
    error_page 404 403 = /errors/404.php;

    access_log /var/log/nginx/magento_access.log;
    error_log /var/log/nginx/magento_error.log;

    # Deny access to sensitive files
    location /.user.ini {
        deny all;
    }

    # PHP entry point for setup application
    location ~* ^/setup($|/) {
        root \$MAGE_ROOT;
        location ~ ^/setup/index.php {

            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php-magento.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param  PHP_FLAG  "session.auto_start=off \n suhosin.session.cryptua=off";
            fastcgi_param  PHP_VALUE "memory_limit=756M \n max_execution_time=600";
            fastcgi_read_timeout 600s;
            fastcgi_connect_timeout 600s;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
        }

        location ~ ^/setup/(?!pub/). {
            deny all;
        }

        location ~ ^/setup/pub/ {
            add_header X-Frame-Options "SAMEORIGIN";
        }
    }

    location ~* ^/update($|/) {
        root \$MAGE_ROOT;

        location ~ ^/update/index.php {
            fastcgi_split_path_info ^(/update/index.php)(/.+)$;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php-magento.sock;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            fastcgi_param  PATH_INFO        \$fastcgi_path_info;
        }

        # Deny everything but index.php
        location ~ ^/update/(?!pub/). {
            deny all;
        }

        location ~ ^/update/pub/ {
            add_header X-Frame-Options "SAMEORIGIN";
        }
    }

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    location /pub/ {
        location ~ ^/pub/media/(downloadable|customer|import|custom_options|theme_customization/.*\.xml) {
            deny all;
        }
        alias \$MAGE_ROOT/pub/;
        add_header X-Frame-Options "SAMEORIGIN";
    }

    location /static/ {
        # Uncomment the following line in production mode
        # expires max;

        # Remove signature of the static files that is used to overcome the browser cache
        location ~ ^/static/version\d*/ {
            rewrite ^/static/version\d*/(.*)$ /static/\$1 last;
        }

        location ~* \.(ico|jpg|jpeg|png|gif|svg|svgz|webp|avif|avifs|js|css|eot|ttf|otf|woff|woff2|html|json|webmanifest)$ {
            add_header Cache-Control "public";
            add_header X-Frame-Options "SAMEORIGIN";
            expires +1y;

            if (!-f \$request_filename) {
                rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
            }
        }
        location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
            add_header Cache-Control "no-store";
            add_header X-Frame-Options "SAMEORIGIN";
            expires    off;

            if (!-f \$request_filename) {
               rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
            }
        }
        if (!-f \$request_filename) {
            rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
        }
        add_header X-Frame-Options "SAMEORIGIN";
    }

    location /media/ {

        try_files \$uri \$uri/ /get.php\$is_args\$args;

        location ~ ^/media/theme_customization/.*\.xml {
            deny all;
        }

        location ~* \.(ico|jpg|jpeg|png|gif|svg|svgz|webp|avif|avifs|js|css|eot|ttf|otf|woff|woff2)$ {
            add_header Cache-Control "public";
            add_header X-Frame-Options "SAMEORIGIN";
            expires +1y;
            try_files \$uri \$uri/ /get.php\$is_args\$args;
        }
        location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
            add_header Cache-Control "no-store";
            add_header X-Frame-Options "SAMEORIGIN";
            expires    off;
            try_files \$uri \$uri/ /get.php\$is_args\$args;
        }
        add_header X-Frame-Options "SAMEORIGIN";
    }

    location /media/customer/ {
        deny all;
    }

    location /media/downloadable/ {
        deny all;
    }

    location /media/import/ {
        deny all;
    }

    location /media/custom_options/ {
        deny all;
    }

    location /errors/ {
        location ~* \.xml$ {
            deny all;
        }
    }

    # PHP entry point for main application
    location ~ ^/(index|get|static|errors/report|errors/404|errors/503|health_check)\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-magento.sock;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;

        fastcgi_param  PHP_FLAG  "session.auto_start=off \n suhosin.session.cryptua=off";
        fastcgi_param  PHP_VALUE "memory_limit=756M \n max_execution_time=18000";
        fastcgi_read_timeout 600s;
        fastcgi_connect_timeout 600s;

        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
    }

    gzip on;
    gzip_disable "msie6";

    gzip_comp_level 6;
    gzip_min_length 1100;
    gzip_buffers 16 8k;
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/js
        text/xml
        text/javascript
        application/javascript
        application/x-javascript
        application/json
        application/xml
        application/xml+rss
        image/svg+xml;
    gzip_vary on;

    # Banned locations (only reached if the earlier PHP entry point regexes don't match)
    location ~* (\.php$|\.phtml$|\.htaccess$|\.htpasswd$|\.git) {
        deny all;
    }
}

EOF

# Aktifkan konfigurasi Nginx
ln -s /etc/nginx/sites-available/magento2 /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx || print_error "Konfigurasi Nginx gagal"

# Cetak informasi akhir
print_message "Instalasi software pendukung selesai!"
echo "Detail database:"
echo "  Database: $MAGEDB_NAME"
echo "  Pengguna: $MAGEDB_USER"
echo "  Kata sandi: $MAGEDB_PASSWD"
echo "Lanjutkan dengan menginstal Magento menggunakan Composer di /usr/share/nginx/html/magento2."
