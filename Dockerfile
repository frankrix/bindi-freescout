# FreeScout for Bindi AI Support
# Build: 2026-01-06-v5 - Use official tiredofit/freescout image
# Based on: https://hub.docker.com/r/tiredofit/freescout

FROM tiredofit/freescout:latest

LABEL maintainer="Bindi AI Team <hello@bindi-ai.com>"
LABEL description="FreeScout Helpdesk for Bindi AI Support"

# Map Sevalla env vars to FreeScout expected vars
# Sevalla provides: DB_HOST, DB_DATABASE, DB_PASSWORD, DB_PORT
# FreeScout expects: DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT

# Set defaults that will be overridden by Sevalla env vars at runtime
ENV DB_TYPE=mysql
ENV DB_PORT=3306
ENV SETUP_TYPE=AUTO
ENV ENABLE_SSL_PROXY=TRUE
ENV TIMEZONE=Australia/Perth

# Create wrapper script to map env vars
COPY <<'WRAPPER' /etc/cont-init.d/00-sevalla-env
#!/command/with-contenv bash

# Map Sevalla env vars to FreeScout expected vars
if [ -n "$DB_DATABASE" ] && [ -z "$DB_NAME" ]; then
    export DB_NAME="$DB_DATABASE"
    echo "DB_NAME=$DB_DATABASE" >> /etc/environment
    printf "$DB_DATABASE" > /run/s6/container_environment/DB_NAME
fi

if [ -n "$DB_USERNAME" ] && [ -z "$DB_USER" ]; then
    export DB_USER="$DB_USERNAME"
    echo "DB_USER=$DB_USERNAME" >> /etc/environment
    printf "$DB_USERNAME" > /run/s6/container_environment/DB_USER
fi

if [ -n "$DB_PASSWORD" ] && [ -z "$DB_PASS" ]; then
    export DB_PASS="$DB_PASSWORD"
    printf "$DB_PASSWORD" > /run/s6/container_environment/DB_PASS
fi

echo "=== Bindi AI FreeScout Starting ==="
echo "Build: 2026-01-06-v5"
echo "DB_HOST: ${DB_HOST:-not set}"
echo "DB_NAME: ${DB_NAME:-$DB_DATABASE}"
echo "=================================="
WRAPPER

RUN chmod +x /etc/cont-init.d/00-sevalla-env

# Override default ports - Sevalla requires 8080
ENV NGINX_LISTEN_PORT=8080

EXPOSE 8080
