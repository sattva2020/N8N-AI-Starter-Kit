#!/bin/bash

# =============================================
# Исправление критических проблем N8N AI Starter Kit
# =============================================

set -e

echo "🔧 Исправление критических проблем окружения..."

# Проверяем наличие .env файла
if [ ! -f .env ]; then
    echo "❌ Файл .env не найден. Создайте его из template.env"
    exit 1
fi

# 1. Исправляем N8N encryption key mismatch
echo "🔑 Исправление N8N encryption key..."
if docker volume ls | grep -q "n8n-ai-starter-kit_n8n_storage"; then
    echo "🗑️ Удаление старого n8n volume для сброса encryption key..."
    docker compose down -v --remove-orphans 2>/dev/null || true
    docker volume rm n8n-ai-starter-kit_n8n_storage 2>/dev/null || true
fi

# 2. Генерируем новый encryption key если нужно
if grep -q "thCylTG+CZZ+49tGDS2FmOpca1Cc2oc1N2Mb+C4jeXY=" .env; then
    NEW_KEY=$(openssl rand -base64 32)
    echo "🔄 Обновление N8N_ENCRYPTION_KEY в .env..."
    sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_KEY}/" .env
fi

# 3. Проверяем переменные окружения
echo "🔍 Проверка переменных окружения..."

# Проверяем OpenAI API key
if ! grep -q "^OPENAI_API_KEY=" .env || grep -q "your_openai_api_key_here" .env; then
    echo "⚠️  ВНИМАНИЕ: OPENAI_API_KEY не настроен."
    echo "   Установите его для работы Graphiti и других AI сервисов:"
    echo "   sed -i 's/OPENAI_API_KEY=.*/OPENAI_API_KEY=your_actual_key/' .env"
fi

# Проверяем Neo4j переменные
if ! grep -q "^NEO4J_URI=" .env; then
    echo "➕ Добавление Neo4j переменных..."
    echo "" >> .env
    echo "# ---- NEO4J НАСТРОЙКИ ----" >> .env
    echo "NEO4J_URI=bolt://neo4j-zep:7687" >> .env
    echo "NEO4J_USER=neo4j" >> .env
    echo "NEO4J_PASSWORD=zepzepzep" >> .env
fi

# 4. Останавливаем все сервисы
echo "⏹️  Остановка всех сервисов..."
docker compose down --remove-orphans 2>/dev/null || true
docker compose -f compose/zep-compose.yaml down --remove-orphans 2>/dev/null || true
docker compose -f compose/supabase-compose.yml down --remove-orphans 2>/dev/null || true

# 5. Очистка проблемных volume'ов
echo "🧹 Очистка проблемных volumes..."
docker volume rm n8n-ai-starter-kit_postgres_storage 2>/dev/null || true
docker volume rm n8n-ai-starter-kit_n8n_storage 2>/dev/null || true

# 6. Запуск основных сервисов
echo "🚀 Запуск основных сервисов..."
docker compose up -d postgres traefik n8n qdrant ollama

# Ждем запуска PostgreSQL
echo "⏳ Ожидание запуска PostgreSQL..."
for i in {1..30}; do
    if docker compose exec postgres pg_isready -U root -d n8n >/dev/null 2>&1; then
        echo "✅ PostgreSQL готов"
        break
    fi
    echo "   Попытка $i/30..."
    sleep 2
done

# Ждем запуска N8N
echo "⏳ Ожидание запуска N8N..."
for i in {1..60}; do
    if curl -s http://localhost:5678 >/dev/null 2>&1; then
        echo "✅ N8N готов"
        break
    fi
    echo "   Попытка $i/60..."
    sleep 2
done

echo ""
echo "🎉 Исправление завершено!"
echo ""
echo "📋 Статус сервисов:"
echo "   N8N: http://localhost:5678"
echo "   Qdrant: http://localhost:6333"
echo "   Ollama: http://localhost:11434"
echo ""
echo "🔧 Для запуска дополнительных сервисов (Zep, Graphiti):"
echo "   1. Установите OPENAI_API_KEY в .env"
echo "   2. Запустите: docker compose -f compose/zep-compose.yaml up -d"
echo ""
echo "📊 Проверка состояния: ./scripts/comprehensive-container-check.sh"
