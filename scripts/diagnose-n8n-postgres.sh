#!/bin/bash

# =============================================
# N8N + PostgreSQL Connection Diagnostics
# =============================================
# Диагностика соединения между N8N и PostgreSQL
# Проверка конфигурации, доступности и совместимости

set -e

echo "🔍 Диагностика соединения N8N + PostgreSQL"
echo "=========================================="

# Загрузка переменных окружения
source .env 2>/dev/null || true

# Функция для вывода статуса
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "ok" ]; then
        echo "✅ $message"
    elif [ "$status" = "warn" ]; then
        echo "⚠️  $message"
    else
        echo "❌ $message"
    fi
}

# Функция для проверки переменных окружения
check_env_vars() {
    echo ""
    echo "1️⃣  Проверка переменных окружения:"
    echo "-----------------------------------"
    
    local required_vars=("POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB" "POSTGRES_HOST" "POSTGRES_PORT" "N8N_ENCRYPTION_KEY")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
            print_status "error" "$var - не задана"
        else
            print_status "ok" "$var = ${!var}"
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo ""
        echo "❌ Критическая ошибка: отсутствуют обязательные переменные окружения"
        echo "Добавьте в файл .env:"
        for var in "${missing_vars[@]}"; do
            echo "   $var=значение"
        done
        return 1
    fi
    
    return 0
}

# Функция для проверки статуса контейнеров
check_containers() {
    echo ""
    echo "2️⃣  Проверка статуса контейнеров:"
    echo "---------------------------------"
    
    local containers=("n8n-ai-starter-kit-postgres-1" "n8n-ai-starter-kit-n8n-1")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
            
            if [ "$status" = "running" ]; then
                if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                    print_status "ok" "$container - запущен и работает"
                else
                    print_status "warn" "$container - запущен, но статус здоровья: $health"
                fi
            else
                print_status "error" "$container - статус: $status"
            fi
        else
            print_status "error" "$container - не найден или не запущен"
        fi
    done
}

# Функция для проверки доступности PostgreSQL
check_postgres_connectivity() {
    echo ""
    echo "3️⃣  Проверка доступности PostgreSQL:"
    echo "-----------------------------------"
    
    # Проверка доступности postgres через pg_isready
    if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then
        print_status "ok" "PostgreSQL сервер отвечает на запросы"
    else
        print_status "error" "PostgreSQL сервер недоступен"
        return 1
    fi
    
    # Проверка подключения с административными правами
    if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "SELECT version();" >/dev/null 2>&1; then
        print_status "ok" "Подключение с правами администратора работает"
    else
        print_status "error" "Ошибка подключения с правами администратора"
        return 1
    fi
    
    # Проверка существования базы данных
    if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "$POSTGRES_DB"; then
        print_status "ok" "База данных '$POSTGRES_DB' существует"
    else
        print_status "error" "База данных '$POSTGRES_DB' не найдена"
        echo "   💡 Запустите: ./scripts/init-postgres.sh"
        return 1
    fi
    
    # Проверка пользователя N8N
    if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='$POSTGRES_USER';" | grep -q "1"; then
        print_status "ok" "Пользователь '$POSTGRES_USER' существует"
    else
        print_status "error" "Пользователь '$POSTGRES_USER' не найден"
        echo "   💡 Запустите: ./scripts/init-postgres.sh"
        return 1
    fi
    
    # Проверка подключения пользователя N8N
    if docker exec n8n-ai-starter-kit-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
        print_status "ok" "Пользователь '$POSTGRES_USER' может подключиться к базе '$POSTGRES_DB'"
    else
        print_status "error" "Пользователь '$POSTGRES_USER' не может подключиться к базе '$POSTGRES_DB'"
        echo "   💡 Запустите: ./scripts/init-postgres.sh"
        return 1
    fi
}

# Функция для проверки сетевой связности
check_network_connectivity() {
    echo ""
    echo "4️⃣  Проверка сетевой связности:"
    echo "------------------------------"
    
    # Проверка резолвинга имени postgres в контейнере N8N
    if docker exec n8n-ai-starter-kit-n8n-1 nslookup postgres >/dev/null 2>&1; then
        print_status "ok" "N8N может резолвить имя 'postgres'"
    else
        print_status "error" "N8N не может резолвить имя 'postgres'"
        echo "   💡 Проверьте конфигурацию сетей в docker-compose.yml"
        return 1
    fi
    
    # Проверка доступности порта PostgreSQL из контейнера N8N
    if docker exec n8n-ai-starter-kit-n8n-1 nc -z postgres "$POSTGRES_PORT" >/dev/null 2>&1; then
        print_status "ok" "N8N может подключиться к postgres:$POSTGRES_PORT"
    else
        print_status "error" "N8N не может подключиться к postgres:$POSTGRES_PORT"
        return 1
    fi
}

# Функция для проверки логов N8N
check_n8n_logs() {
    echo ""
    echo "5️⃣  Проверка логов N8N:"
    echo "----------------------"
    
    local logs=$(docker logs n8n-ai-starter-kit-n8n-1 --tail 20 2>&1)
    
    if echo "$logs" | grep -q "Successfully connected to database"; then
        print_status "ok" "N8N успешно подключился к базе данных"
    elif echo "$logs" | grep -q "Database connection successful"; then
        print_status "ok" "N8N успешно подключился к базе данных"
    elif echo "$logs" | grep -q "Editor is now accessible"; then
        print_status "ok" "N8N запущен и готов к работе"
    else
        print_status "warn" "Не найдены сообщения об успешном подключении к БД"
    fi
    
    # Проверка ошибок в логах
    local error_patterns=("connection refused" "authentication failed" "password authentication" "database.*does not exist" "role.*does not exist")
    
    for pattern in "${error_patterns[@]}"; do
        if echo "$logs" | grep -qi "$pattern"; then
            print_status "error" "Найдена ошибка в логах: $(echo "$logs" | grep -i "$pattern" | tail -1)"
        fi
    done
}

# Функция для проверки API N8N
check_n8n_api() {
    echo ""
    echo "6️⃣  Проверка API N8N:"
    echo "--------------------"
    
    # Проверка healthcheck endpoint
    if curl -s -f "http://localhost:5678/healthz" >/dev/null 2>&1; then
        print_status "ok" "N8N API доступен через http://localhost:5678/healthz"
    else
        print_status "error" "N8N API недоступен через http://localhost:5678/healthz"
        return 1
    fi
    
    # Проверка основной страницы
    if curl -s "http://localhost:5678/" | grep -q "n8n" >/dev/null 2>&1; then
        print_status "ok" "N8N веб-интерфейс отвечает"
    else
        print_status "warn" "N8N веб-интерфейс может быть недоступен"
    fi
}

# Функция для вывода рекомендаций
print_recommendations() {
    echo ""
    echo "💡 Рекомендации для устранения проблем:"
    echo "======================================="
    echo ""
    echo "1. Если PostgreSQL не инициализирован:"
    echo "   ./scripts/init-postgres.sh"
    echo ""
    echo "2. Если есть проблемы с сетью:"
    echo "   docker compose down && docker compose up -d"
    echo ""
    echo "3. Если нужно пересоздать volumes:"
    echo "   docker compose down -v && docker volume rm n8n_storage postgres_storage"
    echo "   docker compose up -d"
    echo ""
    echo "4. Для просмотра логов:"
    echo "   docker logs n8n-ai-starter-kit-n8n-1 -f"
    echo "   docker logs n8n-ai-starter-kit-postgres-1 -f"
    echo ""
    echo "5. Для полной переинициализации:"
    echo "   ./scripts/reset-n8n-postgres.sh"
    echo ""
}

# Основная функция
main() {
    local exit_code=0
    
    # Выполнение всех проверок
    check_env_vars || exit_code=1
    check_containers || exit_code=1
    check_postgres_connectivity || exit_code=1
    check_network_connectivity || exit_code=1
    check_n8n_logs || exit_code=1
    check_n8n_api || exit_code=1
    
    echo ""
    echo "=========================================="
    if [ $exit_code -eq 0 ]; then
        echo "🎉 Все проверки пройдены успешно!"
        echo "N8N + PostgreSQL работают корректно."
    else
        echo "⚠️  Обнаружены проблемы в конфигурации."
        print_recommendations
    fi
    echo "=========================================="
    
    return $exit_code
}

# Запуск диагностики
main "$@"
