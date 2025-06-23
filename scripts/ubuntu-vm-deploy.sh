#!/bin/bash

# N8N AI Starter Kit - Ubuntu VM Deployment Script
# Автоматизированное развертывание для Ubuntu VM

set -e

# Глобальные переменные
PROJECT_DIR=""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
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

# Проверка sudo
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Не запускайте этот скрипт от root! Используйте обычного пользователя с sudo правами."
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_info "Для установки потребуются sudo права. Введите пароль:"
        sudo -v
    fi
}

# Проверка Ubuntu
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Этот скрипт предназначен для Ubuntu. Обнаружена другая ОС."
        exit 1
    fi
    
    local version=$(lsb_release -rs)
    log_info "Обнаружена Ubuntu $version"
    
    if (( $(echo "$version < 20.04" | bc -l) )); then
        log_warning "Рекомендуется Ubuntu 20.04+. Текущая версия: $version"
    fi
}

# Проверка системных требований
check_requirements() {
    log_info "Проверка системных требований..."
    
    # Проверка RAM
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Доступно RAM: ${ram_gb}GB"
    
    if (( ram_gb < 4 )); then
        log_error "Недостаточно RAM. Требуется минимум 4GB, рекомендуется 6GB+"
        exit 1
    elif (( ram_gb < 6 )); then
        log_warning "RAM меньше рекомендуемого (6GB+). Некоторые сервисы могут работать медленно."
    fi
    
    # Проверка дискового пространства
    local disk_gb=$(df -BG / | awk 'NR==2{sub(/G/, "", $4); print $4}')
    log_info "Свободное место на диске: ${disk_gb}GB"
    
    if (( disk_gb < 20 )); then
        log_error "Недостаточно места на диске. Требуется минимум 20GB, рекомендуется 30GB+"
        exit 1
    fi
    
    # Проверка CPU
    local cpu_cores=$(nproc)
    log_info "Количество CPU ядер: $cpu_cores"
    
    if (( cpu_cores < 2 )); then
        log_warning "Рекомендуется минимум 2 CPU ядра для стабильной работы."
    fi
}

# Установка зависимостей
install_dependencies() {
    log_info "Обновление системы и установка зависимостей..."
    
    sudo apt update
    sudo apt install -y \
        curl \
        wget \
        git \
        unzip \
        htop \
        net-tools \
        bc \
        jq \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
        
    log_success "Зависимости установлены"
}

# Установка Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker уже установлен: $(docker --version)"
        return
    fi
    
    log_info "Установка Docker..."
    
    # Удаление старых версий
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавление GPG ключа
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Добавление репозитория
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    
    log_success "Docker установлен: $(docker --version)"
    log_warning "Перелогиньтесь или выполните 'newgrp docker' для применения групповых прав"
}

# Настройка системы
configure_system() {
    log_info "Настройка системы для контейнеров..."
    
    # Увеличение лимитов для Elasticsearch/Qdrant
    if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
        echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
        log_success "Настроены лимиты памяти для векторных БД"
    fi
    
    # Настройка swap если мало RAM
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if (( ram_gb < 8 )) && ! swapon --show | grep -q "/swapfile"; then
        log_info "Настройка swap файла для повышения производительности..."
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        log_success "Swap файл настроен (2GB)"
    fi
}

# Клонирование проекта
clone_project() {
    local project_dir="$HOME/n8n-ai-starter-kit"
    
    if [[ -d "$project_dir" ]]; then
        log_info "Проект уже существует в $project_dir"
        echo
        read -p "Обновить проект? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$project_dir"
            
            # Проверяем, является ли директория git репозиторием
            if [[ -d ".git" ]]; then
                if git pull origin main; then
                    log_success "Проект обновлён"
                else
                    log_warning "Не удалось обновить проект. Продолжаем с текущей версией..."
                fi
            else
                log_warning "Директория не является git репозиторием. Пропускаем обновление..."
                log_info "Если нужно обновление, удалите директорию и запустите скрипт заново"
            fi
        fi
    else
        log_info "Клонирование проекта..."
        cd "$HOME"
        if git clone https://github.com/jdwd40/n8n-ai-starter-kit.git; then
            log_success "Проект склонирован в $project_dir"
        else
            log_error "Не удалось клонировать проект"
            exit 1
        fi
    fi
    
    cd "$project_dir"
    
    # Настройка прав на скрипты
    chmod +x scripts/*.sh 2>/dev/null || true
    chmod +x start.sh 2>/dev/null || true
    
    # Создание необходимых директорий
    mkdir -p data/n8n-files data/n8n-workflows logs
    
    # Возвращаем путь к проекту через переменную, а не echo
    PROJECT_DIR="$project_dir"
}

# Настройка конфигурации
setup_config() {
    log_info "Настройка конфигурации..."
    
    if [[ ! -f ".env" ]]; then
        cp template.env .env
        log_success "Создан файл конфигурации .env"
    else
        log_info "Файл .env уже существует"
    fi
    
    # Получение IP адреса для доступа
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Обновление конфигурации для VM
    sed -i "s/DOMAIN=localhost/DOMAIN=$server_ip/" .env
    sed -i "s/N8N_HOST=localhost/N8N_HOST=$server_ip/" .env
    
    log_success "Конфигурация настроена для IP: $server_ip"
    log_info "N8N будет доступен по адресу: http://$server_ip:5678"
}

# Тестирование минимальной конфигурации
test_minimal() {
    log_info "Запуск тестирования минимальной конфигурации..."
    
    # Проверка Docker группы
    if ! groups | grep -q docker; then
        log_warning "Пользователь не в группе docker. Применяем права..."
        newgrp docker
    fi
    
    # Запуск минимальных сервисов
    docker compose -f compose/test-minimal.yml --profile test up -d
    
    # Ожидание запуска
    log_info "Ожидание запуска сервисов (30 сек)..."
    sleep 30
    
    # Проверка статуса
    local status=$(docker compose -f compose/test-minimal.yml ps --format "table {{.Service}}\t{{.Status}}")
    echo "$status"
    
    # Проверка доступности N8N
    local server_ip=$(hostname -I | awk '{print $1}')
    log_info "Проверка доступности N8N..."
    
    local max_attempts=10
    local attempt=1
    
    while (( attempt <= max_attempts )); do
        if curl -s -f "http://$server_ip:5678" > /dev/null; then
            log_success "N8N доступен по адресу: http://$server_ip:5678"
            break
        else
            log_info "Попытка $attempt/$max_attempts: N8N ещё не готов..."
            sleep 10
            ((attempt++))
        fi
    done
    
    if (( attempt > max_attempts )); then
        log_error "N8N не удалось запустить. Проверьте логи:"
        docker compose -f compose/test-minimal.yml logs n8n-test
        return 1
    fi
    
    # Диагностика
    log_info "Запуск диагностики..."
    if [[ -f "scripts/comprehensive-container-check.sh" ]]; then
        ./scripts/comprehensive-container-check.sh
    fi
    
    return 0
}

# Основная функция
main() {
    echo "=============================================="
    echo "N8N AI Starter Kit - Ubuntu VM Deployment"
    echo "=============================================="
    
    log_info "Начало установки..."
    
    check_sudo
    check_ubuntu
    check_requirements
    install_dependencies
    install_docker
    configure_system
    
    clone_project
    cd "$PROJECT_DIR"
    
    setup_config
    
    # Спрашиваем пользователя о тестировании
    echo
    read -p "Запустить тестирование минимальной конфигурации? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Тестирование пропущено"
    else
        if test_minimal; then
            log_success "Тестирование завершено успешно!"
            echo
            echo "=============================================="
            echo "🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
            echo "=============================================="
            echo
            local server_ip=$(hostname -I | awk '{print $1}')
            echo "📋 Информация для доступа:"
            echo "   N8N Interface: http://$server_ip:5678"
            echo "   Traefik Dashboard: http://$server_ip:80/dashboard/"
            echo
            echo "🔧 Управление сервисами:"
            echo "   Остановка: docker compose -f compose/test-minimal.yml down"
            echo "   Логи: docker compose -f compose/test-minimal.yml logs -f"
            echo "   Статус: docker compose -f compose/test-minimal.yml ps"
            echo
            echo "📖 Документация: docs/UBUNTU_VM_DEPLOYMENT.md"
            echo "=============================================="
        else
            log_error "Тестирование завершилось с ошибками"
            exit 1
        fi
    fi
    
    echo
    log_info "Установка завершена. Проект готов к использованию!"
    log_info "Расположение: $project_dir"
}

# Обработка сигналов
trap 'log_error "Установка прервана"; exit 1' INT TERM

# Запуск
main "$@"
