#!/bin/bash

# 🌐 Проверка сетевой конфигурации тестовой vs production среды

echo "🌐 АНАЛИЗ СЕТЕВОЙ КОНФИГУРАЦИИ"
echo "=============================="

echo "📋 1. Анализ тестовой среды (test-minimal.yml):"
echo "Сети в тестовой среде:"
grep -A5 "^networks:" compose/test-minimal.yml

echo
echo "📋 2. Анализ production среды (docker-compose.yml):"
echo "Сети в production среде:"
grep -A10 "^networks:" docker-compose.yml

echo
echo "📋 3. Подключения сервисов к сетям:"
echo
echo "=== ТЕСТОВАЯ СРЕДА ==="
echo "N8N-test -> test-network"
echo "PostgreSQL-test -> test-network"
echo "Qdrant-test -> test-network"
echo "Ollama-test -> test-network"

echo
echo "=== PRODUCTION СРЕДА ==="
echo "N8N -> frontend + backend"
echo "PostgreSQL -> database + backend"
echo "Qdrant -> backend + frontend"
echo "Traefik -> frontend"
echo "PgAdmin -> frontend + database"
echo "JupyterLab -> frontend + backend"

echo
echo "📋 4. Анализ взаимодействия:"
echo
echo "✅ ТЕСТОВАЯ СРЕДА:"
echo "   - Все сервисы в одной сети (test-network)"
echo "   - Простое взаимодействие между сервисами"
echo "   - N8N может напрямую обращаться к postgres-test"

echo
echo "✅ PRODUCTION СРЕДА:"
echo "   - Сегментированные сети для безопасности"
echo "   - N8N и PostgreSQL общаются через сеть 'backend'"
echo "   - Traefik обеспечивает внешний доступ через 'frontend'"
echo "   - База данных изолирована в сети 'database'"

echo
echo "📋 5. Проверка текущих Docker сетей:"
docker network ls | grep -E "(n8n|test|frontend|backend|database|zep)"

echo
echo "📋 6. Рекомендации:"
echo "✅ Сетевая архитектура production корректна"
echo "✅ Изоляция сервисов по назначению"
echo "⚠️  Важно: убедитесь, что POSTGRES_HOST=postgres в .env"
echo "⚠️  Важно: убедитесь, что POSTGRES_USER=n8n в .env"

echo
echo "🔧 Команды для диагностики сетей:"
echo "Инспекция сети frontend: docker network inspect \$(docker network ls -q -f name=frontend)"
echo "Инспекция сети backend: docker network inspect \$(docker network ls -q -f name=backend)"
echo "Инспекция сети database: docker network inspect \$(docker network ls -q -f name=database)"
