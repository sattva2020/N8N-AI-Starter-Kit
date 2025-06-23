#!/bin/bash
# =============================================
# N8N User Initialization Script (Bash)
# =============================================

set -e

echo "🔧 Инициализация пользователя N8N..."

# Ждем, пока PostgreSQL запустится
until pg_isready -U postgres; do
  echo "⏳ Ожидание PostgreSQL..."
  sleep 2
done

echo "✅ PostgreSQL готов"

# Проверяем, существует ли пользователь n8n
if psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='n8n'" | grep -q 1; then
    echo "✅ Пользователь n8n уже существует"
else
    echo "🔧 Создание пользователя n8n..."
    psql -U postgres -c "CREATE USER n8n WITH PASSWORD '${N8N_PASSWORD:-change_this_secure_password_123}';"
    echo "✅ Пользователь n8n создан"
fi

# Проверяем, существует ли база данных n8n
if psql -U postgres -lqt | cut -d \| -f 1 | grep -qw n8n; then
    echo "✅ База данных n8n уже существует"
else
    echo "🔧 Создание базы данных n8n..."
    psql -U postgres -c "CREATE DATABASE n8n OWNER n8n;"
    echo "✅ База данных n8n создана"
fi

# Даем права на базу данных
echo "🔧 Настройка прав доступа..."
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;"
psql -U postgres -d n8n -c "GRANT ALL ON SCHEMA public TO n8n;"

echo "✅ Инициализация N8N завершена"
