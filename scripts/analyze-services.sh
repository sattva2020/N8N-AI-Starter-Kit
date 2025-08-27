#!/bin/bash

# N8N AI Starter Kit - Service Dependency Analyzer
# Анализатор зависимостей и необходимости сервисов

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Логирование
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_question() {
    echo -e "${CYAN}[?]${NC} $1"
}

# Проверка конфигурационных файлов
analyze_config_files() {
    echo "=============================================="
    echo "📋 АНАЛИЗ КОНФИГУРАЦИОННЫХ ФАЙЛОВ"
    echo "=============================================="
    
    # Анализ docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        log_info "Анализ основного docker-compose.yml..."
        
        # Проверка наличия сервисов
        local services=$(grep -E "^  [a-zA-Z0-9_-]+:" docker-compose.yml | sed 's/://g' | sed 's/^  //')
        
        echo "Обнаруженные сервисы:"
        for service in $services; do
            echo "  - $service"
        done
        
        # Проверка зависимостей между сервисами
        echo
        log_info "Анализ зависимостей между сервисами..."
        
        if grep -q "depends_on:" docker-compose.yml; then
            echo "Явные зависимости:"
            grep -A 5 "depends_on:" docker-compose.yml | grep -E "^\s*-" | sed 's/^.*- /  /'
        fi
    fi
    
    # Анализ дополнительных compose файлов
    echo
    log_info "Анализ дополнительных compose файлов..."
    
    for compose_file in compose/*.yml; do
        if [[ -f "$compose_file" ]]; then
            local filename=$(basename "$compose_file")
            local services=$(grep -E "^  [a-zA-Z0-9_-]+:" "$compose_file" 2>/dev/null | wc -l || echo "0")
            echo "  - $filename: $services сервисов"
        fi
    done
}

# Анализ переменных окружения
analyze_environment() {
    echo
    echo "=============================================="
    echo "🔧 АНАЛИЗ ПЕРЕМЕННЫХ ОКРУЖЕНИЯ"
    echo "=============================================="
    
    if [[ -f ".env" ]]; then
        log_info "Анализ .env файла..."
        
        # Поиск упоминаний сервисов
        echo "Настройки для сервисов:"
        
        if grep -q "QDRANT" .env; then
            echo "  ✓ Qdrant: настроен"
        else
            echo "  ✗ Qdrant: не настроен"
        fi
        
        if grep -q "SUPABASE" .env; then
            echo "  ✓ Supabase: настроен"
        else
            echo "  ✗ Supabase: не настроен"
        fi
        
        if grep -q "OLLAMA" .env; then
            echo "  ✓ Ollama: настроен"
        else
            echo "  ✗ Ollama: не настроен"
        fi
        
            # MinIO is optional; presence in .env is not required for default deployment
    else
        log_warning ".env файл не найден"
    fi
}

# Анализ workflows
analyze_workflows() {
    echo
    echo "=============================================="
    echo "📊 АНАЛИЗ N8N WORKFLOWS"
    echo "=============================================="
    
    local workflow_dir="data/n8n-workflows"
    
    if [[ -d "$workflow_dir" ]] && [[ "$(ls -A $workflow_dir 2>/dev/null)" ]]; then
        log_info "Анализ существующих workflows..."
        
        local workflow_files=$(find "$workflow_dir" -name "*.json" 2>/dev/null | wc -l)
        echo "Найдено workflow файлов: $workflow_files"
        
        if (( workflow_files > 0 )); then
            echo
            echo "Анализ использования сервисов в workflows:"
            
            # Поиск упоминаний AI сервисов
            local ai_usage=$(find "$workflow_dir" -name "*.json" -exec grep -l -i "ollama\|openai\|anthropic\|gpt\|llama" {} \; 2>/dev/null | wc -l)
            echo "  - AI сервисы (Ollama/OpenAI): $ai_usage workflows"
            
            # Поиск упоминаний векторных БД
            local vector_usage=$(find "$workflow_dir" -name "*.json" -exec grep -l -i "qdrant\|pinecone\|weaviate\|vector" {} \; 2>/dev/null | wc -l)
            echo "  - Векторные БД (Qdrant): $vector_usage workflows"
            
            # Поиск упоминаний Supabase
            local supabase_usage=$(find "$workflow_dir" -name "*.json" -exec grep -l -i "supabase" {} \; 2>/dev/null | wc -l)
            echo "  - Supabase: $supabase_usage workflows"
        fi
    else
        log_info "Workflows не найдены или папка пуста"
    fi
}

# Анализ системных ресурсов
analyze_system_resources() {
    echo
    echo "=============================================="
    echo "💻 АНАЛИЗ СИСТЕМНЫХ РЕСУРСОВ"
    echo "=============================================="
    
    # RAM
    local ram_total_gb=$(free -g | awk '/^Mem:/{print $2}')
    local ram_available_gb=$(free -g | awk '/^Mem:/{print $7}')
    echo "Память:"
    echo "  - Всего: ${ram_total_gb}GB"
    echo "  - Доступно: ${ram_available_gb}GB"
    
    # Рекомендации по памяти
    if (( ram_total_gb >= 16 )); then
        log_success "Достаточно памяти для всех сервисов"
    elif (( ram_total_gb >= 8 )); then
        log_warning "Память ограничена. Рекомендуется выборочное включение AI сервисов"
    else
        log_error "Мало памяти. Рекомендуется только базовые сервисы"
    fi
    
    # CPU
    local cpu_cores=$(nproc)
    echo "Процессор:"
    echo "  - Ядер: $cpu_cores"
    
    if (( cpu_cores >= 8 )); then
        log_success "Достаточно CPU для всех сервисов включая AI"
    elif (( cpu_cores >= 4 )); then
        log_warning "CPU ограничен. AI сервисы могут работать медленно"
    else
        log_warning "Мало CPU ядер. Рекомендуется только базовые сервисы"
    fi
    
    # Диск
    local disk_available_gb=$(df -BG . | awk 'NR==2{sub(/G/, "", $4); print $4}')
    echo "Диск:"
    echo "  - Доступно: ${disk_available_gb}GB"
    
    if (( disk_available_gb >= 50 )); then
        log_success "Достаточно места для всех сервисов и моделей"
    elif (( disk_available_gb >= 20 )); then
        log_warning "Место ограничено. Выборочная загрузка AI моделей"
    else
        log_error "Мало места на диске. Только базовые сервисы"
    fi
}

# Интерактивный опрос пользователя
interactive_survey() {
    echo
    echo "=============================================="
    echo "❓ ИНТЕРАКТИВНЫЙ ОПРОС"
    echo "=============================================="
    
    local answers=()
    
    echo "Ответьте на вопросы для определения оптимальной конфигурации:"
    echo
    
    # Вопрос 1: Тип использования
    log_question "1. Основная цель использования N8N?"
    echo "   a) Автоматизация бизнес-процессов без AI"
    echo "   b) Обработка данных с элементами AI"
    echo "   c) Активная работа с AI и машинным обучением"
    read -p "Выберите (a/b/c): " usage_type
    answers+=("usage_type:$usage_type")
    
    # Вопрос 2: AI функциональность
    log_question "2. Планируете использовать AI функции?"
    echo "   a) Нет, только обычная автоматизация"
    echo "   b) Да, через внешние API (OpenAI, Anthropic)"
    echo "   c) Да, локальные модели (Ollama)"
    echo "   d) Оба варианта (API + локальные)"
    read -p "Выберите (a/b/c/d): " ai_usage
    answers+=("ai_usage:$ai_usage")
    
    # Вопрос 3: Векторные операции
    log_question "3. Нужна работа с векторными данными (embeddings, semantic search)?"
    echo "   a) Нет"
    echo "   b) Да, планирую использовать"
    echo "   c) Не уверен"
    read -p "Выберите (a/b/c): " vector_usage
    answers+=("vector_usage:$vector_usage")
    
    # Вопрос 4: Дополнительные БД
    log_question "4. Нужны дополнительные БД кроме PostgreSQL?"
    echo "   a) Нет, PostgreSQL достаточно"
    echo "   b) Да, планирую использовать Supabase"
    echo "   c) Не уверен в требованиях"
    read -p "Выберите (a/b/c): " db_usage
    answers+=("db_usage:$db_usage")
    
    # Вопрос 5: Нагрузка
    log_question "5. Ожидаемая нагрузка?"
    echo "   a) Низкая (development/testing)"
    echo "   b) Средняя (small production)"
    echo "   c) Высокая (enterprise)"
    read -p "Выберите (a/b/c): " load_level
    answers+=("load_level:$load_level")
    
    echo "${answers[@]}"
}

# Генерация рекомендаций
generate_recommendations() {
    local answers=("$@")
    
    echo
    echo "=============================================="
    echo "💡 РЕКОМЕНДАЦИИ ПО КОНФИГУРАЦИИ"
    echo "=============================================="
    
    # Парсинг ответов
    local usage_type=""
    local ai_usage=""
    local vector_usage=""
    local db_usage=""
    local load_level=""
    
    for answer in "${answers[@]}"; do
        case $answer in
            usage_type:*) usage_type="${answer#*:}" ;;
            ai_usage:*) ai_usage="${answer#*:}" ;;
            vector_usage:*) vector_usage="${answer#*:}" ;;
            db_usage:*) db_usage="${answer#*:}" ;;
            load_level:*) load_level="${answer#*:}" ;;
        esac
    done
    
    # Анализ системных ресурсов
    local ram_total_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    
    echo "📋 РЕКОМЕНДУЕМАЯ КОНФИГУРАЦИЯ:"
    echo
    
    # Базовые сервисы (всегда нужны)
    log_success "Базовые сервисы (обязательно):"
    echo "  ✓ N8N - основная платформа автоматизации"
    echo "  ✓ PostgreSQL - основная база данных"
    echo "  ✓ Traefik - reverse proxy"
    
    # Qdrant
    echo
    if [[ "$ai_usage" =~ ^[cd]$ ]] || [[ "$vector_usage" == "b" ]]; then
        log_success "Qdrant (рекомендуется):"
        echo "  ✓ Необходим для векторных операций и AI"
        echo "  ✓ Semantic search, embeddings, RAG"
        
        if (( ram_total_gb < 8 )); then
            log_warning "  ⚠ Может потребовать настройки лимитов памяти"
        fi
    else
        log_info "Qdrant (опционально):"
        echo "  ○ Не требуется для текущих задач"
        echo "  ○ Можно добавить позже при необходимости"
    fi
    
    # Ollama
    echo
    if [[ "$ai_usage" =~ ^[cd]$ ]]; then
        if (( ram_total_gb >= 8 && cpu_cores >= 4 )); then
            log_success "Ollama (рекомендуется):"
            echo "  ✓ Локальные AI модели"
            echo "  ✓ Достаточно ресурсов для работы"
            
            if (( ram_total_gb >= 16 )); then
                echo "  ✓ Можно использовать большие модели (7B+)"
            else
                echo "  ⚠ Рекомендуются компактные модели (1-3B)"
            fi
        elif (( ram_total_gb >= 4 && cpu_cores >= 2 )); then
            log_warning "Ollama (тестовый режим):"
            echo "  ⚠ Ограниченные ресурсы - только для тестирования"
            echo "  ✓ Профиль test-ai с лимитом 4GB памяти"
            echo "  ⚠ Только компактные модели (phi-3-mini, llama3.2:1b)"
        else
            log_warning "Ollama (ограниченно):"
            echo "  ⚠ Недостаточно ресурсов для эффективной работы"
            echo "  ⚠ Рекомендуется использовать внешние AI API"
        fi
    else
        log_info "Ollama (не требуется):"
        echo "  ○ Локальные AI модели не планируются"
        echo "  ○ Экономия ресурсов"
    fi
    
    # Supabase
    echo
    if [[ "$db_usage" == "b" ]]; then
        log_warning "Supabase (опционально):"
        echo "  ○ Дополнительные функции БД"
        echo "  ○ Auth, Storage, Realtime"
        echo "  ⚠ Увеличивает потребление ресурсов"
    else
        log_info "Supabase (не требуется):"
        echo "  ○ PostgreSQL достаточно для основных задач"
        echo "  ○ Упрощение архитектуры"
    fi
    
    # Итоговые команды запуска
    echo
    echo "🚀 КОМАНДЫ ДЛЯ ЗАПУСКА:"
    echo
    
    if [[ "$usage_type" == "a" ]] && [[ "$ai_usage" == "a" ]]; then
        log_success "Минимальная конфигурация:"
        echo "  docker compose --profile default up -d n8n postgres traefik"
        
    elif [[ "$ai_usage" =~ ^[cd]$ ]] && (( ram_total_gb >= 8 )); then
        log_success "Полная AI конфигурация:"
        echo "  docker compose --profile default --profile cpu up -d"
        
    elif [[ "$ai_usage" =~ ^[cd]$ ]] && (( ram_total_gb >= 4 && ram_total_gb < 8 )); then
        log_warning "Тестовая AI конфигурация:"
        echo "  docker compose --profile default --profile test-ai up -d"
        echo "  # Ограниченные ресурсы - только для тестирования AI"
        
    else
        log_success "Стандартная конфигурация:"
        echo "  docker compose --profile default up -d"
        
        if [[ "$vector_usage" == "b" ]]; then
            echo "  # Добавить Qdrant:"
            echo "  docker compose up -d qdrant"
        fi
    fi
    
    # Дополнительные рекомендации
    echo
    echo "📚 ДОПОЛНИТЕЛЬНЫЕ РЕКОМЕНДАЦИИ:"
    echo
    
    if (( ram_total_gb < 8 && ram_total_gb >= 4 )); then
        log_warning "Системная оптимизация для ограниченных ресурсов:"
        echo "  - Используйте профиль test-ai для тестирования AI"
        echo "  - Настройте swap для стабильности"
        echo "  - Мониторьте использование памяти"
        echo "  - Загружайте только компактные модели (phi-3-mini, llama3.2:1b)"
        echo "  - Рассмотрите увеличение RAM до 8GB+ для production"
    elif (( ram_total_gb < 4 )); then
        log_warning "Критично мало ресурсов:"
        echo "  - Пока не используйте AI сервисы"
        echo "  - Настройте swap для стабильности"
        echo "  - Мониторьте использование памяти"
        echo "  - Рассмотрите увеличение RAM до 8GB+"
    fi
    
    if [[ "$load_level" == "c" ]]; then
        log_info "Production оптимизация:"
        echo "  - Настройте мониторинг ресурсов"
        echo "  - Используйте внешние БД для высокой нагрузки"
        echo "  - Рассмотрите горизонтальное масштабирование"
    fi
    
    log_info "Тестирование:"
    echo "  - Начните с минимальной конфигурации"
    echo "  - Добавляйте сервисы постепенно"
    echo "  - Для AI: сначала test-ai профиль, потом cpu профиль"
    echo "  - Используйте ./scripts/ubuntu-vm-deploy.sh для автоматизации"
}

# Создание конфигурационных файлов
create_config_files() {
    local answers=("$@")
    
    echo
    echo "=============================================="
    echo "📝 СОЗДАНИЕ КОНФИГУРАЦИОННЫХ ФАЙЛОВ"
    echo "=============================================="
    
    # Создание docker-compose.override.yml на основе рекомендаций
    local has_ai=false
    local has_vector=false
    
    for answer in "${answers[@]}"; do
        case $answer in
            ai_usage:[cd]) has_ai=true ;;
            vector_usage:b) has_vector=true ;;
        esac
    done
    
    # Создание файла быстрого запуска
    cat > quick-start.sh << 'EOF'
#!/bin/bash

# Quick Start Script - Generated by Service Analyzer
# Быстрый запуск рекомендуемой конфигурации

set -e

echo "🚀 Запуск рекомендуемой конфигурации..."

# Определение профилей на основе анализа
PROFILES="default"

EOF
    
    # Проверка системных ресурсов для AI
    local ram_total_gb=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
    
    if [[ "$has_ai" == true ]]; then
        if (( ram_total_gb >= 8 )); then
            echo 'PROFILES="$PROFILES cpu"' >> quick-start.sh
            echo 'echo "✓ Полная AI конфигурация (8GB+ RAM)"' >> quick-start.sh
        elif (( ram_total_gb >= 4 )); then
            echo 'PROFILES="$PROFILES test-ai"' >> quick-start.sh
            echo 'echo "⚠ Тестовая AI конфигурация (ограниченные ресурсы)"' >> quick-start.sh
        else
            echo 'echo "❌ Недостаточно RAM для AI сервисов"' >> quick-start.sh
        fi
    fi
    
    if [[ "$has_vector" == true ]]; then
        echo '# Добавляем Qdrant если есть ресурсы' >> quick-start.sh
        echo 'if [[ $(free -g | awk "/^Mem:/{print \$2}") -ge 6 ]]; then' >> quick-start.sh
        echo '    echo "✓ Добавление Qdrant"' >> quick-start.sh
        echo '    docker compose up -d qdrant' >> quick-start.sh
        echo 'else' >> quick-start.sh
        echo '    echo "⚠ Недостаточно памяти для Qdrant, пропускаем"' >> quick-start.sh
        echo 'fi' >> quick-start.sh
    fi
    
    cat >> quick-start.sh << 'EOF'

# Запуск сервисов
echo "Запуск профилей: $PROFILES"
docker compose --profile $PROFILES up -d

# Ожидание готовности
echo "Ожидание готовности сервисов..."
sleep 30

# Проверка статуса
docker compose ps

echo "✅ Сервисы запущены!"
echo "🌐 N8N доступен по адресу: http://$(hostname -I | awk '{print $1}'):5678"
EOF
    
    chmod +x quick-start.sh
    
    log_success "Создан скрипт быстрого запуска: quick-start.sh"
}

# Основная функция
main() {
    echo "=============================================="
    echo "🔍 N8N AI STARTER KIT - АНАЛИЗ СЕРВИСОВ"
    echo "=============================================="
    echo
    
    # Проверка наличия проекта
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml не найден. Запустите скрипт из корневой папки проекта."
        exit 1
    fi
    
    # Выполнение анализа
    analyze_config_files
    analyze_environment
    analyze_workflows
    analyze_system_resources
    
    # Интерактивный опрос
    local answers=$(interactive_survey)
    
    # Генерация рекомендаций
    generate_recommendations $answers
    
    # Создание конфигураций
    create_config_files $answers
    
    echo
    echo "=============================================="
    echo "✅ АНАЛИЗ ЗАВЕРШЁН"
    echo "=============================================="
    echo
    log_success "Рекомендации сгенерированы на основе анализа системы и ваших ответов"
    log_info "Используйте ./quick-start.sh для запуска рекомендуемой конфигурации"
    log_info "Полная документация: docs/UBUNTU_VM_DEPLOYMENT.md"
}

# Запуск
main "$@"
