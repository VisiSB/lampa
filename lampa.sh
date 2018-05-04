#!/bin/bash
HOST=""
USER=""
PASS=""
DOMAIN=""
IP=$(ifconfig |head -2| grep inet | awk '{print $2}' | cut -d ':' -f2)
   while test $# -gt 0; do
           case "$1" in
                --host)
                    shift
                    HOST=$1
                    shift
                    ;;
                --user)
                    shift
                    USER=$1
                    shift
                    ;;
                --pass)
                   shift
                   PASS=$1
                   shift
                   ;;
                --domain)
                   shift
                   DOMAIN=$1
                   shift
                   ;;
                  *)
                   echo "$1 is not a recognized flag!"
                   return 1;
                   ;;
          esac
  done

if [ "$HOST" != "" ] ; then
        continue
        else
        echo "Please specify the HOSTNAME with flag --host"
        return 1
fi

if [ "$USER" != "" ] ; then
        continue
        else
        echo "Please specify the HOSTNAME with flag --host"
        return 1
fi

if [ "$USER" != "" ] ; then
        continue
        else
        echo "Please specify the USERNAME with flag --user"
        return 1
fi
if [ "$DOMAIN" != "" ] ; then
        continue
        else
        echo "Please specify the DOMAIN with flag --domain"
        return 1
fi
if [ "$PASS" != "" ] ; then
        continue
        else
        echo "Please specify the PASSWORD with flag --pass"
        return 1
fi



echo "$IP       $HOST" >> /etc/hosts
echo $HOST > /etc/hostname

add-apt-repository -y ppa:ondrej/apache2
apt -y update
apt -y upgrade
ufw enable
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw reload

useradd -m $USER
usermod --password $PASS $USER
mkdir -p /home/$USER/public_html

apt -y install apache2
systemctl enable apache2
systemctl start apache2

apt -y install mysql-server
systemctl enable mysql
systemctl start mysql
mysql_secure_installation
apt -y install pure-ftpd

cat <<EOF > /root/.my.cnf
[client]
user=root
password=$PASS
EOF


apt install -y php7.0 php7.0-cgi php7.0-cli php7.0-fpm php7.0-mysql php7.0-curl php7.0-gd php7.0-mbstring php7.0-mcrypt php7.0-xmlrpc

apt -y install libapache2-mod-fcgid

a2enmod fcgi http2 ssl rewrite proxy_fcgi
touch /etc/apache2/sites-available/$domain.conf

cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost $IP:80>
        ServerName $DOMAIN
        ServerAlias www.$DOMAIN
        ServerAdmin webmaster@localhost
        DocumentRoot /home/$USER/public_html/

        Protocols h2 h2c http/1.1

        ProxyPassMatch ^/(.*\.php(/.*)?)$ unix:/run/php/php7.0-fpm.sock|fcgi://localhost/home/$USER/public_html

        <Directory />
            Options Indexes FollowSymLinks Includes ExecCGI
            AllowOverride All
            Require all granted
            Allow from all
        </Directory>
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined



</VirtualHost>
EOF

a2ensite $DOMAIN.conf
service apache2 restart

mysql -e "CREATE DATABASE wp_$USER; GRANT ALL ON wp_$USER.* TO '$USER'@'localhost' IDENTIFIED BY '$PASS'; FLUSH PRIVILEGES;"

cd /tmp && wget https://wordpress.org/latest.tar.gz

tar -xzvf latest.tar.gz

mv ./wordpress/* /home/$USER/public_html/ && touch /home/$USER/public_html/.htaccess

cat <<EOF > /home/$USER/public_html/wp-config.php
<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the
 * installation. You don't have to use the web site, you can
 * copy this file to "wp-config.php" and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * MySQL settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://codex.wordpress.org/Editing_wp-config.php
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define('DB_NAME', 'wp_$USER');

/** MySQL database username */
define('DB_USER', '$USER');

/** MySQL database password */
define('DB_PASSWORD', '$PASS');

/** MySQL hostname */
define('DB_HOST', 'localhost');

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', '');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');

define('FS_METHOD', 'direct');
define('FTP_PUBKEY','/home/$USER/.ssh/id_rsa.pub');
define('FTP_PRIKEY','/home/$USER/.ssh/id_rsa');
define('FTP_USER','$USER');
define('FTP_PASS','$PASS');
define('FTP_HOST','127.0.0.1:22');

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */

EOF

cat <<EOF >> /home/$USER/public_html/wp-config.php
$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
EOF

cat <<EOF >> /home/$USER/public_html/wp-config.php
/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
\$table_prefix  = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the Codex.
 *
 * @link https://codex.wordpress.org/Debugging_in_WordPress
 */
define('WP_DEBUG', false);

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
        define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
EOF

mkdir -p /home/$USER/public_html/wp-content/uploads

chown -R www-data:$USER /home/$USER/public_html

apt -y install software-properties-common
add-apt-repository -y ppa:certbot/certbot
apt-get update
apt-get -y install python-certbot-apache

certbot --apache

echo "Thank you for using LAMPA"
echo " :D "

echo "System will reboot in 5 seconds"
sleep 5

telinit 6

