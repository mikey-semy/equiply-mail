#!/bin/bash
set -e

# Создаем файл с учетными данными Cloudflare из переменной окружения
if [ ! -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > /opt/stalwart-mail/scripts/cloudflare.ini
    chmod 600 /opt/stalwart-mail/scripts/cloudflare.ini
    echo "Cloudflare credentials file created from environment variable"
else
    echo "CLOUDFLARE_API_TOKEN environment variable not set. Cannot create credentials file."
fi

# Проверяем наличие конфигурационного файла
if [ ! -f /opt/stalwart-mail/etc/config.toml ]; then
    echo "Configuration file not found, creating default config..."
    cp /opt/stalwart-mail/etc/config.toml.default /opt/stalwart-mail/etc/config.toml

    # Заменяем переменные в конфигурационном файле
    sed -i "s/\${MAIL_DOMAIN}/${MAIL_DOMAIN}/g" /opt/stalwart-mail/etc/config.toml
fi

# Запускаем cron в фоне
service cron start

# Получаем сертификат при первом запуске
/opt/stalwart-mail/scripts/renew-cert.sh

# Запускаем оригинальный entrypoint
exec /bin/sh /usr/local/bin/docker-entrypoint.sh "$@"
