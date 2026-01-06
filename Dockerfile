# FreeScout for Bindi AI Support
# Build: 2026-01-06-v7 - PHP 7.4 bullseye (Debian 11) for stability
# Based on: https://github.com/freescout-helpdesk/freescout

FROM php:7.4-apache-bullseye

LABEL maintainer="Bindi AI Team <hello@bindi-ai.com>"
LABEL description="FreeScout Helpdesk for Bindi AI Support"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
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
        bcmath \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Enable Apache modules
RUN a2enmod rewrite headers

# Configure Apache for port 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

# Add Directory directive for Laravel
RUN printf '<Directory /var/www/html/public>\n    Options Indexes FollowSymLinks\n    AllowOverride All\n    Require all granted\n</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

# PHP configuration
RUN printf 'upload_max_filesize = 128M\npost_max_size = 128M\nmemory_limit = 256M\nmax_execution_time = 300\nmax_input_time = 300\ndisplay_errors = Off\nlog_errors = On\n' > /usr/local/etc/php/conf.d/freescout.ini

# Download and extract FreeScout
ENV FREESCOUT_VERSION=1.8.201
WORKDIR /var/www/html
RUN wget -q https://github.com/freescout-helpdesk/freescout/archive/refs/tags/${FREESCOUT_VERSION}.tar.gz -O /tmp/freescout.tar.gz \
    && tar -xzf /tmp/freescout.tar.gz --strip-components=1 -C /var/www/html \
    && rm /tmp/freescout.tar.gz

# Install PHP dependencies
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

# Create storage directories and set permissions
RUN mkdir -p storage/app/public storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache

# Create entrypoint script
RUN printf '#!/bin/bash\nset -e\necho "=== FreeScout v7 Starting ==="\ncd /var/www/html\nif [ ! -f .env ]; then\n  cat > .env << ENVEOF\nAPP_URL=${APP_URL:-http://localhost:8080}\nAPP_KEY=${APP_KEY:-}\nDB_CONNECTION=mysql\nDB_HOST=${DB_HOST:-localhost}\nDB_PORT=${DB_PORT:-3306}\nDB_DATABASE=${DB_DATABASE:-freescout}\nDB_USERNAME=${DB_USERNAME:-freescout}\nDB_PASSWORD=${DB_PASSWORD:-}\nAPP_DEBUG=false\nAPP_ENV=production\nAPP_TIMEZONE=Australia/Perth\nENVEOF\nfi\nif [ -z "$APP_KEY" ]; then php artisan key:generate --force 2>/dev/null || true; fi\nchown -R www-data:www-data storage bootstrap/cache\nchmod -R 775 storage bootstrap/cache\nphp artisan migrate --force 2>/dev/null || echo "Migration skipped"\nphp artisan config:cache 2>/dev/null || true\nexec apache2-foreground\n' > /usr/local/bin/start.sh \
    && chmod +x /usr/local/bin/start.sh

EXPOSE 8080

CMD ["/usr/local/bin/start.sh"]
