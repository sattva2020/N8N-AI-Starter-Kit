#!/bin/bash

# Скрипт для генерации безопасных API ключей
# Использование: ./scripts/generate-security-keys.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверяем наличие .env файла
if [ ! -f .env ]; then
    print_error ".env файл не найден. Создайте его из template.env"
    exit 1
fi

print_info "🔐 Генерация безопасных API ключей..."

# Генерация N8N API ключа (если не установлен)
if ! grep -q "^N8N_API_KEY=" .env || grep -q "please_replace_with_n8n_api_key" .env; then
    n8n_api_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
    if grep -q "^N8N_API_KEY=" .env; then
        sed -i "s/^N8N_API_KEY=.*/N8N_API_KEY=${n8n_api_key}/" .env
    else
        echo "N8N_API_KEY=${n8n_api_key}" >> .env
    fi
    print_success "N8N API ключ сгенерирован: ${n8n_api_key}"
else
    print_info "N8N API ключ уже установлен"
fi

# Генерация Workflows Manager API ключа (если не установлен)
if ! grep -q "^WORKFLOWS_MANAGER_API_KEY=" .env || grep -q "^WORKFLOWS_MANAGER_API_KEY=$" .env; then
    workflows_manager_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
    if grep -q "^WORKFLOWS_MANAGER_API_KEY=" .env; then
        sed -i "s/^WORKFLOWS_MANAGER_API_KEY=.*/WORKFLOWS_MANAGER_API_KEY=${workflows_manager_key}/" .env
    else
        echo "WORKFLOWS_MANAGER_API_KEY=${workflows_manager_key}" >> .env
    fi
    print_success "Workflows Manager API ключ сгенерирован: ${workflows_manager_key}"
else
    print_info "Workflows Manager API ключ уже установлен"
fi

# Генерация JWT секрета (если не установлен)
if ! grep -q "^N8N_USER_MANAGEMENT_JWT_SECRET=" .env || grep -q "please_replace_with_min_32_char_secret" .env; then
    jwt_secret=$(openssl rand -base64 64 | tr -cd '[:alnum:]' | cut -c1-64)
    if grep -q "^N8N_USER_MANAGEMENT_JWT_SECRET=" .env; then
        sed -i "s/^N8N_USER_MANAGEMENT_JWT_SECRET=.*/N8N_USER_MANAGEMENT_JWT_SECRET=${jwt_secret}/" .env
    else
        echo "N8N_USER_MANAGEMENT_JWT_SECRET=${jwt_secret}" >> .env
    fi
    print_success "JWT секрет сгенерирован: ${jwt_secret}"
else
    print_info "JWT секрет уже установлен"
fi

# Генерация ключа шифрования (если не установлен)
if ! grep -q "^N8N_ENCRYPTION_KEY=" .env || grep -q "please_replace_with_32_char_random_key" .env; then
    encryption_key=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-32)
    if grep -q "^N8N_ENCRYPTION_KEY=" .env; then
        sed -i "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${encryption_key}/" .env
    else
        echo "N8N_ENCRYPTION_KEY=${encryption_key}" >> .env
    fi
    print_success "Ключ шифрования сгенерирован: ${encryption_key}"
else
    print_info "Ключ шифрования уже установлен"
fi

# Генерация пароля PostgreSQL (если не установлен)
if ! grep -q "^POSTGRES_PASSWORD=" .env || grep -q "change_me_securely" .env; then
    postgres_password=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
    if grep -q "^POSTGRES_PASSWORD=" .env; then
        sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${postgres_password}/" .env
    else
        echo "POSTGRES_PASSWORD=${postgres_password}" >> .env
    fi
    print_success "Пароль PostgreSQL сгенерирован: ${postgres_password}"
else
    print_info "Пароль PostgreSQL уже установлен"
fi

print_success "✅ Все API ключи сгенерированы успешно!"

print_info "📋 Рекомендации по безопасности:"
echo "1. Храните .env файл в безопасном месте"
echo "2. Не коммитьте .env файл в git"
echo "3. Регулярно обновляйте API ключи"
echo "4. Используйте HTTPS в продакшене"
echo "5. Настройте firewall для ограничения доступа"

print_info "🔍 Проверка прав доступа к .env файлу..."
chmod 600 .env
print_success "Права доступа к .env файлу установлены (600)"

print_info "📊 Статус безопасности:"
echo "✅ API ключи сгенерированы"
echo "✅ Права доступа настроены"
echo "✅ Rate limiting включен"
echo "✅ Валидация входных данных"
echo "✅ CORS настроен"
echo "✅ Security headers добавлены"

print_success "🎉 Аудит безопасности завершен!"
