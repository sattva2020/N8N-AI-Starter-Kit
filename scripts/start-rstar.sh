#!/bin/bash
# filepath: scripts/start-rstar.sh
# Запуск rStar2-Agent services

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

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
  print_error "Docker Compose не найден!"
  exit 1
fi

print_info "🚀 Запуск rStar2-Agent с N8N AI Starter Kit..."

# Проверяем наличие .env файла
if [ ! -f .env ]; then
  print_error ".env файл не найден! Запустите сначала ./scripts/setup.sh"
  exit 1
fi

# Проверяем наличие модели
MODEL_DIR="./data/models/rstar2-agent"
if [ ! -d "$MODEL_DIR" ] || [ -z "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]; then
  print_warning "Модель rStar2-Agent не найдена в $MODEL_DIR"
  echo ""
  echo "Загрузить модель сейчас? (Требуется ~28GB свободного места)"
  read -p "Загрузить модель? (y/N): " download_choice

  if [ "$download_choice" = "y" ] || [ "$download_choice" = "Y" ]; then
    print_info "Загрузка модели rStar2-Agent..."
    ./scripts/setup.sh --download-rstar-model
    if [ $? -ne 0 ]; then
      print_error "Ошибка загрузки модели"
      exit 1
    fi
  else
    print_warning "Без модели rStar2-Agent не сможет работать"
    echo "Вы можете загрузить её позже командой: ./scripts/setup.sh --download-rstar-model"
    exit 1
  fi
fi

# Проверяем GPU
if command -v nvidia-smi >/dev/null 2>&1; then
  print_success "NVIDIA GPU обнаружен"
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1
else
  print_warning "NVIDIA GPU не обнаружен. rStar2-Agent будет работать медленно на CPU"
  echo "Продолжить? (y/N):"
  read -p "Запустить на CPU? " cpu_choice
  if [ "$cpu_choice" != "y" ] && [ "$cpu_choice" != "Y" ]; then
    exit 1
  fi
fi

# Запускаем основные сервисы (если не запущены)
print_info "Проверка основных сервисов N8N..."
if ! docker ps --format "table {{.Names}}" | grep -q "postgres\|n8n"; then
  print_info "Запуск основных сервисов N8N..."
  $DC_CMD up -d postgres n8n qdrant traefik

  # Ждём запуска N8N
  print_info "Ожидание запуска N8N..."
  for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz | grep -q "200"; then
      break
    fi
    sleep 2
  done
fi

# Запускаем rStar2-Agent сервисы
print_info "Запуск rStar2-Agent сервисов..."
$DC_CMD --file compose/rstar2-agent.yml up -d

# Проверяем статус
sleep 5
print_info "Проверка статуса сервисов..."

if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "rstar2|n8n"; then
  print_success "Сервисы запущены успешно!"
  echo ""
  echo "🌐 Доступные интерфейсы:"
  echo "  N8N:           http://localhost:5678"
  echo "  rStar2-VLLM:   http://localhost:8000"
  echo "  Code Judge:    http://localhost:8088"
  echo "  Traefik:       http://localhost:8080"
  echo ""
  echo "📋 Для интеграции с N8N:"
  echo "  1. Откройте N8N UI"
  echo "  2. Создайте HTTP Request node"
  echo "  3. URL: http://rstar2-vllm:8000/v1/chat/completions"
  echo "  4. Добавьте заголовок: Authorization: Bearer \${RSTAR_API_KEY}"
  echo ""
  echo "📝 Логи сервисов:"
  echo "  $DC_CMD --file compose/rstar2-agent.yml logs -f"
else
  print_error "Ошибка запуска некоторых сервисов"
  print_info "Проверьте логи: $DC_CMD --file compose/rstar2-agent.yml logs"
  exit 1
fi
