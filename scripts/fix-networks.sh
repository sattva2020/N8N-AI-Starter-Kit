#!/bin/bash

# 🔧 Быстрое исправление проблемы с сетями Docker Compose

echo "🔧 Исправление конфликта сетей Docker Compose"
echo "============================================="

# Остановить все контейнеры если они запущены
echo "Остановка существующих контейнеров..."
docker compose down 2>/dev/null || true
docker compose -f compose/ollama-compose.yml down 2>/dev/null || true

# Удалить проблемные сети если существуют
echo "Очистка конфликтующих сетей..."
docker network rm n8n-ai-starter-kit_backend 2>/dev/null || true
docker network rm n8n-ai-starter-kit_frontend 2>/dev/null || true
docker network rm n8n-ai-starter-kit_database 2>/dev/null || true

# Создать .env если не существует
if [[ ! -f ".env" ]] && [[ -f "template.env" ]]; then
    echo "Создание .env файла..."
    cp template.env .env
    echo "✅ .env файл создан"
fi

echo "✅ Конфликт сетей исправлен"
echo
echo "Теперь можете запустить:"
echo "   docker compose --profile cpu up -d"
echo
echo "Или для проверки конфигурации:"
echo "   docker compose config"
