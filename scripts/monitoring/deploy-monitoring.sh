#!/bin/bash

# N8N AI Starter Kit - Monitoring Stack Deployment Script
# Развертывает Prometheus, Grafana, AlertManager и связанные сервисы

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/compose/monitoring-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env"

# Функции для логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Проверяем Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Проверяем Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Проверяем файлы конфигурации
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Monitoring compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warning "Environment file not found: $ENV_FILE"
        log_info "Creating basic .env file..."
        create_basic_env
    fi
    
    log_success "Dependencies check passed"
}

# Создание базового .env файла
create_basic_env() {
    cat > "$ENV_FILE" << 'EOF'
# N8N AI Starter Kit Environment Configuration

# Domain configuration
DOMAIN_NAME=localhost

# Grafana configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123

# N8N configuration
N8N_API_KEY=your-api-key-here

# PostgreSQL configuration
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8n
POSTGRES_DB=n8n
POSTGRES_PORT=5432

# Environment
ENVIRONMENT=development
EOF
    log_success "Created basic .env file"
}

# Проверка сети Docker
check_network() {
    log_info "Checking Docker networks..."
    
    # Проверяем существование сети n8n_network
    if ! docker network ls | grep -q "n8n_network"; then
        log_warning "n8n_network not found, creating..."
        docker network create n8n_network
        log_success "Created n8n_network"
    fi
}

# Создание необходимых директорий
create_directories() {
    log_info "Creating necessary directories..."
    
    # Создаем директории для данных
    mkdir -p "$PROJECT_ROOT/data/prometheus"
    mkdir -p "$PROJECT_ROOT/data/grafana"
    mkdir -p "$PROJECT_ROOT/data/alertmanager"
    
    # Устанавливаем правильные права доступа
    chmod 755 "$PROJECT_ROOT/data/prometheus"
    chmod 755 "$PROJECT_ROOT/data/grafana" 
    chmod 755 "$PROJECT_ROOT/data/alertmanager"
    
    log_success "Directories created"
}

# Создание .env файла для monitoring
create_monitoring_env() {
    local monitoring_env="$PROJECT_ROOT/compose/.env.monitoring"
    
    log_info "Creating monitoring environment file..."
    
    cat > "$monitoring_env" << EOF
# Monitoring Stack Environment Variables
PROMETHEUS_RETENTION=30d
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
ALERTMANAGER_EXTERNAL_URL=http://alerts.\${DOMAIN_NAME:-localhost}
N8N_API_KEY=${N8N_API_KEY:-}
POSTGRES_USER=${POSTGRES_USER:-n8n}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-n8n}
POSTGRES_DB=${POSTGRES_DB:-n8n}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
EOF
    
    log_success "Monitoring environment file created"
}

# Сборка кастомных образов
build_images() {
    log_info "Building custom images..."
    
    cd "$PROJECT_ROOT"
    
    # Собираем N8N exporter
    log_info "Building N8N exporter..."
    docker-compose -f "$COMPOSE_FILE" build n8n-exporter
    
    # Собираем PostgreSQL exporter
    log_info "Building PostgreSQL exporter..."
    docker-compose -f "$COMPOSE_FILE" build postgres-exporter
    
    log_success "Custom images built"
}

# Запуск мониторинга
start_monitoring() {
    log_info "Starting monitoring stack..."
    
    cd "$PROJECT_ROOT"
    
    # Запускаем сервисы
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log_success "Monitoring stack started"
}

# Проверка статуса сервисов
check_services() {
    log_info "Checking service status..."
    
    local services=("prometheus" "grafana" "alertmanager" "node-exporter" "cadvisor")
    local failed_services=()
    
    for service in "${services[@]}"; do
        local container_name="n8n-ai-$service"
        if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            log_success "✓ $service is running"
        else
            log_error "✗ $service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "All monitoring services are running"
        show_access_urls
    else
        log_error "Some services failed to start: ${failed_services[*]}"
        return 1
    fi
}

# Отображение URL для доступа
show_access_urls() {
    log_info "Monitoring services are available at:"
    echo ""
    echo -e "${GREEN}Prometheus:${NC}   http://localhost:9090"
    echo -e "${GREEN}Grafana:${NC}      http://localhost:3000 (admin/admin123)"
    echo -e "${GREEN}AlertManager:${NC} http://localhost:9093"
    echo -e "${GREEN}Node Exporter:${NC} http://localhost:9100"
    echo -e "${GREEN}cAdvisor:${NC}     http://localhost:8080"
    echo ""
    
    if [[ -n "${DOMAIN_NAME:-}" && "$DOMAIN_NAME" != "localhost" ]]; then
        log_info "Production URLs (if Traefik is running):"
        echo -e "${BLUE}Prometheus:${NC}   https://prometheus.$DOMAIN_NAME"
        echo -e "${BLUE}Grafana:${NC}      https://grafana.$DOMAIN_NAME"
        echo -e "${BLUE}AlertManager:${NC} https://alerts.$DOMAIN_NAME"
        echo ""
    fi
}

# Отображение помощи
show_help() {
    echo "N8N AI Starter Kit - Monitoring Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the monitoring stack"
    echo "  stop      Stop the monitoring stack"
    echo "  restart   Restart the monitoring stack"
    echo "  status    Check status of monitoring services"
    echo "  logs      Show logs from monitoring services"
    echo "  clean     Stop and remove monitoring containers and volumes"
    echo "  help      Show this help message"
    echo ""
}

# Остановка мониторинга
stop_monitoring() {
    log_info "Stopping monitoring stack..."
    cd "$PROJECT_ROOT"
    docker-compose -f "$COMPOSE_FILE" down
    log_success "Monitoring stack stopped"
}

# Перезапуск мониторинга
restart_monitoring() {
    log_info "Restarting monitoring stack..."
    stop_monitoring
    start_monitoring
    check_services
}

# Показать логи
show_logs() {
    cd "$PROJECT_ROOT"
    docker-compose -f "$COMPOSE_FILE" logs -f --tail=50
}

# Очистка
clean_monitoring() {
    log_warning "This will remove all monitoring containers and volumes!"
    read -p "Are you sure? [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleaning monitoring stack..."
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
        docker-compose -f "$COMPOSE_FILE" rm -f
        log_success "Monitoring stack cleaned"
    else
        log_info "Operation cancelled"
    fi
}

# Основная функция
main() {
    local command="${1:-start}"
    
    case "$command" in
        "start")
            check_dependencies
            check_network
            create_directories
            create_monitoring_env
            build_images
            start_monitoring
            sleep 10  # Даем время на запуск
            check_services
            ;;
        "stop")
            stop_monitoring
            ;;
        "restart")
            restart_monitoring
            ;;
        "status")
            check_services
            ;;
        "logs")
            show_logs
            ;;
        "clean")
            clean_monitoring
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
