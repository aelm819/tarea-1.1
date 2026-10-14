#!/usr/bin/env bash
# filepath: /home/ubuntu/tarea-1.1/install_tools.sh
set -Eeuo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Ejecuta el script con sudo: sudo bash ./install_tools.sh" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Configurar phpMyAdmin para Apache sin configurar una base de datos adicional.
if command -v debconf-set-selections >/dev/null 2>&1; then
    printf '%s\n' \
        'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' \
        'phpmyadmin phpmyadmin/dbconfig-install boolean false' \
        | debconf-set-selections
fi

apt-get install -y \
    apache2 \
    libapache2-mod-php \
    php \
    php-curl \
    php-gd \
    php-mbstring \
    php-mysql \
    php-xml \
    php-zip \
    phpmyadmin \
    goaccess \
    apache2-utils \
    curl

# Habilitar la configuración de Apache de phpMyAdmin, si está disponible.
if [[ ! -e /etc/apache2/conf-available/phpmyadmin.conf ]] \
    && [[ -f /etc/phpmyadmin/apache.conf ]]; then
    ln -s /etc/phpmyadmin/apache.conf \
        /etc/apache2/conf-available/phpmyadmin.conf
fi

if [[ -e /etc/apache2/conf-available/phpmyadmin.conf ]]; then
    a2enconf phpmyadmin
fi

# Instalar Adminer desde su distribución oficial.
install -d -m 755 /var/www/html/adminer
curl --fail --silent --show-error --location \
    https://www.adminer.org/latest.php \
    --output /var/www/html/adminer/index.php
chown root:root /var/www/html/adminer/index.php
chmod 644 /var/www/html/adminer/index.php

systemctl enable --now apache2
apache2ctl configtest
systemctl reload apache2

echo "Instalación completada."
echo "phpMyAdmin: http://IP_PUBLICA/phpmyadmin"
echo "Adminer:    http://IP_PUBLICA/adminer/"
echo "GoAccess:   sudo goaccess /var/log/apache2/access.log --log-format=COMBINED"