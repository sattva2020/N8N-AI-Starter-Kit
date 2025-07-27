#!/bin/bash

# Скрипт для обновления конфигурации Traefik с правильными доменами
# Использует переменные из .env файла

# Проверяем наличие .env файла
if [ ! -f ".env" ]; then
    echo "❌ Файл .env не найден!"
    exit 1
fi

# Загружаем переменные из .env
source .env

echo "🔧 Обновление конфигурации Traefik..."
echo "📍 Домен: ${DOMAIN_NAME}"

# Обновляем ssl-security.yml
if [ -f "config/traefik/dynamic/ssl-security.yml" ]; then
    echo "🔄 Обновляем ssl-security.yml..."
    
    # Создаем резервную копию
    cp config/traefik/dynamic/ssl-security.yml config/traefik/dynamic/ssl-security.yml.backup
    
    # Заменяем старые домены на новые
    sed -i "s/yourdomain\.com/${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/n8n\.yourdomain\.com/n8n.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/api\.yourdomain\.com/api.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/monitor\.yourdomain\.com/monitor.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/admin\.yourdomain\.com/admin.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    
    echo "✅ ssl-security.yml обновлен"
else
    echo "⚠️ Файл ssl-security.yml не найден"
fi

# Обновляем development.yml если есть жестко заданные домены
if [ -f "config/traefik/dynamic/development.yml" ]; then
    echo "🔄 Проверяем development.yml..."
    if grep -q "yourdomain\.com\|sattva-ai\.top" config/traefik/dynamic/development.yml; then
        cp config/traefik/dynamic/development.yml config/traefik/dynamic/development.yml.backup
        sed -i "s/sattva-ai\.top/${DOMAIN_NAME}/g" config/traefik/dynamic/development.yml
        sed -i "s/yourdomain\.com/${DOMAIN_NAME}/g" config/traefik/dynamic/development.yml
        echo "✅ development.yml обновлен"
    else
        echo "✅ development.yml не требует обновления"
    fi
fi

echo "🎉 Конфигурация Traefik обновлена для домена: ${DOMAIN_NAME}"
echo "🔄 Перезапустите контейнер Traefik для применения изменений:"
echo "   docker restart n8n-ai-starter-kit-traefik-1"
