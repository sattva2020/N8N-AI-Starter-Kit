#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\scripts\monitor.sh
# Скрипт мониторинга N8N AI Starter Kit в реальном времени
# Версия: 1.0.6

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    N8N AI Starter Kit - Мониторинг системы                  ║${NC}"
    echo -e "${BLUE}║                              $(date '+%Y-%m-%d %H:%M:%S')                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Функция для проверки статуса контейнеров
show_containers_status() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                              СТАТУС КОНТЕЙНЕРОВ                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    if docker ps -a --filter "name=n8n-ai-starter-kit" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -q "n8n-ai-starter-kit"; then
        echo -e "${GREEN}Контейнеры проекта:${NC}"
        docker ps -a --filter "name=n8n-ai-starter-kit" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | \
        while IFS= read -r line; do
            if [[ "$line" =~ "Up" ]]; then
                echo -e "  ${GREEN}✅ $line${NC}"
            elif [[ "$line" =~ "Exited" ]]; then
                echo -e "  ${RED}❌ $line${NC}"
            else
                echo -e "  ${YELLOW}⚠️  $line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️ Контейнеры проекта не найдены${NC}"
    fi
    echo ""
}

# Функция для отображения использования ресурсов
show_resource_usage() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                           ИСПОЛЬЗОВАНИЕ РЕСУРСОВ                            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    if docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null | grep -q "n8n-ai-starter-kit"; then
        echo -e "${GREEN}Ресурсы контейнеров:${NC}"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null | \
        grep -E "(NAME|n8n-ai-starter-kit)" | \
        while IFS= read -r line; do
            if [[ "$line" =~ "NAME" ]]; then
                echo -e "  ${BLUE}$line${NC}"
            else
                # Подсветка высокого использования CPU (>80%)
                if [[ "$line" =~ ([0-9]+\.[0-9]+)% ]] && (( $(echo "${BASH_REMATCH[1]} > 80" | bc -l) )); then
                    echo -e "  ${RED}🔥 $line${NC}"
                else
                    echo -e "  ${GREEN}📊 $line${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️ Статистика контейнеров недоступна${NC}"
    fi
    echo ""
}

# Функция для отображения информации о диске
show_disk_usage() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                              ИСПОЛЬЗОВАНИЕ ДИСКА                            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    if command -v df &> /dev/null; then
        echo -e "${GREEN}Место на диске:${NC}"
        df -h | grep -E "(Filesystem|/$|/var/lib/docker)" | \
        while IFS= read -r line; do
            if [[ "$line" =~ "Filesystem" ]]; then
                echo -e "  ${BLUE}$line${NC}"
            elif [[ "$line" =~ ([0-9]+)% ]]; then
                usage=${BASH_REMATCH[1]}
                if [ "$usage" -gt 90 ]; then
                    echo -e "  ${RED}💾 $line${NC}"
                elif [ "$usage" -gt 80 ]; then
                    echo -e "  ${YELLOW}💾 $line${NC}"
                else
                    echo -e "  ${GREEN}💾 $line${NC}"
                fi
            else
                echo -e "  ${GREEN}💾 $line${NC}"
            fi
        done
        
        # Проверка размера Docker volumes
        echo ""
        echo -e "${GREEN}Docker volumes:${NC}"
        docker system df 2>/dev/null | \
        while IFS= read -r line; do
            if [[ "$line" =~ "TYPE" ]]; then
                echo -e "  ${BLUE}$line${NC}"
            else
                echo -e "  ${GREEN}🗄️  $line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️ Команда df недоступна${NC}"
    fi
    echo ""
}

# Функция для отображения сетевой активности
show_network_activity() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                             СЕТЕВАЯ АКТИВНОСТЬ                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # Проверка открытых портов
    echo -e "${GREEN}Открытые порты проекта:${NC}"
    important_ports=(80 443 5678 6333 11434 8080 9001)
    for port in "${important_ports[@]}"; do
        if command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                echo -e "  ${GREEN}🌐 Порт $port: активен${NC}"
            else
                echo -e "  ${YELLOW}🌐 Порт $port: не активен${NC}"
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln 2>/dev/null | grep -q ":$port "; then
                echo -e "  ${GREEN}🌐 Порт $port: активен${NC}"
            else
                echo -e "  ${YELLOW}🌐 Порт $port: не активен${NC}"
            fi
        fi
    done
    echo ""
}

# Функция для отображения последних логов
show_recent_logs() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                              ПОСЛЕДНИЕ ЛОГИ                                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # Показываем последние 5 строк логов из ключевых контейнеров
    containers=("n8n-ai-starter-kit-n8n-1" "n8n-ai-starter-kit-ollama-1" "n8n-ai-starter-kit-qdrant-1")
    
    for container in "${containers[@]}"; do
        if docker ps --filter "name=$container" --format "{{.Names}}" 2>/dev/null | grep -q "$container"; then
            echo -e "${GREEN}📋 Логи $container (последние 3 строки):${NC}"
            docker logs --tail 3 "$container" 2>/dev/null | sed 's/^/     /' | head -3
            echo ""
        fi
    done
}

# Функция для отображения рекомендаций по оптимизации
show_recommendations() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                            РЕКОМЕНДАЦИИ ПО ОПТИМИЗАЦИИ                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    recommendations=()
    
    # Проверка использования памяти
    if command -v free &> /dev/null; then
        memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [ "$memory_usage" -gt 90 ]; then
            recommendations+=("🔴 Высокое использование памяти ($memory_usage%). Рассмотрите перезапуск контейнеров.")
        elif [ "$memory_usage" -gt 80 ]; then
            recommendations+=("🟡 Использование памяти: $memory_usage%. Мониторьте нагрузку.")
        fi
    fi
    
    # Проверка дискового пространства
    if command -v df &> /dev/null; then
        disk_usage=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$disk_usage" -gt 90 ]; then
            recommendations+=("🔴 Критически мало места на диске ($disk_usage%). Очистите данные.")
        elif [ "$disk_usage" -gt 80 ]; then
            recommendations+=("🟡 Место на диске: $disk_usage%. Планируйте очистку.")
        fi
    fi
    
    # Проверка количества контейнеров
    running_containers=$(docker ps --filter "name=n8n-ai-starter-kit" -q | wc -l)
    if [ "$running_containers" -eq 0 ]; then
        recommendations+=("🔴 Нет запущенных контейнеров. Запустите систему: ./scripts/start.sh cpu")
    elif [ "$running_containers" -lt 3 ]; then
        recommendations+=("🟡 Мало контейнеров запущено ($running_containers). Проверьте статус системы.")
    fi
    
    # Отображение рекомендаций
    if [ ${#recommendations[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✅ Система работает оптимально!${NC}"
    else
        for rec in "${recommendations[@]}"; do
            echo -e "  $rec"
        done
    fi
    echo ""
}

# Основная функция мониторинга
main_monitor() {
    local interval=${1:-5}
    
    echo -e "${BLUE}Запуск мониторинга N8N AI Starter Kit...${NC}"
    echo -e "${YELLOW}Интервал обновления: ${interval} секунд${NC}"
    echo -e "${YELLOW}Для выхода нажмите Ctrl+C${NC}"
    echo ""
    sleep 2
    
    while true; do
        show_header
        show_containers_status
        show_resource_usage
        show_disk_usage
        show_network_activity
        show_recent_logs
        show_recommendations
        
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║    Следующее обновление через ${interval}с | Ctrl+C для выхода | Интервал: ${interval}с               ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        
        sleep "$interval"
    done
}

# Обработка аргументов командной строки
case "${1:-monitor}" in
    "monitor"|"m")
        main_monitor "${2:-5}"
        ;;
    "once"|"o")
        show_header
        show_containers_status
        show_resource_usage
        show_disk_usage
        show_network_activity
        show_recent_logs
        show_recommendations
        ;;
    "logs"|"l")
        container=${2:-"n8n-ai-starter-kit-n8n-1"}
        echo -e "${BLUE}Отображение логов для $container (Ctrl+C для выхода):${NC}"
        docker logs -f "$container" 2>/dev/null
        ;;
    "help"|"h")
        echo "Использование: $0 [команда] [параметры]"
        echo ""
        echo "Команды:"
        echo "  monitor, m [интервал]  - Непрерывный мониторинг (по умолчанию: 5с)"
        echo "  once, o               - Одиночная проверка статуса"
        echo "  logs, l [контейнер]   - Отображение логов контейнера"
        echo "  help, h               - Показать эту справку"
        echo ""
        echo "Примеры:"
        echo "  $0 monitor 10         - Мониторинг с интервалом 10 секунд"
        echo "  $0 once               - Разовая проверка статуса"
        echo "  $0 logs ollama        - Просмотр логов Ollama"
        ;;
    *)
        echo -e "${RED}Неизвестная команда: $1${NC}"
        echo "Используйте '$0 help' для справки"
        exit 1
        ;;
esac