#!/bin/bash

# N8N AI Starter Kit - Production Deployment Script
# Автоматизация запуска production конфигурации с SSL

set -e

echo "🚀 N8N AI Starter Kit - Production Deployment"
echo "=============================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Проверка существования .env.production
check_production_env() {
    if [ ! -f ".env.production" ]; then
        log_warn ".env.production не найден!"
        log_info "Создаю из шаблона .env.production.template..."
        
        if [ -f ".env.production.template" ]; then
            cp .env.production.template .env.production
            log_warn "⚠️  ВАЖНО: Настройте .env.production перед запуском!"
            log_info "Измените следующие значения:"
            echo "  - DOMAIN_NAME=yourdomain.com"
            echo "  - ACME_EMAIL=admin@yourdomain.com"  
            echo "  - Все пароли CHANGE_THIS_*"
            echo ""
            read -p "Нажмите Enter когда настроите .env.production..."
        else
            log_error "Файл .env.production.template не найден!"
            exit 1
        fi
    fi
}

# Проверка DNS и доменов
check_dns() {
    log_info "Проверка DNS настроек..."
    
    source .env.production
    
    if [ "$DOMAIN_NAME" = "yourdomain.com" ]; then
        log_error "Настройте реальный домен в .env.production"
        exit 1
    fi
    
    log_info "Домен: $DOMAIN_NAME"
    log_info "N8N: $N8N_DOMAIN"
    log_info "Web Interface: $WEB_INTERFACE_DOMAIN"
    log_info "API: $DOCUMENT_PROCESSOR_DOMAIN"
}

# Проверка портов
check_ports() {
    log_info "Проверка доступности портов 80 и 443..."
    
    if netstat -tulpn | grep -q ":80 "; then
        log_warn "Порт 80 уже используется"
    fi
    
    if netstat -tulpn | grep -q ":443 "; then
        log_warn "Порт 443 уже используется"
    fi
}

# Создание директорий и разрешений
setup_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p ./data/uploads
    mkdir -p ./data/processed
    mkdir -p ./config/traefik/dynamic
    
    # Права для Let's Encrypt
    sudo mkdir -p /etc/letsencrypt
    sudo chmod 755 /etc/letsencrypt
}

# Остановка development сервисов
stop_development() {
    log_info "Остановка development сервисов..."
    docker-compose --profile default --profile cpu --profile developer down
}

# Запуск production сервисов
start_production() {
    log_info "Запуск production сервисов с SSL..."
    
    # Используем production environment
    docker-compose --env-file .env.production --profile production up -d
    
    log_info "Ожидание готовности сервисов..."
    sleep 30
    
    # Проверка здоровья сервисов
    docker-compose --env-file .env.production --profile production ps
}

# Проверка SSL сертификатов
check_ssl() {
    log_info "Проверка SSL сертификатов..."
    
    source .env.production
    
    # Проверяем доступность сервисов
    for domain in "$N8N_DOMAIN" "$WEB_INTERFACE_DOMAIN" "$DOCUMENT_PROCESSOR_DOMAIN"; do
        log_info "Проверка $domain..."
        if curl -k -f "https://$domain/health" >/dev/null 2>&1; then
            log_success "✅ $domain доступен через HTTPS"
        else
            log_warn "⚠️  $domain пока недоступен"
        fi
    done
}

# Показать информацию о развертывании
show_deployment_info() {
    log_success "🎉 Production развертывание завершено!"
    echo ""
    echo "📋 Информация о сервисах:"
    
    source .env.production
    
    echo "├── 🤖 N8N Workflow Automation: https://$N8N_DOMAIN"
    echo "├── 🌐 Web Interface: https://$WEB_INTERFACE_DOMAIN"  
    echo "├── 🔌 Document Processor API: https://$DOCUMENT_PROCESSOR_DOMAIN"
    echo "├── 📊 Traefik Dashboard: https://$TRAEFIK_DASHBOARD_DOMAIN"
    echo "└── 🗄️  Database Admin: https://$PGADMIN_DOMAIN"
    echo ""
    echo "🔐 SSL сертификаты: Let's Encrypt (автоматическое обновление)"
    echo "🔒 Security headers: Включены"
    echo "📈 Мониторинг: Доступен в Traefik Dashboard"
    echo ""
    log_info "Логи сервисов: docker-compose --env-file .env.production logs -f"
}

# Главная функция
main() {
    echo ""
    log_info "Начинаю production развертывание..."
    
    check_production_env
    check_dns
    check_ports
    setup_directories
    stop_development
    start_production
    
    log_info "Ожидание SSL сертификатов (может занять несколько минут)..."
    sleep 60
    
    check_ssl
    show_deployment_info
}

# Обработка аргументов
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "stop")
        log_info "Остановка production сервисов..."
        docker-compose --env-file .env.production --profile production down
        log_success "Production сервисы остановлены"
        ;;
    "restart")
        log_info "Перезапуск production сервисов..."
        docker-compose --env-file .env.production --profile production restart
        ;;
    "logs")
        docker-compose --env-file .env.production --profile production logs -f
        ;;
    "status")
        docker-compose --env-file .env.production --profile production ps
        ;;
    *)
        echo "Использование: $0 [deploy|stop|restart|logs|status]"
        echo ""
        echo "Команды:"
        echo "  deploy   - Развернуть production с SSL (по умолчанию)"
        echo "  stop     - Остановить production сервисы"
        echo "  restart  - Перезапустить production сервисы"
        echo "  logs     - Показать логи production сервисов"
        echo "  status   - Показать статус production сервисов"
        exit 1
        ;;
esac
