#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\scripts\setup-pgvector.sh

# Этот скрипт устанавливает pgvector в контейнер PostgreSQL

set -e

echo "🔍 Установка pgvector в контейнер PostgreSQL..."

# Установка pgvector в контейнер
docker exec -it zep-ce-postgres bash -c "
apt-get update && 
apt-get install -y postgresql-server-dev-15 build-essential git &&
git clone --branch v0.6.0 https://github.com/pgvector/pgvector.git &&
cd pgvector &&
make &&
make install &&
echo 'CREATE EXTENSION vector;' | psql -U postgres postgres
"

echo "✅ pgvector успешно установлен!"
