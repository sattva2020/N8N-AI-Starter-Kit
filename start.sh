#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\start.sh
# Интеллектуальный скрипт запуска N8N AI Starter Kit
# Версия: 1.0.6

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Интеллектуальный запуск N8N AI Starter Kit ===${NC}"

# Автоматическое определение оптимального профиля
detect_optimal_profile() {
    local memory=$(free -m 2>/dev/null | awk 'NR==2{printf "%.0f", $2/1024}' || echo "0")
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    
    echo -e "${BLUE}Анализ системы:${NC}"
    echo -e "  📊 Память: ${memory}GB"
    echo -e "  🖥️  CPU ядер: ${cpu_cores}"
    
    # Проверка GPU
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1 2>/dev/null || echo "Unknown")
        echo -e "  🎮 GPU: ${gpu_info}"
        echo -e "${GREEN}🚀 Рекомендуемый профиль: gpu-nvidia${NC}"
        echo "gpu-nvidia"
    elif [ "$memory" -gt 16 ] && [ "$cpu_cores" -gt 8 ]; then
        echo -e "${GREEN}🚀 Рекомендуемый профиль: developer${NC}"
        echo "developer"
    else
        echo -e "${GREEN}🚀 Рекомендуемый профиль: cpu${NC}"
        echo "cpu"
    fi
}

# Функция предварительной проверки
pre_flight_check() {
    echo -e "${BLUE}Предварительная проверка...${NC}"
    
    local issues=0
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        echo -e "  ${RED}❌ Docker не найден${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}✅ Docker найден${NC}"
    fi
    
    # Проверка Docker Compose
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo -e "  ${RED}❌ Docker Compose не найден${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}✅ Docker Compose найден${NC}"
    fi
    
    # Проверка .env файла
    if [ ! -f .env ]; then
        echo -e "  ${YELLOW}⚠️ Файл .env не найден${NC}"
        
        # Попытка создать .env из template.env
        if [ -f "template.env" ]; then
            echo -e "  ${BLUE}📋 Создание .env из template.env...${NC}"
            cp "template.env" ".env"
            echo -e "  ${GREEN}✅ Файл .env создан из шаблона${NC}"
        elif [ -f "scripts/template.env" ]; then
            echo -e "  ${BLUE}📋 Создание .env из scripts/template.env...${NC}"
            cp "scripts/template.env" ".env"
            echo -e "  ${GREEN}✅ Файл .env создан из шаблона${NC}"
        else
            echo -e "  ${RED}❌ Шаблон .env не найден${NC}"
            echo -e "  ${YELLOW}   Создайте файл .env или запустите: ./scripts/setup.sh${NC}"
            ((issues++))
        fi
    else
        echo -e "  ${GREEN}✅ Файл .env найден${NC}"
    fi
    
    # Проверка конфигурации Docker Compose
    if ! docker compose config &>/dev/null; then
        echo -e "  ${RED}❌ Ошибки в конфигурации Docker Compose${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}✅ Конфигурация Docker Compose корректна${NC}"
    fi
    
    return $issues
}

# Функция для генерации безопасного пароля
generate_password() {
    local length=${1:-24}
    openssl rand -base64 $length 2>/dev/null | tr -d '=/+' | cut -c1-$length || \
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1 2>/dev/null || \
    echo "$(date +%s)_$(whoami)_$(hostname)" | sha256sum | cut -c1-$length
}

# Функция автоматического исправления проблем
auto_fix_issues() {
    echo -e "${YELLOW}Попытка автоматического исправления проблем...${NC}"
    
    # Создание .env файла если отсутствует
    if [ ! -f .env ]; then
        echo -e "  📋 Создание файла .env..."
        if [ -f "template.env" ]; then
            cp "template.env" ".env"
            echo -e "  ${GREEN}✅ Файл .env создан из template.env${NC}"
            
            # Замена placeholder'ов на безопасные значения
            echo -e "  🔐 Генерация безопасных паролей..."
            sed -i "s/change_this_secure_password_123/$(generate_password 16)/g" .env
            sed -i "s/your_32_char_encryption_key_here_/$(generate_password 32)/g" .env
            sed -i "s/your_jwt_secret_key_here_min_32_chars/$(generate_password 32)/g" .env
            sed -i "s/supabase_secure_password_123/$(generate_password 16)/g" .env
            sed -i "s/your_supabase_jwt_secret_32_chars_min/$(generate_password 32)/g" .env
            sed -i "s/minio_secure_password_123/$(generate_password 16)/g" .env
            sed -i "s/pgadmin_secure_password_123/$(generate_password 16)/g" .env
            sed -i "s/zep_secure_password_123/$(generate_password 16)/g" .env
            
            echo -e "  ${GREEN}✅ Безопасные пароли сгенерированы${NC}"
        elif [ -f "scripts/template.env" ]; then
            cp "scripts/template.env" ".env"
            echo -e "  ${GREEN}✅ Файл .env создан из scripts/template.env${NC}"
        else
            echo -e "  ${RED}❌ Шаблон .env не найден${NC}"
        fi
    fi
    
    # Исправление переменных окружения
    if [ -f ./scripts/fix-env-vars.sh ]; then
        echo -e "  🔧 Исправление переменных окружения..."
        chmod +x ./scripts/fix-env-vars.sh
        ./scripts/fix-env-vars.sh
    fi
    
    # Диагностика системы
    if [ -f ./scripts/diagnose.sh ]; then
        echo -e "  🔍 Запуск диагностики..."
        chmod +x ./scripts/diagnose.sh
        ./scripts/diagnose.sh | grep -E "(❌|⚠️)"
    fi
}

# Основная логика запуска
PROFILE=${1:-$(detect_optimal_profile)}
echo ""
echo -e "${BLUE}Выбранный профиль: ${YELLOW}$PROFILE${NC}"

# Предварительная проверка
echo ""
if ! pre_flight_check; then
    echo -e "${YELLOW}Обнаружены проблемы. Попытка исправления...${NC}"
    auto_fix_issues
    
    echo ""
    echo -e "${BLUE}Повторная проверка...${NC}"
    if ! pre_flight_check; then
        echo -e "${RED}❌ Критические проблемы не исправлены.${NC}"
        echo -e "${YELLOW}Запустите ./scripts/diagnose.sh для детальной диагностики${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Все проверки пройдены! Запуск системы...${NC}"

# Запуск с оптимальными настройками
echo -e "${BLUE}Команда запуска:${NC} COMPOSE_PARALLEL_LIMIT=1 docker compose --profile $PROFILE up -d"
COMPOSE_PARALLEL_LIMIT=1 docker compose --profile $PROFILE up -d

# Проверка результата запуска
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 Система успешно запущена!${NC}"
    echo ""
    echo -e "${BLUE}Полезные команды:${NC}"
    echo -e "  📊 Мониторинг: ${YELLOW}./scripts/monitor.sh${NC}"
    echo -e "  📋 Статус: ${YELLOW}docker ps${NC}"
    echo -e "  📝 Логи: ${YELLOW}docker logs n8n-ai-starter-kit-n8n-1${NC}"
    echo -e "  🛑 Остановка: ${YELLOW}docker compose down${NC}"
    echo ""
    echo -e "${BLUE}Доступ к сервисам:${NC}"
    echo -e "  🌐 N8N: ${YELLOW}http://localhost:5678${NC}"
    echo -e "  🔍 Qdrant: ${YELLOW}http://localhost:6333/dashboard${NC}"
    echo -e "  🤖 Ollama: ${YELLOW}http://localhost:11434${NC}"
    echo -e "  🚦 Traefik: ${YELLOW}http://localhost:8080${NC}"
else
    echo ""
    echo -e "${RED}❌ Ошибка при запуске системы${NC}"
    echo -e "${YELLOW}Запустите для диагностики: ./scripts/diagnose.sh${NC}"
    exit 1
fi