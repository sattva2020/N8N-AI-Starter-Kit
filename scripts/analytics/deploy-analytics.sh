#!/bin/bash

# Deploy Analytics Stack Script
# Развертывание аналитического стека N8N

set -e

echo "🚀 Развертывание Analytics Stack для N8N AI Starter Kit"
echo "=============================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

success() {
    echo -e "${GREEN}[УСПЕХ]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose не установлен"
        exit 1
    fi
    
    success "Все зависимости установлены"
}

# Создание необходимых директорий
create_directories() {
    log "Создание директорий для данных..."
    
    mkdir -p data/clickhouse
    mkdir -p data/superset
    mkdir -p data/postgres-analytics
    mkdir -p data/redis-analytics
    mkdir -p logs/clickhouse
    mkdir -p logs/superset
    mkdir -p logs/postgres
    mkdir -p logs/redis
    mkdir -p logs/etl
    mkdir -p logs/analytics-api
    
    # Установка прав доступа
    chmod 755 data/clickhouse
    chmod 755 data/superset
    chmod 755 data/postgres-analytics
    chmod 755 data/redis-analytics
    
    success "Директории созданы"
}

# Создание Docker networks
create_networks() {
    log "Создание Docker networks..."
    
    # Analytics network
    if ! docker network ls | grep -q "n8n_analytics_network"; then
        docker network create n8n_analytics_network
        success "Создана сеть: n8n_analytics_network"
    else
        warning "Сеть n8n_analytics_network уже существует"
    fi
    
    # Проверка существования основных сетей
    if ! docker network ls | grep -q "n8n_network"; then
        warning "Сеть n8n_network не найдена. Убедитесь, что основные сервисы N8N запущены"
    fi
    
    if ! docker network ls | grep -q "n8n_monitoring_network"; then
        warning "Сеть n8n_monitoring_network не найдена. Мониторинг может быть недоступен"
    fi
}

# Генерация паролей и секретов
generate_secrets() {
    log "Генерация секретов..."
    
    if [ ! -f .env.analytics ]; then
        cat > .env.analytics << EOF
# Analytics Stack Environment Variables
CLICKHOUSE_PASSWORD=clickhouse_pass_$(date +%s)
SUPERSET_SECRET_KEY=superset_secret_$(openssl rand -hex 32)
POSTGRES_PASSWORD=postgres_analytics_$(date +%s)
REDIS_PASSWORD=redis_analytics_$(date +%s)
EOF
        success "Файл .env.analytics создан"
    else
        warning "Файл .env.analytics уже существует"
    fi
}

# Запуск ClickHouse
deploy_clickhouse() {
    log "Развертывание ClickHouse..."
    
    docker-compose -f compose/analytics-compose.yml up -d clickhouse
    
    # Ожидание готовности ClickHouse
    log "Ожидание готовности ClickHouse..."
    for i in {1..30}; do
        if curl -s http://localhost:8123/ > /dev/null 2>&1; then
            success "ClickHouse готов"
            break
        fi
        sleep 5
        if [ $i -eq 30 ]; then
            error "ClickHouse не запустился в течение 150 секунд"
            exit 1
        fi
    done
}

# Запуск PostgreSQL для Superset
deploy_postgres() {
    log "Развертывание PostgreSQL для Superset..."
    
    docker-compose -f compose/analytics-compose.yml up -d postgres
    
    # Ожидание готовности PostgreSQL
    log "Ожидание готовности PostgreSQL..."
    for i in {1..20}; do
        if docker-compose -f compose/analytics-compose.yml exec -T postgres pg_isready -U superset > /dev/null 2>&1; then
            success "PostgreSQL готов"
            break
        fi
        sleep 3
        if [ $i -eq 20 ]; then
            error "PostgreSQL не запустился в течение 60 секунд"
            exit 1
        fi
    done
}

# Запуск Redis
deploy_redis() {
    log "Развертывание Redis..."
    
    docker-compose -f compose/analytics-compose.yml up -d redis
    
    # Ожидание готовности Redis
    log "Ожидание готовности Redis..."
    for i in {1..15}; do
        if docker-compose -f compose/analytics-compose.yml exec -T redis redis-cli ping > /dev/null 2>&1; then
            success "Redis готов"
            break
        fi
        sleep 2
        if [ $i -eq 15 ]; then
            error "Redis не запустился в течение 30 секунд"
            exit 1
        fi
    done
}

# Инициализация и запуск Superset
deploy_superset() {
    log "Инициализация Superset..."
    
    # Запуск инициализации
    docker-compose -f compose/analytics-compose.yml up --no-deps superset-init
    
    log "Запуск Superset..."
    docker-compose -f compose/analytics-compose.yml up -d superset
    
    # Ожидание готовности Superset
    log "Ожидание готовности Superset..."
    for i in {1..60}; do
        if curl -s http://localhost:8088/health > /dev/null 2>&1; then
            success "Superset готов"
            break
        fi
        sleep 5
        if [ $i -eq 60 ]; then
            error "Superset не запустился в течение 300 секунд"
            exit 1
        fi
    done
}

# Запуск ETL сервисов
deploy_etl_services() {
    log "Развертывание ETL сервисов..."
    
    # ETL Processor
    docker-compose -f compose/analytics-compose.yml up -d etl-processor
    
    # Analytics API
    docker-compose -f compose/analytics-compose.yml up -d analytics-api
    
    # Ожидание готовности сервисов
    log "Ожидание готовности ETL сервисов..."
    sleep 10
    
    # Проверка ETL Processor
    for i in {1..20}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            success "ETL Processor готов"
            break
        fi
        sleep 3
        if [ $i -eq 20 ]; then
            warning "ETL Processor может быть недоступен"
        fi
    done
    
    # Проверка Analytics API
    for i in {1..20}; do
        if curl -s http://localhost:8089/health > /dev/null 2>&1; then
            success "Analytics API готов"
            break
        fi
        sleep 3
        if [ $i -eq 20 ]; then
            warning "Analytics API может быть недоступен"
        fi
    done
}

# Проверка состояния всех сервисов
check_services() {
    log "Проверка состояния сервисов..."
    
    echo ""
    echo "🔍 Статус Analytics Stack:"
    echo "========================"
    
    # ClickHouse
    if curl -s http://localhost:8123/ > /dev/null 2>&1; then
        echo -e "✅ ClickHouse: ${GREEN}Работает${NC} (http://localhost:8123)"
    else
        echo -e "❌ ClickHouse: ${RED}Недоступен${NC}"
    fi
    
    # Superset
    if curl -s http://localhost:8088/health > /dev/null 2>&1; then
        echo -e "✅ Superset: ${GREEN}Работает${NC} (http://localhost:8088)"
        echo -e "   👤 Логин: admin / admin123"
    else
        echo -e "❌ Superset: ${RED}Недоступен${NC}"
    fi
    
    # Analytics API
    if curl -s http://localhost:8089/health > /dev/null 2>&1; then
        echo -e "✅ Analytics API: ${GREEN}Работает${NC} (http://localhost:8089)"
    else
        echo -e "❌ Analytics API: ${RED}Недоступен${NC}"
    fi
    
    # ETL Processor
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "✅ ETL Processor: ${GREEN}Работает${NC} (http://localhost:8080)"
    else
        echo -e "❌ ETL Processor: ${RED}Недоступен${NC}"
    fi
    
    echo ""
    echo "📊 Analytics Dashboard доступен по адресу: http://localhost:8088"
    echo "🔑 API документация: http://localhost:8089/docs"
    echo ""
}

# Главная функция
main() {
    echo ""
    log "Начало развертывания Analytics Stack"
    
    check_dependencies
    create_directories
    create_networks
    generate_secrets
    
    log "Развертывание компонентов..."
    deploy_clickhouse
    deploy_postgres
    deploy_redis
    deploy_superset
    deploy_etl_services
    
    check_services
    
    success "🎉 Analytics Stack успешно развернут!"
    echo ""
    echo "🚀 Следующие шаги:"
    echo "1. Откройте Superset: http://localhost:8088"
    echo "2. Войдите как admin/admin123"
    echo "3. Создайте дашборды и графики"
    echo "4. Настройте источники данных из ClickHouse"
    echo ""
    echo "📖 Документация: docs/ANALYTICS_SETUP_GUIDE.md"
}

# Обработка аргументов
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "status")
        check_services
        ;;
    "stop")
        log "Остановка Analytics Stack..."
        docker-compose -f compose/analytics-compose.yml down
        success "Analytics Stack остановлен"
        ;;
    "restart")
        log "Перезапуск Analytics Stack..."
        docker-compose -f compose/analytics-compose.yml restart
        success "Analytics Stack перезапущен"
        ;;
    "logs")
        docker-compose -f compose/analytics-compose.yml logs -f
        ;;
    "help")
        echo "Использование: $0 [deploy|status|stop|restart|logs|help]"
        echo ""
        echo "Команды:"
        echo "  deploy   - Развернуть Analytics Stack (по умолчанию)"
        echo "  status   - Проверить статус сервисов"
        echo "  stop     - Остановить все сервисы"
        echo "  restart  - Перезапустить все сервисы"
        echo "  logs     - Показать логи"
        echo "  help     - Показать эту справку"
        ;;
    *)
        error "Неизвестная команда: $1"
        echo "Используйте '$0 help' для справки"
        exit 1
        ;;
esac
