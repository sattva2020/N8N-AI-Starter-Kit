#!/bin/bash

# N8N Workflows Import Preparation Script
# Версия: 1.2.0
# Дата: 24 июня 2025

echo "=================================="
echo "N8N WORKFLOWS IMPORT PREPARATION"
echo "=================================="
echo ""

# Проверка доступности N8N
echo "1. Проверка доступности N8N..."
N8N_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/)
if [ "$N8N_STATUS" = "200" ]; then
    echo "✅ N8N доступен на http://localhost:5678"
else
    echo "❌ N8N недоступен. Статус код: $N8N_STATUS"
    exit 1
fi

# Проверка Document Processor
echo ""
echo "2. Проверка Document Processor..."
DOC_PROC_STATUS=$(curl -s http://localhost:8001/health | jq -r '.status' 2>/dev/null)
if [ "$DOC_PROC_STATUS" = "healthy" ]; then
    echo "✅ Document Processor работает корректно"
else
    echo "❌ Document Processor недоступен или нездоров"
fi

# Проверка Qdrant
echo ""
echo "3. Проверка Qdrant..."
QDRANT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:6333/collections)
if [ "$QDRANT_STATUS" = "200" ]; then
    echo "✅ Qdrant доступен"
else
    echo "⚠️  Qdrant может быть недоступен. Статус код: $QDRANT_STATUS"
fi

# Проверка PostgreSQL
echo ""
echo "4. Проверка PostgreSQL..."
if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo "✅ PostgreSQL доступен"
else
    echo "❌ PostgreSQL недоступен"
fi

# Список доступных workflows
echo ""
echo "5. Доступные workflows для импорта:"
WORKFLOW_DIR="./n8n/workflows"
if [ -d "$WORKFLOW_DIR" ]; then
    for workflow in "$WORKFLOW_DIR"/*.json; do
        if [ -f "$workflow" ]; then
            WORKFLOW_NAME=$(basename "$workflow" .json)
            WORKFLOW_SIZE=$(wc -l < "$workflow")
            echo "   📄 $WORKFLOW_NAME ($WORKFLOW_SIZE строк)"
        fi
    done
else
    echo "❌ Папка workflows не найдена"
fi

# Проверка доступности API endpoints
echo ""
echo "6. Проверка API endpoints для workflows..."

# Document Processor endpoints
echo "   📡 Document Processor endpoints:"
echo "      - Health: http://localhost:8001/health"
echo "      - Upload: http://localhost:8001/documents/upload"
echo "      - Search: http://localhost:8001/documents/search"
echo "      - List: http://localhost:8001/documents"

# N8N webhook URL
echo "   📡 N8N webhook URL для автоматизации:"
echo "      - Webhook: http://localhost:5678/webhook/rag-automation"

echo ""
echo "=================================="
echo "ИНСТРУКЦИИ ПО ИМПОРТУ:"
echo "=================================="
echo ""
echo "1. Откройте N8N в браузере: http://localhost:5678"
echo "2. Нажмите 'Import' в верхнем меню"
echo "3. Выберите 'From File'"
echo "4. Загрузите workflow файлы из папки n8n/workflows/"
echo "5. Активируйте импортированные workflows"
echo ""
echo "📖 Подробные инструкции: n8n/N8N_WORKFLOWS_IMPORT_GUIDE.md"
echo ""

# Проверка конфигурации N8N
echo "7. Проверка конфигурации N8N..."
if docker logs n8n-ai-starter-kit-n8n-1 2>&1 | grep -q "ready on"; then
    echo "✅ N8N успешно запущен и готов к работе"
else
    echo "⚠️  Проверьте логи N8N для диагностики проблем"
fi

echo ""
echo "🚀 Система готова к импорту workflows!"
echo "=================================="
