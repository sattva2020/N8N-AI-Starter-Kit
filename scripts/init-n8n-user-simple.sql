-- =============================================
-- N8N User Initialization Script (Simple)
-- =============================================
-- Создает пользователя N8N с необходимыми правами

-- Проверяем, существует ли пользователь n8n
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n') THEN
        CREATE USER n8n WITH PASSWORD 'AkQhtouKmdoXOYKD';
        RAISE NOTICE 'Пользователь n8n создан';
    ELSE
        RAISE NOTICE 'Пользователь n8n уже существует';
    END IF;
END
$$;

-- Предоставляем права на базу данных n8n
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

-- Устанавливаем владельца базы данных
ALTER DATABASE n8n OWNER TO n8n;

-- Предоставляем права на создание схем
GRANT CREATE ON DATABASE n8n TO n8n;

RAISE NOTICE 'Пользователь N8N настроен успешно';
