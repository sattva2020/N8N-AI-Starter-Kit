#!/bin/bash

# =============================================================================
# N8N AI Starter Kit - Server Update Script
# =============================================================================
# Скрипт для безопасного обновления системы на удаленном сервере
# =============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Логирование
LOG_FILE="/tmp/n8n-update-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}      N8N AI Starter Kit - Server Update   ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Функции для печати
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Создание резервной копии
create_backup() {
    print_status "Creating backup..."
    
    BACKUP_DIR="/tmp/n8n-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup environment files
    cp -r .env* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup data directory
    if [ -d "data" ]; then
        cp -r data "$BACKUP_DIR/"
    fi
    
    # Backup custom configurations
    if [ -d "config" ]; then
        cp -r config "$BACKUP_DIR/"
    fi
    
    # Export current Docker volumes
    print_status "Backing up Docker volumes..."
    docker run --rm -v "$(pwd)":/backup -v n8n_storage:/data alpine tar czf /backup/n8n_storage_backup.tar.gz -C /data .
    mv n8n_storage_backup.tar.gz "$BACKUP_DIR/"
    
    print_status "Backup created at: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /tmp/n8n-last-backup.txt
}

# Остановка системы
stop_system() {
    print_status "Stopping current system..."
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose down
        print_status "System stopped"
    else
        print_warning "docker-compose.yml not found, skipping stop"
    fi
}

# Обновление кода
update_code() {
    print_status "Updating code from repository..."
    
    # Stash any local changes
    git stash push -m "Auto-stash before update $(date)"
    
    # Pull latest changes
    git pull origin main
    
    print_status "Code updated successfully"
}

# Обновление Docker образов
update_docker_images() {
    print_status "Updating Docker images..."
    
    # Pull latest images
    docker-compose pull
    
    # Remove old images
    docker image prune -f
    
    print_status "Docker images updated"
}

# Обновление конфигурации
update_configuration() {
    print_status "Updating configuration..."
    
    # Check if new environment variables are needed
    if [ -f "template.env" ] && [ -f ".env" ]; then
        # Find new variables in template that don't exist in current .env
        NEW_VARS=$(comm -23 <(grep "^[^#]" template.env | cut -d= -f1 | sort) <(grep "^[^#]" .env | cut -d= -f1 | sort))
        
        if [ -n "$NEW_VARS" ]; then
            print_warning "New environment variables found:"
            echo "$NEW_VARS"
            
            # Add new variables to .env with default values
            for var in $NEW_VARS; do
                default_value=$(grep "^$var=" template.env | cut -d= -f2-)
                echo "$var=$default_value" >> .env
                print_status "Added $var to .env"
            done
        fi
    fi
}

# Миграция данных
migrate_data() {
    print_status "Checking for data migrations..."
    
    # Check if migration scripts exist
    if [ -d "scripts/migrations" ]; then
        for migration in scripts/migrations/*.sh; do
            if [ -f "$migration" ]; then
                print_status "Running migration: $(basename "$migration")"
                bash "$migration"
            fi
        done
    fi
}

# Запуск обновленной системы
start_updated_system() {
    print_status "Starting updated system..."
    
    # Start with CPU profile for servers
    docker-compose --profile cpu up -d
    
    print_status "Updated system started"
}

# Проверка работоспособности
health_check() {
    print_status "Performing health check..."
    
    # Wait for services to start
    sleep 30
    
    # Check if containers are running
    FAILED_SERVICES=()
    
    REQUIRED_SERVICES=("traefik" "postgres" "n8n" "qdrant")
    
    for service in "${REQUIRED_SERVICES[@]}"; do
        if ! docker-compose ps | grep -q "$service.*Up"; then
            FAILED_SERVICES+=("$service")
        fi
    done
    
    if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
        print_status "All services are running successfully"
        return 0
    else
        print_error "Failed services: ${FAILED_SERVICES[*]}"
        return 1
    fi
}

# Откат изменений
rollback() {
    print_error "Rolling back to previous version..."
    
    # Stop current system
    docker-compose down
    
    # Restore from backup
    BACKUP_DIR=$(cat /tmp/n8n-last-backup.txt)
    
    if [ -d "$BACKUP_DIR" ]; then
        # Restore environment files
        cp "$BACKUP_DIR"/.env* . 2>/dev/null || true
        
        # Restore data
        if [ -f "$BACKUP_DIR/n8n_storage_backup.tar.gz" ]; then
            docker run --rm -v "$(pwd)":/backup -v n8n_storage:/data alpine tar xzf /backup/"$BACKUP_DIR"/n8n_storage_backup.tar.gz -C /data
        fi
        
        # Restore previous Git state
        git stash pop
        
        # Start previous version
        docker-compose --profile cpu up -d
        
        print_status "Rollback completed"
    else
        print_error "Backup directory not found. Manual recovery required."
    fi
}

# Очистка
cleanup() {
    print_status "Cleaning up..."
    
    # Remove unused Docker resources
    docker system prune -f
    
    # Clean old backups (keep last 5)
    find /tmp -name "n8n-backup-*" -type d | sort | head -n -5 | xargs rm -rf
    
    print_status "Cleanup completed"
}

# Главная функция
main() {
    print_status "Starting N8N AI Starter Kit update process..."
    
    # Pre-update checks
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found. Please run from project directory."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        exit 1
    fi
    
    # Update process
    create_backup
    
    if ! stop_system; then
        print_error "Failed to stop system"
        exit 1
    fi
    
    if ! update_code; then
        print_error "Failed to update code"
        rollback
        exit 1
    fi
    
    if ! update_docker_images; then
        print_error "Failed to update Docker images"
        rollback
        exit 1
    fi
    
    update_configuration
    migrate_data
    
    if ! start_updated_system; then
        print_error "Failed to start updated system"
        rollback
        exit 1
    fi
    
    if ! health_check; then
        print_error "Health check failed"
        rollback
        exit 1
    fi
    
    cleanup
    
    # Show final status
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}     UPDATE COMPLETED SUCCESSFULLY!        ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    
    # Show URLs
    EXTERNAL_IP=$(curl -s ifconfig.me)
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${BLUE}Access URLs:${NC}"
        echo "N8N: http://$EXTERNAL_IP:5678"
        echo "Web Interface: http://$EXTERNAL_IP:8002"
        echo "Document Processor: http://$EXTERNAL_IP:8001"
        echo "Qdrant Dashboard: http://$EXTERNAL_IP:6333/dashboard"
    fi
    
    echo ""
    print_status "Update log saved to: $LOG_FILE"
}

# Обработка сигналов
trap 'print_error "Update interrupted"; rollback; exit 1' INT TERM

# Запуск
main "$@"
