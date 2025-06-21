# filepath: e:\AI\n8n-ai-starter-kit\scripts\diagnose.sh
# Скрипт диагностики N8N AI Starter Kit
# Версия: 1.0.6

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Диагностика N8N AI Starter Kit ===${NC}"
echo ""

# 1. Проверка Docker
echo -e "${BLUE}1. Проверка Docker...${NC}"
if command -v docker &> /dev/null; then
    docker_version=$(docker --version)
    echo -e "   ${GREEN}✅ Docker найден: ${docker_version}${NC}"
    
    # Проверка статуса Docker daemon
    if docker info &> /dev/null; then
        echo -e "   ${GREEN}✅ Docker daemon запущен${NC}"
    else
        echo -e "   ${RED}❌ Docker daemon не запущен${NC}"
    fi
else
    echo -e "   ${RED}❌ Docker не найден${NC}"
fi

# 2. Проверка Docker Compose
echo -e "${BLUE}2. Проверка Docker Compose...${NC}"
if command -v docker-compose &> /dev/null; then
    compose_version=$(docker-compose --version)
    echo -e "   ${GREEN}✅ Docker Compose найден: ${compose_version}${NC}"
elif docker compose version &> /dev/null; then
    compose_version=$(docker compose version)
    echo -e "   ${GREEN}✅ Docker Compose (плагин) найден: ${compose_version}${NC}"
else
    echo -e "   ${RED}❌ Docker Compose не найден${NC}"
fi

# 3. Проверка конфигурации Docker Compose
echo -e "${BLUE}3. Проверка конфигурации Docker Compose...${NC}"
if docker compose config &>/dev/null; then
    echo -e "   ${GREEN}✅ Конфигурация корректна${NC}"
else
    echo -e "   ${RED}❌ Найдены ошибки в конфигурации${NC}"
    echo -e "   ${YELLOW}Детали ошибок:${NC}"
    docker compose config 2>&1 | head -10 | sed 's/^/      /'
fi

# 4. Проверка .env файла
echo -e "${BLUE}4. Проверка .env файла...${NC}"
if [ -f .env ]; then
    echo -e "   ${GREEN}✅ Файл .env найден${NC}"
    
    # Проверка на незакавыченные $
    if grep -q '\$[^{]' .env; then
        echo -e "   ${YELLOW}⚠️ Найдены неэкранированные символы $ в .env${NC}"
        echo -e "   ${YELLOW}   Рекомендуется запустить: ./scripts/fix-env-vars.sh${NC}"
    else
        echo -e "   ${GREEN}✅ Переменные окружения корректно экранированы${NC}"
    fi
    
    # Проверка обязательных переменных
    required_vars=("N8N_ENCRYPTION_KEY" "POSTGRES_PASSWORD" "TRAEFIK_PASSWORD_HASHED")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env; then
            echo -e "   ${GREEN}✅ ${var} установлена${NC}"
        else
            echo -e "   ${RED}❌ ${var} не найдена${NC}"
        fi
    done
else
    echo -e "   ${RED}❌ Файл .env не найден${NC}"
    echo -e "   ${YELLOW}   Запустите: ./scripts/setup.sh${NC}"
fi

# 5. Проверка портов
echo -e "${BLUE}5. Проверка занятых портов...${NC}"
ports_to_check=(80 443 5678 6333 11434 8080)
for port in "${ports_to_check[@]}"; do
    if command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "   ${YELLOW}⚠️ Порт $port уже используется${NC}"
        else
            echo -e "   ${GREEN}✅ Порт $port свободен${NC}"
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "   ${YELLOW}⚠️ Порт $port уже используется${NC}"
        else
            echo -e "   ${GREEN}✅ Порт $port свободен${NC}"
        fi
    else
        echo -e "   ${YELLOW}⚠️ Команды netstat/ss не найдены, проверка портов пропущена${NC}"
        break
    fi
done

# 6. Проверка доступности GPU
echo -e "${BLUE}6. Проверка GPU...${NC}"
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
        echo -e "   ${GREEN}✅ NVIDIA GPU найден: ${gpu_info}${NC}"
    else
        echo -e "   ${YELLOW}⚠️ nvidia-smi найден, но GPU недоступен${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️ NVIDIA GPU не обнаружен${NC}"
fi

# 7. Проверка дискового пространства
echo -e "${BLUE}7. Проверка дискового пространства...${NC}"
if command -v df &> /dev/null; then
    available_space=$(df . | awk 'NR==2 {print $4}')
    available_gb=$((available_space / 1024 / 1024))
    
    if [ "$available_gb" -gt 20 ]; then
        echo -e "   ${GREEN}✅ Доступно: ${available_gb}GB${NC}"
    elif [ "$available_gb" -gt 10 ]; then
        echo -e "   ${YELLOW}⚠️ Доступно: ${available_gb}GB (рекомендуется >20GB)${NC}"
    else
        echo -e "   ${RED}❌ Доступно: ${available_gb}GB (критически мало места)${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️ Не удалось проверить дисковое пространство${NC}"
fi

# 8. Проверка памяти
echo -e "${BLUE}8. Проверка памяти...${NC}"
if command -v free &> /dev/null; then
    total_memory=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
    
    if [ "$total_memory" -gt 16 ]; then
        echo -e "   ${GREEN}✅ Доступно: ${total_memory}GB (отлично для developer профиля)${NC}"
    elif [ "$total_memory" -gt 8 ]; then
        echo -e "   ${GREEN}✅ Доступно: ${total_memory}GB (хорошо для cpu профиля)${NC}"
    elif [ "$total_memory" -gt 4 ]; then
        echo -e "   ${YELLOW}⚠️ Доступно: ${total_memory}GB (минимально для работы)${NC}"
    else
        echo -e "   ${RED}❌ Доступно: ${total_memory}GB (недостаточно памяти)${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️ Не удалось проверить память${NC}"
fi

# 9. Проверка существующих контейнеров
echo -e "${BLUE}9. Проверка состояния контейнеров...${NC}"
if docker ps -a --filter "name=n8n-ai-starter-kit" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -q "n8n-ai-starter-kit"; then
    echo -e "   ${GREEN}✅ Найдены контейнеры проекта:${NC}"
    docker ps -a --filter "name=n8n-ai-starter-kit" --format "      {{.Names}}: {{.Status}}" 2>/dev/null
else
    echo -e "   ${YELLOW}⚠️ Контейнеры проекта не найдены${NC}"
fi

# 10. Рекомендации по оптимизации
echo ""
echo -e "${BLUE}=== Рекомендации ===${NC}"

# Определение оптимального профиля
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo -e "   ${GREEN}🚀 Рекомендуемый профиль: gpu-nvidia${NC}"
elif [ "${total_memory:-0}" -gt 16 ]; then
    echo -e "   ${GREEN}🚀 Рекомендуемый профиль: developer${NC}"
else
    echo -e "   ${GREEN}🚀 Рекомендуемый профиль: cpu${NC}"
fi

# Дополнительные рекомендации
if [ ! -f .env ]; then
    echo -e "   ${YELLOW}📋 Запустите установку: ./scripts/setup.sh${NC}"
fi

if grep -q '\$[^{]' .env 2>/dev/null; then
    echo -e "   ${YELLOW}🔧 Исправьте переменные: ./scripts/fix-env-vars.sh${NC}"
fi

echo ""
echo -e "${BLUE}Диагностика завершена!${NC}"