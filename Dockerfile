# FreeScout for Bindi AI Support
# Build: 2026-01-06-v15 - Step by step

FROM php:8.1-apache-bookworm

# Step 1: MySQL extensions only (v12 worked)
RUN docker-php-ext-install pdo_mysql mysqli

# Step 2: Install composer
RUN apt-get update && apt-get install -y unzip curl git \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Step 3: Apache config
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

# Test page
RUN echo '<?php echo "Step 1-3 OK. Composer: " . shell_exec("composer --version"); phpinfo(); ?>' > /var/www/html/index.php

EXPOSE 8080
CMD ["apache2-foreground"]
