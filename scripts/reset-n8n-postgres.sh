#!/bin/bash

# =============================================
# N8N + PostgreSQL Reset and Reinitialize
# =============================================
# Полный сброс и переинициализация связки N8N + PostgreSQL
# ВНИМАНИЕ: Этот скрипт удаляет ВСЕ данные N8N и PostgreSQL!

set -e

echo "⚠️  N8N + PostgreSQL: Полный сброс и переинициализация"
echo "======================================================"
echo ""
echo "🚨 ВНИМАНИЕ: Этот скрипт удалит ВСЕ данные:"
echo "   - Все рабочие процессы N8N"
echo "   - Все пользователи N8N"
echo "   - Всю базу данных PostgreSQL"
echo "   - Все настройки и конфигурации"
echo ""

# Подтверждение пользователя
read -p "❓ Вы уверены, что хотите продолжить? (введите 'YES' для подтверждения): " confirm
if [ "$confirm" != "YES" ]; then
    echo "🚫 Операция отменена."
    exit 0
fi

echo ""
echo "🔄 Начинаем процедуру сброса..."

# Загрузка переменных окружения
source .env 2>/dev/null || true

# Проверка обязательных переменных
if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_PASSWORD" || -z "$POSTGRES_DB" ]]; then
    echo "❌ Ошибка: Не заданы переменные POSTGRES_USER, POSTGRES_PASSWORD или POSTGRES_DB"
    echo "Проверьте файл .env"
    exit 1
fi

# Шаг 1: Остановка сервисов
echo ""
echo "1️⃣  Остановка сервисов..."
echo "------------------------"
docker compose stop n8n postgres 2>/dev/null || true
echo "✅ Сервисы остановлены"

# Шаг 2: Удаление контейнеров
echo ""
echo "2️⃣  Удаление контейнеров..."
echo "--------------------------"
docker compose rm -f n8n postgres 2>/dev/null || true
echo "✅ Контейнеры удалены"

# Шаг 3: Удаление volumes
echo ""
echo "3️⃣  Удаление volumes..."
echo "---------------------"

# Получение имени проекта
PROJECT_NAME=$(docker compose config --format json | jq -r '.name' 2>/dev/null || echo "n8n-ai-starter-kit")

# Удаление named volumes
docker volume rm "${PROJECT_NAME}_n8n_storage" 2>/dev/null && echo "✅ Volume n8n_storage удален" || echo "⚠️  Volume n8n_storage не найден"
docker volume rm "${PROJECT_NAME}_postgres_storage" 2>/dev/null && echo "✅ Volume postgres_storage удален" || echo "⚠️  Volume postgres_storage не найден"

# Удаление orphaned volumes
echo "🧹 Удаление orphaned volumes..."
docker volume prune -f >/dev/null 2>&1 || true

echo "✅ Volumes очищены"

# Шаг 4: Очистка образов (опционально)
echo ""
echo "4️⃣  Очистка образов..."
echo "--------------------"
docker image prune -f >/dev/null 2>&1 || true
echo "✅ Неиспользуемые образы удалены"

# Шаг 5: Проверка и генерация нового ключа шифрования
echo ""
echo "5️⃣  Генерация нового ключа шифрования..."
echo "---------------------------------------"

# Генерация нового 32-байтового ключа в base64
NEW_ENCRYPTION_KEY=$(openssl rand -base64 32)

# Резервное копирование .env
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Создана резервная копия .env"

# Обновление ключа в .env файле
if grep -q "^N8N_ENCRYPTION_KEY=" .env; then
    # Замена существующего ключа
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_ENCRYPTION_KEY}/" .env
    else
        # Linux
        sed -i "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_ENCRYPTION_KEY}/" .env
    fi
    echo "✅ Обновлен ключ шифрования N8N"
else
    # Добавление нового ключа
    echo "N8N_ENCRYPTION_KEY=${NEW_ENCRYPTION_KEY}" >> .env
    echo "✅ Добавлен новый ключ шифрования N8N"
fi

echo "🔑 Новый ключ шифрования: ${NEW_ENCRYPTION_KEY}"

# Шаг 6: Пересоздание инфраструктуры
echo ""
echo "6️⃣  Пересоздание инфраструктуры..."
echo "---------------------------------"

# Создание сетей
echo "🔄 Создание Docker сетей..."
docker compose up --no-start 2>/dev/null || true

# Запуск PostgreSQL
echo "🔄 Запуск PostgreSQL..."
docker compose up -d postgres

# Ожидание готовности PostgreSQL
echo "⏳ Ожидание готовности PostgreSQL..."
for i in {1..30}; do
    if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then
        echo "✅ PostgreSQL готов"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL не готов после 30 попыток"
        exit 1
    fi
    sleep 2
done

# Шаг 7: Инициализация PostgreSQL
echo ""
echo "7️⃣  Инициализация PostgreSQL..."
echo "------------------------------"

# Создание базы данных и пользователя
echo "🔄 Создание базы данных и пользователя..."

# Создание базы данных
docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "CREATE DATABASE \"$POSTGRES_DB\";" 2>/dev/null || echo "⚠️  База данных уже существует"

# Создание пользователя
docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "CREATE USER \"$POSTGRES_USER\" WITH PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null || echo "⚠️  Пользователь уже существует"

# Предоставление прав
docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$POSTGRES_DB\" TO \"$POSTGRES_USER\";"
docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "ALTER DATABASE \"$POSTGRES_DB\" OWNER TO \"$POSTGRES_USER\";"
docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "ALTER USER \"$POSTGRES_USER\" CREATEDB;"

# Настройка схемы public
docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -d "$POSTGRES_DB" -c "
    GRANT ALL ON SCHEMA public TO \"$POSTGRES_USER\";
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$POSTGRES_USER\";
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$POSTGRES_USER\";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$POSTGRES_USER\";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$POSTGRES_USER\";
" 2>/dev/null || echo "⚠️  Частично настроена схема public"

echo "✅ PostgreSQL инициализирован"

# Проверка подключения
if docker exec n8n-ai-starter-kit-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Подключение пользователя проверено"
else
    echo "❌ Ошибка подключения пользователя"
    exit 1
fi

# Шаг 8: Запуск N8N
echo ""
echo "8️⃣  Запуск N8N..."
echo "----------------"
docker compose up -d n8n

# Ожидание готовности N8N
echo "⏳ Ожидание готовности N8N..."
for i in {1..60}; do
    if curl -s -f "http://localhost:5678/healthz" >/dev/null 2>&1; then
        echo "✅ N8N готов и доступен"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ N8N не готов после 60 попыток"
        echo "📋 Логи N8N:"
        docker logs n8n-ai-starter-kit-n8n-1 --tail 10
        exit 1
    fi
    sleep 3
done

# Шаг 9: Финальная проверка
echo ""
echo "9️⃣  Финальная проверка..."
echo "-----------------------"

# Проверка статуса контейнеров
if docker ps | grep -q "n8n-ai-starter-kit-n8n-1.*Up" && docker ps | grep -q "n8n-ai-starter-kit-postgres-1.*Up"; then
    echo "✅ Контейнеры запущены и работают"
else
    echo "❌ Проблемы с запуском контейнеров"
    docker ps | grep "n8n-ai-starter-kit"
    exit 1
fi

# Проверка API
if curl -s -f "http://localhost:5678/healthz" >/dev/null 2>&1; then
    echo "✅ N8N API отвечает"
else
    echo "❌ N8N API недоступен"
    exit 1
fi

# Проверка логов на отсутствие ошибок
echo "🔍 Проверка логов на ошибки..."
n8n_logs=$(docker logs n8n-ai-starter-kit-n8n-1 --tail 20 2>&1)
if echo "$n8n_logs" | grep -qi "error\|failed\|connection refused"; then
    echo "⚠️  Обнаружены возможные ошибки в логах N8N:"
    echo "$n8n_logs" | grep -i "error\|failed\|connection refused" | tail -3
else
    echo "✅ Критических ошибок в логах не обнаружено"
fi

# Завершение
echo ""
echo "🎉 Сброс и переинициализация завершены успешно!"
echo "=============================================="
echo ""
echo "📊 Результаты:"
echo "   - PostgreSQL: ✅ Инициализирован"
echo "   - N8N: ✅ Запущен и готов"
echo "   - База данных: ✅ Создана и настроена"
echo "   - Пользователь: ✅ Создан с полными правами"
echo "   - Ключ шифрования: ✅ Сгенерирован новый"
echo ""
echo "🌐 Доступ к N8N:"
echo "   - Веб-интерфейс: http://localhost:5678"
echo "   - API Healthcheck: http://localhost:5678/healthz"
echo ""
echo "🔑 Важная информация:"
echo "   - Новый ключ шифрования сохранен в .env"
echo "   - Резервная копия .env создана с расширением .backup"
echo "   - Все старые данные удалены - это чистая установка"
echo ""
echo "📝 Следующие шаги:"
echo "   1. Откройте http://localhost:5678 в браузере"
echo "   2. Настройте администратора N8N"
echo "   3. Импортируйте необходимые рабочие процессы"
echo ""
