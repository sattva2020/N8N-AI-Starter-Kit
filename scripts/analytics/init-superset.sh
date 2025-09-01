#!/bin/bash

# Superset initialization script
echo "Инициализация Superset..."

# Wait for dependencies
echo "Ожидание готовности PostgreSQL..."
while ! pg_isready -h postgres -p 5432 -U superset; do
    echo "PostgreSQL не готов, ожидание..."
    sleep 5
done

echo "Ожидание готовности Redis..."
while ! redis-cli -h redis ping; do
    echo "Redis не готов, ожидание..."
    sleep 5
done

echo "Ожидание готовности ClickHouse..."
while ! curl -s http://clickhouse:8123/ > /dev/null; do
    echo "ClickHouse не готов, ожидание..."
    sleep 5
done

# Initialize Superset database
echo "Инициализация базы данных Superset..."
superset db upgrade

# Create admin user if not exists
echo "Создание администратора..."
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@n8n-analytics.local \
    --password admin123

# Load examples (optional)
echo "Загрузка примеров..."
# superset load_examples

# Initialize roles and permissions
echo "Инициализация ролей и разрешений..."
superset init

# Create ClickHouse database connection
echo "Создание подключения к ClickHouse..."
python3 << EOF
import os
from superset import app, db
from superset.models.core import Database

# Create app context
with app.app_context():
    # Check if ClickHouse database already exists
    existing_db = db.session.query(Database).filter_by(database_name='ClickHouse Analytics').first()
    
    if not existing_db:
        clickhouse_db = Database(
            database_name='ClickHouse Analytics',
            sqlalchemy_uri='clickhouse+native://analytics_user:clickhouse_pass_2024@clickhouse:9000/n8n_analytics',
            expose_in_sqllab=True,
            allow_ctas=True,
            allow_cvas=True,
            allow_dml=False,
            allow_run_async=True
        )
        
        db.session.add(clickhouse_db)
        db.session.commit()
        print("ClickHouse database connection created successfully")
    else:
        print("ClickHouse database connection already exists")
EOF

echo "Superset инициализация завершена!"
