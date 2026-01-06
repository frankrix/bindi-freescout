# Hesk Helpdesk for Bindi AI Support
# Build: 2026-01-06-v19 - Try Hesk (3MB, PHP 5.6-8.4)

FROM php:8.1-apache-bookworm

# MySQL extensions
RUN docker-php-ext-install pdo_mysql mysqli

# Apache config for port 8080
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

RUN printf '<Directory /var/www/html>\n  AllowOverride All\n  Require all granted\n</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

# Download Hesk
RUN apt-get update && apt-get install -y wget unzip \
    && wget -q "https://www.hesk.com/download/hesk370.zip" -O /tmp/hesk.zip \
    && unzip -q /tmp/hesk.zip -d /var/www/html \
    && rm /tmp/hesk.zip \
    && apt-get remove -y wget unzip && apt-get autoremove -y && apt-get clean

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 8080
CMD ["apache2-foreground"]
