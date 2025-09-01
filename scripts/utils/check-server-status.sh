#!/bin/bash

# =============================================================================
# N8N AI Starter Kit - Server Status Check Script
# =============================================================================
# Скрипт для проверки статуса всех сервисов на удаленном сервере
# =============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}     N8N AI Starter Kit - Status Check     ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Функция для печати статуса
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Проверка Docker
check_docker() {
    echo -e "${BLUE}Docker Status:${NC}"
    if command -v docker &> /dev/null; then
        print_status "Docker installed: $(docker --version)"
        if systemctl is-active --quiet docker; then
            print_status "Docker service is running"
        else
            print_error "Docker service is not running"
            return 1
        fi
    else
        print_error "Docker is not installed"
        return 1
    fi
    echo ""
}

# Проверка Docker Compose
check_docker_compose() {
    echo -e "${BLUE}Docker Compose Status:${NC}"
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose installed: $(docker-compose --version)"
    else
        print_error "Docker Compose is not installed"
        return 1
    fi
    echo ""
}

# Проверка контейнеров
check_containers() {
    echo -e "${BLUE}Container Status:${NC}"
    
    # Проверка запущенных контейнеров
    RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
    
    if [ -z "$RUNNING_CONTAINERS" ]; then
        print_error "No containers are running"
        return 1
    fi
    
    echo "$RUNNING_CONTAINERS"
    echo ""
    
    # Проверка основных сервисов
    REQUIRED_SERVICES=("n8n" "postgres" "traefik" "qdrant")
    
    for service in "${REQUIRED_SERVICES[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "$service"; then
            print_status "$service container is running"
        else
            print_error "$service container is not running"
        fi
    done
    echo ""
}

# Проверка портов
check_ports() {
    echo -e "${BLUE}Port Status:${NC}"
    
    PORTS=(80 443 5678 8001 8002 6333)
    
    for port in "${PORTS[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            print_status "Port $port is open"
        else
            print_warning "Port $port is not listening"
        fi
    done
    echo ""
}

# Проверка HTTP эндпоинтов
check_endpoints() {
    echo -e "${BLUE}HTTP Endpoints Status:${NC}"
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    ENDPOINTS=(
        "http://localhost:5678"
        "http://localhost:8001/health"
        "http://localhost:8002"
        "http://localhost:6333/dashboard"
    )
    
    for endpoint in "${ENDPOINTS[@]}"; do
        if curl -s -f "$endpoint" > /dev/null 2>&1; then
            print_status "$endpoint is responding"
        else
            print_error "$endpoint is not responding"
        fi
    done
    echo ""
}

# Проверка ресурсов системы
check_resources() {
    echo -e "${BLUE}System Resources:${NC}"
    
    # Память
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "Memory Usage: ${MEMORY_USAGE}%"
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "CPU Usage: ${CPU_USAGE}%"
    
    # Диск
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}')
    echo "Disk Usage: $DISK_USAGE"
    
    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }')
    echo "Load Average:$LOAD_AVG"
    echo ""
}

# Проверка логов
check_logs() {
    echo -e "${BLUE}Recent Logs (last 10 lines):${NC}"
    
    CONTAINERS=$(docker ps --format "{{.Names}}")
    
    for container in $CONTAINERS; do
        echo -e "${YELLOW}=== $container ===${NC}"
        docker logs --tail 5 "$container" 2>&1 | head -10
        echo ""
    done
}

# Проверка .env файла
check_env_file() {
    echo -e "${BLUE}Environment Configuration:${NC}"
    
    if [ -f ".env" ]; then
        print_status ".env file exists"
        
        # Проверка ключевых переменных
        ENV_VARS=("POSTGRES_PASSWORD" "N8N_ENCRYPTION_KEY" "DOMAIN_NAME")
        
        for var in "${ENV_VARS[@]}"; do
            if grep -q "^$var=" .env; then
                print_status "$var is configured"
            else
                print_error "$var is missing in .env"
            fi
        done
    else
        print_error ".env file not found"
    fi
    echo ""
}

# Проверка сети
check_network() {
    echo -e "${BLUE}Network Status:${NC}"
    
    # Проверка Docker сетей
    NETWORKS=$(docker network ls --format "{{.Name}}")
    
    for network in $NETWORKS; do
        if [[ "$network" != "bridge" && "$network" != "host" && "$network" != "none" ]]; then
            print_status "Docker network: $network"
        fi
    done
    
    # Проверка внешнего IP
    EXTERNAL_IP=$(curl -s ifconfig.me)
    if [ -n "$EXTERNAL_IP" ]; then
        print_status "External IP: $EXTERNAL_IP"
    else
        print_warning "Cannot determine external IP"
    fi
    echo ""
}

# Генерация отчета
generate_report() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    REPORT_FILE="/tmp/n8n-status-report-$(date +%Y%m%d-%H%M%S).txt"
    
    echo -e "${BLUE}Generating status report...${NC}"
    
    {
        echo "N8N AI Starter Kit - Status Report"
        echo "Generated: $TIMESTAMP"
        echo "=========================================="
        echo ""
        
        echo "Docker Version:"
        docker --version
        echo ""
        
        echo "Container Status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        
        echo "System Resources:"
        free -h
        echo ""
        df -h
        echo ""
        
        echo "Network Configuration:"
        docker network ls
        echo ""
        
    } > "$REPORT_FILE"
    
    print_status "Report saved to: $REPORT_FILE"
}

# Главная функция
main() {
    check_docker
    check_docker_compose
    check_containers
    check_ports
    check_endpoints
    check_resources
    check_env_file
    check_network
    check_logs
    generate_report
    
    echo -e "${GREEN}Status check completed!${NC}"
    
    # Показать URLs для доступа
    EXTERNAL_IP=$(curl -s ifconfig.me)
    if [ -n "$EXTERNAL_IP" ]; then
        echo ""
        echo -e "${BLUE}Access URLs:${NC}"
        echo "N8N: http://$EXTERNAL_IP:5678"
        echo "Web Interface: http://$EXTERNAL_IP:8002"
        echo "Document Processor: http://$EXTERNAL_IP:8001"
        echo "Qdrant Dashboard: http://$EXTERNAL_IP:6333/dashboard"
    fi
}

# Проверка нахождения в директории проекта
if [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the N8N AI Starter Kit directory"
    exit 1
fi

# Запуск
main "$@"
