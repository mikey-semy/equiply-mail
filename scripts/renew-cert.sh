#!/bin/bash
set -e

# Проверяем наличие переменных окружения
if [ -z "$MAIL_DOMAIN" ]; then
    echo "MAIL_DOMAIN environment variable not set. Cannot obtain certificate."
    exit 1
fi

if [ -z "$ADMIN_EMAIL" ]; then
    echo "ADMIN_EMAIL environment variable not set. Cannot obtain certificate."
    exit 1
fi

# Проверяем наличие файла с учетными данными Cloudflare
if [ ! -f /opt/stalwart-mail/scripts/cloudflare.ini ]; then
    echo "Cloudflare credentials file not found. Cannot obtain certificate using DNS challenge."
    exit 1
fi

# Проверяем наличие сертификата
if [ -f /opt/stalwart-mail/certs/fullchain.pem ] && [ -f /opt/stalwart-mail/certs/privkey.pem ]; then
    # Проверяем срок действия сертификата
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in /opt/stalwart-mail/certs/fullchain.pem | cut -d= -f2)
    CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_REMAINING=$(( (CERT_EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

    if [ $DAYS_REMAINING -gt 30 ]; then
        echo "Certificate is still valid, no renewal needed"
        exit 0
    fi
fi

# Создаем директорию для сертификатов
mkdir -p /opt/stalwart-mail/certs

# Получаем сертификат с помощью certbot и DNS-01 challenge
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /opt/stalwart-mail/scripts/cloudflare.ini \
    --email $ADMIN_EMAIL \
    --agree-tos \
    --non-interactive \
    --cert-name $MAIL_DOMAIN \
    -d $MAIL_DOMAIN \
    --deploy-hook "cp /etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem /opt/stalwart-mail/certs/fullchain.pem && cp /etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem /opt/stalwart-mail/certs/privkey.pem && chmod 600 /opt/stalwart-mail/certs/privkey.pem"

# Копируем сертификаты в директорию Stalwart Mail
cp /etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem /opt/stalwart-mail/certs/fullchain.pem
cp /etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem /opt/stalwart-mail/certs/privkey.pem
chmod 600 /opt/stalwart-mail/certs/privkey.pem

echo "Certificate has been obtained and installed"
