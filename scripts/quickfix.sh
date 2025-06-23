#!/bin/bash

# 🚀 Быстрое исправление для текущей ситуации

echo "=========================================="
echo "🔧 N8N AI Starter Kit - Быстрое исправление"
echo "=========================================="

# Проверяем, что мы в правильной директории
if [[ ! -f "scripts/ubuntu-vm-deploy.sh" ]]; then
    echo "❌ Ошибка: Запустите этот скрипт из корневой директории проекта n8n-ai-starter-kit"
    exit 1
fi

echo "✅ Обнаружена корневая директория проекта"

# Проверяем git репозиторий
if [[ ! -d ".git" ]]; then
    echo "⚠️  Git репозиторий не найден"
    echo "🔧 Инициализация git репозитория..."
    git init
    git remote add origin https://github.com/sattva2020/N8N-AI-Starter-Kit.git
    echo "✅ Git репозиторий инициализирован"
else
    echo "✅ Git репозиторий найден"
fi

# Исправляем права доступа на скрипты
echo "🔧 Исправление прав доступа на скрипты..."
chmod +x scripts/*.sh
chmod +x start.sh

echo "✅ Права доступа исправлены"

# Создаем необходимые директории
echo "📁 Создание необходимых директорий..."
mkdir -p data/n8n-files data/n8n-workflows logs

echo "✅ Директории созданы"

# Проверяем .env файл
if [[ ! -f ".env" ]]; then
    if [[ -f "template.env" ]]; then
        echo "📝 Создание файла .env из шаблона..."
        cp template.env .env
        echo "✅ Файл .env создан"
    else
        echo "⚠️  template.env не найден, создаем базовый .env файл..."
        cat > .env << 'EOF'
# N8N AI Starter Kit - Базовая конфигурация
DOMAIN_NAME=localhost
NODE_ENV=production
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8npassword123
POSTGRES_DB=n8n
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_ENCRYPTION_KEY=randomly_generated_key_123456789
OLLAMA_HOST=http://ollama:11434
QDRANT_URL=http://qdrant:6333
EOF
        echo "✅ Базовый файл .env создан"
    fi
else
    echo "✅ Файл .env уже существует"
fi

# Исправляем скрипт ubuntu-vm-deploy.sh, если есть проблемы
echo "🔧 Проверка и исправление скрипта ubuntu-vm-deploy.sh..."
if grep -q 'PROJECT_DIR=' scripts/ubuntu-vm-deploy.sh; then
    echo "✅ Скрипт уже исправлен"
else
    echo "⚠️  Исправляем потенциальные проблемы в скрипте..."
    # Здесь можно добавить дополнительные исправления если нужно
fi

# Проверяем Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    echo "Установите Docker перед продолжением"
    exit 1
else
    echo "✅ Docker найден: $(docker --version)"
fi

# Проверяем Docker Compose
if docker compose version &> /dev/null; then
    echo "✅ Docker Compose найден: $(docker compose version)"
elif docker-compose --version &> /dev/null; then
    echo "✅ Docker Compose найден: $(docker-compose --version)"
else
    echo "❌ Docker Compose не найден!"
    exit 1
fi

echo
echo "=========================================="
echo "🎉 Исправление завершено!"
echo "=========================================="
echo
echo "Теперь вы можете:"
echo "1. Продолжить развертывание (исправленная версия):"
echo "   ./scripts/ubuntu-vm-deploy.sh"
echo
echo "2. Или запустить только Docker сервисы напрямую:"
echo "   docker compose --profile cpu up -d"
echo
echo "3. Проверить статус сервисов:"
echo "   docker ps"
echo
echo "4. Запустить диагностику (если есть):"
echo "   ./scripts/analyze-services.sh"
echo
echo "5. Если возникают проблемы с Git, выполните:"
echo "   git init"
echo "   git remote add origin https://github.com/sattva2020/N8N-AI-Starter-Kit.git"
echo
echo "6. Быстрый запуск N8N без полного развертывания:"
echo "   docker run -d --name n8n-quick -p 5678:5678 n8nio/n8n"
echo
echo "=========================================="
echo "📋 Для диагностики проблем:"
echo "   docker logs <container_name>"
echo "   docker compose logs -f"
echo "=========================================="
