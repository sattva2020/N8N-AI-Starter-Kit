#!/bin/bash
set -e

echo "Creating n8n user and database..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create n8n user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$N8N_USER') THEN
            CREATE USER $N8N_USER WITH PASSWORD '$N8N_PASSWORD';
            RAISE NOTICE 'User $N8N_USER created';
        ELSE
            RAISE NOTICE 'User $N8N_USER already exists';
        END IF;
    END
    \$\$;
    
    -- Grant privileges on database
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $N8N_USER;
    
    -- Grant schema privileges
    GRANT ALL ON SCHEMA public TO $N8N_USER;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $N8N_USER;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $N8N_USER;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $N8N_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $N8N_USER;
EOSQL

echo "N8N user setup completed successfully."
