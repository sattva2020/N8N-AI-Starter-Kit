#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\start.sh
# Интеллектуальный скрипт запуска N8N AI Starter Kit
# Версия: 1.0.7

# Документация флагов CLI (коротко):
#  --auto-import         Включить автоматический импорт workflows только для этой сессии
#                        (эквивалент N8N_AUTO_IMPORT=true во время выполнения). Скрипт
#                        не будет записывать это значение в .env — действие временно.
#  --no-import-prompt    Подавить все запросы об импорте workflows для этой сессии
#                        (эквивалент N8N_AUTO_IMPORT=false во время выполнения). Не изменяет .env.
#
# Примеры:
#   ./start.sh --auto-import
#   ./start.sh --no-import-prompt
#   ./start.sh --auto-import --no-import-prompt  # --auto-import имеет приоритет

# Цвета для вывода
# Проверка на Windows-подобную систему (например, Git Bash) для отключения цветов
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    GREEN=''
    RED=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
    EMOJI_CHART="[MEM]"
    EMOJI_CPU="[CPU]"
    EMOJI_GPU="[GPU]"
    EMOJI_ROCKET="->"
    EMOJI_OK="[OK]"
    EMOJI_ERROR="[ERROR]"
    EMOJI_WARN="[WARN]"
    EMOJI_SETUP="[SETUP]"
    EMOJI_FILE="[FILE]"
    EMOJI_SECURE="[SECURE]"
    EMOJI_NOTE="[NOTE]"
    EMOJI_CRITICAL="[CRITICAL]"
    EMOJI_PARTY="[SUCCESS]"
else
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    EMOJI_CHART="📊"
    EMOJI_CPU="🖥️"
    EMOJI_GPU="🎮"
    EMOJI_ROCKET="🚀"
    EMOJI_OK="✅"
    EMOJI_ERROR="❌"
    EMOJI_WARN="⚠️"
    EMOJI_SETUP="🔧"
    EMOJI_FILE="📋"
    EMOJI_SECURE="🔐"
    EMOJI_NOTE="📝"
    EMOJI_CRITICAL="🚨"
    EMOJI_PARTY="🎉"
fi

echo -e "${BLUE}=== Интеллектуальный запуск N8N AI Starter Kit ===${NC}"

# Flag set to 1 when ./scripts/setup.sh created or updated .env during this run.
# This prevents re-prompting the user later in the script when .env was just generated.
ENV_CREATED_BY_SETUP=0

# CLI flags to control import prompt behavior without editing .env
CLI_AUTO_IMPORT=false
CLI_NO_IMPORT_PROMPT=false

# Parse optional CLI flags (they are allowed before the optional profile positional arg)
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --auto-import)
            CLI_AUTO_IMPORT=true
            shift
            ;;
        --no-import-prompt)
            CLI_NO_IMPORT_PROMPT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--auto-import] [--no-import-prompt] [profile]"
            echo "  --auto-import        enable automatic import of workflows (equivalent to N8N_AUTO_IMPORT=true)"
            echo "  --no-import-prompt   never prompt about importing workflows; skip import prompts (equivalent to N8N_AUTO_IMPORT=false)"
            exit 0
            ;;
        --*)
            # Unknown flag — stop parsing and leave positional args
            break
            ;;
        *)
            # first non-flag is positional profile — stop parsing
            break
            ;;
    esac
done

# If CLI flags were provided, set an override marker and export N8N_AUTO_IMPORT
# so the rest of the script respects the flag without modifying .env.
CLI_OVERRIDE_IMPORT=0
if [ "$CLI_AUTO_IMPORT" = "true" ] && [ "$CLI_NO_IMPORT_PROMPT" = "true" ]; then
    echo -e "${YELLOW}${EMOJI_WARN} Both --auto-import and --no-import-prompt were provided; --auto-import will take precedence.${NC}"
    CLI_NO_IMPORT_PROMPT=false
fi
if [ "$CLI_AUTO_IMPORT" = "true" ]; then
    export N8N_AUTO_IMPORT=true
    CLI_OVERRIDE_IMPORT=1
    echo -e "${CYAN}CLI: auto-import enabled for this run (won't be written to .env).${NC}"
elif [ "$CLI_NO_IMPORT_PROMPT" = "true" ]; then
    export N8N_AUTO_IMPORT=false
    CLI_OVERRIDE_IMPORT=1
    echo -e "${CYAN}CLI: import prompts suppressed for this run (won't be written to .env).${NC}"
fi

# Автоматическое определение оптимального профиля
detect_optimal_profile() {
    local memory=$(free -m 2>/dev/null | awk 'NR==2{printf "%.0f", $2/1024}' || echo "0")
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    
    echo -e "${BLUE}Анализ системы:${NC}" >&2
    echo -e "  ${EMOJI_CHART} Память: ${memory}GB" >&2
    echo -e "  ${EMOJI_CPU}  CPU ядер: ${cpu_cores}" >&2
    
    # Проверка GPU
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1 2>/dev/null || echo "Unknown")
        echo -e "  ${EMOJI_GPU} GPU: ${gpu_info}" >&2
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu-nvidia${NC}" >&2
        echo "gpu-nvidia"
    elif [ "$memory" -gt 16 ] && [ "$cpu_cores" -gt 8 ]; then
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: developer${NC}" >&2
        echo "developer"
    else
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: cpu${NC}" >&2
        echo "cpu"
    fi
}

# Функция предварительной проверки
pre_flight_check() {
    echo -e "${BLUE}Предварительная проверка...${NC}"
    
    local issues=0
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        echo -e "  ${RED}${EMOJI_ERROR} Docker не найден${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}${EMOJI_OK} Docker найден${NC}"
    fi
    
    # Проверка Docker Compose
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo -e "  ${RED}${EMOJI_ERROR} Docker Compose не найден${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}${EMOJI_OK} Docker Compose найден${NC}"
    fi
    
    # Проверка .env файла
    if [ ! -f .env ]; then
        echo -e "  ${YELLOW}${EMOJI_WARN} Файл .env не найден${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}${EMOJI_OK} Файл .env найден${NC}"
        
        # Проверка ключевых переменных в .env
        if ! grep -q "OPENAI_API_KEY" .env || grep -q "^# OPENAI_API_KEY=" .env; then
            echo -e "  ${YELLOW}${EMOJI_WARN} OpenAI API key не настроен${NC}"
        else
            echo -e "  ${GREEN}${EMOJI_OK} OpenAI API key настроен${NC}"
        fi
        
        if ! grep -q "N8N_ENCRYPTION_KEY" .env; then
            echo -e "  ${YELLOW}${EMOJI_WARN} N8N encryption key не найден${NC}"
            ((issues++))
        else
            echo -e "  ${GREEN}${EMOJI_OK} N8N encryption key найден${NC}"
        fi
        
        # Проверка на проблемные символы в .env
        if grep -q '\$[^{]' .env; then
            echo -e "  ${YELLOW}${EMOJI_WARN} Найдены неэкранированные символы $ в .env${NC}"
            ((issues++))
        fi
    fi
    
    # Проверка конфигурации Docker Compose
    if ! docker compose config &>/dev/null; then
        echo -e "  ${RED}${EMOJI_ERROR} Ошибки в конфигурации Docker Compose${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}${EMOJI_OK} Конфигурация Docker Compose корректна${NC}"
    fi
    
    return $issues
}

# Функция для запуска setup.sh
run_setup() {
    echo -e "${BLUE}${EMOJI_SETUP} Запуск мастера настройки...${NC}"
    echo ""
    
    if [ -f "./scripts/setup.sh" ]; then
        chmod +x ./scripts/setup.sh
        echo -e "${CYAN}Запускается ./scripts/setup.sh...${NC}"
        ./scripts/setup.sh
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${EMOJI_OK} Настройка завершена успешно!${NC}"
            # setup.sh created or updated .env during its run; record this to avoid
            # re-prompting the user later in the start script.
            ENV_CREATED_BY_SETUP=1
            # Если мы в интерактивном терминале — спросим пользователя
            # хочет ли он автоматически запустить импорт workflows после старта n8n.
            # If CLI override provided, do not prompt and do not write to .env
            if [ "$CLI_OVERRIDE_IMPORT" -eq 1 ]; then
                echo -e "${CYAN}Import behavior controlled by CLI flag for this run; not changing .env.${NC}"
            elif [ -t 0 ]; then
                echo -e ""
                read -r -p "Хотите автоматически запустить импорт workflows после старта n8n? (y/N): " import_choice
                import_choice=${import_choice:-N}
                if [[ "$import_choice" =~ ^[Yy]$ ]]; then
                    # Установим флаг в .env чтобы импорт выполнился автоматически позже
                    if [ -f .env ]; then
                        if grep -q '^N8N_AUTO_IMPORT=' .env 2>/dev/null; then
                            sed -i 's/^N8N_AUTO_IMPORT=.*/N8N_AUTO_IMPORT=true/' .env 2>/dev/null || true
                        else
                            echo "N8N_AUTO_IMPORT=true" >> .env
                        fi
                    fi
                    echo -e "${GREEN}Импорт workflows будет запущен автоматически после старта n8n.${NC}"
                else
                    if [ -f .env ]; then
                        if grep -q '^N8N_AUTO_IMPORT=' .env 2>/dev/null; then
                            sed -i 's/^N8N_AUTO_IMPORT=.*/N8N_AUTO_IMPORT=false/' .env 2>/dev/null || true
                        else
                            echo "N8N_AUTO_IMPORT=false" >> .env
                        fi
                    fi
                fi
            fi
            return 0
        else
            echo -e "${RED}${EMOJI_ERROR} Ошибка при настройке${NC}"
            return 1
        fi
    else
        echo -e "${RED}${EMOJI_ERROR} Файл ./scripts/setup.sh не найден${NC}"
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

# Merge old .env into new .env: preserve any key=value lines that existed in
# the old file but are missing (or empty) in the newly generated file.
merge_env_files() {
    local oldfile="$1"
    local newfile="$2"
    local tmpnew
    tmpnew=$(mktemp 2>/dev/null || echo "./.env.tmp.$$")

    # If new does not exist, fall back to copying old
    if [ ! -f "$newfile" ]; then
        if [ -f "$oldfile" ]; then
            cp -p "$oldfile" "$newfile" || true
        fi
        return 0
    fi

    # Start with the new file contents
    cp -p "$newfile" "$tmpnew"

    # For each key in the old file, append it if it's missing from new
    if [ -f "$oldfile" ]; then
        while IFS= read -r line; do
            # only consider lines like KEY=VALUE (ignore comments/blank)
            if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*) ]]; then
                key="${BASH_REMATCH[1]}"
                # if key not present in newfile (exact key=) then append the old line
                if ! grep -q -E "^${key}=" "$newfile" 2>/dev/null; then
                    echo "$line" >> "$tmpnew"
                else
                    # if present but value empty in newfile, replace with old value
                    val=$(grep -E "^${key}=" "$newfile" | tail -n1 | cut -d'=' -f2-)
                    if [ -z "$val" ]; then
                        # remove existing empty line(s) for key in tmpnew and append full old line
                        sed -i.bak "/^${key}=/d" "$tmpnew" 2>/dev/null || true
                        echo "$line" >> "$tmpnew"
                    fi
                fi
            fi
        done < "$oldfile"
    fi

    # Move merged file into place
    mv "$tmpnew" "$newfile" 2>/dev/null || cp -f "$tmpnew" "$newfile" || true
    rm -f "${tmpnew}.bak" 2>/dev/null || true
}

# Функция автоматического исправления проблем (быстрые исправления)
auto_fix_issues() {
    echo -e "${YELLOW}Попытка автоматического исправления проблем...${NC}"
    
    # Создание .env файла если отсутствует
    if [ ! -f .env ]; then
        echo -e "  ${EMOJI_FILE} Файл .env не найден — запускаем генерацию из схемы переменных..."
            if [ -f "./scripts/setup.sh" ]; then
            echo -e "  ${CYAN}Вызов: ./scripts/setup.sh --generate-only${NC}"
            chmod +x ./scripts/setup.sh
                ./scripts/setup.sh --generate-only || {
                    echo -e "  ${RED}${EMOJI_ERROR} Не удалось автоматически сгенерировать .env${NC}"
                    echo -e "  ${YELLOW}Запустите ./scripts/setup.sh вручную для интерактивной настройки.${NC}"
                    return 1
                }
                # mark that setup created .env
                ENV_CREATED_BY_SETUP=1
            echo -e "  ${GREEN}${EMOJI_OK} Файл .env сгенерирован из схемы переменных${NC}"
        else
            echo -e "  ${RED}${EMOJI_ERROR} Скрипт ./scripts/setup.sh не найден — создайте .env вручную${NC}"
            return 1
        fi
    fi
    
    # Исправление переменных окружения
    if [ -f ./scripts/fix-env-vars.sh ]; then
        echo -e "  ${EMOJI_SETUP} Исправление переменных окружения..."
        chmod +x ./scripts/fix-env-vars.sh
        ./scripts/fix-env-vars.sh > /dev/null 2>&1
    fi
    
    # Исправление проблем с хэшем пароля
    if [ -f .env ] && grep -q '\$[^{]' .env; then
        echo -e "  ${EMOJI_SETUP} Исправление хэша пароля Traefik..."
        # Убираем лишние символы $ из хэша пароля
        sed -i 's/\$\$\$/$/g' .env 2>/dev/null || true
        sed -i 's/\$\$/$/g' .env 2>/dev/null || true
    fi
    
    # Добавление отсутствующих переменных
    if [ -f .env ] && ! grep -q "WEBHOOK_URL" .env; then
        echo -e "  ${EMOJI_NOTE} Добавление отсутствующих переменных..."
        echo "WEBHOOK_URL=" >> .env
    fi
    
    return 0
}

# Функция для проверки критических компонентов
check_critical_components() {
    local critical_issues=0
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}${EMOJI_ERROR} Docker не установлен${NC}"
        ((critical_issues++))
    elif ! docker info &> /dev/null; then
        echo -e "${RED}${EMOJI_ERROR} Docker демон не запущен${NC}"
        ((critical_issues++))
    fi
    
    # Проверка Docker Compose
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}${EMOJI_ERROR} Docker Compose не установлен${NC}"
        ((critical_issues++))
    fi
    
    return $critical_issues
}

# Основная логика запуска
if [ -n "$1" ]; then
    PROFILE="$1"
    echo ""
    echo -e "${BLUE}Выбранный профиль: ${YELLOW}$PROFILE${NC}"
else
    PROFILE=$(detect_optimal_profile)
    echo ""
    echo -e "${BLUE}Выбранный профиль: ${YELLOW}$PROFILE${NC}"
fi

# Проверка критических компонентов
echo ""
if ! check_critical_components; then
    echo ""
    echo -e "${RED}${EMOJI_CRITICAL} Обнаружены критические проблемы с Docker/Docker Compose${NC}"
    echo -e "${YELLOW}Необходимо запустить полную настройку для установки зависимостей${NC}"
    echo ""
    echo -e "${CYAN}Запустить мастер настройки? (y/n): ${NC}"
    read -r setup_choice
    
    if [[ "$setup_choice" =~ ^[Yy]$ ]]; then
        if ! run_setup; then
            echo -e "${RED}${EMOJI_ERROR} Настройка не завершена. Завершение работы.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Установите Docker и Docker Compose, затем повторите запуск${NC}"
        exit 1
    fi
fi

# Если .env уже существует, спросим пользователя, что делать: бекап+генерация, перезаписать или продолжить
if [ -f .env ]; then
    # Use deterministic template-based completeness check instead of marker/mtime.
    # Prefer env.schema (plain canonical). If missing, fall back to env.schema.md (legacy) or template.env.
    check_env_against_template() {
        # Prefer plain env.schema (canonical). If missing, fall back to env.schema.md
        # (legacy documented schema), then template.env.
        local schema_file=""
        if [ -f env.schema ]; then
            schema_file="env.schema"
    elif [ -f env.schema.md ]; then  # This line remains unchanged
            schema_file="env.schema.md"
        elif [ -f template.env ]; then
            schema_file="template.env"
        else
            schema_file=""
        fi

        if [ -z "$schema_file" ] || [ ! -f "$schema_file" ]; then
            # No schema available — fall back to interactive prompt
            return 2
        fi

        # Extract keys from schema (ignore comments/blank lines)
        mapfile -t tmpl_keys < <(grep -E '^[A-Za-z0-9_]+=.*' "$schema_file" | sed -E 's/=.*$//' | sort -u)

        missing_keys=()
        for k in "${tmpl_keys[@]}"; do
            # Get value from .env (last matching line)
            if grep -q -E "^${k}=" .env; then
                val=$(grep -E "^${k}=" .env | tail -n1 | cut -d'=' -f2-)
                # treat empty string or placeholders as missing
                if [ -z "$val" ] || echo "$val" | grep -qE 'change_this|yourdomain|your_openai_api_key_here'; then
                    missing_keys+=("$k")
                fi
            else
                missing_keys+=("$k")
            fi
        done

        if [ ${#missing_keys[@]} -eq 0 ]; then
            return 0  # complete
        else
            return 1  # incomplete
        fi
    }

    # If setup ran in this process (ENV_CREATED_BY_SETUP), skip prompts.
    if [ "${ENV_CREATED_BY_SETUP:-0}" -eq 1 ]; then
        echo ""
        echo -e "${CYAN}Файл .env был сгенерирован мастером в рамках этого запуска; пропускаю запрос о бэкапе и продолжаю.${NC}"
        env_choice=3
    else
        # If template exists and .env is complete, skip prompting.
        check_env_against_template
        tmpl_status=$?
        if [ "$tmpl_status" -eq 0 ]; then
            echo ""
            echo -e "${CYAN}Файл .env соответствует схеме ${template_file} — продолжаю без запроса.${NC}"
            env_choice=3
        elif [ "$tmpl_status" -eq 2 ]; then
            # No template — fall back to interactive prompt
            :
        else
            # .env incomplete — prompt user
        echo ""
        echo -e "${YELLOW}${EMOJI_WARN} Обнаружен файл .env в корне проекта.${NC}"
        echo "Выберите действие для существующего .env:"
        echo "  1) Создать бэкап (.env.bak.<timestamp>) и сгенерировать новый .env"
        echo "  2) Перезаписать существующий .env новым (без сохранения бэкапа)"
        echo "  3) Продолжить с существующим .env (рекомендуется, если вы уверены)"
        echo -ne "Ваш выбор (1/2/3, по-умолчанию 3): "
        read -r env_choice
        env_choice=${env_choice:-3}

        case "$env_choice" in
            1)
                echo -e "${CYAN}Создаём бэкап .env и запускаем генерацию нового .env...${NC}"
                timestamp=$(date +%Y%m%d%H%M%S 2>/dev/null || echo "bk_$(date +%s)")
                cp .env ".env.bak.$timestamp" || { echo -e "${RED}Не удалось создать бэкап .env${NC}"; }
                if [ -f "./scripts/setup.sh" ]; then
                    chmod +x ./scripts/setup.sh
                    # Preserve previous .env path
                    prev_env=".env.bak.$timestamp"
                    ./scripts/setup.sh --generate-only || echo -e "${YELLOW}Генерация .env завершилась с ошибкой, проверьте./scripts/setup.sh${NC}"
                    # If a previous .env existed and a new .env was generated, merge
                    if [ -f "$prev_env" ] && [ -f .env ]; then
                        merge_env_files "$prev_env" .env
                    fi
                    # mark that setup created .env
                    ENV_CREATED_BY_SETUP=1
                else
                    echo -e "${RED}./scripts/setup.sh не найден — создайте .env вручную или поместите скрипт в директорию scripts/${NC}"
                fi
                ;;
            2)
                echo -e "${CYAN}Перезаписываем .env новым, без создания бэкапа...${NC}"
                if [ -f "./scripts/setup.sh" ]; then
                    chmod +x ./scripts/setup.sh
                    # Save temporary copy of old .env (if present) so merge can preserve keys
                    if [ -f .env ]; then
                        cp .env .env.preoverwrite.$(date +%s) 2>/dev/null || true
                        prev_tmp=".env.preoverwrite.$(date +%s)"
                    else
                        prev_tmp=""
                    fi
                    ./scripts/setup.sh --generate-only || echo -e "${YELLOW}Генерация .env завершилась с ошибкой${NC}"
                    if [ -n "$prev_tmp" ] && [ -f "$prev_tmp" ] && [ -f .env ]; then
                        merge_env_files "$prev_tmp" .env
                        rm -f "$prev_tmp" 2>/dev/null || true
                    fi
                    ENV_CREATED_BY_SETUP=1
                else
                    echo -e "${RED}./scripts/setup.sh не найден — невозможно сгенерировать .env${NC}"
                fi
                ;;
            3)
                echo -e "${GREEN}Продолжаем с существующим .env${NC}"
                ;;
            *)
                echo -e "${YELLOW}Неверный выбор — продолжаем с существующим .env${NC}"
                ;;
        esac
        fi
    fi

    # If user chose to continue with existing .env, ask whether to enable automatic import
    if [ "$env_choice" = "3" ]; then
        if [ "$CLI_OVERRIDE_IMPORT" -eq 1 ]; then
            echo -e "${CYAN}Import behavior forced by CLI flag for this run; not prompting and not modifying .env.${NC}"
        elif [ -t 0 ]; then
            echo ""
            read -r -p "Хотите автоматически запускать импорт workflows после старта n8n? (y/N): " import_choice_existing
            import_choice_existing=${import_choice_existing:-N}
            if [[ "${import_choice_existing}" =~ ^[Yy]$ ]]; then
                if [ -f .env ]; then
                    if grep -q '^N8N_AUTO_IMPORT=' .env 2>/dev/null; then
                        sed -i 's/^N8N_AUTO_IMPORT=.*/N8N_AUTO_IMPORT=true/' .env 2>/dev/null || true
                    else
                        echo "N8N_AUTO_IMPORT=true" >> .env
                    fi
                fi
                echo -e "${GREEN}Импорт workflows будет запущен автоматически после старта n8n.${NC}"
            else
                if [ -f .env ]; then
                    if grep -q '^N8N_AUTO_IMPORT=' .env 2>/dev/null; then
                        sed -i 's/^N8N_AUTO_IMPORT=.*/N8N_AUTO_IMPORT=false/' .env 2>/dev/null || true
                    else
                        echo "N8N_AUTO_IMPORT=false" >> .env
                    fi
                fi
            fi
        fi
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
                            echo -e "${RED}${EMOJI_ERROR} Настройка не завершена. Завершение работы.${NC}"
                            exit 1
                        fi
                    else
                        echo -e "${YELLOW}Продолжение с текущей конфигурацией...${NC}"
                    fi
                fi
            else
                echo -e "${YELLOW}Быстрое исправление не удалось. Запуск полной настройки...${NC}"
                if ! run_setup; then
                    echo -e "${RED}${EMOJI_ERROR} Настройка не завершена. Завершение работы.${NC}"
                    exit 1
                fi
            fi
            ;;
        2)
            if ! run_setup; then
                echo -e "${RED}${EMOJI_ERROR} Настройка не завершена. Завершение работы.${NC}"
                exit 1
            fi
            ;;
        3)
            echo -e "${YELLOW}${EMOJI_WARN} Продолжение без исправлений. Возможны ошибки при запуске.${NC}"
            ;;
        *)
            echo -e "${YELLOW}Неверный выбор. Запуск полной настройки...${NC}"
            if ! run_setup; then
                echo -e "${RED}${EMOJI_ERROR} Настройка не завершена. Завершение работы.${NC}"
                exit 1
            fi
            ;;
    esac
    
    # Финальная проверка перед запуском
    echo ""
    echo -e "${BLUE}Финальная проверка конфигурации...${NC}"
    if ! pre_flight_check; then
        echo -e "${RED}${EMOJI_ERROR} Критические проблемы не исправлены.${NC}"
        echo -e "${YELLOW}Запустите ./scripts/diagnose.sh для детальной диагностики${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}${EMOJI_OK} Все проверки пройдены! Запуск системы...${NC}"

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
# Ensure docker-compose has access to variables defined in .env. Some docker
# compose versions don't automatically load .env depending on context, so we
# export the file into the environment and also pass --env-file for robustness.
ENV_FILE_ARG=""
if [ -f .env ]; then
    echo -e "${CYAN}Экспорт переменных из .env для docker compose...${NC}"
    # Export all variables from .env into the environment (idempotent)
    set -o allexport
    # shellcheck disable=SC1090
    . ./.env 2>/dev/null || . .env 2>/dev/null || true
    set +o allexport
    ENV_FILE_ARG="--env-file .env"
fi

echo -e "${BLUE}Команда запуска:${NC} $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} --profile $PROFILE up -d"
$DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} --profile $PROFILE up -d

# Проверка результата запуска
if [ $? -eq 0 ]; then
    echo ""
    printf "${GREEN}${EMOJI_PARTY} Система успешно запущена!${NC}\n"
    echo ""
    printf "${BLUE}Полезные команды:${NC}\n"
    printf "  ${EMOJI_CHART} Мониторинг: ${YELLOW}./scripts/monitor.sh${NC}\n"
    printf "  ${EMOJI_FILE} Статус: ${YELLOW}docker ps${NC}\n"
    printf "  ${EMOJI_NOTE} Логи: ${YELLOW}docker logs n8n-ai-starter-kit-n8n-1${NC}\n"
    printf "  ${EMOJI_ERROR} Остановка: ${YELLOW}$DOCKER_COMPOSE_CMD down${NC}\n"
    echo ""
    printf "${BLUE}Доступ к сервисам:${NC}\n"
    printf "  🌐 N8N: ${YELLOW}http://localhost:5678${NC}\n"
    printf "  🔍 Qdrant: ${YELLOW}http://localhost:6333/dashboard${NC}\n"
    printf "  🤖 Ollama: ${YELLOW}http://localhost:11434${NC}\n"
    printf "  🚦 Traefik: ${YELLOW}http://localhost:8080${NC}\n"
    
    # Проверка OpenAI API Key
    if [ -f .env ] && (grep -q "^# OPENAI_API_KEY=" .env || ! grep -q "OPENAI_API_KEY=" .env); then
        echo ""
        printf "${YELLOW}${EMOJI_NOTE} Примечание: OpenAI API key не настроен${NC}\n"
        printf "   ${CYAN}Для использования OpenAI моделей добавьте ключ в файл .env${NC}\n"
        printf "   ${CYAN}или запустите: ./scripts/setup.sh для полной настройки${NC}\n"
    fi
else
    echo ""
    printf "${RED}${EMOJI_ERROR} Ошибка при запуске системы${NC}\n"
    printf "${YELLOW}Запустите для диагностики: ./scripts/diagnose.sh${NC}\n"
    printf "${YELLOW}Или запустите полную настройку: ./scripts/setup.sh${NC}\n"
    exit 1
fi

# Запуск импорта workflows после старта системы
echo ""
echo -e "${BLUE}Ожидание готовности n8n для импорта workflows...${NC}"

# HTTP-based readiness check (preferred). Uses localhost:5678 by default but can be
# overridden with N8N_HOST/N8N_PORT/N8N_HEALTH_PATH environment variables.
check_n8n_http() {
    # Use N8N_PROBE_HOST for container-local probing. This defaults to loopback
    # to avoid depending on externally routed domain names (Traefik/DNS).
    local host="${N8N_PROBE_HOST:-127.0.0.1}"
    local port="${N8N_PORT:-5678}"
    local path="${N8N_HEALTH_PATH:-/}"

    # prefer curl when available
    if command -v curl >/dev/null 2>&1; then
        http_code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 5 "http://${host}:${port}${path}" 2>/dev/null || echo "000")
        # Accept 200 and common redirects as readiness
        if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
            return 0
        fi
    fi
    return 1
}

max_wait=${N8N_READY_TIMEOUT:-300}
waited=0
while [ "$waited" -lt "$max_wait" ]; do
    # 1) Prefer application-level HTTP readiness: faster and more accurate.
    if check_n8n_http; then
        echo -e "${GREEN}${EMOJI_OK} n8n отвечает по HTTP — считается готовым.${NC}"

        # Выполняем импорт workflows по той же логике, что и раньше
        if [ "${N8N_AUTO_IMPORT:-false}" != "true" ]; then
            if [ -t 0 ]; then
                echo -e "${YELLOW}${EMOJI_NOTE} Автоматический импорт отключён (N8N_AUTO_IMPORT!=true).${NC}"
                read -r -p "Запустить импорт workflows один раз сейчас? (y/N): " run_import_choice
                run_import_choice=${run_import_choice:-N}
                if [[ "$run_import_choice" =~ ^[Yy]$ ]]; then
                    if $DOCKER_COMPOSE_CMD config --services 2>/dev/null | grep -q '^n8n-importer$'; then
                        echo -e "${BLUE}${EMOJI_SETUP} Запуск n8n-importer...${NC}"
                        $DOCKER_COMPOSE_CMD run --rm n8n-importer
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                        else
                            echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows.${NC}"
                        fi
                    else
                        echo -e "${YELLOW}${EMOJI_WARN} Сервис n8n-importer не определён в compose — невозможно запустить импорт.${NC}"
                    fi
                else
                    echo -e "${YELLOW}Импорт пропущен по выбору пользователя.${NC}"
                fi
            else
                echo -e "${YELLOW}${EMOJI_NOTE} Автоматический импорт отключён (N8N_AUTO_IMPORT!=true). Пропускаем (неинтерактивный режим).${NC}"
            fi
        else
            if $DOCKER_COMPOSE_CMD config --services 2>/dev/null | grep -q '^n8n-importer$'; then
                echo -e "${BLUE}${EMOJI_SETUP} Запуск n8n-importer...${NC}"
                $DOCKER_COMPOSE_CMD run --rm n8n-importer
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                else
                    echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows.${NC}"
                fi
            else
                echo -e "${YELLOW}${EMOJI_WARN} Сервис n8n-importer не определён в compose — пропускаем импорт.${NC}"
            fi
        fi

        break
    fi

    # 2) Fallback: check docker-compose reported health (if present)
    n8n_status=$($DOCKER_COMPOSE_CMD ps --format '{{.State}}' n8n 2>/dev/null || echo "")
    if [ "$n8n_status" = "running" ]; then
        n8n_health=$($DOCKER_COMPOSE_CMD ps --format '{{.Health}}' n8n 2>/dev/null || echo "")
        if [[ "$n8n_health" == *"healthy"* ]]; then
            echo -e "${GREEN}${EMOJI_OK} n8n готов (docker health).${NC}"

            # повторяем ту же логику импорта
            if [ "${N8N_AUTO_IMPORT:-false}" != "true" ]; then
                if [ -t 0 ]; then
                    echo -e "${YELLOW}${EMOJI_NOTE} Автоматический импорт отключён (N8N_AUTO_IMPORT!=true).${NC}"
                    read -r -p "Запустить импорт workflows один раз сейчас? (y/N): " run_import_choice
                    run_import_choice=${run_import_choice:-N}
                    if [[ "$run_import_choice" =~ ^[Yy]$ ]]; then
                        if $DOCKER_COMPOSE_CMD config --services 2>/dev/null | grep -q '^n8n-importer$'; then
                            echo -e "${BLUE}${EMOJI_SETUP} Запуск n8n-importer...${NC}"
                            $DOCKER_COMPOSE_CMD run --rm n8n-importer
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                            else
                                echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows.${NC}"
                            fi
                        else
                            echo -e "${YELLOW}${EMOJI_WARN} Сервис n8n-importer не определён в compose — невозможно запустить импорт.${NC}"
                        fi
                    else
                        echo -e "${YELLOW}Импорт пропущен по выбору пользователя.${NC}"
                    fi
                else
                    echo -e "${YELLOW}${EMOJI_NOTE} Автоматический импорт отключён (N8N_AUTO_IMPORT!=true). Пропускаем (неинтерактивный режим).${NC}"
                fi
            else
                if $DOCKER_COMPOSE_CMD config --services 2>/dev/null | grep -q '^n8n-importer$'; then
                    echo -e "${BLUE}${EMOJI_SETUP} Запуск n8n-importer...${NC}"
                    $DOCKER_COMPOSE_CMD run --rm n8n-importer
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                    else
                        echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows.${NC}"
                    fi
                else
                    echo -e "${YELLOW}${EMOJI_WARN} Сервис n8n-importer не определён в compose — пропускаем импорт.${NC}"
                fi
            fi

            break
        fi
    fi

    printf "."
    sleep 5
    waited=$((waited + 5))
done

if [ "$waited" -ge "$max_wait" ]; then
    echo -e "\n${RED}${EMOJI_ERROR} Сервис n8n не перешел в состояние ready за $max_wait секунд. Импорт пропущен.${NC}"
fi