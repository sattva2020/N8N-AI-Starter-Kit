#!/bin/bash

# N8N Workflows Auto-Import Status Checker v1.2.0
# Проверка статуса автоматического импорта workflows

echo "🔍 N8N Workflows Auto-Import Status Checker"
echo "=============================================="

if [ "${N8N_AUTO_IMPORT:-false}" != "true" ]; then
    echo "ℹ️ Автоматический импорт отключён (N8N_AUTO_IMPORT != true)."
    echo "    Для включения установите N8N_AUTO_IMPORT=true в окружении контейнера/compose."
    echo "✅ Проверка завершена (auto-import отключён)."
    exit 0
fi

# Проверяем запущенные контейнеры
echo "📋 Статус контейнеров:"
echo "  N8N: $(docker-compose ps n8n --status --quiet 2>/dev/null || echo 'не запущен')"
echo "  Importer: $(docker-compose ps n8n-workflows-importer --status --quiet 2>/dev/null || echo 'завершен')"

echo ""
echo "📊 Логи автоматического импорта:"
echo "--------------------------------"

# Проверяем логи импорта
if docker-compose logs n8n-workflows-importer 2>/dev/null | grep -q "N8N Workflows Auto-Importer"; then
    echo "✅ Импорт выполнялся"
    
    # Показываем результаты
    docker-compose logs n8n-workflows-importer 2>/dev/null | grep -E "(РЕЗУЛЬТАТ|импортировано|Обновлено|Ошибок|успешно|ошибками)"
    
    # Проверяем ошибки
    if docker-compose logs n8n-workflows-importer 2>/dev/null | grep -q "❌.*Ошибок: 0"; then
        echo "🎉 Импорт завершен успешно!"
    elif docker-compose logs n8n-workflows-importer 2>/dev/null | grep -q "❌.*Ошибок:"; then
        echo "⚠️ Импорт завершен с ошибками"
    fi
else
    echo "❌ Логи импорта не найдены"
fi

echo ""
echo "🌐 Проверка доступности N8N:"
echo "----------------------------"

# Проверяем доступность N8N
if curl -s http://localhost:5678/healthz >/dev/null 2>&1; then
    echo "✅ N8N доступен: http://localhost:5678"
    
    # Проверяем количество workflows
    workflow_count=$(curl -s "http://localhost:5678/rest/workflows" 2>/dev/null | jq '.data | length' 2>/dev/null)
    if [ "$workflow_count" ] && [ "$workflow_count" -gt 0 ]; then
        echo "📄 Найдено workflows: $workflow_count"
        
        # Показываем список workflows
        echo "📋 Список workflows:"
        curl -s "http://localhost:5678/rest/workflows" 2>/dev/null | jq -r '.data[] | "  • \(.name) (ID: \(.id)) - Активен: \(.active)"' 2>/dev/null || echo "  Не удалось получить список"
    else
        echo "📄 Workflows не найдены"
    fi
else
    echo "❌ N8N недоступен"
fi

echo ""
echo "🛠️ Команды для управления:"
echo "---------------------------"
echo "  Перезапуск импорта: docker-compose up n8n-workflows-importer --force-recreate"
echo "  Просмотр логов:     docker-compose logs n8n-workflows-importer"
echo "  Открыть N8N:        http://localhost:5678"

echo ""
echo "✅ Проверка завершена"
