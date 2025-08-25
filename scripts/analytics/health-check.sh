#!/bin/bash

# Analytics Stack Health Check Script
# Проверка состояния аналитического стека

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 Проверка состояния Analytics Stack"
echo "===================================="

# Функции для проверки сервисов
check_service() {
    local service_name=$1
    local url=$2
    local expected_response=${3:-"200"}
    
    echo -n "Проверка $service_name... "
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_response"; then
        echo -e "${GREEN}✅ Работает${NC}"
        return 0
    else
        echo -e "${RED}❌ Недоступен${NC}"
        return 1
    fi
}

check_clickhouse() {
    echo -n "Проверка ClickHouse... "
    
    if curl -s http://localhost:8123/ | grep -q "Ok."; then
        echo -e "${GREEN}✅ Работает${NC}"
        
        # Проверка базы данных
        echo -n "  - База данных n8n_analytics... "
        if curl -s "http://localhost:8123/?query=SELECT%201%20FROM%20system.databases%20WHERE%20name='n8n_analytics'" | grep -q "1"; then
            echo -e "${GREEN}✅ Существует${NC}"
        else
            echo -e "${YELLOW}⚠️  Не найдена${NC}"
        fi
        
        # Проверка таблиц
        echo -n "  - Таблицы аналитики... "
        tables_count=$(curl -s "http://localhost:8123/?query=SELECT%20count()%20FROM%20system.tables%20WHERE%20database='n8n_analytics'" 2>/dev/null || echo "0")
        if [ "$tables_count" -gt "0" ]; then
            echo -e "${GREEN}✅ $tables_count таблиц${NC}"
        else
            echo -e "${YELLOW}⚠️  Таблицы не созданы${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Недоступен${NC}"
        return 1
    fi
}

check_container() {
    local container_name=$1
    echo -n "Контейнер $container_name... "
    
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        local status=$(docker inspect --format="{{.State.Health.Status}}" "$container_name" 2>/dev/null || echo "unknown")
        case $status in
            "healthy")
                echo -e "${GREEN}✅ Здоров${NC}"
                return 0
                ;;
            "starting")
                echo -e "${YELLOW}🔄 Запускается${NC}"
                return 1
                ;;
            "unhealthy")
                echo -e "${RED}❌ Нездоров${NC}"
                return 1
                ;;
            "unknown")
                echo -e "${BLUE}ℹ️  Работает (без health check)${NC}"
                return 0
                ;;
            *)
                echo -e "${YELLOW}⚠️  Неизвестно ($status)${NC}"
                return 1
                ;;
        esac
    else
        echo -e "${RED}❌ Не запущен${NC}"
        return 1
    fi
}

# Общая информация
echo ""
echo "📊 Состояние контейнеров:"
echo "========================"

check_container "n8n_clickhouse"
check_container "n8n_superset"
check_container "n8n_analytics_postgres"
check_container "n8n_analytics_redis"
check_container "n8n_etl_processor"
check_container "n8n_analytics_api"

echo ""
echo "🌐 Состояние веб-сервисов:"
echo "=========================="

# ClickHouse
check_clickhouse

# Superset
check_service "Superset" "http://localhost:8088/health"

# Analytics API
if check_service "Analytics API" "http://localhost:8089/health"; then
    # Проверка дополнительных эндпоинтов
    echo -n "  - Metrics endpoint... "
    if curl -s http://localhost:8089/metrics | head -1 | grep -q "^#"; then
        echo -e "${GREEN}✅ Работает${NC}"
    else
        echo -e "${YELLOW}⚠️  Недоступен${NC}"
    fi
fi

# ETL Processor
if check_service "ETL Processor" "http://localhost:8080/health"; then
    # Проверка статуса ETL
    echo -n "  - ETL Status... "
    if curl -s http://localhost:8080/status | grep -q "status"; then
        echo -e "${GREEN}✅ Работает${NC}"
    else
        echo -e "${YELLOW}⚠️  Недоступен${NC}"
    fi
fi

echo ""
echo "🔗 Состояние сетей:"
echo "=================="

# Проверка Docker networks
networks=("n8n_analytics_network" "n8n_network" "n8n_monitoring_network")
for network in "${networks[@]}"; do
    echo -n "Сеть $network... "
    if docker network ls | grep -q "$network"; then
        echo -e "${GREEN}✅ Существует${NC}"
    else
        echo -e "${RED}❌ Отсутствует${NC}"
    fi
done

echo ""
echo "💾 Состояние хранилища:"
echo "======================"

# Проверка volumes
volumes=("clickhouse_data" "superset_data" "postgres_analytics_data" "redis_analytics_data")
for volume in "${volumes[@]}"; do
    echo -n "Volume $volume... "
    if docker volume ls | grep -q "$volume"; then
        echo -e "${GREEN}✅ Существует${NC}"
    else
        echo -e "${RED}❌ Отсутствует${NC}"
    fi
done

# Проверка директорий
echo -n "Директории данных... "
missing_dirs=()
for dir in data/clickhouse data/superset data/postgres-analytics data/redis-analytics; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Все существуют${NC}"
else
    echo -e "${YELLOW}⚠️  Отсутствуют: ${missing_dirs[*]}${NC}"
fi

echo ""
echo "📈 Статистика использования:"
echo "==========================="

# Docker stats для Analytics контейнеров
if command -v docker &> /dev/null; then
    echo "Использование ресурсов:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
        n8n_clickhouse n8n_superset n8n_analytics_postgres n8n_analytics_redis n8n_etl_processor n8n_analytics_api 2>/dev/null || echo "Контейнеры не запущены"
fi

echo ""
echo "📋 Сводка:"
echo "========="

# Подсчет успешных проверок
total_checks=0
successful_checks=0

# Список всех доступных URL
echo "🌐 Доступные интерфейсы:"
urls=(
    "http://localhost:8088|Superset Dashboard"
    "http://localhost:8089|Analytics API"
    "http://localhost:8089/docs|API Документация"
    "http://localhost:8080|ETL Processor"
    "http://localhost:8123|ClickHouse HTTP"
)

for url_info in "${urls[@]}"; do
    IFS='|' read -r url description <<< "$url_info"
    echo -n "  - $description: "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo -e "${GREEN}✅ $url${NC}"
        ((successful_checks++))
    else
        echo -e "${RED}❌ Недоступен${NC}"
    fi
    ((total_checks++))
done

echo ""
if [ $successful_checks -eq $total_checks ]; then
    echo -e "${GREEN}🎉 Все сервисы Analytics Stack работают корректно! ($successful_checks/$total_checks)${NC}"
    exit 0
elif [ $successful_checks -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Частично работает: $successful_checks/$total_checks сервисов доступны${NC}"
    exit 1
else
    echo -e "${RED}❌ Analytics Stack не работает${NC}"
    exit 2
fi
