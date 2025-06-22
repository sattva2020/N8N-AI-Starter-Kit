#!/bin/bash

echo "=== Диагностика N8N AI Starter Kit ==="

# Проверка Docker
echo "1. Проверка Docker..."
if command -v docker &> /dev/null; then
    echo "✅ Docker найден: $(docker --version)"
    
    # Проверка запуска демона Docker
    if docker info &> /dev/null; then
        echo "✅ Docker демон запущен"
    else
        echo "❌ Docker демон не запущен или нет прав доступа"
        echo "   Попробуйте: sudo systemctl start docker"
        echo "   Или добавьте пользователя в группу: sudo usermod -aG docker $USER"
    fi
else
    echo "❌ Docker не найден"
fi

# Проверка Docker Compose
echo ""
echo "2. Проверка Docker Compose..."
if docker compose version &> /dev/null; then
    echo "✅ Docker Compose (новый формат) найден: $(docker compose version --short 2>/dev/null || echo 'версия неизвестна')"
elif command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose (старый формат) найден: $(docker-compose --version)"
else
    echo "❌ Docker Compose не найден"
fi

# Проверка конфигурации docker-compose
echo ""
echo "3. Проверка конфигурации docker-compose..."
if docker compose config &>/dev/null; then
    echo "✅ Конфигурация корректна"
else
    echo "❌ Найдены ошибки в конфигурации:"
    echo "--- Детали ошибок ---"
    docker compose config 2>&1 | head -20
    echo "--- Конец ошибок ---"
fi

# Проверка переменных окружения
echo ""
echo "4. Проверка .env файла..."
if [ -f .env ]; then
    echo "✅ Файл .env найден"
    
    # Проверка на проблемные символы
    if grep -q '\$[^{]' .env; then
        echo "⚠️ Найдены неэкранированные символы $ в .env"
        echo "Проблемные строки:"
        grep -n '\$[^{]' .env | head -5
    fi
    
    # Проверка ключевых переменных
    echo ""
    echo "Проверка ключевых переменных:"
    for var in "N8N_ENCRYPTION_KEY" "POSTGRES_PASSWORD" "TRAEFIK_PASSWORD_HASHED" "DOMAIN_NAME"; do
        if grep -q "^$var=" .env; then
            echo "✅ $var найден"
        else
            echo "❌ $var отсутствует или закомментирован"
        fi
    done
    
    # Проверка API ключей
    echo ""
    echo "Проверка API ключей:"
    if grep -q "^OPENAI_API_KEY=" .env && ! grep -q "^# OPENAI_API_KEY=" .env; then
        echo "✅ OpenAI API ключ настроен"
    else
        echo "⚠️ OpenAI API ключ не настроен"
    fi
    
    if grep -q "^ANTHROPIC_API_KEY=" .env && ! grep -q "^# ANTHROPIC_API_KEY=" .env; then
        echo "✅ Anthropic API ключ настроен"
    else
        echo "ℹ️ Anthropic API ключ не настроен (необязательно)"
    fi
else
    echo "❌ Файл .env не найден"
    echo "   Запустите: ./scripts/setup.sh для создания"
fi

# Проверка портов
echo ""
echo "5. Проверка доступности портов..."
for port in 5678 6333 8080 11434; do
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            echo "⚠️ Порт $port уже используется"
            # Показываем какой процесс использует порт
            ss -tulnp | grep ":$port " | head -1
        else
            echo "✅ Порт $port доступен"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            echo "⚠️ Порт $port уже используется"
        else
            echo "✅ Порт $port доступен"
        fi
    elif command -v lsof &> /dev/null; then
        if lsof -i :$port -sTCP:LISTEN &> /dev/null; then
            echo "⚠️ Порт $port уже используется"
        else
            echo "✅ Порт $port доступен"
        fi
    else
        echo "⚠️ Не удалось проверить порт $port (нет подходящих утилит)"
    fi
done

# Проверка системных ресурсов
echo ""
echo "6. Проверка системных ресурсов..."
if command -v free &> /dev/null; then
    memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    echo "Доступная память: ${memory_mb}MB"
    if [ "$memory_mb" -gt 8000 ]; then
        echo "✅ Достаточно памяти для всех профилей"
    elif [ "$memory_mb" -gt 4000 ]; then
        echo "⚠️ Рекомендуется использовать профиль cpu (4-8GB памяти)"
    else
        echo "❌ Недостаточно памяти (меньше 4GB). Возможны проблемы."
    fi
else
    echo "⚠️ Не удалось определить объем памяти"
fi

if command -v nproc &> /dev/null; then
    cpu_cores=$(nproc)
    echo "CPU ядер: $cpu_cores"
    if [ "$cpu_cores" -ge 4 ]; then
        echo "✅ Достаточно CPU ядер"
    elif [ "$cpu_cores" -ge 2 ]; then
        echo "⚠️ Минимальное количество CPU ядер (2-3)"
    else
        echo "❌ Недостаточно CPU ядер (меньше 2)"
    fi
else
    echo "⚠️ Не удалось определить количество CPU ядер"
fi

# Проверка дискового пространства
echo ""
echo "7. Проверка дискового пространства..."
if command -v df &> /dev/null; then
    available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    echo "Доступное место: ${available_gb}GB"
    if [ "$available_gb" -gt 10 ]; then
        echo "✅ Достаточно места на диске"
    elif [ "$available_gb" -gt 5 ]; then
        echo "⚠️ Ограниченное место на диске ($available_gb GB)"
    else
        echo "❌ Недостаточно места на диске (меньше 5GB)"
    fi
else
    echo "⚠️ Не удалось проверить дисковое пространство"
fi

# Проверка сети
echo ""
echo "8. Проверка сетевого подключения..."
if command -v curl &> /dev/null; then
    if curl -s --connect-timeout 5 https://registry.hub.docker.com/_ping > /dev/null; then
        echo "✅ Подключение к Docker Hub работает"
    else
        echo "❌ Нет подключения к Docker Hub"
    fi
    
    if curl -s --connect-timeout 5 https://api.github.com > /dev/null; then
        echo "✅ Подключение к GitHub работает"
    else
        echo "❌ Нет подключения к GitHub"
    fi
else
    echo "⚠️ curl не найден, проверка сети пропущена"
fi

# Проверка запущенных контейнеров
echo ""
echo "9. Проверка запущенных контейнеров..."
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    containers=$(docker ps --filter "label=com.docker.compose.project=n8n-ai-starter-kit" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null)
    if [ -n "$containers" ]; then
        echo "Запущенные контейнеры N8N AI Starter Kit:"
        echo "$containers"
    else
        echo "ℹ️ Контейнеры N8N AI Starter Kit не запущены"
    fi
else
    echo "⚠️ Не удалось проверить запущенные контейнеры"
fi

echo ""
echo "=== Диагностика завершена ==="
echo ""
echo "Рекомендации:"
echo "• Если есть ошибки конфигурации - запустите: ./scripts/setup.sh"
echo "• Если порты заняты - остановите конфликтующие сервисы"
echo "• Если нет API ключей - добавьте их в файл .env"
echo "• Для запуска системы используйте: ./start.sh"