#!/bin/bash

# Quick Workflows Import Test
# Быстрое тестирование импорта workflows

echo "🚀 Quick N8N Workflows Import Test"
echo "=================================="

# Проверяем N8N
echo "📋 Проверка N8N..."
if curl -s http://localhost:5678/healthz >/dev/null 2>&1; then
    echo "✅ N8N доступен"
else
    echo "❌ N8N недоступен"
    exit 1
fi

# Проверяем workflows
echo ""
echo "📂 Доступные workflows:"
ls -la n8n/workflows/*.json | awk '{print "  📄 " $9 " (" $5 " bytes)"}'

echo ""
echo "📥 Импорт workflows..."

# Импорт каждого workflow
for workflow in n8n/workflows/*.json; do
    if [ -f "$workflow" ]; then
        name=$(basename "$workflow" .json)
        echo "  📋 Импорт: $name"
        
        response=$(curl -s -X POST "http://localhost:5678/rest/workflows" \
            -H "Content-Type: application/json" \
            -d @"$workflow")
        
        if echo "$response" | grep -q '"id"'; then
            echo "  ✅ $name импортирован успешно"
        else
            echo "  ❌ Ошибка импорта $name: $response"
        fi
    fi
done

echo ""
echo "📊 Проверка результата..."
workflow_count=$(curl -s "http://localhost:5678/rest/workflows" | jq -r '.data | length' 2>/dev/null)
if [ "$workflow_count" ] && [ "$workflow_count" -gt 0 ]; then
    echo "✅ Найдено workflows: $workflow_count"
    
    echo "📋 Список workflows:"
    curl -s "http://localhost:5678/rest/workflows" | jq -r '.data[] | "  • \(.name) (ID: \(.id)) - Активен: \(.active)"' 2>/dev/null
else
    echo "❌ Workflows не найдены"
fi

echo ""
echo "🎉 Тест завершен!"
