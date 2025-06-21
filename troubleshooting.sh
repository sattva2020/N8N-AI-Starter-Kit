#!/bin/bash

echo "=== Диагностика N8N AI Starter Kit ==="

# Проверка Docker
echo "1. Проверка Docker..."
docker --version || echo "❌ Docker не найден"

# Проверка конфликтов сервисов
echo "2. Проверка конфликтов в docker-compose..."
if docker compose config &>/dev/null; then
    echo "✅ Конфигурация корректна"
else
    echo "❌ Найдены ошибки в конфигурации"
fi

# Проверка переменных окружения
echo "3. Проверка .env файла..."
if [ -f .env ]; then
    echo "✅ Файл .env найден"
    # Проверка на незакавыченные $
    if grep -q '\$[^{]' .env; then
        echo "⚠️ Найдены неэкранированные символы $ в .env"
    fi
else
    echo "❌ Файл .env не найден"
fi

# Проверка портов
echo "4. Проверка занятых портов..."
for port in 80 443 5678; do
    if netstat -tuln | grep -q ":$port "; then
        echo "⚠️ Порт $port уже используется"
    else
        echo "✅ Порт $port свободен"
    fi
done