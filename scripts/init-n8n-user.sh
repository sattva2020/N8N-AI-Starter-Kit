#!/bin/bash
set -e

echo "Creating n8n user and database..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- Создать пользователя n8n, если не существует, иначе обновить пароль
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${N8N_USER}') THEN
            CREATE USER ${N8N_USER} WITH PASSWORD '${N8N_PASSWORD}';
            RAISE NOTICE 'User $N8N_USER created with password';
        ELSE
            ALTER USER ${N8N_USER} WITH PASSWORD '${N8N_PASSWORD}';
            RAISE NOTICE 'User $N8N_USER already exists, password updated';
        END IF;
    END
    \$\$;

    -- Создать базу только если не существует
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${N8N_USER}') THEN
            CREATE DATABASE ${N8N_USER} OWNER ${N8N_USER};
        END IF;
    END
    \$\$;

    -- Назначить владельца базы (на всякий случай)
    ALTER DATABASE ${N8N_USER} OWNER TO ${N8N_USER};
EOSQL

echo "N8N user setup completed successfully."