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

# Находим путь к исполняемому файлу Stalwart Mail
echo "Searching for stalwart-mail executable..."
STALWART_BIN=$(find / -name "stalwart-mail" -type f -executable 2>/dev/null | head -n 1)

if [ -z "$STALWART_BIN" ]; then
    echo "Could not find stalwart-mail executable. Listing all executables in /usr/bin and /usr/local/bin:"
    ls -la /usr/bin | grep -i stalwart || true
    ls -la /usr/local/bin | grep -i stalwart || true
    ls -la /bin | grep -i stalwart || true

    echo "Trying to find any stalwart-related files:"
    find / -name "*stalwart*" 2>/dev/null || true

    echo "Error: stalwart-mail executable not found. Trying to run the default command..."
    # Пробуем запустить команду по умолчанию из образа
    if [ -f /usr/local/bin/docker-entrypoint.sh ]; then
        exec /usr/local/bin/docker-entrypoint.sh
    else
        echo "Default entrypoint not found. Trying to run stalwart-smtp directly..."
        if command -v stalwart-smtp &> /dev/null; then
            exec stalwart-smtp -c /opt/stalwart-mail/etc/config.toml
        else
            echo "Fatal error: Could not find any stalwart executable."
            exit 1
        fi
    fi
else
    echo "Found Stalwart Mail executable at: $STALWART_BIN"
    # Запускаем сервер
    exec $STALWART_BIN -c /opt/stalwart-mail/etc/config.toml
fi
