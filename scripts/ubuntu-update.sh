#!/bin/bash

# ==================================================
# N8N AI Starter Kit - Ubuntu Update Script
# ==================================================
# Автоматическое обновление проекта на Ubuntu
# Версия: 1.0
# Дата: 22.06.2025

set -e  # Остановить при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Настройки
PROJECT_DIR="$(pwd)"
BACKUP_DIR="$HOME/n8n-backups/$(date +%Y%m%d_%H%M%S)"
PROFILE="${1:-cpu}"  # Первый аргумент или 'cpu' по умолчанию

echo "🚀 N8N AI Starter Kit - Скрипт обновления для Ubuntu"
echo "=================================================="

# Проверка что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml не найден. Убедитесь что вы в корне проекта."
    exit 1
fi

# Проверка Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker не установлен. Установите Docker перед продолжением."
    exit 1
fi

if ! command -v git &> /dev/null; then
    print_error "Git не установлен. Установите Git перед продолжением."
    exit 1
fi

print_info "Используемый профиль: $PROFILE"
print_info "Директория проекта: $PROJECT_DIR"
print_info "Директория бэкапа: $BACKUP_DIR"

# Подтверждение от пользователя
read -p "🤔 Продолжить обновление? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Обновление отменено пользователем."
    exit 0
fi

# 1. Остановка сервисов
print_info "Остановка текущих сервисов..."
docker compose down
print_success "Сервисы остановлены"

# 2. Создание бэкапа
print_info "Создание бэкапа данных..."
mkdir -p "$BACKUP_DIR"

# Бэкап конфигурации
if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/"
    print_success "Конфигурация .env сохранена"
fi

# Бэкап Docker volumes (если они существуют)
VOLUMES=$(docker volume ls -q | grep n8n-ai-starter-kit || true)
if [ ! -z "$VOLUMES" ]; then
    for volume in $VOLUMES; do
        print_info "Создание бэкапа volume: $volume"
        docker run --rm \
            -v "$volume":/data \
            -v "$BACKUP_DIR":/backup \
            alpine tar czf "/backup/${volume}.tar.gz" -C /data . 2>/dev/null || true
    done
    print_success "Бэкап volumes создан"
else
    print_warning "Docker volumes не найдены (первый запуск?)"
fi

# 3. Сохранение локальных изменений
print_info "Проверка локальных изменений Git..."
if ! git diff-index --quiet HEAD --; then
    git stash push -m "Auto-backup before update $(date)"
    print_success "Локальные изменения сохранены в Git stash"
else
    print_info "Локальных изменений не обнаружено"
fi

# 4. Получение обновлений
print_info "Получение обновлений из репозитория..."
git fetch origin main

# Показать что изменилось
CHANGES=$(git log --oneline HEAD..origin/main | wc -l)
if [ "$CHANGES" -gt 0 ]; then
    print_info "Найдено $CHANGES новых коммитов:"
    git log --oneline HEAD..origin/main | head -5
    
    read -p "🤔 Применить эти изменения? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Обновление отменено пользователем."
        exit 0
    fi
    
    git pull origin main
    print_success "Код обновлен"
else
    print_info "Новых обновлений не найдено"
fi

# 5. Проверка .env файла
print_info "Проверка конфигурации .env..."
if [ ! -f ".env" ]; then
    if [ -f "./scripts/setup.sh" ]; then
        print_info "Файл .env отсутствует — запускаем ./scripts/setup.sh --generate-only"
        chmod +x ./scripts/setup.sh
        ./scripts/setup.sh --generate-only || {
            print_error "Не удалось сгенерировать .env автоматически"
            exit 1
        }
        print_success "Файл .env сгенерирован встроенным генератором"
    else
        print_error ".env файл не найден и скрипт setup.sh отсутствует"
        exit 1
    fi
fi

# 6. Обновление Docker образов
print_info "Обновление Docker образов..."
docker compose pull
print_success "Docker образы обновлены"

# 7. Запуск обновленной системы
print_info "Запуск обновленных сервисов с профилем '$PROFILE'..."
docker compose --profile "$PROFILE" up -d

# Ожидание запуска сервисов
print_info "Ожидание запуска сервисов (30 секунд)..."
sleep 30

# 8. Проверка статуса
print_info "Проверка статуса сервисов..."
docker compose ps

# Проверка health checks
UNHEALTHY=$(docker compose ps --format json | jq -r 'select(.Health == "unhealthy") | .Service' 2>/dev/null || true)
if [ ! -z "$UNHEALTHY" ]; then
    print_warning "Некоторые сервисы имеют статус unhealthy:"
    echo "$UNHEALTHY"
    print_info "Проверьте логи: docker compose logs [service_name]"
else
    print_success "Все сервисы запущены успешно"
fi

# 9. Проверка API endpoints (если доступны)
print_info "Проверка API endpoints..."

# Qdrant
if curl -s http://localhost:6333/ > /dev/null 2>&1; then
    print_success "Qdrant API доступен"
else
    print_warning "Qdrant API недоступен (возможно еще запускается)"
fi

# Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    print_success "Ollama API доступен"
else
    print_warning "Ollama API недоступен (возможно еще запускается или не включен)"
fi

# 10. Финальный отчет
echo
echo "🎉 Обновление завершено!"
echo "=================================================="
print_success "Бэкап сохранен в: $BACKUP_DIR"
print_info "Для проверки логов используйте: docker compose logs"
print_info "Для проверки статуса: docker compose ps"

# Показать URL доступа (если настроены домены)
if [ -f ".env" ]; then
    DOMAIN=$(grep "^DOMAIN_NAME=" .env | cut -d'=' -f2 | tr -d '"' || echo "localhost")
    if [ "$DOMAIN" != "localhost" ]; then
        print_info "Доступ к сервисам:"
        echo "  N8N: https://n8n.$DOMAIN"
        echo "  Qdrant: https://qdrant.$DOMAIN"
        echo "  Traefik: https://traefik.$DOMAIN"
    fi
fi

echo
print_success "N8N AI Starter Kit успешно обновлен! 🚀"
