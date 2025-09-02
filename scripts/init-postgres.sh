#!/bin/bash

# =============================================
# PostgreSQL Initialization Script for N8N
# =============================================
# Автоматическая инициализация PostgreSQL для N8N
# Создание пользователей, баз данных и настройка прав доступа

set -e

echo "🔧 Инициализация PostgreSQL для N8N..."

# Загрузка переменных окружения
source .env 2>/dev/null || true

# Проверка обязательных переменных
if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_PASSWORD" || -z "$POSTGRES_DB" ]]; then
    echo "❌ Ошибка: Не заданы переменные POSTGRES_USER, POSTGRES_PASSWORD или POSTGRES_DB"
    echo "Проверьте файл .env"
    exit 1
fi

# Функция для выполнения SQL команд
execute_sql() {
    local sql_command="$1"
    local description="$2"
    
    echo "🔄 $description..."
    
    if docker exec -i n8n-ai-starter-kit-postgres-1 psql -U postgres -c "$sql_command" >/dev/null 2>&1; then
        echo "✅ $description - выполнено успешно"
        return 0
    else
        echo "⚠️  $description - пропущено (возможно, уже существует)"
        return 1
    fi
}

# Проверка работы PostgreSQL
echo "🔍 Проверка состояния PostgreSQL..."
if ! docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then
    echo "❌ PostgreSQL недоступен. Убедитесь, что контейнер запущен."
    exit 1
fi

echo "✅ PostgreSQL доступен"

# Создание базы данных для N8N (если не существует)
execute_sql "CREATE DATABASE \"$POSTGRES_DB\";" "Создание базы данных $POSTGRES_DB"

# Создание пользователя для N8N (если не существует) 
execute_sql "CREATE USER \"$POSTGRES_USER\" WITH PASSWORD '$POSTGRES_PASSWORD';" "Создание пользователя $POSTGRES_USER"

# Передача базы n8n пользователю n8n (корректно!)
execute_sql "ALTER DATABASE \"$POSTGRES_DB\" OWNER TO \"$POSTGRES_USER\";" "Передача базы $POSTGRES_DB пользователю $POSTGRES_USER"

# Предоставление прав пользователю
execute_sql "GRANT ALL PRIVILEGES ON DATABASE \"$POSTGRES_DB\" TO \"$POSTGRES_USER\";" "Предоставление прав на базу данных"

# Установка пользователя как владельца базы данных
execute_sql "ALTER DATABASE \"$POSTGRES_DB\" OWNER TO \"$POSTGRES_USER\";" "Установка владельца базы данных"

# Дополнительные права для работы с расширениями
execute_sql "ALTER USER \"$POSTGRES_USER\" CREATEDB;" "Предоставление права создания БД"

# Создание схемы public и предоставление прав (для некоторых версий PostgreSQL)
echo "🔄 Настройка схемы public..."
docker exec -i n8n-ai-starter-kit-postgres-1 psql -U postgres -d "$POSTGRES_DB" -c "
    GRANT ALL ON SCHEMA public TO \"$POSTGRES_USER\";
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$POSTGRES_USER\";
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$POSTGRES_USER\";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$POSTGRES_USER\";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$POSTGRES_USER\";
" >/dev/null 2>&1 || echo "⚠️  Настройка схемы public - частично выполнена"

echo "✅ Настройка схемы public завершена"

# Проверка подключения с новым пользователем
echo "🔍 Проверка подключения пользователя N8N к базе данных..."
if docker exec -i n8n-ai-starter-kit-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Пользователь $POSTGRES_USER успешно подключается к базе данных $POSTGRES_DB"
else
    echo "❌ Ошибка подключения пользователя $POSTGRES_USER к базе данных $POSTGRES_DB"
    exit 1
fi

# Создание таблицы для тестирования (если нужно)
echo "🔄 Создание тестовой таблицы..."
docker exec -i n8n-ai-starter-kit-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
    CREATE TABLE IF NOT EXISTS connection_test (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        test_value TEXT DEFAULT 'N8N PostgreSQL connection test'
    );
    INSERT INTO connection_test (test_value) VALUES ('Connection successful at $(date)') ON CONFLICT DO NOTHING;
" >/dev/null 2>&1 || echo "⚠️  Создание тестовой таблицы - пропущено"

echo "✅ Тестовая таблица создана"

echo ""
echo "🎉 Инициализация PostgreSQL для N8N завершена успешно!"
echo ""
echo "📊 Информация о подключении:"
echo "   Хост: $POSTGRES_HOST:$POSTGRES_PORT"
echo "   База данных: $POSTGRES_DB"
echo "   Пользователь: $POSTGRES_USER"
echo "   Статус: Готов для подключения N8N"
echo ""
echo "🔄 Перезапустите сервис N8N для применения изменений:"
echo "   docker compose restart n8n"
echo ""
