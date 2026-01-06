# FreeScout for Bindi AI Support
# Build: 2026-01-06-v8 - PHP 8.1 with ignore-platform-reqs
# Based on: https://github.com/freescout-helpdesk/freescout

FROM php:8.1-apache-bookworm

LABEL maintainer="Bindi AI Team"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev libicu-dev \
    libc-client-dev libkrb5-dev unzip wget curl git default-mysql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install gd mysqli pdo_mysql intl opcache zip imap mbstring bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Apache config for port 8080
RUN a2enmod rewrite headers \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' /etc/apache2/sites-available/000-default.conf \
    && printf '<Directory /var/www/html/public>\n  AllowOverride All\n  Require all granted\n</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

# PHP config
RUN printf 'memory_limit=256M\nupload_max_filesize=128M\npost_max_size=128M\n' > /usr/local/etc/php/conf.d/custom.ini

# Download FreeScout
WORKDIR /var/www/html
RUN wget -q https://github.com/freescout-helpdesk/freescout/archive/refs/tags/1.8.201.tar.gz -O /tmp/fs.tar.gz \
    && tar -xzf /tmp/fs.tar.gz --strip-components=1 && rm /tmp/fs.tar.gz

# Install deps ignoring PHP version constraints
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

# Permissions
RUN mkdir -p storage/app/public storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data /var/www/html && chmod -R 775 storage bootstrap/cache

# Startup script
COPY <<'EOF' /start.sh
#!/bin/bash
cd /var/www/html
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
php artisan key:generate --force 2>/dev/null || true
chown -R www-data:www-data storage bootstrap/cache
php artisan migrate --force 2>/dev/null || true
php artisan config:cache 2>/dev/null || true
exec apache2-foreground
EOF
RUN chmod +x /start.sh

EXPOSE 8080
CMD ["/start.sh"]
