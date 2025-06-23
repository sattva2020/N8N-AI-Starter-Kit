#!/bin/bash

# 🔍 Быстрая диагностика тестового окружения

echo "🔍 Диагностика тестового окружения N8N"
echo "====================================="

# Проверка статуса контейнеров
echo "📋 1. Статус контейнеров:"
docker compose -f compose/test-minimal.yml ps

echo
echo "📋 2. Использование ресурсов:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo
echo "📋 3. Проверка доступности сервисов:"

# Проверка N8N
echo -n "N8N (http://localhost:5678): "
if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    echo "✅ Доступен"
else
    echo "❌ Недоступен"
fi

# Проверка Qdrant если запущен
if docker compose -f compose/test-minimal.yml ps | grep -q qdrant-test; then
    echo -n "Qdrant (http://localhost:6333): "
    if curl -s -f http://localhost:6333 >/dev/null 2>&1; then
        echo "✅ Доступен"
    else
        echo "❌ Недоступен"
    fi
fi

# Проверка PostgreSQL
echo -n "PostgreSQL: "
if docker exec compose-postgres-test-1 pg_isready -U postgres >/dev/null 2>&1; then
    echo "✅ Доступен"
else
    echo "❌ Недоступен"
fi

echo
echo "📋 4. Проверка базы данных N8N:"
if docker exec compose-postgres-test-1 psql -U postgres -d postgres -c "\l" | grep -q n8n; then
    echo "✅ База данных n8n создана"
    echo "Таблицы в базе n8n:"
    docker exec compose-postgres-test-1 psql -U n8n -d n8n -c "\dt" 2>/dev/null || echo "   (Таблицы пока не созданы - это нормально при первом запуске)"
else
    echo "❌ База данных n8n не найдена"
fi

echo
echo "📋 5. Последние логи N8N (только ошибки и предупреждения):"
docker compose -f compose/test-minimal.yml logs --tail=20 n8n-test | grep -E "(ERROR|WARN|error|warn)"

echo
echo "📋 6. Сетевая информация:"
local_ip=$(hostname -I | awk '{print $1}')
echo "Локальный IP: $local_ip"
echo "Доступ к сервисам:"
echo "  - N8N: http://localhost:5678 или http://$local_ip:5678"
if docker compose -f compose/test-minimal.yml ps | grep -q qdrant-test; then
    echo "  - Qdrant: http://localhost:6333/dashboard или http://$local_ip:6333/dashboard"
fi

echo
echo "📋 7. Полезные команды для отладки:"
echo "Полные логи N8N:"
echo "  docker compose -f compose/test-minimal.yml logs -f n8n-test"
echo
echo "Подключение к контейнеру N8N:"
echo "  docker exec -it compose-n8n-test-1 /bin/bash"
echo
echo "Проверка базы данных:"
echo "  docker exec -it compose-postgres-test-1 psql -U n8n -d n8n"
echo
echo "Остановка тестирования:"
echo "  docker compose -f compose/test-minimal.yml down"
