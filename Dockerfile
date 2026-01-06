# FreeScout for Bindi AI Support
# Build: 2026-01-06-v1 - Initial FreeScout setup
# Based on: https://github.com/freescout-helpdesk/freescout

FROM php:8.1-apache-bookworm

LABEL maintainer="Bindi AI Team <hello@bindi-ai.com>"
LABEL description="FreeScout Helpdesk for Bindi AI Support"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libc-client-dev \
    libkrb5-dev \
    unzip \
    wget \
    curl \
    git \
    cron \
    supervisor \
    default-mysql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
        gd \
        mysqli \
        pdo_mysql \
        gettext \
        intl \
        opcache \
        zip \
        imap \
        mbstring \
        xml \
        curl \
        bcmath \
        tokenizer \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Enable Apache modules
RUN a2enmod rewrite headers

# Configure Apache for port 8080 and FreeScout
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

# Set document root to public folder
RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

# Add Directory directive for Laravel
RUN echo '<Directory /var/www/html/public>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/sites-available/000-default.conf

# PHP configuration
RUN { \
    echo 'upload_max_filesize = 128M'; \
    echo 'post_max_size = 128M'; \
    echo 'memory_limit = 256M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    echo 'display_errors = Off'; \
    echo 'display_startup_errors = Off'; \
    echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT'; \
    echo 'log_errors = On'; \
    echo 'error_log = /var/log/php_errors.log'; \
} > /usr/local/etc/php/conf.d/freescout.ini

# Download and extract FreeScout
ENV FREESCOUT_VERSION=1.8.201
WORKDIR /var/www/html
RUN wget -q https://github.com/freescout-helpdesk/freescout/archive/refs/tags/${FREESCOUT_VERSION}.tar.gz -O /tmp/freescout.tar.gz \
    && tar -xzf /tmp/freescout.tar.gz --strip-components=1 -C /var/www/html \
    && rm /tmp/freescout.tar.gz

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Create storage directories and set permissions
RUN mkdir -p storage/app/public \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 storage bootstrap/cache \
    && touch /var/log/php_errors.log \
    && chown www-data:www-data /var/log/php_errors.log

# Create entrypoint
COPY <<'ENTRYPOINT' /usr/local/bin/freescout-entrypoint.sh
#!/bin/bash
set -e

echo "=== FreeScout Bindi AI Support Starting ==="
echo "Build: 2026-01-06-v1"
echo "FreeScout Version: 1.8.201"

cd /var/www/html

# Generate .env if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file from environment variables..."
    cat > .env << EOF
APP_URL=${APP_URL:-http://localhost:8080}
APP_KEY=${APP_KEY:-}

DB_CONNECTION=mysql
DB_HOST=${MYSQL_HOST:-localhost}
DB_PORT=3306
DB_DATABASE=${MYSQL_DATABASE:-freescout}
DB_USERNAME=${MYSQL_USER:-freescout}
DB_PASSWORD=${MYSQL_PASSWORD:-}

MAIL_DRIVER=smtp
MAIL_HOST=${MAIL_HOST:-smtp.mailgun.org}
MAIL_PORT=${MAIL_PORT:-587}
MAIL_USERNAME=${MAIL_USERNAME:-}
MAIL_PASSWORD=${MAIL_PASSWORD:-}
MAIL_ENCRYPTION=${MAIL_ENCRYPTION:-tls}

APP_DEBUG=false
APP_ENV=production
APP_TIMEZONE=Australia/Perth
EOF
fi

# Generate app key if not set
if [ -z "$APP_KEY" ]; then
    echo "Generating application key..."
    php artisan key:generate --force 2>/dev/null || true
fi

# Set permissions
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Run migrations
echo "Running database migrations..."
php artisan migrate --force 2>/dev/null || echo "Migrations skipped (may need database setup)"

# Clear and cache
php artisan config:cache 2>/dev/null || true
php artisan route:cache 2>/dev/null || true
php artisan view:cache 2>/dev/null || true

# Show environment
echo "=== Environment ==="
echo "APP_URL: ${APP_URL:-not set}"
echo "MYSQL_HOST: ${MYSQL_HOST:-not set}"
echo "MYSQL_DATABASE: ${MYSQL_DATABASE:-not set}"
echo "===================="

# Start Apache
echo "Starting Apache on port 8080..."
exec apache2-foreground
ENTRYPOINT

RUN chmod +x /usr/local/bin/freescout-entrypoint.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["/usr/local/bin/freescout-entrypoint.sh"]
