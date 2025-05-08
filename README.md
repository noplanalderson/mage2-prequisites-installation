# Magento2 Installation

- Buat akun magento pada website https://account.magento.com/applications/customer/login
- atau bisa menggunakan single sign on (SSO) dengan akun google
- Setelah berhasil membuat akun dan login, pada halaman akun, klik My Profile
- Pada halaman My Profile, klik menu Access Keys
- Buat Access Keys baru dengan mengisi nama dan deskripsi, lalu klik tombol Create New Key
- Public Key dan Private Key akan otomatis dibuat, yang nantinya akan digunakan untuk username dan password saat instalasi Magento. Gunakan public key untuk username dan private key untuk password.
- Masuk ke server sebagai root, unduh file automation untuk instal software pendukung magento

  
```bash
# sudo apt install wget -y
# cd /home
# wget https://raw.githubusercontent.com/noplanalderson/mage2-prequisites-installation/refs/heads/main/mage-prequisites-install.sh
# chmod +x mage-prequisites-install.sh
```

- Sebelum menjalankan proses instalasi software pendukung, sesuaikan hak akses database dan server name

```bash
# nano mage-prequisites-install.sh
```

- Sesuaikan nilai pada variabel berikut
```bash
MAGEDB_NAME=magentodb
MAGEDB_USER=magentouser
MAGEDB_PASSWD=_Ch4n93M3e_ # HARAP DIUBAH!

MAGE_SERVER_NAME=k7commerce.my.id # Sesuaikan
```

- Simpan dan keluar kemudian jalankan perintah

```bash

# ./mage-prequisites-install.sh

```

- Buat password untuk user magento
```bash
# passwd magento
//  Atur  password  baru
//  Masuk  menggunakan  user  magento
# su magento
//  Masukkan  password  baru
```

- Jalankan perintah berikut
```bash
$  export  PATH=$PATH:/usr/share/nginx/html/magento2/bin
$  sudo  composer  create-project  --repository-url=https://repo.magento.com/  magento/project-community-edition  /usr/share/nginx/html/magento2/
Do  not  run  Composer  as  root/super  user!  See  https://getcomposer.org/root  for  details
Continue  as  root/super  user [yes]? yes
Creating  a  "magento/project-community-edition"  project  at  "/usr/share/nginx/html/magento2"
Warning  from  repo.magento.com:  You  haven't provided your Magento authentication keys. For instructions, visit https://devdocs.magento.com/guides/v2.3/install-gde/prereq/connect-auth.html
Authentication required (repo.magento.com):
Username: <public key>
Password: <private key> <-- Password tidak akan ditampilkan
Do you want to store credentials for repo.magento.com in /root/.config/composer/auth.json ? [Yn] Y
```

- Masukkan public key sebagai username dan private key sebagai password
- Tunggu hingga proses unduh selesai

```bash
$  cd  /usr/share/nginx/html/magento2/
$  sudo  find  var  generated  vendor  pub/static  pub/media  app/etc  -type  f  -exec  chmod  g+w  {}  +
$  sudo  find  var  generated  vendor  pub/static  pub/media  app/etc  -type  d  -exec  chmod  g+ws  {}  +
$  sudo  chown  -R  www-data:www-data  .
$  sudo  chmod  u+x  bin/magento
```
- Install SSL untuk nginx
```bash
$  cd  /home
$  sudo  wget  https://raw.githubusercontent.com/noplanalderson/mage2-prequisites-installation/refs/heads/main/ssl-certbot.sh
$  sudo  chmod  +x  mage-prequisites-install.sh
```
- Sebelum menjalankan proses instalasi SSL, sesuaikan variabel DOMAIN dan WWW_DOMAIN pada ssl-certbot.sh dengan direktif server_name pada server block nginx untuk magento2.
```bash
$  nano  ssl-certbot.sh
```
- Jika sudah, simpan dan keluar. Jalankan perintah berikut.
```bash
$  sudo  chmod  +x  ssl-certbot.sh
$  sudo  ./ssl-certbot.sh
```
- Mulai setup magento2
```bash
$  cd  /usr/share/nginx/html/magento2/bin/
$  sudo  ./magento  setup:install  \
--base-url-secure=https://k7commerce.my.id  \
--use-secure=1  \
--db-host=localhost  \
--db-name=magentodb  \
--db-user=magentouser  \
--db-password='_Ch4n93M3e_'  \
--admin-firstname=admin  \
--admin-lastname=k7  \
--admin-email=admin@k7commerce.my.id  \
--admin-user=admink7  \
--admin-password=@AdminKelompok7_  \
--language=id_ID  \
--currency=IDR  \
--timezone=Asia/Jakarta  \
--use-rewrites=1  \
--elasticsearch-host=localhost  \
--elasticsearch-port=9200  \
--elasticsearch-index-prefix=magento2  \
--elasticsearch-timeout=15  \
--use-secure-admin=1
```
- Jika proses instalasi berhasil, akan diatur secara otomatis halaman administratornya.
- Disable otentikasi 2 faktor (isu pengiriman kode verifikasi via email)
```bash
$  sudo  ./magento  module:disable  Magento_AdminAdobeImsTwoFactorAuth  Magento_TwoFactorAuth
$  sudo  ./magento  setup:upgrade
$  sudo  ./magento  cache:flush
```
- Buat cron untuk Magento
```bash
$  sudo  ./magento  cron:install
$  sudo  ./magento  cron:run
```  
- Lakukan pembatasan JVM heap size oleh elasticsearch
```bash
$  sudo  nano  /etc/elasticsearch/jvm.options
```
- Tambahkan kode berikut pada bagian paling bawah
```bash
-Xms2g
-Xmx2g
```
- Kemudian simpan dan keluar, serta restart service elasticsearch
```bash
$  sudo  systemctl  restart  elasticsearch
```
