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

# Генерируем случайный пароль администратора, если он не указан
if [ -z "$ADMIN_PASSWORD" ]; then
    export ADMIN_PASSWORD=$(openssl rand -base64 12)
    echo "🔑 Your administrator account is 'admin' with password '$ADMIN_PASSWORD'."
fi

# Создаем необходимые директории
mkdir -p /opt/stalwart-mail/data
mkdir -p /opt/stalwart-mail/etc
mkdir -p /opt/stalwart-mail/certs

# Проверяем наличие конфигурационного файла
if [ ! -f /opt/stalwart-mail/etc/config.toml ]; then
    echo "Configuration file not found, creating default config..."
    cp /opt/stalwart-mail/etc/config.toml.default /opt/stalwart-mail/etc/config.toml

    # Заменяем переменные в конфигурационном файле
    sed -i "s/\${MAIL_DOMAIN}/${MAIL_DOMAIN}/g" /opt/stalwart-mail/etc/config.toml
    sed -i "s/\${ADMIN_EMAIL}/${ADMIN_EMAIL}/g" /opt/stalwart-mail/etc/config.toml
    sed -i "s/\${ADMIN_PASSWORD}/${ADMIN_PASSWORD}/g" /opt/stalwart-mail/etc/config.toml
fi

# Запускаем cron в фоне
service cron start

# Получаем сертификат при первом запуске
/opt/stalwart-mail/scripts/renew-cert.sh

# Создаем самоподписанный сертификат, если не удалось получить через Let's Encrypt
if [ ! -f /opt/stalwart-mail/certs/fullchain.pem ] || [ ! -f /opt/stalwart-mail/certs/privkey.pem ]; then
    echo "Creating self-signed certificate..."
    openssl req -x509 -newkey rsa:4096 -keyout /opt/stalwart-mail/certs/privkey.pem -out /opt/stalwart-mail/certs/fullchain.pem -days 365 -nodes -subj "/CN=${MAIL_DOMAIN}"
    chmod 600 /opt/stalwart-mail/certs/privkey.pem
fi

# Выводим содержимое конфигурационного файла для отладки
echo "Current configuration:"
cat /opt/stalwart-mail/etc/config.toml

# Находим путь к исполняемому файлу Stalwart Mail
echo "Searching for stalwart executables..."
find / -name "*stalwart*" -type f -executable 2>/dev/null || echo "No stalwart executables found"

# Проверяем наличие исполняемых файлов в стандартных директориях
echo "Checking standard directories for stalwart executables..."
ls -la /usr/bin | grep -i stalwart || echo "No stalwart in /usr/bin"
ls -la /usr/local/bin | grep -i stalwart || echo "No stalwart in /usr/local/bin"

# Пробуем запустить сервер разными способами
if command -v stalwart-mail &> /dev/null; then
    echo "Found stalwart-mail in PATH"
    exec stalwart-mail -c /opt/stalwart-mail/etc/config.toml
elif command -v stalwart-smtp &> /dev/null; then
    echo "Found stalwart-smtp in PATH"
    exec stalwart-smtp -c /opt/stalwart-mail/etc/config.toml
elif [ -f /usr/local/bin/stalwart-mail ]; then
    echo "Found stalwart-mail in /usr/local/bin"
    exec /usr/local/bin/stalwart-mail -c /opt/stalwart-mail/etc/config.toml
elif [ -f /usr/bin/stalwart-mail ]; then
    echo "Found stalwart-mail in /usr/bin"
    exec /usr/bin/stalwart-mail -c /opt/stalwart-mail/etc/config.toml
else
    echo "Could not find stalwart executable. Trying to run the original entrypoint..."
    if [ -f /usr/local/bin/docker-entrypoint.sh ]; then
        exec /usr/local/bin/docker-entrypoint.sh
    else
        echo "Fatal error: Could not find any stalwart executable or entrypoint."
        # Выводим содержимое директорий для отладки
        echo "Contents of /usr/local/bin:"
        ls -la /usr/local/bin
        echo "Contents of /usr/bin:"
        ls -la /usr/bin
        exit 1
    fi
fi
