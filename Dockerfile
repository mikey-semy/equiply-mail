FROM stalwartlabs/mail-server:latest

# Устанавливаем необходимые пакеты
RUN apt-get update && apt-get install -y \
    certbot \
    openssl \
    cron \
    python3-certbot-dns-cloudflare \
    && rm -rf /var/lib/apt/lists/*

# Создаем директории
RUN mkdir -p /opt/stalwart-mail/certs \
    /opt/stalwart-mail/scripts \
    /opt/stalwart-mail/data \
    /opt/stalwart-mail/etc \
    /etc/letsencrypt

# Копируем конфигурационный файл как шаблон
COPY config.toml /opt/stalwart-mail/etc/config.toml.default

# Копируем скрипты
COPY scripts/docker-entrypoint.sh /opt/stalwart-mail/scripts/docker-entrypoint.sh
COPY scripts/renew-cert.sh /opt/stalwart-mail/scripts/renew-cert.sh

# Устанавливаем права на выполнение
RUN chmod +x /opt/stalwart-mail/scripts/docker-entrypoint.sh \
    && chmod +x /opt/stalwart-mail/scripts/renew-cert.sh

# Настраиваем cron для обновления сертификатов
RUN echo "0 3 * * * /opt/stalwart-mail/scripts/renew-cert.sh >> /var/log/cert-renewal.log 2>&1" > /etc/cron.d/cert-renewal \
    && chmod 0644 /etc/cron.d/cert-renewal \
    && crontab /etc/cron.d/cert-renewal

# Точка входа
ENTRYPOINT ["sh", "/opt/stalwart-mail/scripts/docker-entrypoint.sh"]
