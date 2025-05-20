#!/bin/bash

# Создание файла .env из шаблона, если он не существует
if [ ! -f .env ]; then
  cp scripts/template.env .env
  echo "Создан новый файл .env из шаблона"
fi

# Генерация случайной строки заданной длины
generate_random_string() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# Установка переменных, если они не определены
set_if_empty() {
  var_name=$1
  var_value=$2
  
  if ! grep -q "^$var_name=" .env || grep -q "^$var_name=$" .env || grep -q "^$var_name=\"\"" .env; then
    # Если переменная не существует или пустая
    sed -i "s|^$var_name=.*|$var_name=$var_value|" .env
    if ! grep -q "^$var_name=" .env; then
      echo "$var_name=$var_value" >> .env
    fi
    echo "Установлено значение для $var_name"
  fi
}

# Установка основных переменных
set_if_empty "JWT_SECRET" "$(generate_random_string 32)"
set_if_empty "JWT_EXPIRY" "3600"
set_if_empty "POSTGRES_HOST" "supabase-db"
set_if_empty "POSTGRES_PORT" "5432"
set_if_empty "POSTGRES_DB" "postgres"
set_if_empty "POSTGRES_USER" "postgres"
set_if_empty "POSTGRES_PASSWORD" "$(generate_random_string 16)"
set_if_empty "ANON_KEY" "$(generate_random_string 64)"
set_if_empty "SERVICE_ROLE_KEY" "$(generate_random_string 64)"
set_if_empty "POOLER_TENANT_ID" "n8n_$(generate_random_string 8)"
set_if_empty "POOLER_DEFAULT_POOL_SIZE" "20"
set_if_empty "POOLER_MAX_CLIENT_CONN" "100"
set_if_empty "SECRET_KEY_BASE" "$(generate_random_string 64)"
set_if_empty "VAULT_ENC_KEY" "$(generate_random_string 32)"
set_if_empty "POOLER_PROXY_PORT_TRANSACTION" "6543"
set_if_empty "LOGFLARE_API_KEY" "$(generate_random_string 16)"

# Установка переменных для Supabase
set_if_empty "IMGPROXY_ENABLE_WEBP_DETECTION" "true"
set_if_empty "KONG_HTTP_PORT" "8000"
set_if_empty "KONG_HTTPS_PORT" "8443"
set_if_empty "DASHBOARD_USERNAME" "admin"
set_if_empty "DASHBOARD_PASSWORD" "$(generate_random_string 12)"
set_if_empty "FUNCTIONS_VERIFY_JWT" "false"
set_if_empty "SUPABASE_PUBLIC_URL" "http://localhost:8000"

# Настройки для Supabase Studio
set_if_empty "STUDIO_DEFAULT_ORGANIZATION" "n8n"
set_if_empty "STUDIO_DEFAULT_PROJECT" "n8n-ai-project"

# Настройки для REST API
set_if_empty "PGRST_DB_SCHEMAS" "public,storage,graphql_public"

# Настройки для аутентификации
set_if_empty "SMTP_ADMIN_EMAIL" "admin@example.com"
set_if_empty "SMTP_HOST" "smtp.example.com"
set_if_empty "SMTP_PORT" "587"
set_if_empty "SMTP_USER" "smtp_user"
set_if_empty "SMTP_PASS" "$(generate_random_string 12)"
set_if_empty "SMTP_SENDER_NAME" "N8N AI Starter Kit"
set_if_empty "SITE_URL" "http://localhost:8000"
set_if_empty "API_EXTERNAL_URL" "http://localhost:8000"
set_if_empty "ADDITIONAL_REDIRECT_URLS" ""
set_if_empty "DISABLE_SIGNUP" "false"
set_if_empty "ENABLE_EMAIL_SIGNUP" "true"
set_if_empty "ENABLE_EMAIL_AUTOCONFIRM" "true"
set_if_empty "ENABLE_PHONE_SIGNUP" "false"
set_if_empty "ENABLE_PHONE_AUTOCONFIRM" "false"
set_if_empty "ENABLE_ANONYMOUS_USERS" "false"
set_if_empty "MAILER_URLPATHS_INVITE" "/auth/v1/verify"
set_if_empty "MAILER_URLPATHS_CONFIRMATION" "/auth/v1/verify"
set_if_empty "MAILER_URLPATHS_RECOVERY" "/auth/v1/verify"
set_if_empty "MAILER_URLPATHS_EMAIL_CHANGE" "/auth/v1/verify"

echo "Переменные окружения установлены успешно"
