#!/bin/bash

# N8N API-based Workflows Importer
# Использует N8N REST API для импорта workflows
# Версия: 1.2.0

set -e

# Конфигурация
N8N_API_URL="${N8N_URL:-http://localhost:5678}/rest"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-./n8n/workflows}"
MAX_RETRIES=60
RETRY_INTERVAL=5

echo "🚀 N8N API Workflows Importer v1.2.0"
echo "   API URL: $N8N_API_URL"
echo "   Workflows Dir: $WORKFLOWS_DIR"
echo ""

# Функция ожидания готовности N8N
wait_for_n8n_api() {
    echo "⏳ Ожидание готовности N8N API..."
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        # Проверяем доступность API без аутентификации
        if curl -s -f "$N8N_API_URL/login" -o /dev/null 2>&1; then
            echo "✅ N8N API доступен"
            return 0
        fi
        
        retries=$((retries + 1))
        echo "⏳ Попытка $retries/$MAX_RETRIES - ожидание N8N API..."
        sleep $RETRY_INTERVAL
    done
    
    echo "❌ N8N API недоступен после $MAX_RETRIES попыток"
    return 1
}

# Функция получения списка существующих workflows
get_existing_workflows() {
    curl -s -X GET "$N8N_API_URL/workflows" \
        -H "Content-Type: application/json" 2>/dev/null || echo "[]"
}

# Функция проверки существования workflow
workflow_exists() {
    local workflow_name="$1"
    local existing_workflows=$(get_existing_workflows)
    
    echo "$existing_workflows" | jq -r '.[].name' | grep -q "^$workflow_name$" 2>/dev/null
}

# Функция импорта workflow через API
import_workflow_api() {
    local workflow_file="$1"
    local workflow_name=$(jq -r '.name // "Unknown"' "$workflow_file")
    
    echo "📥 Импорт workflow: $workflow_name"
    
    # Проверяем существование
    if workflow_exists "$workflow_name"; then
        echo "⚠️  Workflow '$workflow_name' уже существует, пропускаем"
        return 0
    fi
    
    # Читаем содержимое workflow
    local workflow_data=$(cat "$workflow_file")
    
    # Импорт через API
    local response=$(curl -s -X POST "$N8N_API_URL/workflows" \
        -H "Content-Type: application/json" \
        -d "$workflow_data" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        local workflow_id=$(echo "$response" | jq -r '.id')
        echo "✅ Workflow '$workflow_name' импортирован (ID: $workflow_id)"
        
        # Активация workflow
        if [ "$workflow_id" != "null" ]; then
            curl -s -X POST "$N8N_API_URL/workflows/$workflow_id/activate" \
                -H "Content-Type: application/json" >/dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo "🟢 Workflow '$workflow_name' активирован"
            else
                echo "⚠️  Workflow '$workflow_name' импортирован, но не удалось активировать"
            fi
        fi
        return 0
    else
        echo "❌ Ошибка импорта workflow '$workflow_name'"
        echo "Response: $response"
        return 1
    fi
}

# Функция создания простого API токена (если нужно)
setup_api_access() {
    # Для случаев когда нужна аутентификация
    # В данном случае N8N настроен без пользовательской аутентификации
    echo "🔓 N8N настроен без аутентификации, продолжаем..."
}

# Основная функция
main() {
    echo "🔍 Поиск workflow файлов в $WORKFLOWS_DIR"
    
    if [ ! -d "$WORKFLOWS_DIR" ]; then
        echo "❌ Директория workflows не найдена: $WORKFLOWS_DIR"
        exit 1
    fi
    
    # Ожидание готовности N8N API
    if ! wait_for_n8n_api; then
        echo "❌ N8N API недоступен"
        exit 1
    fi
    
    # Настройка доступа к API
    setup_api_access
    
    # Поиск и импорт всех workflow файлов
    local imported_count=0
    local failed_count=0
    local skipped_count=0
    
    for workflow_file in "$WORKFLOWS_DIR"/*.json; do
        if [ -f "$workflow_file" ]; then
            echo ""
            if import_workflow_api "$workflow_file"; then
                imported_count=$((imported_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    echo ""
    echo "=" * 50
    echo "📊 РЕЗУЛЬТАТЫ АВТОМАТИЧЕСКОГО ИМПОРТА:"
    echo "=" * 50
    echo "   ✅ Успешно импортировано: $imported_count"
    echo "   ❌ Ошибок импорта: $failed_count"
    echo "   ⏭️  Пропущено (уже существуют): $skipped_count"
    echo ""
    
    if [ $failed_count -eq 0 ]; then
        echo "🎉 Автоматический импорт workflows завершен успешно!"
        echo "🌐 N8N доступен: ${N8N_URL:-http://localhost:5678}"
        echo "📋 Workflows импортированы и готовы к использованию"
        exit 0
    else
        echo "⚠️  Импорт завершен с ошибками ($failed_count)"
        exit 1
    fi
}

# Обработка сигналов
trap 'echo "❌ Импорт прерван"; exit 1' INT TERM

# Запуск
main "$@"
