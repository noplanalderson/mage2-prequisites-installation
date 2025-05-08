#!/bin/bash

DOMAIN="yourdomain.com"
EMAIL="admin@yourdomain.com" # Ganti dengan email kamu
WWW_DOMAIN="www.${DOMAIN}"

echo "Memastikan snapd dan certbot terinstal..."
sudo apt update
sudo apt install -y snapd
sudo snap install core && sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "Mengecek konfigurasi domain di Nginx..."
sudo nginx -t || { echo "Konfigurasi Nginx error. Periksa dahulu."; exit 1; }

echo "Menjalankan certbot untuk mendapatkan sertifikat SSL..."
sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN --agree-tos --email $EMAIL --non-interactive --redirect

echo "Mengecek status SSL renewal otomatis..."
sudo systemctl status snap.certbot.renew.timer

echo "Selesai! SSL untuk $DOMAIN dan $WWW_DOMAIN berhasil dipasang.
