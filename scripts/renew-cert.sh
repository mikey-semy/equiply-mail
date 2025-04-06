#!/bin/bash
set -e

DOMAIN="${MAIL_DOMAIN:-mail.domain.com}"

# Проверяем наличие файла с учетными данными Cloudflare
if [ ! -f /opt/stalwart-mail/scripts/cloudflare.ini ]; then
    echo "Cloudflare credentials file not found. Cannot obtain certificate automatically."
    # Генерируем самоподписанный сертификат
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/stalwart-mail/certs/privkey.pem \
        -out /opt/stalwart-mail/certs/fullchain.pem \
        -subj "/CN=$DOMAIN"
    chmod 600 /opt/stalwart-mail/certs/*.pem
    exit 0
fi

# Проверяем, есть ли уже сертификат и не истек ли он
if [ ! -f /opt/stalwart-mail/certs/fullchain.pem ] || [ ! -f /opt/stalwart-mail/certs/privkey.pem ] || ! openssl x509 -checkend 2592000 -noout -in /opt/stalwart-mail/certs/fullchain.pem > /dev/null 2>&1; then
    echo "Obtaining or renewing certificate for $DOMAIN"

    # Пытаемся получить сертификат через DNS-challenge с API токеном
    if certbot certonly --dns-cloudflare --dns-cloudflare-credentials /opt/stalwart-mail/scripts/cloudflare.ini \
        -d "$DOMAIN" --non-interactive --agree-tos --email "${ADMIN_EMAIL:-admin@example.com}" \
        --cert-name "$DOMAIN" --deploy-hook "cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /opt/stalwart-mail/certs/ && cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /opt/stalwart-mail/certs/ && chmod 600 /opt/stalwart-mail/certs/*.pem"; then
        echo "Certificate successfully obtained/renewed"
    else
        # Если не удалось получить сертификат, генерируем самоподписанный
        echo "Failed to obtain certificate from Let's Encrypt, generating self-signed certificate"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /opt/stalwart-mail/certs/privkey.pem \
            -out /opt/stalwart-mail/certs/fullchain.pem \
            -subj "/CN=$DOMAIN"
        chmod 600 /opt/stalwart-mail/certs/*.pem
    fi
else
    echo "Certificate is still valid, no renewal needed"
fi
