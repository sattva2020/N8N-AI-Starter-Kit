#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\scripts\healthcheck.sh
# Скрипт проверки здоровья всех сервисов N8N AI Starter Kit
# Версия: 1.0.6

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Проверка здоровья сервисов N8N AI Starter Kit ===${NC}"
echo ""

# Функция для проверки HTTP сервиса
check_http_service() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    if command -v curl &> /dev/null; then
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [ "$response_code" = "$expected_code" ]; then
            echo -e "  ${GREEN}✅ $name: Доступен (HTTP $response_code)${NC}"
            return 0
        else
            echo -e "  ${RED}❌ $name: Недоступен (HTTP $response_code)${NC}"
            return 1
        fi
    else
        echo -e "  ${YELLOW}⚠️ $name: Невозможно проверить (curl не найден)${NC}"
        return 2
    fi
}

# Функция для проверки TCP порта
check_tcp_port() {
    local name="$1"
    local host="$2"
    local port="$3"
    
    if command -v nc &> /dev/null; then
        if nc -z "$host" "$port" 2>/dev/null; then
            echo -e "  ${GREEN}✅ $name: Порт $port доступен${NC}"
            return 0
        else
            echo -e "  ${RED}❌ $name: Порт $port недоступен${NC}"
            return 1
        fi
    elif command -v telnet &> /dev/null; then
        if timeout 3 telnet "$host" "$port" 2>/dev/null | grep -q "Connected"; then
            echo -e "  ${GREEN}✅ $name: Порт $port доступен${NC}"
            return 0
        else
            echo -e "  ${RED}❌ $name: Порт $port недоступен${NC}"
            return 1
        fi
    else
        echo -e "  ${YELLOW}⚠️ $name: Невозможно проверить порт (nc/telnet не найдены)${NC}"
        return 2
    fi
}

# Функция для проверки статуса контейнера Docker
check_docker_container() {
    local name="$1"
    local container_name="$2"
    
    if docker ps --filter "name=$container_name" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "$container_name"; then
        # Получаем дополнительную информацию о контейнере
        status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" 2>/dev/null)
        echo -e "  ${GREEN}✅ $name: Запущен ($status)${NC}"
        
        # Проверяем здоровье контейнера, если есть healthcheck
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container_name" 2>/dev/null)
        if [ "$health" = "healthy" ]; then
            echo -e "     ${GREEN}💚 Healthcheck: Здоров${NC}"
        elif [ "$health" = "unhealthy" ]; then
            echo -e "     ${RED}💔 Healthcheck: Нездоров${NC}"
        elif [ "$health" = "starting" ]; then
            echo -e "     ${YELLOW}🟡 Healthcheck: Запускается${NC}"
        fi
        
        return 0
    elif docker ps -a --filter "name=$container_name" --format "{{.Names}}" 2>/dev/null | grep -q "$container_name"; then
        status=$(docker ps -a --filter "name=$container_name" --format "{{.Status}}" 2>/dev/null)
        echo -e "  ${RED}❌ $name: Остановлен ($status)${NC}"
        return 1
    else
        echo -e "  ${YELLOW}⚠️ $name: Контейнер не найден${NC}"
        return 2
    fi
}

# Функция для проверки API Ollama
check_ollama_api() {
    echo -e "${BLUE}Проверка API Ollama...${NC}"
    
    if check_http_service "Ollama API" "http://localhost:11434/api/version"; then
        # Проверяем доступные модели
        if command -v curl &> /dev/null; then
            models=$(curl -s "http://localhost:11434/api/tags" 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | wc -l)
            if [ "$models" -gt 0 ]; then
                echo -e "     ${GREEN}📦 Загружено моделей: $models${NC}"
            else
                echo -e "     ${YELLOW}📦 Модели не загружены${NC}"
            fi
        fi
    fi
}

# Функция для проверки Qdrant
check_qdrant_api() {
    echo -e "${BLUE}Проверка Qdrant...${NC}"
    
    if check_http_service "Qdrant API" "http://localhost:6333/health"; then
        # Проверяем количество коллекций
        if command -v curl &> /dev/null; then
            collections=$(curl -s "http://localhost:6333/collections" 2>/dev/null | grep -o '"name":"[^"]*"' | wc -l)
            echo -e "     ${GREEN}🗃️ Коллекций: $collections${NC}"
        fi
    fi
}

# Проверка основных контейнеров
echo -e "${BLUE}Проверка контейнеров Docker...${NC}"
check_docker_container "N8N" "n8n-ai-starter-kit-n8n-1"
check_docker_container "PostgreSQL" "n8n-ai-starter-kit-postgres-1"
check_docker_container "Traefik" "n8n-ai-starter-kit-traefik-1"
check_docker_container "Ollama" "n8n-ai-starter-kit-ollama-1"
check_docker_container "Qdrant" "n8n-ai-starter-kit-qdrant-1"
check_docker_container "Zep" "n8n-ai-starter-kit-zep-1"

echo ""

# Проверка HTTP сервисов
echo -e "${BLUE}Проверка HTTP сервисов...${NC}"
check_http_service "N8N Web UI" "http://localhost:5678"
check_http_service "Traefik Dashboard" "http://localhost:8080"
check_http_service "Qdrant Dashboard" "http://localhost:6333/dashboard"

echo ""

# Проверка API сервисов
check_ollama_api
echo ""
check_qdrant_api

echo ""

# Проверка TCP портов
echo -e "${BLUE}Проверка портов...${NC}"
check_tcp_port "N8N HTTP" "localhost" "5678"
check_tcp_port "Traefik HTTP" "localhost" "80"
check_tcp_port "Traefik HTTPS" "localhost" "443"
check_tcp_port "Traefik Dashboard" "localhost" "8080"
check_tcp_port "Qdrant HTTP" "localhost" "6333"
check_tcp_port "Qdrant gRPC" "localhost" "6334"
check_tcp_port "Ollama API" "localhost" "11434"

echo ""

# Проверка файловой системы
echo -e "${BLUE}Проверка файловой системы...${NC}"

# Проверка наличия важных файлов
important_files=(".env" "docker-compose.yml" "scripts/setup.sh")
for file in "${important_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✅ $file: Найден${NC}"
    else
        echo -e "  ${RED}❌ $file: Отсутствует${NC}"
    fi
done

# Проверка размера логов
echo ""
echo -e "${BLUE}Размер данных...${NC}"
if [ -d "logs" ]; then
    log_size=$(du -sh logs 2>/dev/null | cut -f1)
    echo -e "  📋 Логи: $log_size"
fi

if [ -d "n8n" ]; then
    n8n_size=$(du -sh n8n 2>/dev/null | cut -f1)
    echo -e "  🔧 Данные N8N: $n8n_size"
fi

# Проверка использования Docker volumes
echo ""
echo -e "${BLUE}Docker volumes...${NC}"
if command -v docker &> /dev/null; then
    docker volume ls --filter "name=n8n-ai-starter-kit" --format "table {{.Name}}\t{{.Size}}" 2>/dev/null | \
    while IFS= read -r line; do
        if [[ "$line" =~ "NAME" ]]; then
            echo -e "  ${BLUE}$line${NC}"
        else
            echo -e "  ${GREEN}💾 $line${NC}"
        fi
    done
fi

echo ""

# Итоговая сводка
echo -e "${BLUE}=== Сводка проверки здоровья ===${NC}"

# Подсчет успешных проверок (это приблизительная оценка)
total_checks=15
healthy_services=$(docker ps --filter "name=n8n-ai-starter-kit" --filter "status=running" -q | wc -l)

if [ "$healthy_services" -gt 4 ]; then
    echo -e "${GREEN}🎉 Система работает хорошо! ($healthy_services/6 основных сервисов запущено)${NC}"
elif [ "$healthy_services" -gt 2 ]; then
    echo -e "${YELLOW}⚠️ Система частично работает ($healthy_services/6 основных сервисов запущено)${NC}"
    echo -e "${YELLOW}Рекомендуется проверить логи проблемных сервисов${NC}"
else
    echo -e "${RED}❌ Система не работает должным образом ($healthy_services/6 основных сервисов запущено)${NC}"
    echo -e "${RED}Запустите диагностику: ./scripts/diagnose.sh${NC}"
fi

echo ""
echo -e "${BLUE}Для получения дополнительной информации:${NC}"
echo -e "  📊 Мониторинг: ${YELLOW}./scripts/monitor.sh${NC}"
echo -e "  🔍 Диагностика: ${YELLOW}./scripts/diagnose.sh${NC}"
echo -e "  📝 Логи: ${YELLOW}docker logs <container_name>${NC}"