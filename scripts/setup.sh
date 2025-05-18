#!/bin/bash
# filepath: scripts/setup.sh

echo "==================================="
echo "  N8N AI Starter Kit - Установка   "
echo "==================================="

# Проверка зависимостей
echo "Проверка зависимостей..."
command -v docker >/dev/null 2>&1 || { echo "Требуется Docker, но он не установлен. Установите Docker и повторите попытку."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "Требуется openssl, но он не установлен. Установите openssl и повторите попытку."; exit 1; }

# Создание .env файла
if [ -f .env ]; then
  read -p "Файл .env уже существует. Перезаписать? (y/n): " overwrite
  if [ "$overwrite" != "y" ]; then
    echo "Сохранение существующего файла .env"
    exit 0
  fi
fi

# Ввод базовых настроек
echo -e "\n--- Настройка основных параметров ---"
read -p "Введите основное доменное имя (например, example.com): " domain_name
read -p "Введите ваш email (для Let's Encrypt и уведомлений): " email

# Генерация паролей и ключей
echo -e "\nГенерация безопасных паролей и ключей..."
postgres_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
n8n_encryption_key=$(openssl rand -base64 32 | tr -d "=" | tr -d "/+")
n8n_jwt_secret=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")
supabase_postgres_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
supabase_anon_key=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")
supabase_service_role_key=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")
supabase_jwt_secret=$(openssl rand -base64 32 | tr -d "=" | tr -d "/+")
minio_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
pgadmin_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
zep_api_secret=$(openssl rand -base64 48 | tr -d "=" | tr -d "/+")
# Добавляем генерацию учетных данных для Grafana и Jupyter DS
grafana_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
jupyter_ds_token=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")

# Генерация хэша пароля для Traefik Dashboard
read -p "Введите пароль для панели управления Traefik: " traefik_pwd
traefik_pwd_hash=$(openssl passwd -apr1 $traefik_pwd)

# Запрос API ключа OpenAI
read -p "Введите ваш OpenAI API ключ (или оставьте пустым, чтобы настроить позже): " openai_key

# Создание файла .env
cat > .env << EOF
# =============================================
# N8N AI Starter Kit - Конфигурация окружения
# =============================================
# Создано автоматически $(date)
# Последнее обновление: $(date)

# ---- БАЗОВЫЕ НАСТРОЙКИ ----
DOMAIN_NAME=${domain_name}

# ---- POSTGRESQL ----
# Main Database для n8n
POSTGRES_USER=root
POSTGRES_PASSWORD=${postgres_pwd}
POSTGRES_DB=n8n

# ---- N8N НАСТРОЙКИ ----
N8N_ENCRYPTION_KEY=${n8n_encryption_key}
N8N_USER_MANAGEMENT_JWT_SECRET=${n8n_jwt_secret}
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# ---- SUPABASE НАСТРОЙКИ ----
SUPABASE_POSTGRES_PASSWORD=${supabase_postgres_pwd}
SUPABASE_ANON_KEY=${supabase_anon_key}
SUPABASE_SERVICE_ROLE_KEY=${supabase_service_role_key}
SUPABASE_JWT_SECRET=${supabase_jwt_secret}

# ---- MINIO НАСТРОЙКИ ----
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=${minio_pwd}

# ---- PGADMIN НАСТРОЙКИ ----
PGADMIN_DEFAULT_EMAIL=${email}
PGADMIN_DEFAULT_PASSWORD=${pgadmin_pwd}

# ---- TRAEFIK НАСТРОЙКИ ----
ACME_EMAIL=${email}
TRAEFIK_USERNAME=admin
TRAEFIK_PASSWORD_HASHED=\${traefik_pwd_hash}

# ---- ZEP НАСТРОЙКИ ----
ZEP_POSTGRES_USER=postgres
ZEP_POSTGRES_PASSWORD=postgres
ZEP_POSTGRES_DB=postgres
ZEP_API_SECRET=${zep_api_secret}

# ---- GRAPHITI НАСТРОЙКИ ----
OPENAI_API_KEY=${openai_key}

# ---- JUPYTER НАСТРОЙКИ ----
# JUPYTER_TOKEN=your_secure_jupyter_token

# ---- GRAFANA НАСТРОЙКИ ----
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=${grafana_pwd}

# ---- JUPYTER DATA SCIENCE НАСТРОЙКИ ----
JUPYTER_DS_TOKEN=${jupyter_ds_token}

# ---- ДОМЕНЫ СЕРВИСОВ ----
N8N_DOMAIN=n8n.${domain_name}
OLLAMA_DOMAIN=ollama.${domain_name}
QDRANT_DOMAIN=qdrant.${domain_name}
SUPABASE_STUDIO_DOMAIN=supabase.${domain_name}
SUPABASE_API_DOMAIN=api.supabase.${domain_name}
MINIO_API_DOMAIN=minio.${domain_name}
MINIO_CONSOLE_DOMAIN=minio-console.${domain_name}
PGADMIN_DOMAIN=pgadmin.${domain_name}
JUPYTER_DOMAIN=jupyter.${domain_name}
TRAEFIK_DASHBOARD_DOMAIN=traefik.${domain_name}
ZEP_DOMAIN=zep.${domain_name}
GRAPHITI_DOMAIN=graphiti.${domain_name}

# ---- ДОПОЛНИТЕЛЬНЫЕ ДОМЕНЫ СЕРВИСОВ ----
PROMETHEUS_DOMAIN=prometheus.${domain_name}
GRAFANA_DOMAIN=grafana.${domain_name}
CADVISOR_DOMAIN=cadvisor.${domain_name}
LOKI_DOMAIN=loki.${domain_name}
KIBANA_DOMAIN=kibana.${domain_name}
JUPYTER_DS_DOMAIN=jupyter-ds.${domain_name}
LANGSMITH_DOMAIN=langsmith.${domain_name}
WANDB_DOMAIN=wandb.${domain_name}
EOF

echo -e "\nФайл .env успешно создан!"
echo -e "\nНастройка завершена!"
echo "Для запуска проекта выполните: docker compose --profile cpu up -d"
echo -e "\nДля запуска с GPU Nvidia выполните:"
echo "docker compose --profile gpu-nvidia up -d"
echo -e "\nДля запуска с GPU AMD выполните:"
echo "docker compose --profile gpu-amd up -d"
echo -e "\nВажно: Сохраните копию файла .env в безопасном месте!"