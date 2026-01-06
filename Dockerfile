# FreeScout for Bindi AI Support
# Build: 2026-01-06-v11 - Extensions without IMAP

FROM php:8.1-apache-bookworm

# Install deps + extensions (no IMAP - optional for FreeScout)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev libicu-dev \
    unzip wget curl git default-mysql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd mysqli pdo_mysql intl opcache zip mbstring bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Apache port 8080
RUN a2enmod rewrite headers \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

RUN echo '<?php phpinfo(); ?>' > /var/www/html/index.php

EXPOSE 8080
CMD ["apache2-foreground"]
