#!/bin/bash

# =============================================================================
# 🔍 АНАЛИЗ ОШИБОК В ЛОГАХ КОНТЕЙНЕРОВ
# =============================================================================

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

container_name=${1:-"all"}

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

analyze_container_logs() {
    local container=$1
    local lines=${2:-100}
    
    echo -e "${BLUE}🔍 Анализируем логи: $container (последние $lines строк)${NC}"
    
    if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
        echo -e "${RED}❌ Контейнер '$container' не найден или не запущен${NC}"
        return 1
    fi
    
    # Получаем логи
    logs=$(docker logs --tail "$lines" "$container" 2>&1)
    
    if [ -z "$logs" ]; then
        echo -e "${GREEN}ℹ️  Логи пусты или недоступны${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}📊 Статистика логов:${NC}"
    total_lines=$(echo "$logs" | wc -l)
    echo "  Всего строк: $total_lines"
    
    # Анализируем разные типы сообщений
    errors=$(echo "$logs" | grep -i -c "error" || echo "0")
    warnings=$(echo "$logs" | grep -i -c "warning\|warn" || echo "0")
    fatals=$(echo "$logs" | grep -i -c "fatal\|panic" || echo "0")
    exceptions=$(echo "$logs" | grep -i -c "exception" || echo "0")
    
    echo "  Ошибки (ERROR): $errors"
    echo "  Предупреждения (WARNING): $warnings"
    echo "  Критичные (FATAL/PANIC): $fatals"
    echo "  Исключения (EXCEPTION): $exceptions"
    
    # Показываем последние ошибки
    if [ "$errors" -gt 0 ] || [ "$fatals" -gt 0 ] || [ "$exceptions" -gt 0 ]; then
        echo -e "\n${RED}❌ НАЙДЕННЫЕ ОШИБКИ:${NC}"
        echo "$logs" | grep -i -E "(error|fatal|panic|exception)" | tail -10
        
        # Проверяем известные проблемы и решения
        echo -e "\n${YELLOW}💡 АНАЛИЗ ПРОБЛЕМ:${NC}"
        
        if echo "$logs" | grep -q -i "connection refused\|connect: connection refused"; then
            echo -e "${YELLOW}⚠️  Проблема подключения к сервису${NC}"
            echo "   Решение: Проверьте зависимости сервисов (depends_on)"
        fi
        
        if echo "$logs" | grep -q -i "getaddrinfo ENOTFOUND"; then
            echo -e "${YELLOW}⚠️  DNS проблема (сервис не найден)${NC}"
            echo "   Решение: Проверьте имена сервисов в docker-compose.yml"
        fi
        
        if echo "$logs" | grep -q -i "role.*does not exist"; then
            echo -e "${YELLOW}⚠️  Проблема с пользователем базы данных${NC}"
            echo "   Решение: Запустите ./scripts/reset-n8n-postgres.sh"
        fi
        
        if echo "$logs" | grep -q -i "encryption.*key\|mismatching.*key"; then
            echo -e "${YELLOW}⚠️  Проблема с ключом шифрования${NC}"
            echo "   Решение: Проверьте N8N_ENCRYPTION_KEY в .env"
        fi
        
        if echo "$logs" | grep -q -i "port.*already in use\|bind.*address already in use"; then
            echo -e "${YELLOW}⚠️  Порт уже используется${NC}"
            echo "   Решение: Остановите конфликтующие сервисы или измените порты"
        fi
        
        if echo "$logs" | grep -q -i "no space left on device"; then
            echo -e "${YELLOW}⚠️  Недостаточно места на диске${NC}"
            echo "   Решение: Очистите место или запустите docker system prune"
        fi
        
        if echo "$logs" | grep -q -i "memory\|oom"; then
            echo -e "${YELLOW}⚠️  Проблемы с памятью${NC}"
            echo "   Решение: Увеличьте лимиты памяти в docker-compose.yml"
        fi
    else
        echo -e "\n${GREEN}✅ КРИТИЧНЫХ ОШИБОК НЕ НАЙДЕНО${NC}"
    fi
    
    # Показываем последние предупреждения (если есть)
    if [ "$warnings" -gt 0 ]; then
        echo -e "\n${YELLOW}⚠️  ПОСЛЕДНИЕ ПРЕДУПРЕЖДЕНИЯ:${NC}"
        echo "$logs" | grep -i "warning\|warn" | tail -5
    fi
    
    # Показываем последние успешные сообщения
    echo -e "\n${GREEN}✅ ПОСЛЕДНИЕ УСПЕШНЫЕ ОПЕРАЦИИ:${NC}"
    echo "$logs" | grep -i -E "(success|started|ready|listening|connected|ok)" | tail -5
    
    return 0
}

# Основная логика
if [ "$container_name" = "all" ]; then
    print_header "🔍 АНАЛИЗ ЛОГОВ ВСЕХ КОНТЕЙНЕРОВ"
    
    for container in $(docker ps --format "{{.Names}}"); do
        analyze_container_logs "$container" 50
        echo ""
    done
else
    print_header "🔍 АНАЛИЗ ЛОГОВ КОНТЕЙНЕРА: $container_name"
    analyze_container_logs "$container_name" 200
fi

print_header "🔧 РЕКОМЕНДАЦИИ"

echo "📝 Для решения найденных проблем:"
echo "1. Перезапуск конкретного сервиса: docker-compose restart <service>"
echo "2. Полная диагностика N8N: ./scripts/diagnose-n8n-postgres.sh"
echo "3. Сброс N8N+PostgreSQL: ./scripts/reset-n8n-postgres.sh"
echo "4. Проверка всех сервисов: ./scripts/validate-all-services.sh"
echo "5. Мониторинг в реальном времени: docker-compose logs -f <service>"

echo -e "\n${GREEN}🎯 Анализ логов завершён!${NC}"
