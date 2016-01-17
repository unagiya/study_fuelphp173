#!/bin/bash
yum -y update kernel
yum -y install kernel-devel kernel-headers dkms gcc gcc-c++

localectl set-locale LANG=ja_JP.UTF-8
export LANG=ja_JP.UTF-8

echo "yum installs"

yum localinstall -y http://ftp.iij.ad.jp/pub/linux/fedora/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum localinstall -y http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum localinstall -y http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum localinstall -y http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm

yum install -y git
yum install -y --enablerepo=remi --enablerepo=remi-php56 php php-mbstring php-xml php-pdo php-fpm php-soap php-mysqlnd php-pecl-redis
yum install -y nginx
yum install -y ld-linux.so.2 libstdc++.so.6
yum install -y --enablerepo=mysql56-community install mysql-community-server
yum install -y redis

echo "config set"

cp -p /etc/nginx/nginx.conf /etc/nginx/conf.d/nginx.conf.bak

cat << 'EOF' > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log  /var/log/nginx/access.log  main;
    
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    
    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        server_name  localhost;
        
        root           /var/www/html/studyprj/public;

        location / {
            index index.php;
            try_files $uri $uri/ /index.php$is_args$args;
        }
        
        gzip              on;
        gzip_types        text/css
                              application/javascript;
        gzip_static       always;

        location ~ \.php$ {
            fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
            fastcgi_index  index.php;
            fastcgi_param SCRIPT_FILENAME  $document_root/$fastcgi_script_name;
            fastcgi_param FUEL_ENV "development";
            include        fastcgi_params;
        }

    }
    server {
        listen       81;
        server_name  localhost;
        
        root           /var/www/html/vanilla;
        
        location / {
            index index.php;
            try_files $uri $uri/ /index.php$is_args$args;
        }
        
        gzip              on;
        gzip_types        text/css
                          application/javascript;
        gzip_static       always;
        
        location ~ \.php$ {
            fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
            fastcgi_index  index.php;
            fastcgi_param SCRIPT_FILENAME  $document_root/$fastcgi_script_name;
            include        fastcgi_params;
        }

    }
}
EOF

sed -i -e '/^$/d' /etc/nginx/nginx.conf

echo "config sed"

sed -i -e "s|^listen =.*|listen = /var/run/php-fpm/php-fpm.sock|g" /etc/php-fpm.d/www.conf
sed -i -e "s|;listen.owner =.*|listen.owner = nginx|g" /etc/php-fpm.d/www.conf
sed -i -e "s|;listen.group =.*|listen.group = nginx|g" /etc/php-fpm.d/www.conf
sed -i -e "s|;date.timezone =.*|date.timezone = \"Asia/Tokyo\"|g" /etc/php.ini

echo "service restart"

systemctl enable php-fpm
systemctl restart php-fpm
systemctl enable nginx
systemctl restart nginx
systemctl enable mysqld.service
systemctl restart mysqld.service
systemctl enable redis
systemctl restart redis
systemctl disable firewalld
systemctl stop firewalld
setenforce 0
sed -i.bak "/SELINUX/s/enforcing/disabled/g" /etc/selinux/config

rm -rf /etc/nginx/conf.d/default.conf
rm -rf /etc/nginx/conf.d/example_ssl.conf

echo "MySql set"
mysql -uroot -e'create database study_fuel'