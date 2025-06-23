#!/bin/bash

# 🚀 Полное исправление всех проблем

echo "🔧 Полное исправление проблем Docker Compose"
echo "============================================"

# 1. Исправление прав доступа
echo "1. Исправление прав доступа на скрипты..."
chmod +x scripts/*.sh
chmod +x *.sh 2>/dev/null || true

# 2. Остановка и очистка
echo "2. Остановка контейнеров и очистка сетей..."
docker compose down 2>/dev/null || true
docker network prune -f

# 3. Создание .env если нет
echo "3. Проверка .env файла..."
if [[ ! -f ".env" ]] && [[ -f "template.env" ]]; then
    cp template.env .env
    echo "✅ .env файл создан из template.env"
elif [[ ! -f ".env" ]]; then
    echo "⚠️  Нет template.env файла. Создаем базовый .env..."
    cat > .env << 'EOF'
# Базовая конфигурация N8N AI Starter Kit
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
JUPYTER_TOKEN=jupyter_token_123
EOF
    echo "✅ Создан базовый .env файл"
else
    echo "✅ .env файл существует"
fi

# 4. Проверка конфигурации
echo "4. Проверка конфигурации Docker Compose..."
if docker compose config >/dev/null 2>&1; then
    echo "✅ Конфигурация Docker Compose корректна"
else
    echo "❌ Ошибка в конфигурации Docker Compose:"
    docker compose config
    exit 1
fi

# 5. Создание необходимых директорий
echo "5. Создание необходимых директорий..."
mkdir -p data/n8n-files data/n8n-workflows logs

echo
echo "🎉 Все исправления применены!"
echo "============================"
echo
echo "Теперь вы можете:"
echo "1. Запустить минимальную конфигурацию:"
echo "   docker compose --profile cpu up -d"
echo
echo "2. Проверить статус:"
echo "   docker ps"
echo
echo "3. Посмотреть логи:"
echo "   docker compose logs -f"
echo
echo "4. Доступ к N8N:"
echo "   http://localhost:5678"
echo
echo "5. Если проблемы остались, запустите диагностику:"
echo "   ./scripts/analyze-services.sh"
echo "============================"
