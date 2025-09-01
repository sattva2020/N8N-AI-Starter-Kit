#!/bin/bash
# Скрипт для сброса развертывания N8N AI Starter Kit
# Использовать в случае проблем с несовместимыми ключами шифрования или конфликтами

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Определяем команду docker compose
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  DC_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC_CMD="docker-compose"
else
  DC_CMD="docker compose"
fi

print_info "🧹 Начинаем сброс развертывания N8N AI Starter Kit..."

print_warning "⚠️  ВНИМАНИЕ: Эта операция удалит все данные контейнеров!"
print_warning "   - Конфигурация N8N"
print_warning "   - Данные PostgreSQL"
print_warning "   - Workflows и credentials"
print_warning "   - Данные векторных баз"

read -p "Продолжить? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  print_info "Операция отменена."
  exit 0
fi

# Создаем резервную копию .env если существует
if [ -f .env ]; then
  print_info "Создание резервной копии .env..."
  backup_dir="./backup/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"
  cp .env "$backup_dir/.env.backup"
  print_success "Резервная копия сохранена в $backup_dir"
fi

# Останавливаем все контейнеры
print_info "Останавливаем все контейнеры..."
$DC_CMD down

# Удаляем проблематичные тома
print_info "Удаляем тома данных..."
docker volume rm -f n8n-ai-starter-kit_n8n_storage 2>/dev/null || true
docker volume rm -f n8n-ai-starter-kit_postgres_storage 2>/dev/null || true
docker volume rm -f n8n-ai-starter-kit_qdrant_storage 2>/dev/null || true
docker volume rm -f n8n-ai-starter-kit_pgadmin_data 2>/dev/null || true

print_success "Тома удалены успешно"

# Очищаем неиспользуемые образы для освобождения места
print_info "Очистка неиспользуемых образов..."
docker image prune -f >/dev/null 2>&1 || true

print_success "🎉 Сброс завершен успешно!"
print_info "Теперь можно запустить чистое развертывание:"
print_info "  ./scripts/setup.sh  # Для интерактивной настройки"
print_info "  или"
print_info "  docker compose --profile default up -d  # Для быстрого запуска"
