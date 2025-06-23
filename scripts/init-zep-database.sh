#!/bin/bash
set -e

# Создаём базу данных для Zep, если она не существует
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Создаём базу данных zep, если она не существует
    SELECT 'CREATE DATABASE zep'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'zep')\gexec
    
    -- Подключаемся к базе zep и включаем расширение pgvector
    \c zep
    
    -- Создаём расширение pgvector, если оно не существует
    CREATE EXTENSION IF NOT EXISTS vector;
    
    -- Предоставляем права пользователю n8n на базу данных zep
    GRANT ALL PRIVILEGES ON DATABASE zep TO n8n;
    GRANT ALL PRIVILEGES ON SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO n8n;
    
    -- Устанавливаем права по умолчанию для новых объектов
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO n8n;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO n8n;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO n8n;
EOSQL

echo "База данных zep создана и настроена успешно!"
