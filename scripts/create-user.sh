#!/bin/bash

# N8N AI Starter Kit - User Creation Script for Ubuntu VM
# Создание обычного пользователя с необходимыми правами для развертывания

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверка root
if [[ $EUID -ne 0 ]]; then
    log_error "Этот скрипт должен запускаться от root для создания пользователя."
    log_info "Используйте: sudo $0"
    exit 1
fi

# Функция создания пользователя
create_user() {
    local username="${1:-n8nuser}"
    local password="${2:-n8npass123}"
    
    log_info "Создание пользователя: $username"
    
    # Проверяем, не существует ли уже пользователь
    if id "$username" &>/dev/null; then
        log_warning "Пользователь $username уже существует"
        read -p "Хотите обновить его права? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Выход без изменений"
            exit 0
        fi
    else
        # Создаем пользователя
        useradd -m -s /bin/bash "$username"
        echo "$username:$password" | chpasswd
        log_success "Пользователь $username создан"
    fi
    
    # Добавляем в группы
    usermod -aG sudo "$username"
    usermod -aG docker "$username" 2>/dev/null || true
    
    # Создаем директорию для проекта
    project_dir="/home/$username/n8n-ai-starter-kit"
    if [[ ! -d "$project_dir" ]]; then
        mkdir -p "$project_dir"
        chown "$username:$username" "$project_dir"
    fi
    
    # Настраиваем sudo без пароля для Docker команд (опционально)
    echo "$username ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose, /usr/local/bin/docker-compose" > "/etc/sudoers.d/90-$username-docker"
    
    log_success "Пользователь $username настроен с правами:"
    log_info "- Группа sudo (административные права)"
    log_info "- Группа docker (если установлен Docker)"
    log_info "- Домашняя директория: /home/$username"
    log_info "- Проектная директория: $project_dir"
    log_info "- Sudo без пароля для Docker команд"
    
    echo
    log_warning "ВАЖНАЯ ИНФОРМАЦИЯ:"
    echo "Имя пользователя: $username"
    echo "Пароль: $password"
    echo
    log_info "Для переключения на этого пользователя используйте:"
    echo "su - $username"
    echo
    log_info "Для входа по SSH (если настроен):"
    echo "ssh $username@<IP_адрес_VM>"
}

# Функция установки Docker (если нужно)
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker уже установлен"
        return 0
    fi
    
    log_info "Установка Docker..."
    
    # Обновляем пакеты
    apt-get update
    
    # Устанавливаем зависимости
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Добавляем официальный GPG ключ Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Добавляем репозиторий
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Устанавливаем Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Запускаем и включаем автозапуск
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker установлен и запущен"
}

# Основной процесс
main() {
    log_info "N8N AI Starter Kit - Настройка пользователя для Ubuntu VM"
    echo
    
    # Проверяем Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Этот скрипт предназначен для Ubuntu"
        exit 1
    fi
    
    # Запрашиваем данные пользователя
    read -p "Введите имя пользователя (по умолчанию: n8nuser): " username
    username="${username:-n8nuser}"
    
    read -s -p "Введите пароль (по умолчанию: n8npass123): " password
    echo
    password="${password:-n8npass123}"
    
    # Спрашиваем про установку Docker
    read -p "Установить Docker, если не установлен? (Y/n): " -n 1 -r
    echo
    install_docker_flag="Y"
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        install_docker_flag="N"
    fi
    
    # Создаем пользователя
    create_user "$username" "$password"
    
    # Устанавливаем Docker если нужно
    if [[ "$install_docker_flag" == "Y" ]]; then
        install_docker
        # Добавляем пользователя в группу docker после установки
        usermod -aG docker "$username"
        log_info "Пользователь $username добавлен в группу docker"
    fi
    
    echo
    log_success "Настройка завершена!"
    log_info "Теперь вы можете:"
    log_info "1. Переключиться на пользователя: su - $username"
    log_info "2. Клонировать проект в: /home/$username/n8n-ai-starter-kit"
    log_info "3. Запустить ubuntu-vm-deploy.sh от имени $username"
    echo
    log_warning "Не забудьте выйти из root и войти под новым пользователем!"
}

# Запуск
main "$@"
