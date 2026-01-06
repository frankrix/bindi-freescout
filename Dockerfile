# FreeScout for Bindi AI Support
# Build: 2026-01-06-v14 - Dist version, no composer

FROM php:8.1-apache-bookworm

# Minimal extensions
RUN docker-php-ext-install pdo_mysql mysqli

# Apache port 8080 and rewrite
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

RUN printf '<Directory /var/www/html/public>\n  AllowOverride All\n  Require all granted\n</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

# PHP config
RUN printf 'memory_limit=256M\nupload_max_filesize=50M\npost_max_size=50M\n' > /usr/local/etc/php/conf.d/freescout.ini

# Download FreeScout dist (with vendor)
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y wget unzip \
    && wget -q https://freescout.net/download/freescout-dist-latest.zip -O /tmp/fs.zip \
    && unzip -q /tmp/fs.zip -d /var/www/html \
    && rm /tmp/fs.zip \
    && apt-get remove -y wget unzip && apt-get autoremove -y && apt-get clean

# Permissions
RUN chown -R www-data:www-data /var/www/html && chmod -R 775 storage bootstrap/cache 2>/dev/null || true

# Startup
COPY <<'EOF' /start.sh
#!/bin/bash
cd /var/www/html
if [ ! -f .env ]; then
cat > .env << ENVFILE
APP_URL=${APP_URL:-http://localhost:8080}
APP_KEY=${APP_KEY:-}
DB_CONNECTION=mysql
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-freescout}
DB_USERNAME=${DB_USERNAME:-freescout}
DB_PASSWORD=${DB_PASSWORD:-}
APP_DEBUG=false
APP_ENV=production
ENVFILE
fi
php artisan key:generate --force 2>/dev/null || true
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
php artisan migrate --force 2>/dev/null || true
exec apache2-foreground
EOF
RUN chmod +x /start.sh

EXPOSE 8080
CMD ["/start.sh"]
