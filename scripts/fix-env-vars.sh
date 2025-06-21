#!/bin/bash
# fix-env-vars.sh - Скрипт для исправления проблем с переменными окружения в N8N AI Starter Kit
# Использование: ./scripts/fix-env-vars.sh

echo "===== Исправление переменных окружения ====="
echo "Этот скрипт добавляет отсутствующие переменные окружения в файл .env"

# Проверка существования файла .env
if [ ! -f ".env" ]; then
    echo "ОШИБКА: Файл .env не найден в текущей директории."
    echo "Пожалуйста, запустите скрипт из корневой директории проекта или выполните ./scripts/setup.sh для начальной настройки."
    exit 1
fi

# Бэкап текущего .env файла
timestamp=$(date +"%Y%m%d_%H%M%S")
cp .env ".env.backup_$timestamp"
echo "✅ Создана резервная копия .env: .env.backup_$timestamp"

# Чтение существующих переменных и добавление недостающих
echo "📝 Проверка и добавление необходимых переменных окружения..."

# Функция для копирования переменных
copy_variable() {
    local src_var="$1"
    local dest_var="$2"
    
    src_value=$(grep "^$src_var=" .env | cut -d '=' -f2-)
    dest_check=$(grep "^$dest_var=" .env)
    
    if [ -n "$src_value" ] && [ -z "$dest_check" ]; then
        echo "$dest_var=$src_value" >> .env
        echo "✅ Добавлена переменная $dest_var на основе $src_var"
    fi
}

# Копирование переменных Supabase
copy_variable "SUPABASE_ANON_KEY" "ANON_KEY"
copy_variable "SUPABASE_SERVICE_ROLE_KEY" "SERVICE_ROLE_KEY"
copy_variable "SUPABASE_JWT_SECRET" "JWT_SECRET"

# Генерация или заполнение других переменных, если отсутствуют
add_if_missing() {
    local var_name="$1"
    local var_value="$2"
    local var_comment="$3"
    
    if ! grep -q "^$var_name=" .env; then
        if [ -n "$var_comment" ]; then
            echo "" >> .env
            echo "# $var_comment" >> .env
        fi
        echo "$var_name=$var_value" >> .env
        echo "✅ Добавлена переменная $var_name"
    fi
}

# Добавление переменных для пула соединений
add_if_missing "POOLER_TENANT_ID" "pg_$(openssl rand -hex 6)" "Tenant ID для пула соединений"
add_if_missing "POOLER_DEFAULT_POOL_SIZE" "20" "Размер пула соединений по умолчанию"
add_if_missing "POOLER_MAX_CLIENT_CONN" "100" "Максимальное количество клиентских соединений"
add_if_missing "POOLER_PROXY_PORT_TRANSACTION" "5432" "Порт прокси для транзакций"

# Добавление других необходимых переменных
add_if_missing "IMGPROXY_ENABLE_WEBP_DETECTION" "true" "Включение обнаружения WebP"
add_if_missing "KONG_HTTP_PORT" "8000" "HTTP-порт для Kong"
add_if_missing "KONG_HTTPS_PORT" "8443" "HTTPS-порт для Kong"
add_if_missing "FUNCTIONS_VERIFY_JWT" "true" "Проверка JWT для функций"

echo ""
echo "✅ Все необходимые переменные окружения добавлены в файл .env"

# Улучшенная версия скрипта исправления переменных
echo -e "${BLUE}Расширенная проверка переменных окружения...${NC}"

# Проверка обязательных переменных
required_vars=(
    "N8N_ENCRYPTION_KEY"
    "POSTGRES_PASSWORD" 
    "TRAEFIK_PASSWORD_HASHED"
    "SUPABASE_JWT_SECRET"
    "SUPABASE_ANON_KEY"
    "SUPABASE_SERVICE_ROLE_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if grep -q "^${var}=" .env; then
        echo -e "   ${GREEN}✅ $var${NC}"
    else
        echo -e "   ${RED}❌ $var отсутствует${NC}"
        missing_vars+=("$var")
    fi
done

# Финальная проверка на проблемы
echo -e "${BLUE}=== Итоговая проверка ===${NC}"
if grep -q '\$[^{]' .env; then
    echo -e "${RED}❌ Все еще есть незакавыченные символы $${NC}"
else
    echo -e "${GREEN}✅ Все символы $ корректно экранированы${NC}"
fi

echo "ℹ️ Для применения изменений перезапустите систему с помощью:"
echo "   docker compose down && docker compose --profile cpu up -d"
echo ""
echo "Или используйте скрипт ./scripts/fix-and-start.sh для автоматического исправления и запуска."
