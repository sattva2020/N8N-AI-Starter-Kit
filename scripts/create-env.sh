#!/bin/bash
# Автоматический скрипт создания .env файла для N8N AI Starter Kit

set -e

echo "=== Создание .env файла ==="

# Проверяем наличие template.env
if [ ! -f template.env ]; then
    echo "❌ Файл template.env не найден!"
    exit 1
fi

# Генерируем случайные значения
echo "🔑 Генерация паролей и ключей..."
postgres_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
n8n_encryption_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
n8n_jwt_secret=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
pgadmin_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
traefik_pwd=$(openssl rand -base64 16 | tr -cd '[:alnum:]' | cut -c1-12)
traefik_pwd_hash=$(echo -n "${traefik_pwd}" | md5sum | cut -d' ' -f1)

# Создаем резервную копию если .env уже существует
if [ -f .env ]; then
    backup_dir="./backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp .env "$backup_dir/.env.backup"
    echo "✅ Резервная копия сохранена в $backup_dir"
fi

# Копируем template.env в .env
cp template.env .env

# Заменяем placeholder значения
sed -i "s/change_this_secure_password_123/${postgres_pwd}/g" .env
sed -i "s/your_32_char_encryption_key_here_/${n8n_encryption_key}/g" .env
sed -i "s/your_jwt_secret_key_here_min_32_chars/${n8n_jwt_secret}/g" .env
sed -i "s/pgadmin_secure_password_123/${pgadmin_pwd}/g" .env
sed -i "s/admin@example.com/admin@sattva-ai.top/g" .env
sed -i "s/\\\$\\\$\\\$\\\$apr1\\\$\\\$\\\$\\\$1LF8GnRQ\\\$\\\$\\\$\\\$qBinSa\/CmAS\/lLy4vz6DL1/${traefik_pwd_hash}/g" .env

echo "✅ Файл .env создан успешно!"
echo ""
echo "🔐 Сгенерированные пароли:"
echo "  PostgreSQL: ${postgres_pwd}"
echo "  N8N Encryption Key: ${n8n_encryption_key}"
echo "  N8N JWT Secret: ${n8n_jwt_secret}"
echo "  PgAdmin: ${pgadmin_pwd}"
echo "  Traefik Dashboard: ${traefik_pwd}"
echo ""
echo "⚠️  Сохраните эти пароли в безопасном месте!"
