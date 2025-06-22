#!/bin/bash
# Comprehensive Container Validation Script
# Проверяет все контейнеры на наличие ошибок и корректность работы

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 COMPREHENSIVE CONTAINER VALIDATION${NC}"
echo "=================================================================="
echo -e "Дата: $(date)"
echo -e "Проверка всех контейнеров на ошибки и корректность работы\n"

# Функция для проверки статуса контейнера
check_container_status() {
    local container_name=$1
    echo -e "${BLUE}🔍 Проверка контейнера: ${container_name}${NC}"
    
    # Проверяем существует ли контейнер
    if ! docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}⚠️  Контейнер ${container_name} не найден${NC}\n"
        return 1
    fi
    
    # Получаем статус контейнера
    local status=$(docker inspect --format='{{.State.Status}}' ${container_name} 2>/dev/null)
    local health=$(docker inspect --format='{{.State.Health.Status}}' ${container_name} 2>/dev/null || echo "no-healthcheck")
    local exit_code=$(docker inspect --format='{{.State.ExitCode}}' ${container_name} 2>/dev/null)
    local started_at=$(docker inspect --format='{{.State.StartedAt}}' ${container_name} 2>/dev/null)
    
    echo "   📊 Статус: ${status}"
    echo "   🏥 Health: ${health}"
    echo "   📤 Exit Code: ${exit_code}"
    echo "   🕐 Запущен: ${started_at}"
    
    # Анализируем результаты
    if [[ "$status" == "running" ]]; then
        if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
            echo -e "   ${GREEN}✅ Контейнер работает корректно${NC}"
            return 0
        else
            echo -e "   ${RED}❌ Health check failed: ${health}${NC}"
            return 1
        fi
    else
        echo -e "   ${RED}❌ Контейнер не запущен: ${status}${NC}"
        return 1
    fi
}

# Функция для анализа ошибок в логах
analyze_container_logs() {
    local container_name=$1
    local lines=${2:-50}
    
    echo -e "${BLUE}📋 Анализ логов контейнера: ${container_name} (последние ${lines} строк)${NC}"
    
    if ! docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}⚠️  Контейнер ${container_name} не найден${NC}\n"
        return 1
    fi
    
    # Получаем логи и ищем ошибки
    local logs=$(docker logs ${container_name} --tail ${lines} 2>&1)
    
    # Паттерны ошибок для поиска
    local error_patterns=(
        "ERROR"
        "FATAL"
        "CRITICAL"
        "Exception"
        "Traceback"
        "failed"
        "Failed"
        "error"
        "Error"
        "panic"
        "PANIC"
        "Connection refused"
        "Connection reset"
        "timeout"
        "Timeout"
        "permission denied"
        "Permission denied"
        "No such file"
        "not found"
        "Not found"
        "unhealthy"
        "Unhealthy"
    )
    
    local found_errors=0
    
    for pattern in "${error_patterns[@]}"; do
        local matches=$(echo "$logs" | grep -i "$pattern" | head -5)
        if [[ -n "$matches" ]]; then
            if [[ $found_errors -eq 0 ]]; then
                echo -e "   ${RED}🚨 Найдены ошибки:${NC}"
                found_errors=1
            fi
            echo -e "   ${RED}▶ $pattern:${NC}"
            echo "$matches" | sed 's/^/     /'
        fi
    done
    
    if [[ $found_errors -eq 0 ]]; then
        echo -e "   ${GREEN}✅ Ошибок в логах не найдено${NC}"
    fi
    
    echo ""
}

# Функция для проверки портов
check_service_ports() {
    echo -e "${BLUE}🌐 Проверка доступности портов сервисов${NC}"
    
    local services=(
        "5678:N8N"
        "11434:Ollama"
        "6333:Qdrant"
        "5432:PostgreSQL"
        "9000:MinIO"
        "8080:Traefik"
        "8001:Graphiti"
    )
    
    for service in "${services[@]}"; do
        local port=$(echo $service | cut -d':' -f1)
        local name=$(echo $service | cut -d':' -f2)
        
        echo -n "   🔌 ${name} (port ${port}): "
        
        if command -v curl >/dev/null 2>&1; then
            if curl -s --connect-timeout 5 "http://localhost:${port}" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Доступен${NC}"
            else
                echo -e "${RED}❌ Недоступен${NC}"
            fi
        elif command -v nc >/dev/null 2>&1; then
            if nc -z localhost ${port} 2>/dev/null; then
                echo -e "${GREEN}✅ Порт открыт${NC}"
            else
                echo -e "${RED}❌ Порт закрыт${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Нет инструментов для проверки${NC}"
        fi
    done
    echo ""
}

# Функция для общей статистики Docker
docker_system_info() {
    echo -e "${BLUE}📊 Общая информация о Docker${NC}"
    
    # Количество контейнеров
    local total_containers=$(docker ps -a -q | wc -l)
    local running_containers=$(docker ps -q | wc -l)
    local stopped_containers=$((total_containers - running_containers))
    
    echo "   📦 Всего контейнеров: ${total_containers}"
    echo "   ▶️  Запущено: ${running_containers}"
    echo "   ⏹️  Остановлено: ${stopped_containers}"
    
    # Использование ресурсов
    echo -e "   💾 Использование диска Docker:"
    docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}" | sed 's/^/     /'
    
    echo ""
}

# Основная проверка
main() {
    echo -e "${BLUE}🏁 Начинаем комплексную проверку...${NC}\n"
    
    # Проверяем запущен ли Docker
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker не запущен или недоступен${NC}"
        exit 1
    fi
    
    # Общая информация
    docker_system_info
    
    # Получаем список всех контейнеров проекта
    echo -e "${BLUE}📋 Получение списка контейнеров проекта...${NC}"
    local project_containers=(
        "n8n-ai-starter-kit-n8n-1"
        "n8n-ai-starter-kit-postgres-1" 
        "n8n-ai-starter-kit-ollama-1"
        "n8n-ai-starter-kit-qdrant-1"
        "n8n-ai-starter-kit-minio-1"
        "n8n-ai-starter-kit-traefik-1"
        "n8n-ai-starter-kit-graphiti-1"
        "n8n-ai-starter-kit-zep-1"
        "n8n-ai-starter-kit-neo4j-1"
    )
    
    # Также проверяем автоматически найденные контейнеры
    local auto_containers=$(docker ps -a --filter "label=com.docker.compose.project=n8n-ai-starter-kit" --format "{{.Names}}" 2>/dev/null | sort)
    
    if [[ -n "$auto_containers" ]]; then
        echo -e "   🔍 Найденные контейнеры проекта:"
        echo "$auto_containers" | sed 's/^/     /'
        # Объединяем списки
        local all_containers=$(echo -e "${project_containers[*]}\n$auto_containers" | tr ' ' '\n' | sort -u)
    else
        echo -e "   📋 Используем предопределённый список контейнеров"
        local all_containers=$(printf '%s\n' "${project_containers[@]}")
    fi
    
    echo ""
    
    # Проверяем каждый контейнер
    local total_checked=0
    local healthy_count=0
    local error_count=0
    
    while IFS= read -r container; do
        [[ -z "$container" ]] && continue
        
        echo "=================================================================="
        total_checked=$((total_checked + 1))
        
        if check_container_status "$container"; then
            healthy_count=$((healthy_count + 1))
            analyze_container_logs "$container" 30
        else
            error_count=$((error_count + 1))
            echo -e "${RED}🔍 Анализируем логи для диагностики проблемы...${NC}"
            analyze_container_logs "$container" 50
        fi
        
    done <<< "$all_containers"
    
    # Проверяем порты
    echo "=================================================================="
    check_service_ports
    
    # Итоговая статистика
    echo "=================================================================="
    echo -e "${BLUE}📊 ИТОГОВАЯ СТАТИСТИКА${NC}"
    echo "   📦 Всего проверено: ${total_checked}"
    echo -e "   ${GREEN}✅ Работают корректно: ${healthy_count}${NC}"
    echo -e "   ${RED}❌ С ошибками: ${error_count}${NC}"
    
    if [[ $error_count -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ВСЕ КОНТЕЙНЕРЫ РАБОТАЮТ КОРРЕКТНО!${NC}"
        exit 0
    else
        echo -e "\n${RED}⚠️  ОБНАРУЖЕНЫ ПРОБЛЕМЫ В ${error_count} КОНТЕЙНЕРАХ${NC}"
        echo -e "${YELLOW}💡 Рекомендации:${NC}"
        echo "   1. Проверьте логи проблемных контейнеров"
        echo "   2. Перезапустите контейнеры с ошибками"
        echo "   3. Проверьте конфигурацию docker-compose.yml"
        echo "   4. Убедитесь что все зависимости доступны"
        exit 1
    fi
}

# Запускаем основную функцию
main "$@"
