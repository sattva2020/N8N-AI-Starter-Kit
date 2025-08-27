#!/bin/bash

# 🔧 N8N AI Starter Kit - Скрипт диагностики и исправления проблем
# Автор: AI Assistant
# Дата: 22.06.2025

set -e

PROJECT_DIR="$HOME/N8N-AI-Starter-Kit"
LOG_FILE="/tmp/n8n-kit-fix.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

check_directory() {
    if [ ! -d "$PROJECT_DIR" ]; then
        error "Папка проекта не найдена: $PROJECT_DIR"
        error "Убедитесь что проект клонирован в правильную папку"
        exit 1
    fi
    cd "$PROJECT_DIR"
}

diagnose_services() {
    log "🔍 Диагностика состояния сервисов..."
    
    # Проверить статус Docker Compose
    if ! docker compose ps > /dev/null 2>&1; then
        error "Docker Compose недоступен или проект не запущен"
        return 1
    fi
    
    # Получить статус сервисов
    docker compose ps --format "table {{.Service}}\t{{.Status}}" | tee -a "$LOG_FILE"
    
    # Проверить unhealthy сервисы
    UNHEALTHY=$(docker compose ps --filter "health=unhealthy" --format "{{.Service}}")
    if [ -n "$UNHEALTHY" ]; then
        warning "Найдены нездоровые сервисы: $UNHEALTHY"
        return 1
    fi
    
    return 0
}

fix_env_file() {
    log "📝 Проверка и исправление .env файла..."
    
    if [ ! -f ".env" ]; then
        warning ".env файл не найден, генерируем с помощью setup.sh --generate-only"
        if [ -x "./scripts/setup.sh" ]; then
            ./scripts/setup.sh --generate-only
        else
            warning "Не найден ./scripts/setup.sh — создайте .env вручную"
        fi
    fi
    
    # Исправить POSTGRES_USER если неправильный
    if ! grep -q "POSTGRES_USER=postgres" .env; then
        log "Исправление POSTGRES_USER в .env..."
        sed -i 's/POSTGRES_USER=.*/POSTGRES_USER=postgres/' .env
    fi
    
    # Проверить наличие обязательных переменных
    REQUIRED_VARS=("POSTGRES_PASSWORD" "N8N_ENCRYPTION_KEY" "POSTGRES_DB")
    for var in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "$var=" .env; then
            warning "Отсутствует переменная $var в .env файле"
        fi
    done
}

fix_n8n_encryption() {
    log "🔐 Исправление проблем с N8N encryption key..."
    
    # Проверить есть ли проблема с encryption key
    if docker compose logs n8n 2>/dev/null | grep -q "Mismatching encryption keys"; then
        warning "Обнаружена проблема с encryption key"
        
        # Получить encryption key из контейнера N8N
        if docker compose ps | grep -q "n8n.*Up"; then
            CONTAINER_KEY=$(docker exec n8n-ai-starter-kit-n8n-1 cat /home/node/.n8n/config 2>/dev/null | grep -o '"encryptionKey":"[^"]*"' | cut -d'"' -f4 || true)
            
            if [ -n "$CONTAINER_KEY" ]; then
                log "Обновление N8N_ENCRYPTION_KEY в .env файле..."
                sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$CONTAINER_KEY/" .env
            else
                warning "Не удалось получить encryption key из контейнера"
                log "Сброс конфигурации N8N (потеря настроек!)..."
                docker compose down
                docker volume rm n8n-ai-starter-kit_n8n_storage 2>/dev/null || true
            fi
        fi
    fi
}

fix_services_step_by_step() {
    log "🚀 Поэтапный запуск сервисов..."
    
    # Остановить все
    log "Остановка всех сервисов..."
    docker compose down
    
    # Удалить проблемные контейнеры
    log "Удаление проблемных контейнеров..."
    docker compose rm -f n8n x-service-n8n ollama 2>/dev/null || true
    
    # Запуск базовых сервисов
    log "Запуск базовых сервисов (traefik, postgres)..."
    docker compose up -d traefik postgres
    sleep 10
    
    # Проверить базовые сервисы
    if ! docker compose ps | grep -E "(traefik|postgres|minio)" | grep -q "Up"; then
        error "Базовые сервисы не запустились"
        return 1
    fi
    
    # Запуск Qdrant
    log "Запуск Qdrant..."
    docker compose up -d qdrant
    sleep 10
    
    # Запуск Ollama
    log "Запуск Ollama..."
    docker compose up -d ollama
    sleep 15
    
    # Проверить Ollama
    log "Проверка Ollama API..."
    if docker exec ollama curl -f http://localhost:11434/api/tags >/dev/null 2>&1; then
        success "Ollama API доступен"
    else
        warning "Ollama API недоступен, но продолжаем..."
    fi
    
    # Запуск остальных сервисов
    log "Запуск остальных сервисов..."
    docker compose --profile cpu up -d
    sleep 20
}

check_final_status() {
    log "🏁 Финальная проверка статуса..."
    
    docker compose ps
    
    # Проверить API endpoints
    log "Проверка API endpoints..."
    
    # Qdrant
    if curl -s http://localhost:6333/ >/dev/null; then
        success "✅ Qdrant API доступен"
    else
        warning "❌ Qdrant API недоступен"
    fi
    
    # Ollama
    if curl -s http://localhost:11434/api/tags >/dev/null; then
        success "✅ Ollama API доступен"
    else
        warning "❌ Ollama API недоступен"
    fi
    
    # Подсчет healthy сервисов
    TOTAL=$(docker compose ps | grep -c "Up" || true)
    HEALTHY=$(docker compose ps | grep -c "healthy" || true)
    
    log "📊 Статистика: $HEALTHY/$TOTAL сервисов в healthy состоянии"
}

main() {
    log "🔧 Начинаем исправление N8N AI Starter Kit..."
    log "📋 Лог сохраняется в: $LOG_FILE"
    
    check_directory
    
    # Диагностика
    if diagnose_services; then
        success "Все сервисы работают нормально!"
        return 0
    fi
    
    # Исправления
    fix_env_file
    fix_n8n_encryption
    fix_services_step_by_step
    
    # Финальная проверка
    check_final_status
    
    success "🎉 Исправление завершено!"
    log "📋 Полный лог: $LOG_FILE"
    log "📚 Документация: docs/UBUNTU_UPDATE_GUIDE.md"
}

# Запуск скрипта
main "$@"
