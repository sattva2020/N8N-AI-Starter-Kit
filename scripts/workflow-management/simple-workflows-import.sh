#!/bin/bash

# Simple N8N Workflows Auto-Import
# Простой скрипт для автоматического импорта при запуске

echo "🚀 N8N Auto-Import Service v1.2.0"

# Ожидание доступности N8N
echo "⏳ Ожидание готовности N8N..."
while ! curl -s http://n8n:5678/healthz >/dev/null 2>&1; do
    echo "⏳ N8N еще не готов, ожидаем..."
    sleep 5
done

echo "✅ N8N готов, начинаем импорт workflows..."

# Счетчики
imported=0
failed=0

# Импорт каждого workflow файла
for workflow in /workflows/*.json; do
    if [ -f "$workflow" ]; then
        name=$(basename "$workflow" .json)
        echo "📥 Импорт: $name"
        
        # Простой метод через curl (без аутентификации)
        response=$(curl -s -X POST "http://n8n:5678/rest/workflows" \
            -H "Content-Type: application/json" \
            -d @"$workflow" 2>/dev/null)
        
        if echo "$response" | grep -q '"id"'; then
            echo "✅ $name импортирован успешно"
            imported=$((imported + 1))
        else
            echo "❌ Ошибка импорта $name"
            failed=$((failed + 1))
        fi
    fi
done

echo ""
echo "📊 Результат импорта:"
echo "   ✅ Успешно: $imported"
echo "   ❌ Ошибок: $failed"

if [ $failed -eq 0 ]; then
    echo "🎉 Автоматический импорт завершен успешно!"
else
    echo "⚠️  Импорт завершен с ошибками"
fi
