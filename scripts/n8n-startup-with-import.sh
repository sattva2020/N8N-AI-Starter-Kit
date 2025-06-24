#!/bin/bash

# N8N Startup with Auto-Import
# Запускает N8N и автоматически импортирует workflows

set -e

echo "🚀 Запуск N8N с автоматическим импортом workflows..."

# Функция запуска в фоне процесса импорта
start_import_process() {
    sleep 30  # Ждем запуска N8N
    
    echo "📥 Начинаем автоматический импорт workflows..."
    
    if [ -x "/scripts/auto-import-workflows-api.sh" ]; then
        /scripts/auto-import-workflows-api.sh
    else
        echo "⚠️  Скрипт импорта не найден, пропускаем автоимпорт"
    fi
} &

# Запуск стандартного N8N процесса
echo "🔄 Запуск N8N..."
exec n8n start
