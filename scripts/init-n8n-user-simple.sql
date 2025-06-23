-- =============================================
-- N8N User Initialization Script (Simple)
-- =============================================
-- Создает пользователя N8N с необходимыми правами

-- Создание пользователя n8n (если не существует)
\set password `echo "$N8N_PASSWORD"`
CREATE USER n8n WITH PASSWORD :'password';

-- Создание базы данных n8n (если не существует)
CREATE DATABASE n8n OWNER n8n;
$$;

-- Предоставляем права на базу данных n8n
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

-- Устанавливаем владельца базы данных
ALTER DATABASE n8n OWNER TO n8n;

-- Предоставляем права на создание схем
GRANT CREATE ON DATABASE n8n TO n8n;

RAISE NOTICE 'Пользователь N8N настроен успешно';
