#!/bin/bash
# Автоматическая установка n8n-ai-starter-kit на Ubuntu
# Версия: 1.0.0

set -e  # Выход при любой ошибке

echo "🚀 Автоматическая установка n8n-ai-starter-kit"
echo "================================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Проверка операционной системы
if ! grep -q "Ubuntu" /etc/os-release; then
    error "Этот скрипт предназначен для Ubuntu. Обнаружена другая ОС."
fi

log "Обнаружена Ubuntu $(lsb_release -rs)"

# Проверка прав sudo
if ! sudo -n true 2>/dev/null; then
    warn "Требуются права sudo. Введите пароль если потребуется."
fi

# Обновление системы
log "Обновление системы..."
sudo apt update -y
sudo apt upgrade -y

# Установка зависимостей
log "Установка зависимостей..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    wget

# Проверка Docker
if ! command -v docker &> /dev/null; then
    log "Установка Docker..."
    
    # Удаление старых версий
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавление GPG ключа
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Добавление репозитория
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    
    log "Docker установлен успешно"
else
    log "Docker уже установлен: $(docker --version)"
fi

# Проверка Docker Compose
if ! docker compose version &> /dev/null; then
    error "Docker Compose не найден. Убедитесь, что установлена актуальная версия Docker."
fi

log "Docker Compose найден: $(docker compose version --short)"

# Клонирование проекта
PROJECT_DIR="$HOME/N8N-AI-Starter-Kit"

if [ -d "$PROJECT_DIR" ]; then
    warn "Папка $PROJECT_DIR уже существует. Обновляем проект..."
    cd "$PROJECT_DIR"
    git pull origin main
else
    log "Клонирование проекта..."
    cd "$HOME"
    git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git
    cd N8N-AI-Starter-Kit
fi

# Установка прав выполнения
log "Установка прав выполнения для скриптов..."
chmod +x scripts/*.sh
chmod +x start.sh

# Проверка системы
log "Проверка готовности системы..."
if [ -f "./scripts/diagnose.sh" ]; then
    ./scripts/diagnose.sh
else
    warn "Скрипт диагностики не найден"
fi

# Запуск настройки
log "Запуск автоматической настройки..."
echo ""
echo "🔧 Теперь будет запущен интерактивный мастер настройки."
echo "Вам нужно будет указать:"
echo "  - Email для SSL сертификатов"
echo "  - Доменное имя (или localhost)"
echo "  - OpenAI API ключ"
echo ""
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/setup.sh
    
    log "Запуск проекта..."
    ./start.sh
    
    echo ""
    echo "🎉 Установка завершена успешно!"
    echo ""
    echo "🌐 Доступ к сервисам:"
    echo "  - n8n: http://localhost:5678"
    echo "  - Qdrant: http://localhost:6333"
    echo "  - Traefik: http://localhost:8080"
    echo ""
    echo "📋 Полезные команды:"
    echo "  - Статус: docker compose ps"
    echo "  - Логи: docker compose logs -f"
    echo "  - Остановка: docker compose down"
    echo "  - Диагностика: ./scripts/diagnose.sh"
    echo ""
    echo "📖 Документация: ./docs/UBUNTU_DEPLOYMENT.md"
else
    log "Автоматическая настройка пропущена."
    echo ""
    echo "Для ручной настройки выполните:"
    echo "  cd $PROJECT_DIR"
    echo "  ./scripts/setup.sh"
    echo "  ./start.sh"
fi

log "Установка завершена!"

# Напоминание о перезагрузке группы docker
if groups $USER | grep -q docker; then
    log "Пользователь уже в группе docker"
else
    warn "Требуется перезапуск сессии для применения группы docker:"
    echo "  newgrp docker"
    echo "  или перелогиньтесь в систему"
fi
