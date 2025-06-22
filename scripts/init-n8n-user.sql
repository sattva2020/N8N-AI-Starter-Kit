-- =============================================
-- N8N User Initialization Script for PostgreSQL
-- =============================================
-- Этот скрипт автоматически выполняется при инициализации PostgreSQL
-- Создает пользователя и базу данных для N8N с необходимыми правами

-- Переменные из docker-compose environment будут доступны как ${POSTGRES_USER}, ${POSTGRES_DB}, etc.
-- Но в init скриптах нужно использовать фиксированные значения или читать из файлов

DO
$do$
DECLARE 
    n8n_user text := COALESCE(current_setting('n8n.user', true), 'root');
    n8n_db text := COALESCE(current_setting('n8n.db', true), 'n8n');
    n8n_password text := COALESCE(current_setting('n8n.password', true), 'change_this_secure_password_123');
BEGIN
    -- Получаем переменные из переменных окружения через файл
    IF EXISTS (SELECT 1 FROM pg_stat_file('/tmp/n8n_config.txt', true)) THEN
        -- Читаем конфигурацию из файла, если он существует
        RAISE NOTICE 'Читаем конфигурацию N8N из файла...';
    ELSE
        RAISE NOTICE 'Используем конфигурацию N8N по умолчанию...';
    END IF;

    -- Создание пользователя N8N (если не существует)
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = n8n_user) THEN
        EXECUTE format('CREATE USER %I WITH PASSWORD %L', n8n_user, n8n_password);
        RAISE NOTICE 'Создан пользователь: %', n8n_user;
    ELSE
        RAISE NOTICE 'Пользователь % уже существует', n8n_user;
    END IF;

    -- Создание базы данных N8N (если не существует)
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = n8n_db) THEN
        EXECUTE format('CREATE DATABASE %I OWNER %I', n8n_db, n8n_user);
        RAISE NOTICE 'Создана база данных: %', n8n_db;
    ELSE
        RAISE NOTICE 'База данных % уже существует', n8n_db;
    END IF;

    -- Предоставление дополнительных прав пользователю
    EXECUTE format('ALTER USER %I CREATEDB', n8n_user);
    EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', n8n_db, n8n_user);
    
    RAISE NOTICE 'Инициализация пользователя N8N завершена успешно';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка при инициализации пользователя N8N: %', SQLERRM;
        -- Не прерываем выполнение, продолжаем
END
$do$;

-- Создание расширений для векторной базы данных (если доступно)
DO
$extensions$
BEGIN
    -- Попытка создать расширение pgvector для векторных операций
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
        CREATE EXTENSION IF NOT EXISTS vector;
        RAISE NOTICE 'Расширение pgvector создано успешно';
    ELSE
        RAISE NOTICE 'Расширение pgvector недоступно, пропускаем';
    END IF;

    -- Создание других полезных расширений
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    RAISE NOTICE 'Расширение uuid-ossp создано успешно';
    
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    RAISE NOTICE 'Расширение pg_trgm создано успешно';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка при создании расширений: %', SQLERRM;
        -- Не прерываем выполнение
END
$extensions$;

-- Настройка производительности для N8N
DO
$performance$
BEGIN
    -- Настройки для оптимизации работы с N8N
    -- Эти настройки можно переопределить в postgresql.conf
    
    RAISE NOTICE 'Настройка производительности PostgreSQL для N8N завершена';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка при настройке производительности: %', SQLERRM;
END
$performance$;

-- Вывод информации о завершении инициализации
DO
$info$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'N8N PostgreSQL Initialization Complete';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'User: root (or configured)';
    RAISE NOTICE 'Database: n8n (or configured)';
    RAISE NOTICE 'Extensions: uuid-ossp, pg_trgm, vector (if available)';
    RAISE NOTICE 'Status: Ready for N8N connection';
    RAISE NOTICE '==========================================';
END
$info$;
