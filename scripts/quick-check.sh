#!/bin/bash

# =============================================================================
# 🚀 БЫСТРАЯ ПРОВЕРКА ВСЕХ КОНТЕЙНЕРОВ N8N AI STARTER KIT
# =============================================================================

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 БЫСТРАЯ ПРОВЕРКА СТАТУСА ВСЕХ СЕРВИСОВ${NC}\n"

# 1. Показать все запущенные контейнеры
echo -e "${BLUE}📋 Запущенные контейнеры:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

# 2. Проверить основные сервисы
echo -e "\n${BLUE}🔍 Статус основных сервисов:${NC}"

services=("n8n" "postgres" "qdrant" "ollama" "minio" "traefik")

for service in "${services[@]}"; do
    if docker ps | grep -q "$service"; then
        echo -e "${GREEN}✅ $service: запущен${NC}"
    else
        echo -e "${RED}❌ $service: не найден${NC}"
    fi
done

# 3. Быстрая проверка API
echo -e "\n${BLUE}🌐 API endpoints:${NC}"

# N8N
if curl -s --max-time 5 http://localhost:5678 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ N8N (5678): доступен${NC}"
else
    echo -e "${RED}❌ N8N (5678): недоступен${NC}"
fi

# Ollama
if curl -s --max-time 5 http://localhost:11434 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ollama (11434): доступен${NC}"
else
    echo -e "${RED}❌ Ollama (11434): недоступен${NC}"
fi

# Qdrant
if curl -s --max-time 5 http://localhost:6333 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Qdrant (6333): доступен${NC}"
else
    echo -e "${RED}❌ Qdrant (6333): недоступен${NC}"
fi

# 4. Проверка ошибок в логах
echo -e "\n${BLUE}📋 Проверка ошибок в логах (последние 20 строк):${NC}"

for container in $(docker ps --format "{{.Names}}" | head -10); do
    errors=$(docker logs --tail 20 "$container" 2>&1 | grep -i -c -E "(error|fatal|exception)" || echo "0")
    if [ "$errors" -gt 0 ]; then
        echo -e "${RED}⚠️  $container: $errors ошибок${NC}"
    else
        echo -e "${GREEN}✅ $container: без ошибок${NC}"
    fi
done

# 5. Healthcheck статусы
echo -e "\n${BLUE}💚 Health check статусы:${NC}"
for container in $(docker ps --format "{{.Names}}" | head -10); do
    health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    case $health in
        "healthy")
            echo -e "${GREEN}✅ $container: healthy${NC}" ;;
        "unhealthy")
            echo -e "${RED}❌ $container: unhealthy${NC}" ;;
        "starting")
            echo -e "${YELLOW}⏳ $container: starting${NC}" ;;
        *)
            echo -e "${BLUE}ℹ️  $container: no healthcheck${NC}" ;;
    esac
done

echo -e "\n${GREEN}🎯 Быстрая проверка завершена!${NC}"
echo -e "${BLUE}💡 Для подробной диагностики: ./scripts/validate-all-services.sh${NC}"
