#!/bin/bash

# 🔧 Автоматическое исправление проблемы document-processor
# Версия: 1.0
# Дата: $(date)

echo "🔧 Исправление проблемы document-processor для N8N AI Starter Kit v1.2.0..."
echo "=================================================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция логирования
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка существования .env файла
log_info "Проверка .env файла..."
if [ ! -f ".env" ]; then
    log_warn ".env файл не найден. Создание из шаблона..."
    if [ -f "template.env" ]; then
        cp template.env .env
        log_info ".env файл создан из template.env"
    else
        log_error "template.env не найден! Создайте .env файл вручную."
        exit 1
    fi
else
    log_info ".env файл найден"
fi

# Резервная копия .env
log_info "Создание резервной копии .env..."
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# Проверка и установка переменных PostgreSQL
log_info "Настройка переменных PostgreSQL..."

# Функция для обновления или добавления переменной
update_env_var() {
    local var_name=$1
    local var_value=$2
    local env_file=".env"
    
    if grep -q "^${var_name}=" "$env_file"; then
        # Обновляем существующую переменную
        sed -i "s/^${var_name}=.*/${var_name}=${var_value}/" "$env_file"
        log_info "Обновлена переменная: ${var_name}"
    else
        # Добавляем новую переменную
        echo "${var_name}=${var_value}" >> "$env_file"
        log_info "Добавлена переменная: ${var_name}"
    fi
}

# Установка необходимых переменных
update_env_var "POSTGRES_USER" "n8n"
update_env_var "POSTGRES_PASSWORD" "changeme"
update_env_var "POSTGRES_DB" "n8n"
update_env_var "N8N_DB_POSTGRESDB_USER" "n8n"
update_env_var "N8N_DB_POSTGRESDB_PASSWORD" "changeme"
update_env_var "N8N_DB_POSTGRESDB_DATABASE" "n8n"
update_env_var "N8N_DB_POSTGRESDB_HOST" "postgres"
update_env_var "N8N_DB_POSTGRESDB_PORT" "5432"
update_env_var "N8N_DB_TYPE" "postgresdb"

log_info "Переменные окружения настроены"

# Остановка проблемного контейнера
log_info "Остановка document-processor контейнера..."
docker stop n8n-ai-starter-kit-document-processor-1 2>/dev/null || log_warn "Контейнер уже остановлен"

# Перезапуск с обновленными переменными
log_info "Перезапуск системы с обновленными переменными..."
docker-compose --profile cpu down
sleep 3
docker-compose --profile cpu up -d

log_info "Ожидание инициализации сервисов (60 секунд)..."
for i in {1..60}; do
    echo -n "."
    sleep 1
done
echo ""

# Проверка статуса document-processor
log_info "Проверка статуса document-processor..."
sleep 10

# Проверка логов
log_info "Анализ логов document-processor..."
if docker logs n8n-ai-starter-kit-document-processor-1 2>/dev/null | grep -q "password authentication failed"; then
    log_error "Проблема с аутентификацией все еще существует!"
    log_info "Дополнительная диагностика:"
    echo "--- Логи PostgreSQL ---"
    docker logs n8n-ai-starter-kit-postgres-1 | tail -10
    echo "--- Логи Document Processor ---"
    docker logs n8n-ai-starter-kit-document-processor-1 | tail -10
    exit 1
elif docker logs n8n-ai-starter-kit-document-processor-1 2>/dev/null | grep -q "Сервис готов к работе\|Application startup complete"; then
    log_info "✅ Document Processor успешно запущен!"
else
    log_warn "Статус неопределен. Проверка логов..."
    docker logs n8n-ai-starter-kit-document-processor-1 | tail -20
fi

# Проверка доступности API
log_info "Проверка доступности API endpoints..."

# Document Processor Health Check
if curl -s http://localhost:8001/health >/dev/null 2>&1; then
    log_info "✅ Document Processor API доступен (http://localhost:8001)"
else
    log_warn "⚠️ Document Processor API недоступен (http://localhost:8001)"
fi

# N8N Health Check
if curl -s http://localhost:5678/healthz >/dev/null 2>&1; then
    log_info "✅ N8N доступен (http://localhost:5678)"
else
    log_warn "⚠️ N8N недоступен (http://localhost:5678)"
fi

# Qdrant Health Check
if curl -s http://localhost:6333/health >/dev/null 2>&1; then
    log_info "✅ Qdrant доступен (http://localhost:6333)"
else
    log_warn "⚠️ Qdrant недоступен (http://localhost:6333)"
fi

# Финальная проверка статуса контейнеров
log_info "Статус всех контейнеров:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep n8n-ai-starter-kit

log_info "=================================================================="
log_info "🎯 Исправление завершено!"
log_info ""
log_info "📋 Следующие шаги:"
log_info "1. Проверьте http://localhost:5678 (N8N)"
log_info "2. Проверьте http://localhost:8001/health (Document Processor)"
log_info "3. Проверьте http://localhost:6333/dashboard (Qdrant)"
log_info ""
log_info "📁 Workflow Management:"
log_info "cd n8n/workflows/management && python workflow-import-cli.py"
log_info ""
log_info "🔧 Если проблемы остались:"
log_info "- Проверьте логи: docker logs n8n-ai-starter-kit-document-processor-1"
log_info "- Запустите диагностику: ./scripts/utils/check-server-status.sh"
log_info "- Смотрите DOCUMENT_PROCESSOR_FIX.md для подробной диагностики"
