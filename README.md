# Práctica 1.1: Instalación de la pila LAMP en una instancia de AWS

Guía para instalar y configurar Apache HTTP Server, PHP, MySQL Server, phpMyAdmin, Adminer y GoAccess en Ubuntu Server. Los comandos usan los paquetes disponibles en los repositorios de Ubuntu; `apt` instala las versiones compatibles con la versión del sistema.

## 1. Requisitos y preparación

Se necesita una instancia de AWS con Ubuntu Server, acceso SSH con permisos `sudo` y conexión a Internet. En el grupo de seguridad de la instancia, permite:

- **SSH**, puerto 22, limitado a mi IP.
- **HTTP**, puerto 80, para acceder al sitio.
- **HTTPS**, puerto 443, si se configura TLS.

No abras el puerto 3306 de MySQL a Internet. Comprueba la versión del sistema y actualiza los paquetes:

```bash
lsb_release -ds
sudo apt update
sudo apt upgrade -y
```

## 2. Apache, PHP y MySQL

Instala Apache, MySQL y PHP con los módulos habituales:

```bash
sudo apt install -y apache2 mysql-server \
  php libapache2-mod-php php-mysql php-cli \
  php-curl php-gd php-mbstring php-xml php-zip
```

Activa los servicios para que arranquen al iniciar el sistema:

```bash
sudo systemctl enable --now apache2 mysql
```

Comprueba que Apache y MySQL están activos:

```bash
sudo systemctl status apache2 --no-pager
sudo systemctl status mysql --no-pager
```

Visita `http://IP_PUBLICA_DE_LA_INSTANCIA/`. La página predeterminada de Apache confirma que el servidor web responde.

### Probar PHP

Crea temporalmente una página de prueba:

```bash
echo '<?php phpinfo();' | sudo tee /var/www/html/info.php
```

Visita `http://IP_PUBLICA_DE_LA_INSTANCIA/info.php`. Después de comprobar PHP, elimina el archivo, ya que muestra información de configuración:

```bash
sudo rm /var/www/html/info.php
```

### Preparar una base de datos

Crea una base de datos y un usuario local para la aplicación. Sustituye `CAMBIA_ESTA_CLAVE` por una contraseña segura:

```bash
sudo mysql
```

En la consola de MySQL:

```sql
CREATE DATABASE aplicacion CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lampuser'@'localhost' IDENTIFIED BY 'CAMBIA_ESTA_CLAVE';
GRANT ALL PRIVILEGES ON aplicacion.* TO 'lampuser'@'localhost';
EXIT;
```

El usuario queda limitado a conexiones locales. No uses la cuenta `root` de MySQL desde una aplicación.

## 3. phpMyAdmin

phpMyAdmin proporciona una interfaz web para administrar MySQL. Instálalo desde los repositorios de Ubuntu:

```bash
sudo apt install -y phpmyadmin
```

Durante la instalación:

1. Selecciona **apache2** en la lista de servidores web y confirma con la barra espaciadora.
2. Si se pregunta si se debe configurar la base de datos con `dbconfig-common`, selecciona **Sí** y sigue las instrucciones.

Comprueba la configuración y reinicia Apache:

```bash
test -e /etc/apache2/conf-available/phpmyadmin.conf && sudo a2enconf phpmyadmin
sudo systemctl reload apache2
```

Accede a `http://IP_PUBLICA_DE_LA_INSTANCIA/phpmyadmin` e inicia sesión con un usuario de MySQL. No expongas esta interfaz públicamente sin protección: utiliza HTTPS y limita el acceso por IP, VPN u otro mecanismo adecuado.

## 4. Adminer

Adminer es otra interfaz web de administración de bases de datos, distribuida como una aplicación PHP. Instálalo:

```bash
sudo apt install -y adminer
```

Si el paquete proporciona una configuración de Apache, actívala y recarga el servicio:

```bash
test -e /etc/apache2/conf-available/adminer.conf && sudo a2enconf adminer
sudo systemctl reload apache2
```

Accede a `http://IP_PUBLICA_DE_LA_INSTANCIA/adminer` si esa ruta está habilitada por el paquete. En la pantalla de inicio de sesión selecciona **MySQL** y utiliza como servidor `localhost`, junto con las credenciales de MySQL.

Al igual que phpMyAdmin, Adminer debe protegerse y no debería quedar expuesto sin HTTPS y restricciones de acceso.

## 5. GoAccess para analizar logs de Apache

GoAccess analiza los registros de acceso de Apache y puede mostrar estadísticas en la terminal:

```bash
sudo apt install -y goaccess
sudo goaccess /var/log/apache2/access.log --log-format=COMBINED
```

Usa las flechas del teclado para navegar por el informe y `q` para salir. Para generar un informe HTML en tu directorio personal:

```bash
sudo goaccess /var/log/apache2/access.log \
  --log-format=COMBINED \
  -o "$HOME/informe-goaccess.html"
sudo chown "$USER":"$USER" "$HOME/informe-goaccess.html"
```

El informe puede contener datos de actividad del sitio; evita publicarlo en un directorio web sin controlar quién puede acceder.

## 6. Control de acceso con `.htaccess`

Esta configuración protege un directorio con autenticación básica. Para usarla de forma segura, habilita HTTPS: las credenciales de autenticación básica no están cifradas si se transmiten por HTTP.

Crea el directorio y una contraseña para el usuario `alumno`:

```bash
sudo mkdir -p /var/www/html/privado
sudo htpasswd -c /etc/apache2/.htpasswd alumno
```

El comando `htpasswd` solicita la contraseña. Para agregar más usuarios posteriormente, vuelve a ejecutarlo **sin** `-c`, porque esa opción crea un archivo nuevo.

Permite que Apache lea las directivas de autenticación de `.htaccess`:

```bash
sudo tee /etc/apache2/conf-available/privado.conf >/dev/null <<'EOF'
<Directory "/var/www/html/privado">
    AllowOverride AuthConfig
</Directory>
EOF

sudo a2enconf privado
```

Crea `/var/www/html/privado/.htaccess`:

```bash
sudo tee /var/www/html/privado/.htaccess >/dev/null <<'EOF'
AuthType Basic
AuthName "Área privada"
AuthUserFile /etc/apache2/.htpasswd
Require valid-user
EOF
```

Comprueba la configuración y recarga Apache:

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
```

Crea una página de prueba y visita `http://IP_PUBLICA_DE_LA_INSTANCIA/privado/`. Apache debe solicitar el usuario y la contraseña:

```bash
echo '<h1>Acceso autorizado</h1>' | sudo tee /var/www/html/privado/index.html
```

## 7. Comprobaciones finales

```bash
sudo systemctl is-active apache2
sudo systemctl is-active mysql
sudo apache2ctl configtest
```

El servidor MySQL debe permanecer accesible solo desde la instancia, salvo que exista una necesidad concreta y una configuración de red segura.
