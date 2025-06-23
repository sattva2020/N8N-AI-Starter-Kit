#!/bin/bash

# 🔄 Сравнение тестовой и production-среды N8N AI Starter Kit

echo "🔄 СРАВНЕНИЕ ТЕСТОВОЙ И PRODUCTION-СРЕДЫ"
echo "========================================"

echo "📋 1. Запуск диагностики тестовой среды:"
echo "----------------------------------------"

# Запускаем тестовую среду
echo "🚀 Запуск тестовой среды..."
docker compose -f compose/test-minimal.yml --profile test up -d

# Ждем запуска
echo "⏳ Ожидание запуска сервисов (30 секунд)..."
sleep 30

# Проверяем тестовую среду
echo "🧪 Проверка тестовой среды:"
test_n8n_status="❌"
test_postgres_status="❌"
test_containers=0

if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    test_n8n_status="✅"
fi

if docker exec compose-postgres-test-1 pg_isready -U postgres >/dev/null 2>&1; then
    test_postgres_status="✅"
fi

test_containers=$(docker compose -f compose/test-minimal.yml --profile test ps --format "table {{.Service}}" | grep -v SERVICE | wc -l)

echo "   N8N: $test_n8n_status"
echo "   PostgreSQL: $test_postgres_status"
echo "   Контейнеров: $test_containers"

# Останавливаем тестовую среду
echo "🛑 Остановка тестовой среды..."
docker compose -f compose/test-minimal.yml --profile test down

echo
echo "📋 2. Запуск диагностики production-среды:"
echo "------------------------------------------"

# Запускаем production
echo "🚀 Запуск production-среды..."
docker compose --profile cpu up -d

# Ждем запуска (дольше, так как больше сервисов)
echo "⏳ Ожидание запуска сервисов (60 секунд)..."
sleep 60

# Проверяем production
echo "🏭 Проверка production-среды:"
prod_n8n_status="❌"
prod_postgres_status="❌"
prod_ollama_status="❌"
prod_qdrant_status="❌"
prod_containers=0

if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    prod_n8n_status="✅"
fi

if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then
    prod_postgres_status="✅"
fi

if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then
    prod_ollama_status="✅"
fi

if curl -s -f http://localhost:6333/health >/dev/null 2>&1; then
    prod_qdrant_status="✅"
fi

prod_containers=$(docker compose ps --format "table {{.Service}}" | grep -v SERVICE | wc -l)

echo "   N8N: $prod_n8n_status"
echo "   PostgreSQL: $prod_postgres_status"
echo "   Ollama: $prod_ollama_status"
echo "   Qdrant: $prod_qdrant_status"
echo "   Контейнеров: $prod_containers"

echo
echo "📋 3. СРАВНИТЕЛЬНАЯ ТАБЛИЦА:"
echo "============================"

echo "| Компонент     | Тест  | Production | Статус     |"
echo "|---------------|-------|------------|------------|"
echo "| N8N           | $test_n8n_status    | $prod_n8n_status         | $([ "$test_n8n_status" = "$prod_n8n_status" ] && echo "✅ Совпадает" || echo "⚠️  Отличается") |"
echo "| PostgreSQL    | $test_postgres_status    | $prod_postgres_status         | $([ "$test_postgres_status" = "$prod_postgres_status" ] && echo "✅ Совпадает" || echo "⚠️  Отличается") |"
echo "| Ollama        | ➖    | $prod_ollama_status         | 🆕 Только в Prod |"
echo "| Qdrant        | ➖    | $prod_qdrant_status         | 🆕 Только в Prod |"
echo "| Контейнеры    | $test_containers     | $prod_containers          | $([ $test_containers -lt $prod_containers ] && echo "✅ Prod больше" || echo "⚠️  Проверить") |"

echo
echo "📋 4. АНАЛИЗ РАЗЛИЧИЙ:"
echo "====================="

echo "🧪 Тестовая среда (минимальная):"
echo "   - Только базовые компоненты (N8N + PostgreSQL)"
echo "   - Быстрый запуск и тестирование"
echo "   - Низкое потребление ресурсов"
echo "   - Префикс контейнеров: compose-*-test-1"

echo
echo "🏭 Production-среда (полная):"
echo "   - Все AI-компоненты (Ollama, Qdrant, Graphiti)"
echo "   - Полный функционал для работы с AI"
echo "   - Больше ресурсов и времени запуска"
echo "   - Стандартные имена контейнеров"

echo
echo "📋 5. РЕКОМЕНДАЦИИ:"
echo "=================="

if [ "$test_n8n_status" = "✅" ] && [ "$prod_n8n_status" = "✅" ]; then
    echo "✅ Основная функциональность работает в обеих средах"
    echo "✅ Можно безопасно использовать production для реальной работы"
    
    if [ "$prod_ollama_status" = "✅" ] && [ "$prod_qdrant_status" = "✅" ]; then
        echo "✅ AI-компоненты работают корректно"
        echo "🚀 Production-среда полностью готова для AI-workflows"
    else
        echo "⚠️  Проблемы с AI-компонентами в production"
        echo "🔧 Проверьте логи: docker compose logs ollama qdrant"
    fi
    
else
    echo "❌ Обнаружены проблемы в одной или обеих средах"
    echo "🔧 Требуется диагностика и исправление"
fi

echo
echo "📋 6. СЛЕДУЮЩИЕ ШАГИ:"
echo "===================="

if [ "$prod_n8n_status" = "✅" ] && [ "$prod_postgres_status" = "✅" ]; then
    echo "1. ✅ Production-среда запущена и готова"
    echo "2. 🌐 Откройте N8N: http://localhost:5678"
    echo "3. 🤖 Создайте AI-workflow с использованием Ollama"
    echo "4. 🔍 Протестируйте векторный поиск с Qdrant"
    echo "5. 📊 Мониторьте производительность"
else
    echo "1. 🔧 Исправьте проблемы в production-среде"
    echo "2. 📝 Проверьте логи: docker compose logs -f"
    echo "3. 🔄 Перезапустите проблемные сервисы"
    echo "4. 🧪 Повторите сравнение после исправлений"
fi

echo
echo "🎯 ЗАКЛЮЧЕНИЕ:"
echo "=============="

success_rate=0
if [ "$test_n8n_status" = "✅" ] && [ "$prod_n8n_status" = "✅" ]; then success_rate=$((success_rate + 50)); fi
if [ "$prod_ollama_status" = "✅" ]; then success_rate=$((success_rate + 25)); fi
if [ "$prod_qdrant_status" = "✅" ]; then success_rate=$((success_rate + 25)); fi

echo "📊 Общий процент готовности: $success_rate%"

if [ $success_rate -ge 75 ]; then
    echo "🎉 ОТЛИЧНО! Production-среда готова к использованию"
elif [ $success_rate -ge 50 ]; then
    echo "⚠️  ХОРОШО! Основная функциональность работает, AI-компоненты требуют внимания"
else
    echo "❌ ТРЕБУЕТСЯ ДОРАБОТКА! Критические проблемы"
fi
