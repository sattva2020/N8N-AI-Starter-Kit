#!/bin/bash

# =============================================================================
# 🔍 ПОЛНАЯ ВАЛИДАЦИЯ ВСЕХ СЕРВИСОВ N8N AI STARTER KIT
# =============================================================================
# Проверяет состояние всех контейнеров, их логи, healthcheck'и и API

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода заголовков
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Функция для проверки успеха/неудачи
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1 - OK${NC}"
        return 0
    else
        echo -e "${RED}❌ $1 - FAILED${NC}"
        return 1
    fi
}

# Функция для проверки HTTP endpoint'а
check_http() {
    local url=$1
    local service=$2
    local expected_text=$3
    
    echo -n "Проверяем $service ($url)... "
    
    if curl -s --max-time 10 "$url" > /dev/null 2>&1; then
        if [ -n "$expected_text" ]; then
            response=$(curl -s --max-time 10 "$url")
            if echo "$response" | grep -q "$expected_text"; then
                echo -e "${GREEN}✅ OK${NC} (содержит: $expected_text)"
            else
                echo -e "${YELLOW}⚠️  ПРЕДУПРЕЖДЕНИЕ${NC} (отвечает, но не содержит ожидаемый текст)"
            fi
        else
            echo -e "${GREEN}✅ OK${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

print_header "🐳 ПРОВЕРКА СТАТУСА DOCKER КОНТЕЙНЕРОВ"

# Проверяем, что Docker работает
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker не запущен или недоступен!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker работает${NC}\n"

# Список всех контейнеров в проекте
echo "📋 Все контейнеры в системе:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

print_header "🔍 ПРОВЕРКА ОСНОВНЫХ СЕРВИСОВ"

# Основные сервисы для проверки
SERVICES=("n8n" "postgres" "qdrant" "minio" "traefik")

for service in "${SERVICES[@]}"; do
    echo -n "Проверяем контейнер $service... "
    
    if docker ps --format "{{.Names}}" | grep -q "^${service}$\|_${service}_\|${service}_"; then
        container_name=$(docker ps --format "{{.Names}}" | grep "${service}" | head -1)
        status=$(docker ps --filter "name=${service}" --format "{{.Status}}")
        
        if echo "$status" | grep -q "Up"; then
            echo -e "${GREEN}✅ Запущен${NC} ($status)"
        else
            echo -e "${RED}❌ Проблема${NC} ($status)"
        fi
    else
        echo -e "${YELLOW}⚠️  Не найден или остановлен${NC}"
    fi
done

print_header "🔍 ПРОВЕРКА ДОПОЛНИТЕЛЬНЫХ СЕРВИСОВ"

# Дополнительные сервисы
OPTIONAL_SERVICES=("ollama" "graphiti" "zep" "neo4j" "pgadmin" "jupyterlab")

for service in "${OPTIONAL_SERVICES[@]}"; do
    echo -n "Проверяем контейнер $service... "
    
    if docker ps --format "{{.Names}}" | grep -q "${service}"; then
        container_name=$(docker ps --format "{{.Names}}" | grep "${service}" | head -1)
        status=$(docker ps --filter "name=${service}" --format "{{.Status}}")
        
        if echo "$status" | grep -q "Up"; then
            echo -e "${GREEN}✅ Запущен${NC} ($status)"
        else
            echo -e "${YELLOW}⚠️  Проблема${NC} ($status)"
        fi
    else
        echo -e "${BLUE}ℹ️  Не запущен (опциональный)${NC}"
    fi
done

print_header "🌐 ПРОВЕРКА HTTP API ENDPOINTS"

# Проверяем HTTP endpoints
check_http "http://localhost:5678" "N8N Web UI" "n8n.io"
check_http "http://localhost:11434" "Ollama API" "Ollama is running"
check_http "http://localhost:6333" "Qdrant API" "qdrant"
check_http "http://localhost:9000/minio/health/live" "MinIO Health" ""
check_http "http://localhost:8080" "Traefik Dashboard" ""

print_header "🔍 ПРОВЕРКА HEALTHCHECK СТАТУСОВ"

echo "📊 Healthcheck статусы контейнеров:"
for container in $(docker ps --format "{{.Names}}"); do
    health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    if [ "$health" = "healthy" ]; then
        echo -e "${GREEN}✅ $container: healthy${NC}"
    elif [ "$health" = "unhealthy" ]; then
        echo -e "${RED}❌ $container: unhealthy${NC}"
    elif [ "$health" = "starting" ]; then
        echo -e "${YELLOW}⏳ $container: starting${NC}"
    else
        echo -e "${BLUE}ℹ️  $container: no healthcheck${NC}"
    fi
done

print_header "📋 ПРОВЕРКА ЛОГОВ НА ОШИБКИ"

echo "🔍 Проверяем последние логи на наличие ошибок..."
for container in $(docker ps --format "{{.Names}}"); do
    echo -n "Анализируем логи $container... "
    
    # Получаем последние 50 строк логов
    logs=$(docker logs --tail 50 "$container" 2>&1)
    
    # Ищем ошибки (исключаем некритичные предупреждения)
    errors=$(echo "$logs" | grep -i -E "(error|fatal|exception|failed|panic)" | grep -v -i -E "(warning|info|debug|deprecated)" | wc -l)
    
    if [ "$errors" -gt 0 ]; then
        echo -e "${RED}❌ Найдено $errors ошибок${NC}"
        echo "Последние ошибки:"
        echo "$logs" | grep -i -E "(error|fatal|exception|failed|panic)" | grep -v -i -E "(warning|info|debug|deprecated)" | tail -3
        echo ""
    else
        echo -e "${GREEN}✅ Ошибок не найдено${NC}"
    fi
done

print_header "🔧 ПРОВЕРКА РЕСУРСОВ И ПРОИЗВОДИТЕЛЬНОСТИ"

echo "📊 Использование ресурсов контейнерами:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

print_header "🌐 ПРОВЕРКА СЕТЕВЫХ ПОДКЛЮЧЕНИЙ"

echo "🔗 Docker сети:"
docker network ls

echo -e "\n🔍 Контейнеры в сетях:"
for network in $(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none"); do
    echo "Сеть: $network"
    docker network inspect "$network" --format "{{range .Containers}}  - {{.Name}}: {{.IPv4Address}}{{end}}" 2>/dev/null || echo "  (пустая или недоступна)"
done

print_header "📋 ИТОГОВЫЙ ОТЧЁТ"

# Подсчитываем статистику
total_containers=$(docker ps | wc -l)
running_containers=$((total_containers - 1)) # Исключаем заголовок
healthy_containers=$(docker ps --format "{{.Names}}" | xargs -I {} docker inspect --format='{{.State.Health.Status}}' {} 2>/dev/null | grep -c "healthy" || echo "0")

echo "📊 Статистика:"
echo -e "  Всего запущенных контейнеров: ${BLUE}$running_containers${NC}"
echo -e "  Контейнеров с healthy статусом: ${GREEN}$healthy_containers${NC}"

# Проверяем критичные сервисы
critical_services=("n8n" "postgres")
critical_ok=true

for service in "${critical_services[@]}"; do
    if ! docker ps --format "{{.Names}}" | grep -q "${service}"; then
        critical_ok=false
        echo -e "${RED}❌ Критичный сервис $service не запущен!${NC}"
    fi
done

if [ "$critical_ok" = true ]; then
    echo -e "\n${GREEN}🎉 ВСЕ КРИТИЧНЫЕ СЕРВИСЫ РАБОТАЮТ!${NC}"
    echo -e "${GREEN}✅ N8N AI Starter Kit готов к использованию${NC}"
else
    echo -e "\n${RED}⚠️  ОБНАРУЖЕНЫ ПРОБЛЕМЫ С КРИТИЧНЫМИ СЕРВИСАМИ!${NC}"
    echo -e "${YELLOW}💡 Запустите: docker-compose up -d${NC}"
fi

print_header "🔧 РЕКОМЕНДУЕМЫЕ ДЕЙСТВИЯ"

echo "📝 Если обнаружены проблемы:"
echo "1. Перезапустить проблемные сервисы: docker-compose restart <service>"
echo "2. Проверить логи: docker-compose logs <service>"
echo "3. Полный перезапуск: docker-compose down && docker-compose up -d"
echo "4. Диагностика N8N+PostgreSQL: ./scripts/diagnose-n8n-postgres.sh"
echo "5. Мониторинг: ./scripts/monitor-n8n.sh"

echo -e "\n${GREEN}🎯 Валидация завершена!${NC}"
