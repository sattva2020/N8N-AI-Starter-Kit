#!/bin/bash

# =============================================
# N8N + PostgreSQL Health Monitor
# =============================================
# Мониторинг состояния связки N8N + PostgreSQL
# Отправка уведомлений о проблемах и автоматическое восстановление

set -e

# Конфигурация
SCRIPT_NAME="N8N Health Monitor"
LOG_FILE="/tmp/n8n-health-monitor.log"
ALERT_FILE="/tmp/n8n-health-alerts.log"
CHECK_INTERVAL=30
MAX_RETRIES=3
RESTART_COOLDOWN=300  # 5 минут между перезапусками

# Функция для логирования
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Функция для отправки алертов
send_alert() {
    local severity=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$severity] $message" >> "$ALERT_FILE"
    log_message "ALERT" "$severity: $message"
    
    # Здесь можно добавить интеграцию с системами уведомлений
    # например, webhook, email, Slack, Discord и т.д.
    # curl -X POST "https://your-webhook-url" -d "N8N Alert: $message"
}

# Функция проверки контейнера
check_container() {
    local container_name=$1
    local service_name=$2
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
        return 1
    fi
    
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
    
    if [ "$status" != "running" ]; then
        return 1
    fi
    
    if [ "$health" != "healthy" ] && [ "$health" != "none" ]; then
        return 1
    fi
    
    return 0
}

# Функция проверки PostgreSQL
check_postgres() {
    local container_name="n8n-ai-starter-kit-postgres-1"
    
    # Проверка контейнера
    if ! check_container "$container_name" "PostgreSQL"; then
        return 1
    fi
    
    # Проверка доступности
    if ! docker exec "$container_name" pg_isready -U postgres >/dev/null 2>&1; then
        return 1
    fi
    
    # Проверка подключения пользователя N8N
    source .env 2>/dev/null || true
    if [[ -n "$POSTGRES_USER" && -n "$POSTGRES_DB" ]]; then
        if ! docker exec "$container_name" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    return 0
}

# Функция проверки N8N
check_n8n() {
    local container_name="n8n-ai-starter-kit-n8n-1"
    
    # Проверка контейнера
    if ! check_container "$container_name" "N8N"; then
        return 1
    fi
    
    # Проверка API
    if ! curl -s -f "http://localhost:5678/healthz" >/dev/null 2>&1; then
        return 1
    fi
    
    # Проверка логов на критические ошибки
    local logs=$(docker logs "$container_name" --tail 10 2>&1)
    if echo "$logs" | grep -qi "database connection.*failed\|authentication.*failed\|connection refused"; then
        return 1
    fi
    
    return 0
}

# Функция проверки сетевой связности
check_network() {
    local n8n_container="n8n-ai-starter-kit-n8n-1"
    local postgres_container="n8n-ai-starter-kit-postgres-1"
    
    # Проверка резолвинга имени
    if ! docker exec "$n8n_container" nslookup postgres >/dev/null 2>&1; then
        return 1
    fi
    
    # Проверка доступности порта
    source .env 2>/dev/null || true
    local postgres_port=${POSTGRES_PORT:-5432}
    if ! docker exec "$n8n_container" nc -z postgres "$postgres_port" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Функция перезапуска сервиса
restart_service() {
    local service_name=$1
    local cooldown_file="/tmp/n8n-restart-$service_name"
    
    # Проверка cooldown периода
    if [ -f "$cooldown_file" ]; then
        local last_restart=$(cat "$cooldown_file")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_restart))
        
        if [ $time_diff -lt $RESTART_COOLDOWN ]; then
            log_message "WARN" "Перезапуск $service_name пропущен (cooldown: $((RESTART_COOLDOWN - time_diff))s)"
            return 1
        fi
    fi
    
    log_message "INFO" "Перезапуск сервиса: $service_name"
    send_alert "WARNING" "Перезапуск сервиса $service_name из-за проблем со здоровьем"
    
    # Выполнение перезапуска
    if docker compose restart "$service_name" >/dev/null 2>&1; then
        echo "$(date +%s)" > "$cooldown_file"
        log_message "INFO" "Сервис $service_name перезапущен успешно"
        return 0
    else
        log_message "ERROR" "Ошибка при перезапуске сервиса $service_name"
        send_alert "CRITICAL" "Не удалось перезапустить сервис $service_name"
        return 1
    fi
}

# Функция полной проверки здоровья
health_check() {
    local overall_status="OK"
    local issues=()
    
    log_message "INFO" "Начало проверки здоровья системы"
    
    # Проверка PostgreSQL
    if ! check_postgres; then
        issues+=("PostgreSQL")
        overall_status="DEGRADED"
        log_message "WARN" "PostgreSQL: проблемы обнаружены"
    else
        log_message "INFO" "PostgreSQL: OK"
    fi
    
    # Проверка N8N
    if ! check_n8n; then
        issues+=("N8N")
        overall_status="DEGRADED"
        log_message "WARN" "N8N: проблемы обнаружены"
    else
        log_message "INFO" "N8N: OK"
    fi
    
    # Проверка сети
    if ! check_network; then
        issues+=("Network")
        overall_status="DEGRADED"
        log_message "WARN" "Network: проблемы с сетевой связностью"
    else
        log_message "INFO" "Network: OK"
    fi
    
    # Обработка проблем
    if [ ${#issues[@]} -gt 0 ]; then
        log_message "WARN" "Обнаружены проблемы: ${issues[*]}"
        
        # Попытка автоматического восстановления
        for issue in "${issues[@]}"; do
            case "$issue" in
                "PostgreSQL")
                    restart_service "postgres"
                    ;;
                "N8N")
                    restart_service "n8n"
                    ;;
                "Network")
                    log_message "INFO" "Проблемы с сетью, перезапуск связанных сервисов"
                    restart_service "postgres"
                    sleep 10
                    restart_service "n8n"
                    ;;
            esac
        done
        
        # Отправка алерта
        send_alert "WARNING" "Система в состоянии $overall_status. Проблемы: ${issues[*]}"
    else
        log_message "INFO" "Все сервисы работают нормально"
    fi
    
    return 0
}

# Функция мониторинга ресурсов
monitor_resources() {
    log_message "INFO" "Мониторинг использования ресурсов"
    
    # Получение статистики контейнеров
    local stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep "n8n-ai-starter-kit")
    
    if [ -n "$stats" ]; then
        log_message "INFO" "Статистика ресурсов:"
        echo "$stats" | while read line; do
            log_message "INFO" "  $line"
        done
    fi
    
    # Проверка использования диска
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 85 ]; then
        send_alert "WARNING" "Высокое использование диска: ${disk_usage}%"
    fi
}

# Функция очистки старых логов
cleanup_logs() {
    local max_lines=1000
    
    if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt $max_lines ]; then
        tail -n $max_lines "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log_message "INFO" "Логи очищены (оставлено последние $max_lines строк)"
    fi
    
    if [ -f "$ALERT_FILE" ] && [ $(wc -l < "$ALERT_FILE") -gt $max_lines ]; then
        tail -n $max_lines "$ALERT_FILE" > "${ALERT_FILE}.tmp"
        mv "${ALERT_FILE}.tmp" "$ALERT_FILE"
        log_message "INFO" "Логи алертов очищены"
    fi
}

# Функция отображения статистики
show_stats() {
    echo "======================================"
    echo "$SCRIPT_NAME - Статистика"
    echo "======================================"
    echo ""
    
    if [ -f "$LOG_FILE" ]; then
        echo "📊 Последние события:"
        tail -n 10 "$LOG_FILE"
        echo ""
    fi
    
    if [ -f "$ALERT_FILE" ]; then
        echo "🚨 Последние алерты:"
        tail -n 5 "$ALERT_FILE"
        echo ""
    fi
    
    echo "🔧 Статус сервисов:"
    health_check
    echo ""
    
    monitor_resources
}

# Основная функция
main() {
    case "${1:-monitor}" in
        "monitor")
            log_message "INFO" "Запуск мониторинга ($SCRIPT_NAME)"
            while true; do
                health_check
                monitor_resources
                cleanup_logs
                sleep $CHECK_INTERVAL
            done
            ;;
        "check")
            health_check
            ;;
        "stats")
            show_stats
            ;;
        "restart-postgres")
            restart_service "postgres"
            ;;
        "restart-n8n")
            restart_service "n8n"
            ;;
        "restart-all")
            restart_service "postgres"
            sleep 10
            restart_service "n8n"
            ;;
        *)
            echo "Использование: $0 [monitor|check|stats|restart-postgres|restart-n8n|restart-all]"
            echo ""
            echo "Команды:"
            echo "  monitor          - Непрерывный мониторинг (по умолчанию)"
            echo "  check            - Однократная проверка здоровья"
            echo "  stats            - Показать статистику и состояние"
            echo "  restart-postgres - Перезапустить PostgreSQL"
            echo "  restart-n8n      - Перезапустить N8N"
            echo "  restart-all      - Перезапустить все сервисы"
            echo ""
            exit 1
            ;;
    esac
}

# Обработка сигналов для graceful shutdown
trap 'log_message "INFO" "Получен сигнал завершения, останавливаем мониторинг"; exit 0' SIGTERM SIGINT

# Запуск
main "$@"
