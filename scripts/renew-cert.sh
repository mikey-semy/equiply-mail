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

# Проверяем наличие сертификата
if [ -f "/etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem" ]; then
    # Проверяем срок действия сертификата
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem" | cut -d= -f2)
    CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_REMAINING=$(( ($CERT_EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

    if [ $DAYS_REMAINING -gt 30 ]; then
        echo "Certificate is still valid, no renewal needed"
        # Копируем сертификаты в директорию Stalwart Mail
        cp "/etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem" /opt/stalwart-mail/certs/fullchain.pem
        cp "/etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem" /opt/stalwart-mail/certs/privkey.pem
        chmod 644 /opt/stalwart-mail/certs/fullchain.pem
        chmod 600 /opt/stalwart-mail/certs/privkey.pem
        exit 0
    fi
fi

echo "Obtaining or renewing certificate for $MAIL_DOMAIN"

# Пытаемся получить сертификат с увеличенным временем ожидания DNS
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /opt/stalwart-mail/scripts/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    -d "$MAIL_DOMAIN" \
    --email "$ADMIN_EMAIL" \
    --agree-tos \
    --non-interactive \
    --deploy-hook "cp /etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem /opt/stalwart-mail/certs/fullchain.pem && cp /etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem /opt/stalwart-mail/certs/privkey.pem && chmod 644 /opt/stalwart-mail/certs/fullchain.pem && chmod 600 /opt/stalwart-mail/certs/privkey.pem"

# Проверяем, успешно ли получен сертификат
if [ ! -f "/etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem" ]; then
    echo "Failed to obtain certificate from Let's Encrypt, generating self-signed certificate"

    # Генерируем самоподписанный сертификат
    openssl req -x509 -newkey rsa:4096 -nodes -keyout /opt/stalwart-mail/certs/privkey.pem -out /opt/stalwart-mail/certs/fullchain.pem -days 365 -subj "/CN=$MAIL_DOMAIN" -addext "subjectAltName=DNS:$MAIL_DOMAIN"
    chmod 644 /opt/stalwart-mail/certs/fullchain.pem
    chmod 600 /opt/stalwart-mail/certs/privkey.pem
fi
