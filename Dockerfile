# FreeScout for Bindi AI Support
# Build: 2026-01-06-v16 - Download FreeScout

FROM php:8.1-apache-bookworm

# MySQL extensions
RUN docker-php-ext-install pdo_mysql mysqli

# Composer + wget
RUN apt-get update && apt-get install -y unzip curl git wget \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Apache config
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

RUN printf '<Directory /var/www/html/public>\n  AllowOverride All\n  Require all granted\n</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

# Download FreeScout from GitHub
WORKDIR /var/www/html
RUN wget -q https://github.com/freescout-helpdesk/freescout/archive/refs/tags/1.8.201.tar.gz -O /tmp/fs.tar.gz \
    && tar -xzf /tmp/fs.tar.gz --strip-components=1 \
    && rm /tmp/fs.tar.gz

# Create test page to verify download
RUN echo '<?php echo "FreeScout downloaded. Files: " . count(glob("*")); ?>' > /var/www/html/public/test.php

EXPOSE 8080
CMD ["apache2-foreground"]
