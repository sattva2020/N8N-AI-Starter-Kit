#!/bin/bash

# 🧪 Скрипт для запуска тестирования N8N AI Starter Kit

echo "🧪 Запуск тестирования N8N AI Starter Kit"
echo "========================================"

# Проверяем, что мы в правильной директории
if [[ ! -f "compose/test-minimal.yml" ]]; then
    echo "❌ Ошибка: Запустите этот скрипт из корневой директории проекта"
    exit 1
fi

# Остановка существующих контейнеров
echo "📋 1. Остановка существующих контейнеров..."
docker compose down 2>/dev/null || true
docker compose -f compose/test-minimal.yml down 2>/dev/null || true

# Очистка сетей и томов (опционально)
read -p "Очистить тестовые тома и сети? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 Очистка тестовых ресурсов..."
    docker volume rm n8n-ai-starter-kit_n8n_storage_test 2>/dev/null || true
    docker volume rm n8n-ai-starter-kit_postgres_storage_test 2>/dev/null || true
    docker volume rm n8n-ai-starter-kit_qdrant_storage_test 2>/dev/null || true
    docker network prune -f
fi

# Выбор профиля тестирования
echo
echo "📋 2. Выберите профиль тестирования:"
echo "1) minimal - Только N8N + PostgreSQL (рекомендуется)"
echo "2) test-qdrant - N8N + PostgreSQL + Qdrant"
echo "3) test-ai - N8N + PostgreSQL + Qdrant + Ollama"
echo
read -p "Введите номер (1-3) [по умолчанию: 1]: " choice

case $choice in
    2)
        PROFILE="--profile minimal --profile test-qdrant"
        echo "🎯 Запуск тестирования с Qdrant..."
        ;;
    3)
        PROFILE="--profile minimal --profile test-qdrant --profile test-ai"
        echo "🎯 Запуск полного тестирования с AI..."
        ;;
    *)
        PROFILE="--profile minimal"
        echo "🎯 Запуск минимального тестирования..."
        ;;
esac

# Запуск тестирования
echo
echo "📋 3. Запуск контейнеров..."
if docker compose -f compose/test-minimal.yml $PROFILE up -d; then
    echo "✅ Контейнеры запущены успешно"
else
    echo "❌ Ошибка при запуске контейнеров"
    exit 1
fi

# Ожидание готовности сервисов
echo
echo "📋 4. Ожидание готовности сервисов..."
echo "Ожидание PostgreSQL..."
for i in {1..30}; do
    if docker exec n8n-ai-starter-kit-postgres-test-1 pg_isready -U postgres >/dev/null 2>&1; then
        echo "✅ PostgreSQL готов"
        break
    fi
    echo -n "."
    sleep 2
done

echo "Ожидание N8N..."
sleep 10
for i in {1..30}; do
    if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
        echo "✅ N8N готов"
        break
    fi
    echo -n "."
    sleep 2
done

# Проверка статуса
echo
echo "📋 5. Статус сервисов:"
docker compose -f compose/test-minimal.yml ps

# Проверка доступности
echo
echo "📋 6. Проверка доступности:"
local_ip=$(hostname -I | awk '{print $1}')

echo "🌐 N8N Web Interface:"
echo "   Local: http://localhost:5678"
echo "   Network: http://$local_ip:5678"

if [[ "$PROFILE" == *"test-qdrant"* ]]; then
    echo "🗄️  Qdrant Dashboard:"
    echo "   Local: http://localhost:6333/dashboard"
    echo "   Network: http://$local_ip:6333/dashboard"
fi

if [[ "$PROFILE" == *"test-ai"* ]]; then
    echo "🤖 Ollama API:"
    echo "   Local: http://localhost:11434"
    echo "   Network: http://$local_ip:11434"
fi

echo
echo "📋 7. Полезные команды:"
echo "   Логи всех сервисов: docker compose -f compose/test-minimal.yml logs -f"
echo "   Логи N8N: docker compose -f compose/test-minimal.yml logs -f n8n-test"
echo "   Остановка: docker compose -f compose/test-minimal.yml down"
echo "   Перезапуск: docker compose -f compose/test-minimal.yml restart"
echo
echo "🎉 Тестирование запущено! Откройте http://localhost:5678 для доступа к N8N"
