#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\start.sh
# Интеллектуальный скрипт запуска N8N AI Starter Kit
# Версия: 1.0.7

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
        ((issues++))
    else
        echo -e "  ${GREEN}✅ Файл .env найден${NC}"
        
        # Проверка ключевых переменных в .env
        if ! grep -q "OPENAI_API_KEY" .env || grep -q "^# OPENAI_API_KEY=" .env; then
            echo -e "  ${YELLOW}⚠️ OpenAI API key не настроен${NC}"
        else
            echo -e "  ${GREEN}✅ OpenAI API key настроен${NC}"
        fi
        
        if ! grep -q "N8N_ENCRYPTION_KEY" .env; then
            echo -e "  ${YELLOW}⚠️ N8N encryption key не найден${NC}"
            ((issues++))
        else
            echo -e "  ${GREEN}✅ N8N encryption key найден${NC}"
        fi
        
        # Проверка на проблемные символы в .env
        if grep -q '\$[^{]' .env; then
            echo -e "  ${YELLOW}⚠️ Найдены неэкранированные символы $ в .env${NC}"
            ((issues++))
        fi
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

# Функция для запуска setup.sh
run_setup() {
    echo -e "${BLUE}🔧 Запуск мастера настройки...${NC}"
    echo ""
    
    if [ -f "./scripts/setup.sh" ]; then
        chmod +x ./scripts/setup.sh
        echo -e "${CYAN}Запускается ./scripts/setup.sh...${NC}"
        ./scripts/setup.sh
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Настройка завершена успешно!${NC}"
            return 0
        else
            echo -e "${RED}❌ Ошибка при настройке${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Файл ./scripts/setup.sh не найден${NC}"
        echo -e "${YELLOW}Создайте файл .env вручную или убедитесь, что setup.sh находится в директории scripts/${NC}"
        return 1
    fi
}

# Функция для генерации безопасного пароля
generate_password() {
    local length=${1:-24}
    openssl rand -base64 $length 2>/dev/null | tr -d '=/+' | cut -c1-$length || \
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1 2>/dev/null || \
    echo "$(date +%s)_$(whoami)_$(hostname)" | sha256sum | cut -c1-$length
}

# Функция автоматического исправления проблем (быстрые исправления)
auto_fix_issues() {
    echo -e "${YELLOW}Попытка автоматического исправления проблем...${NC}"
    
    # Создание .env файла если отсутствует
    if [ ! -f .env ]; then
        echo -e "  📋 Попытка создания файла .env из шаблона..."
        if [ -f "template.env" ]; then
            cp "template.env" ".env"
            echo -e "  ${GREEN}✅ Файл .env создан из template.env${NC}"
            
            # Замена placeholder'ов на безопасные значения
            echo -e "  🔐 Генерация безопасных паролей..."
            sed -i "s/change_this_secure_password_123/$(generate_password 16)/g" .env 2>/dev/null
            sed -i "s/your_32_char_encryption_key_here_/$(generate_password 32)/g" .env 2>/dev/null
            sed -i "s/your_jwt_secret_key_here_min_32_chars/$(generate_password 32)/g" .env 2>/dev/null
            sed -i "s/supabase_secure_password_123/$(generate_password 16)/g" .env 2>/dev/null
            sed -i "s/your_supabase_jwt_secret_32_chars_min/$(generate_password 32)/g" .env 2>/dev/null
            sed -i "s/minio_secure_password_123/$(generate_password 16)/g" .env 2>/dev/null
            sed -i "s/pgadmin_secure_password_123/$(generate_password 16)/g" .env 2>/dev/null
            sed -i "s/zep_secure_password_123/$(generate_password 16)/g" .env 2>/dev/null
            sed -i "s/your_openai_api_key_here//g" .env 2>/dev/null
            
            echo -e "  ${GREEN}✅ Безопасные пароли сгенерированы${NC}"
        elif [ -f "scripts/template.env" ]; then
            cp "scripts/template.env" ".env"
            echo -e "  ${GREEN}✅ Файл .env создан из scripts/template.env${NC}"
        else
            echo -e "  ${RED}❌ Шаблон .env не найден${NC}"
            echo -e "  ${YELLOW}   Необходимо запустить полную настройку${NC}"
            return 1
        fi
    fi
    
    # Исправление переменных окружения
    if [ -f ./scripts/fix-env-vars.sh ]; then
        echo -e "  🔧 Исправление переменных окружения..."
        chmod +x ./scripts/fix-env-vars.sh
        ./scripts/fix-env-vars.sh > /dev/null 2>&1
    fi
    
    # Исправление проблем с хэшем пароля
    if [ -f .env ] && grep -q '\$[^{]' .env; then
        echo -e "  🔧 Исправление хэша пароля Traefik..."
        # Убираем лишние символы $ из хэша пароля
        sed -i 's/\$\$\$/$/g' .env 2>/dev/null || true
        sed -i 's/\$\$/$/g' .env 2>/dev/null || true
    fi
    
    # Добавление отсутствующих переменных
    if [ -f .env ] && ! grep -q "WEBHOOK_URL" .env; then
        echo -e "  📝 Добавление отсутствующих переменных..."
        echo "WEBHOOK_URL=" >> .env
    fi
    
    return 0
}

# Функция для проверки критических компонентов
check_critical_components() {
    local critical_issues=0
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker не установлен${NC}"
        ((critical_issues++))
    elif ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker демон не запущен${NC}"
        ((critical_issues++))
    fi
    
    # Проверка Docker Compose
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose не установлен${NC}"
        ((critical_issues++))
    fi
    
    return $critical_issues
}

# Основная логика запуска
PROFILE=${1:-$(detect_optimal_profile)}
echo ""
echo -e "${BLUE}Выбранный профиль: ${YELLOW}$PROFILE${NC}"

# Проверка критических компонентов
echo ""
if ! check_critical_components; then
    echo ""
    echo -e "${RED}🚨 Обнаружены критические проблемы с Docker/Docker Compose${NC}"
    echo -e "${YELLOW}Необходимо запустить полную настройку для установки зависимостей${NC}"
    echo ""
    echo -e "${CYAN}Запустить мастер настройки? (y/n): ${NC}"
    read -r setup_choice
    
    if [[ "$setup_choice" =~ ^[Yy]$ ]]; then
        if ! run_setup; then
            echo -e "${RED}❌ Настройка не завершена. Завершение работы.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Установите Docker и Docker Compose, затем повторите запуск${NC}"
        exit 1
    fi
fi

# Предварительная проверка
echo ""
if ! pre_flight_check; then
    echo ""
    echo -e "${YELLOW}Обнаружены проблемы с конфигурацией${NC}"
    echo ""
    echo -e "${CYAN}Выберите действие:${NC}"
    echo -e "  ${CYAN}1)${NC} Попробовать быстрое исправление"
    echo -e "  ${CYAN}2)${NC} Запустить полную настройку (рекомендуется)"
    echo -e "  ${CYAN}3)${NC} Продолжить без исправлений (может привести к ошибкам)"
    echo ""
    echo -ne "${CYAN}Ваш выбор (1-3): ${NC}"
    read -r fix_choice
    
    case $fix_choice in
        1)
            echo -e "${YELLOW}Выполнение быстрого исправления...${NC}"
            if auto_fix_issues; then
                echo ""
                echo -e "${BLUE}Повторная проверка после исправления...${NC}"
                if ! pre_flight_check; then
                    echo -e "${YELLOW}Быстрое исправление не помогло. Рекомендуется полная настройка.${NC}"
                    echo -e "${CYAN}Запустить полную настройку? (y/n): ${NC}"
                    read -r full_setup_choice
                    if [[ "$full_setup_choice" =~ ^[Yy]$ ]]; then
                        if ! run_setup; then
                            echo -e "${RED}❌ Настройка не завершена. Завершение работы.${NC}"
                            exit 1
                        fi
                    else
                        echo -e "${YELLOW}Продолжение с текущей конфигурацией...${NC}"
                    fi
                fi
            else
                echo -e "${YELLOW}Быстрое исправление не удалось. Запуск полной настройки...${NC}"
                if ! run_setup; then
                    echo -e "${RED}❌ Настройка не завершена. Завершение работы.${NC}"
                    exit 1
                fi
            fi
            ;;
        2)
            if ! run_setup; then
                echo -e "${RED}❌ Настройка не завершена. Завершение работы.${NC}"
                exit 1
            fi
            ;;
        3)
            echo -e "${YELLOW}⚠️ Продолжение без исправлений. Возможны ошибки при запуске.${NC}"
            ;;
        *)
            echo -e "${YELLOW}Неверный выбор. Запуск полной настройки...${NC}"
            if ! run_setup; then
                echo -e "${RED}❌ Настройка не завершена. Завершение работы.${NC}"
                exit 1
            fi
            ;;
    esac
    
    # Финальная проверка перед запуском
    echo ""
    echo -e "${BLUE}Финальная проверка конфигурации...${NC}"
    if ! pre_flight_check; then
        echo -e "${RED}❌ Критические проблемы не исправлены.${NC}"
        echo -e "${YELLOW}Запустите ./scripts/diagnose.sh для детальной диагностики${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Все проверки пройдены! Запуск системы...${NC}"

# Определение команды Docker Compose
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Остановка существующих контейнеров
echo -e "${BLUE}Остановка существующих контейнеров...${NC}"
$DOCKER_COMPOSE_CMD down > /dev/null 2>&1

# Запуск с оптимальными настройками
echo -e "${BLUE}Команда запуска:${NC} COMPOSE_PARALLEL_LIMIT=1 $DOCKER_COMPOSE_CMD --profile $PROFILE up -d"
COMPOSE_PARALLEL_LIMIT=1 $DOCKER_COMPOSE_CMD --profile $PROFILE up -d

# Проверка результата запуска
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 Система успешно запущена!${NC}"
    echo ""
    echo -e "${BLUE}Полезные команды:${NC}"
    echo -e "  📊 Мониторинг: ${YELLOW}./scripts/monitor.sh${NC}"
    echo -e "  📋 Статус: ${YELLOW}docker ps${NC}"
    echo -e "  📝 Логи: ${YELLOW}docker logs n8n-ai-starter-kit-n8n-1${NC}"
    echo -e "  🛑 Остановка: ${YELLOW}$DOCKER_COMPOSE_CMD down${NC}"
    echo ""
    echo -e "${BLUE}Доступ к сервисам:${NC}"
    echo -e "  🌐 N8N: ${YELLOW}http://localhost:5678${NC}"
    echo -e "  🔍 Qdrant: ${YELLOW}http://localhost:6333/dashboard${NC}"
    echo -e "  🤖 Ollama: ${YELLOW}http://localhost:11434${NC}"
    echo -e "  🚦 Traefik: ${YELLOW}http://localhost:8080${NC}"
    
    # Проверка OpenAI API Key
    if [ -f .env ] && (grep -q "^# OPENAI_API_KEY=" .env || ! grep -q "OPENAI_API_KEY=" .env); then
        echo ""
        echo -e "${YELLOW}📝 Примечание: OpenAI API key не настроен${NC}"
        echo -e "   ${CYAN}Для использования OpenAI моделей добавьте ключ в файл .env${NC}"
        echo -e "   ${CYAN}или запустите: ./scripts/setup.sh для полной настройки${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Ошибка при запуске системы${NC}"
    echo -e "${YELLOW}Запустите для диагностики: ./scripts/diagnose.sh${NC}"
    echo -e "${YELLOW}Или запустите полную настройку: ./scripts/setup.sh${NC}"
    exit 1
fi