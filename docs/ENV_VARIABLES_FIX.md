# Решение проблемы с отсутствующими переменными окружения

При запуске системы вы можете увидеть множество предупреждений вида:

```
WARN[0000] The "JWT_SECRET" variable is not set. Defaulting to a blank string.
WARN[0000] The "ANON_KEY" variable is not set. Defaulting to a blank string.
WARN[0000] The "SERVICE_ROLE_KEY" variable is not set. Defaulting to a blank string.
```

## Проблема с переменными для Supabase

Основная причина этих предупреждений - в Docker Compose файлах используются переменные `ANON_KEY` и `SERVICE_ROLE_KEY`, в то время как в файле `.env` они определены как `SUPABASE_ANON_KEY` и `SUPABASE_SERVICE_ROLE_KEY`. 

Несмотря на то, что значения хранятся в файле `.env`, Docker Compose не может их найти из-за различий в именах переменных.

## Автоматическое решение

### Для Linux/macOS

Используйте скрипт для автоматического исправления проблемы с переменными окружения:

```bash
./scripts/fix-env-vars.sh
```

После этого запустите систему с ограниченным параллелизмом:

```bash
./scripts/start-with-limited-parallelism.sh
```

Или воспользуйтесь комплексным скриптом, который исправляет переменные и запускает систему:

```bash
./scripts/fix-and-start.sh
```

### Для Windows

Для пользователей Windows предусмотрены PowerShell скрипты:

```powershell
# Только исправление переменных
.\scripts\fix-env-vars.ps1

# Исправление переменных и запуск системы
.\scripts\fix-and-start.ps1
```

## Ручное решение

Для ручного решения добавьте следующие строки в конец вашего файла `.env`:

```
# ---- SUPABASE ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ----
ANON_KEY=ваш_ключ_из_SUPABASE_ANON_KEY
SERVICE_ROLE_KEY=ваш_ключ_из_SUPABASE_SERVICE_ROLE_KEY
JWT_SECRET=ваш_ключ_из_SUPABASE_JWT_SECRET
```

Замените значения `ваш_ключ_из_*` на соответствующие значения из переменных `SUPABASE_*` в том же файле `.env`.

## Список обязательных переменных Supabase

Для корректной работы Supabase обязательными являются следующие переменные:

- `SUPABASE_ANON_KEY` - Анонимный ключ API Supabase
- `ANON_KEY` - То же значение, что и в SUPABASE_ANON_KEY (требуется для внутренних сервисов)
- `SUPABASE_SERVICE_ROLE_KEY` - Сервисный ключ API Supabase с расширенными правами
- `SERVICE_ROLE_KEY` - То же значение, что и в SUPABASE_SERVICE_ROLE_KEY (требуется для внутренних сервисов)
- `SUPABASE_JWT_SECRET` - Секретный ключ для JWT в Supabase
- `JWT_SECRET` - То же значение, что и в SUPABASE_JWT_SECRET (требуется для внутренних сервисов)
- `POSTGRES_USER` - Имя пользователя PostgreSQL
- `POSTGRES_PASSWORD` - Пароль пользователя PostgreSQL
- `SECRET_KEY_BASE` - Базовый секретный ключ для шифрования
- `VAULT_ENC_KEY` - Ключ шифрования для хранилища
- `LOGFLARE_API_KEY` - API-ключ для Logflare

### Переменные для Supabase
- `ANON_KEY` - Анонимный ключ для Supabase
- `SERVICE_ROLE_KEY` - Ключ сервисной роли для Supabase
- `POOLER_TENANT_ID` - ID арендатора пула соединений
- `POOLER_DEFAULT_POOL_SIZE` - Размер пула соединений по умолчанию
- `POOLER_MAX_CLIENT_CONN` - Максимальное количество клиентских соединений
- `POOLER_PROXY_PORT_TRANSACTION` - Порт прокси для транзакций
- `IMGPROXY_ENABLE_WEBP_DETECTION` - Включение обнаружения WebP
- `KONG_HTTP_PORT` - HTTP-порт для Kong
- `KONG_HTTPS_PORT` - HTTPS-порт для Kong
- `DASHBOARD_USERNAME` - Имя пользователя для панели управления
- `DASHBOARD_PASSWORD` - Пароль для панели управления
- `FUNCTIONS_VERIFY_JWT` - Проверка JWT для функций
- `SUPABASE_PUBLIC_URL` - Публичный URL для Supabase

### Настройки для Supabase Studio
- `STUDIO_DEFAULT_ORGANIZATION` - Организация по умолчанию
- `STUDIO_DEFAULT_PROJECT` - Проект по умолчанию

### Настройки для REST API
- `PGRST_DB_SCHEMAS` - Схемы базы данных для PostgreSQL REST

### Настройки для аутентификации
- `SMTP_ADMIN_EMAIL` - Email администратора SMTP
- `SMTP_HOST` - Хост SMTP-сервера
- `SMTP_PORT` - Порт SMTP-сервера
- `SMTP_USER` - Пользователь SMTP
- `SMTP_PASS` - Пароль SMTP
- `SMTP_SENDER_NAME` - Имя отправителя SMTP
- `SITE_URL` - URL сайта
- `API_EXTERNAL_URL` - Внешний URL API
- `ADDITIONAL_REDIRECT_URLS` - Дополнительные URL-адреса перенаправления
- `DISABLE_SIGNUP` - Отключение регистрации
- `ENABLE_EMAIL_SIGNUP` - Включение регистрации по email
- `ENABLE_EMAIL_AUTOCONFIRM` - Автоподтверждение email
- `ENABLE_PHONE_SIGNUP` - Включение регистрации по телефону
- `ENABLE_PHONE_AUTOCONFIRM` - Автоподтверждение телефона
- `ENABLE_ANONYMOUS_USERS` - Включение анонимных пользователей
- `MAILER_URLPATHS_INVITE` - URL-путь для приглашений
- `MAILER_URLPATHS_CONFIRMATION` - URL-путь для подтверждения
- `MAILER_URLPATHS_RECOVERY` - URL-путь для восстановления
- `MAILER_URLPATHS_EMAIL_CHANGE` - URL-путь для изменения email

## Предупреждение о версии Docker Compose

Вы также можете видеть предупреждения вида:

```
WARN[0000] /root/n8n-ai-starter-kit/compose/optional-services.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
WARN[0000] /root/n8n-ai-starter-kit/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
```

Это происходит потому, что атрибут `version` устарел в новых версиях Docker Compose. Мы уже удалили его из файлов, чтобы избавиться от этих предупреждений.
