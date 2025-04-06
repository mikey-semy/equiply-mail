# Stalwart Mail Server

## Установка

1. Клонируйте репозиторий
2. Создайте файл .env на основе .env.example
3. Запустите сервер:
   ```
   docker-compose up -d
   ```

## Настройка DNS

Для корректной работы почтового сервера необходимо настроить следующие DNS-записи:

- MX запись: `mail.equiply.ru` с приоритетом 10
- A запись: `mail.equiply.ru` указывающая на IP-адрес сервера
- SPF запись: `v=spf1 mx ~all`
- DKIM: будет настроен автоматически
- DMARC: `v=DMARC1; p=none; rua=mailto:admin@equiply.ru`
