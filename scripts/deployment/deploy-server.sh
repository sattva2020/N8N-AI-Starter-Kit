#!/bin/bash

# =============================================================================
# N8N AI Starter Kit - Server Deployment Script
# =============================================================================
# Скрипт для развертывания N8N AI Starter Kit на удаленном сервере
# Поддерживает Ubuntu 20.04+, Debian 11+, CentOS 8+
# =============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="/tmp/n8n-deployment.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  N8N AI Starter Kit - Server Deployment  ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Функция для печати статуса
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка операционной системы
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    print_status "Detected OS: $OS $VER"
}

# Проверка требований
check_requirements() {
    print_status "Checking system requirements..."
    
    # Проверка памяти (минимум 4GB)
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -lt 4 ]; then
        print_warning "Low memory detected: ${MEMORY_GB}GB. Recommended: 4GB+"
    else
        print_status "Memory: ${MEMORY_GB}GB - OK"
    fi
    
    # Проверка дискового пространства (минимум 10GB)
    DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -lt 10 ]; then
        print_error "Insufficient disk space: ${DISK_GB}GB. Required: 10GB+"
        exit 1
    else
        print_status "Disk space: ${DISK_GB}GB - OK"
    fi
}

# Установка Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_status "Docker already installed: $(docker --version)"
        return
    fi
    
    print_status "Installing Docker..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        # Ubuntu/Debian
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        # CentOS/RHEL
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
    fi
    
    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    print_status "Docker installed successfully"
}

# Установка Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose already installed: $(docker-compose --version)"
        return
    fi
    
    print_status "Installing Docker Compose..."
    
    # Получение последней версии
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_status "Docker Compose installed successfully"
}

# Установка дополнительных утилит
install_utilities() {
    print_status "Installing additional utilities..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        sudo apt-get update
        sudo apt-get install -y git curl wget htop nano vim unzip jq python3 python3-pip
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        sudo yum install -y git curl wget htop nano vim unzip jq python3 python3-pip
    fi
    
    print_status "Utilities installed successfully"
}

# Настройка firewall
setup_firewall() {
    print_status "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu UFW
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 5678/tcp  # N8N
        sudo ufw allow 8001/tcp  # Document Processor
        sudo ufw allow 8002/tcp  # Web Interface
        sudo ufw --force enable
        print_status "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --permanent --add-port=5678/tcp
        sudo firewall-cmd --permanent --add-port=8001/tcp
        sudo firewall-cmd --permanent --add-port=8002/tcp
        sudo firewall-cmd --reload
        print_status "Firewalld configured"
    else
        print_warning "No firewall detected. Please configure manually if needed."
    fi
}

# Клонирование проекта
clone_project() {
    print_status "Cloning N8N AI Starter Kit..."
    
    PROJECT_DIR="/opt/n8n-ai-starter-kit"
    
    if [ -d "$PROJECT_DIR" ]; then
        print_status "Project directory exists. Updating..."
        cd "$PROJECT_DIR"
        sudo git pull origin main
    else
        sudo git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git "$PROJECT_DIR"
        sudo chown -R $USER:$USER "$PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR"
    print_status "Project cloned to: $PROJECT_DIR"
}

# Настройка environment файлов
setup_environment() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f ".env" ]; then
        print_status ".env file not found — generating with setup.sh --generate-only"
        if [ -x "./scripts/setup.sh" ]; then
            ./scripts/setup.sh --generate-only || true
        else
            print_warning "./scripts/setup.sh not found — falling back to manual generation"
            POSTGRES_PASSWORD=$(openssl rand -base64 32)
            N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
            cat > .env <<EOF
# Auto-generated .env
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
EOF
        fi

        # Получение IP сервера и запись в .env
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
        if [ -n "$SERVER_IP" ]; then
            if grep -q "^DOMAIN_NAME=" .env 2>/dev/null; then
                sed -i "s/^DOMAIN_NAME=.*/DOMAIN_NAME=$SERVER_IP/" .env || true
            else
                echo "DOMAIN_NAME=$SERVER_IP" >> .env
            fi
        fi

        print_status "Environment configured"
    else
        print_status ".env file already exists"
    fi
}

# Запуск системы
start_system() {
    print_status "Starting N8N AI Starter Kit..."
    
    # Создание необходимых директорий
    mkdir -p data logs
    
    # Запуск с профилем CPU (для серверов без GPU)
    docker-compose --profile cpu up -d
    
    print_status "System started successfully!"
}

# Проверка статуса
check_status() {
    print_status "Checking system status..."
    
    sleep 10  # Ждем запуска контейнеров
    
    echo ""
    echo -e "${BLUE}Container Status:${NC}"
    docker-compose ps
    
    echo ""
    echo -e "${BLUE}System URLs:${NC}"
    SERVER_IP=$(curl -s ifconfig.me)
    echo "N8N Interface: http://$SERVER_IP:5678"
    echo "Web Interface: http://$SERVER_IP:8002"
    echo "Document Processor: http://$SERVER_IP:8001"
    echo "Qdrant Dashboard: http://$SERVER_IP:6333/dashboard"
    
    echo ""
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo "Log file: $LOG_FILE"
}

# Основная функция
main() {
    detect_os
    check_requirements
    install_docker
    install_docker_compose
    install_utilities
    setup_firewall
    clone_project
    setup_environment
    start_system
    check_status
}

# Проверка прав root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Запуск основной функции
main "$@"
