#!/bin/bash

# N8N Workflows Auto-Import Script
# Автоматический импорт workflows при запуске N8N

set -e

echo "🚀 Начинаем автоматический импорт N8N workflows..."

# Переменные
N8N_URL="http://localhost:5678"
WORKFLOWS_DIR="/workflows"
MAX_RETRIES=30
RETRY_INTERVAL=10

# Функция ожидания готовности N8N
wait_for_n8n() {
    echo "⏳ Ожидание готовности N8N..."
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s -f "$N8N_URL" > /dev/null 2>&1; then
            echo "✅ N8N готов к работе"
            return 0
        fi
        
        retries=$((retries + 1))
        echo "⏳ Попытка $retries/$MAX_RETRIES - ожидание N8N..."
        sleep $RETRY_INTERVAL
    done
    
    echo "❌ N8N не готов после $MAX_RETRIES попыток"
    return 1
}

# Функция импорта workflow
import_workflow() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .json)
    
    echo "📥 Импорт workflow: $workflow_name"
    
    # Проверяем, существует ли уже workflow
    if curl -s -X GET "$N8N_URL/rest/workflows" \
       -H "Content-Type: application/json" 2>/dev/null | \
       grep -q "\"name\":\"$workflow_name\""; then
        echo "⚠️  Workflow '$workflow_name' уже существует, пропускаем"
        return 0
    fi
    
    # Импортируем workflow
    local response=$(curl -s -X POST "$N8N_URL/rest/workflows/import" \
        -H "Content-Type: application/json" \
        -d @"$workflow_file" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Workflow '$workflow_name' успешно импортирован"
        
        # Попытка активации workflow
        local workflow_id=$(echo "$response" | jq -r '.id' 2>/dev/null)
        if [ "$workflow_id" != "null" ] && [ -n "$workflow_id" ]; then
            curl -s -X POST "$N8N_URL/rest/workflows/$workflow_id/activate" \
                -H "Content-Type: application/json" >/dev/null 2>&1
            echo "🟢 Workflow '$workflow_name' активирован"
        fi
    else
        echo "❌ Ошибка импорта workflow '$workflow_name'"
        return 1
    fi
}

# Основная функция
main() {
    echo "🔍 Поиск workflow файлов в $WORKFLOWS_DIR"
    
    if [ ! -d "$WORKFLOWS_DIR" ]; then
        echo "❌ Директория workflows не найдена: $WORKFLOWS_DIR"
        exit 1
    fi
    
    # Ожидание готовности N8N
    if ! wait_for_n8n; then
        echo "❌ Не удалось дождаться готовности N8N"
        exit 1
    fi
    
    # Поиск и импорт всех workflow файлов
    local imported_count=0
    local failed_count=0
    
    for workflow_file in "$WORKFLOWS_DIR"/*.json; do
        if [ -f "$workflow_file" ]; then
            if import_workflow "$workflow_file"; then
                imported_count=$((imported_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    echo ""
    echo "📊 Результаты импорта:"
    echo "   ✅ Успешно импортировано: $imported_count"
    echo "   ❌ Ошибок импорта: $failed_count"
    
    if [ $failed_count -eq 0 ]; then
        echo "🎉 Все workflows успешно импортированы!"
        exit 0
    else
        echo "⚠️  Импорт завершен с ошибками"
        exit 1
    fi
}

# Запуск основной функции
main "$@"
