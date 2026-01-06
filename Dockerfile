# FreeScout for Bindi AI Support
# Build: 2026-01-06-v12 - Minimal extensions

FROM php:8.1-apache-bookworm

# Only pdo_mysql, mysqli
RUN docker-php-ext-install pdo_mysql mysqli

# Apache port 8080
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

RUN echo '<?php phpinfo(); ?>' > /var/www/html/index.php

EXPOSE 8080
CMD ["apache2-foreground"]
