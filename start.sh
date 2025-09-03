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
#  --config-check        Вывести и сохранить итоговую конфигурацию Docker Compose и список сервисов
#                        (в .internal/compose_config_<profile>.yml и .internal/services_<profile>.txt),
#                        ничего не pull/up (только проверка и рендер)
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
CONFIG_CHECK=false
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
        --config-check)
            CONFIG_CHECK=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--auto-import] [--no-import-prompt] [profile]"
            echo ""
            echo "OPTIONS:"
            echo "  --auto-import        enable automatic import of workflows (equivalent to N8N_AUTO_IMPORT=true)"
            echo "  --no-import-prompt   never prompt about importing workflows; skip import prompts (equivalent to N8N_AUTO_IMPORT=false)"
            echo "  --config-check       render merged Docker Compose config and services (no pull/up)"
            echo ""
            echo "PROFILES:"
            echo "  default              Core services (Traefik, N8N, PostgreSQL)"
            echo "  developer            + Qdrant, PgAdmin, JupyterLab, optional services"
            echo "  cpu                  CPU-optimized AI services (Ollama CPU-only)"
            echo "  reasoning            rStar2-Agent with CPU inference"
            echo "  gpu                  GPU-accelerated services (auto-detects NVIDIA/AMD)"
            echo "  rstar-gpu            rStar2-Agent with GPU acceleration"
            echo "  developer-gpu        Development tools with GPU acceleration"
            echo "  monitoring-gpu       GPU monitoring and metrics"
            echo ""
            echo "CPU PROFILE COMBINATIONS:"
            echo "  default                           Core services only"
            echo "  cpu,developer                     CPU AI + Development tools"
            echo "  cpu,reasoning,developer           Full CPU stack with reasoning"
            echo ""
            echo "GPU PROFILE COMBINATIONS:"
            echo "  gpu                               Basic GPU services (auto-detects)"
            echo "  gpu,rstar-gpu                     + rStar2-Agent with GPU"
            echo "  gpu,developer-gpu                 + Development tools with GPU"
            echo "  gpu,monitoring-gpu                + GPU monitoring"
            echo "  Full stack (24GB+ VRAM):          gpu,rstar-gpu,developer-gpu,monitoring-gpu"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                                Auto-detect optimal profile"
            echo "  $0 developer                      CPU-only development environment"
            echo "  $0 cpu,reasoning,developer        Full CPU stack with AI reasoning"
            echo "  $0 gpu                            GPU-accelerated services"
            echo "  $0 gpu,rstar-gpu,developer-gpu   Full GPU stack"
            echo "  $0 --auto-import cpu,developer   CPU development with auto-import"
            echo ""
            echo "GPU DETECTION:"
            echo "  Run './scripts/detect-gpu.sh' to analyze your GPU and get recommendations"
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
# При обнаружении AMD/ROCm дополнительно активируем overlay-файл compose/gpu-amd.override.yml
# чтобы сохранить единый профиль "gpu" без отдельных профилей под вендоров
AMD_OVERRIDE=0
detect_optimal_profile() {
    local memory=$(free -m 2>/dev/null | awk 'NR==2{printf "%.0f", $2/1024}' || echo "0")
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    local vendor_override="${GPU_VENDOR:-auto}"
    vendor_override=$(echo "$vendor_override" | tr 'A-Z' 'a-z')

    echo -e "${BLUE}Анализ системы:${NC}" >&2
    echo -e "  ${EMOJI_CHART} Память: ${memory}GB" >&2
    echo -e "  ${EMOJI_CPU}  CPU ядер: ${cpu_cores}" >&2

    # Manual override for GPU vendor if provided
    if [ "$vendor_override" = "nvidia" ]; then
        echo -e "  ${EMOJI_GPU} GPU_VENDOR override: NVIDIA${NC}" >&2
        export GPU_TYPE="nvidia"
        AMD_OVERRIDE=0
        # Best effort check Docker GPU support to inform user
        docker_gpu_ok=0
        if docker info >/dev/null 2>&1 && docker info 2>/dev/null | grep -i -E 'Runtimes:.*nvidia|Default Runtime:.*nvidia|nvidia' >/dev/null 2>&1; then
            docker_gpu_ok=1
        elif docker run --rm --gpus all nvidia/cuda:12.1.1-runtime-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
            docker_gpu_ok=1
        fi
        if [ "$docker_gpu_ok" -eq 1 ]; then
            echo -e "  ${GREEN}${EMOJI_OK} Docker GPU support: Работает${NC}" >&2
        else
            echo -e "  ${YELLOW}${EMOJI_WARN} Docker GPU support: Не настроен (override всё равно применён)${NC}" >&2
        fi
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu${NC}" >&2
        echo "gpu"
        return 0
    elif [ "$vendor_override" = "amd" ]; then
        echo -e "  ${EMOJI_GPU} GPU_VENDOR override: AMD/ROCm${NC}" >&2
        export GPU_TYPE="amd"
        AMD_OVERRIDE=1
        # Best effort ROCm-in-docker hint (do not block on failure)
        if docker run --rm --device=/dev/kfd --device=/dev/dri rocm/rocm-terminal:latest bash -lc 'rocm-smi >/dev/null 2>&1 || rocminfo >/dev/null 2>&1' >/dev/null 2>&1; then
            echo -e "  ${GREEN}${EMOJI_OK} Docker ROCm support: Предположительно работает${NC}" >&2
        else
            echo -e "  ${YELLOW}${EMOJI_WARN} Docker ROCm support: Не подтверждён (override всё равно применён)${NC}" >&2
        fi
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu${NC}" >&2
        echo "gpu"
        return 0
    fi

    # Расширенная проверка GPU
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1 2>/dev/null || echo "Unknown,0")
        gpu_name=$(echo "$gpu_info" | cut -d',' -f1 | xargs)
        gpu_memory=$(echo "$gpu_info" | cut -d',' -f2 | xargs)
        gpu_memory_gb=$((gpu_memory / 1024))

        echo -e "  ${EMOJI_GPU} GPU: ${gpu_name} (${gpu_memory_gb}GB)" >&2

        # Docker GPU support check
        # Prefer probing the Docker daemon for an NVIDIA runtime/devices instead of
        # immediately running a container (this avoids unnecessary large image pulls).
        docker_gpu_ok=0
        if docker info >/dev/null 2>&1; then
            # If docker info mentions 'nvidia' (runtimes or default runtime), assume GPU support
            if docker info 2>/dev/null | grep -i -E 'Runtimes:.*nvidia|Default Runtime:.*nvidia|nvidia' >/dev/null 2>&1; then
                docker_gpu_ok=1
            fi
        fi

        # If the daemon check was inconclusive, perform a lightweight runtime probe
        # by attempting to run nvidia-smi inside a CUDA runtime container. This may
        # pull a small image if missing; failure is treated as no Docker GPU support.
        if [ "$docker_gpu_ok" -eq 0 ]; then
            if docker run --rm --gpus all nvidia/cuda:12.1.1-runtime-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
                docker_gpu_ok=1
            fi
        fi

        if [ "$docker_gpu_ok" -eq 1 ]; then
            echo -e "  ${GREEN}${EMOJI_OK} Docker GPU support: Работает${NC}" >&2
            export GPU_TYPE="nvidia"

            # Рекомендации на основе VRAM
            if [ "$gpu_memory_gb" -ge 24 ]; then
                echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu,rstar-gpu,developer-gpu,monitoring-gpu${NC}" >&2
                echo "gpu,rstar-gpu,developer-gpu,monitoring-gpu"
            elif [ "$gpu_memory_gb" -ge 12 ]; then
                echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu,rstar-gpu${NC}" >&2
                echo "gpu,rstar-gpu"
            elif [ "$gpu_memory_gb" -ge 8 ]; then
                echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu${NC}" >&2
                echo "gpu"
            else
                echo -e "${YELLOW}${EMOJI_WARN} Низкий объем VRAM (${gpu_memory_gb}GB), рекомендуется CPU${NC}" >&2
                echo "default,developer"
            fi
        else
            echo -e "  ${YELLOW}${EMOJI_WARN} Docker GPU support: Не настроен${NC}" >&2
            echo -e "${YELLOW}${EMOJI_ROCKET} Рекомендуемый профиль: developer (CPU fallback)${NC}" >&2
            echo "developer"
        fi
    elif command -v rocm-smi &> /dev/null && rocm-smi &> /dev/null; then
        echo -e "  ${EMOJI_GPU} GPU: AMD ROCm обнаружен" >&2
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: gpu${NC}" >&2
        AMD_OVERRIDE=1
        export GPU_TYPE="amd"
        echo "gpu"
    elif [ "$memory" -gt 32 ] && [ "$cpu_cores" -gt 16 ]; then
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: cpu,reasoning,developer${NC}" >&2
        echo "cpu,reasoning,developer"
    elif [ "$memory" -gt 16 ] && [ "$cpu_cores" -gt 8 ]; then
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: developer${NC}" >&2
        echo "developer"
    else
        echo -e "${GREEN}${EMOJI_ROCKET} Рекомендуемый профиль: default${NC}" >&2
        echo "default"
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
PROFILE_SPECIFIED=0
if [ -n "$1" ]; then
    PROFILE="$1"
    PROFILE_SPECIFIED=1
    echo ""
    echo -e "${BLUE}Выбранный профиль: ${YELLOW}$PROFILE${NC}"
else
    PROFILE=$(detect_optimal_profile)
    echo ""
    echo -e "${BLUE}Выбранный профиль: ${YELLOW}$PROFILE${NC}"
fi

# Если оператор явно передал список профилей — убедимся, что 'default' присутствует
if [ "$PROFILE_SPECIFIED" -eq 1 ]; then
    if ! echo ",$PROFILE," | grep -q ",default,"; then
        PROFILE="default,$PROFILE"
        echo -e "${YELLOW}${EMOJI_NOTE} Автоматически добавлен профиль 'default' к списку профилей: ${PROFILE}${NC}"
    fi
fi

# Неявно включаем мониторинг GPU только по явному флагу окружения,
# чтобы избежать приватных образов по умолчанию
if [ "${GPU_ENABLE_MONITORING:-}" = "true" ]; then
    if ! echo ",$PROFILE," | grep -q ",monitoring-gpu,"; then
        PROFILE="$PROFILE,monitoring-gpu"
        echo -e "${CYAN}GPU_ENABLE_MONITORING=true — добавлен профиль 'monitoring-gpu'.${NC}"
    fi
fi

# Если профиль задан явно и указан GPU_VENDOR, применим оверлей AMD и установим GPU_TYPE
case "${GPU_VENDOR:-auto}" in
    amd|AMD)
        AMD_OVERRIDE=1
        export GPU_TYPE="amd"
        ;;
    nvidia|NVIDIA)
        AMD_OVERRIDE=0
        export GPU_TYPE="nvidia"
        ;;
    *)
        :
        ;;
esac

# Ранний режим: --config-check (без интерактива, без pre-pull/up/stop)
if [ "$CONFIG_CHECK" = "true" ]; then
    # Определяем docker compose команду
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        DOCKER_COMPOSE_CMD="docker compose"
    fi

    # Используем --env-file только если .env существует (ничего не экспортируем)
    ENV_FILE_ARG=""
    if [ -f .env ]; then
        ENV_FILE_ARG="--env-file .env"
    fi

    # Собираем список compose-файлов и оверлеев как в обычном запуске
    COMPOSE_FILES_ARGS=""
    compose_files=("docker-compose.yml")

    base_includes=()
    if [ -f "docker-compose.yml" ]; then
        mapfile -t base_includes < <(grep -Eo 'path:\s*\.?/?[A-Za-z0-9_./-]+\.(yml|yaml)' docker-compose.yml | awk '{print $2}' | sed 's#^\./##g' | sort -u)
    fi

    IFS=',' read -ra _profs <<< "$PROFILE"
    for _p in "${_profs[@]}"; do
        _p_trim=$(echo "$_p" | xargs)
        [ -z "$_p_trim" ] && continue
        for _f in "compose/${_p_trim}.yml" "compose/${_p_trim}-compose.yml" compose/*"${_p_trim}"*.yml; do
            if [ -f "$_f" ]; then
                skip_inc=0
                for inc in "${base_includes[@]}"; do
                    inc_norm=$(echo "$inc" | sed 's#^\./##')
                    f_norm=$(echo "$_f" | sed 's#^\./##')
                    if [ "$inc_norm" = "$f_norm" ]; then
                        skip_inc=1; break
                    fi
                done
                [ $skip_inc -eq 0 ] && compose_files+=("$_f")
            fi
        done
    done

    if [ "$AMD_OVERRIDE" -eq 1 ] && [ -f "./compose/gpu-amd.override.yml" ]; then
        compose_files+=("compose/gpu-amd.override.yml")
    fi

    unique_files=()
    for _f in "${compose_files[@]}"; do
        skip=0
        for _u in "${unique_files[@]}"; do
            [ "$_u" = "$_f" ] && { skip=1; break; }
        done
        [ $skip -eq 0 ] && unique_files+=("$_f")
    done

    if [ ${#unique_files[@]} -gt 0 ]; then
        COMPOSE_FILES_ARGS=""
        for _f in "${unique_files[@]}"; do
            COMPOSE_FILES_ARGS="$COMPOSE_FILES_ARGS -f $_f"
        done
        COMPOSE_FILES_ARGS=$(echo "$COMPOSE_FILES_ARGS" | sed -E 's/^ //')
    fi

    mkdir -p .internal
    slug=$(echo "$PROFILE" | tr ' ,' '__' | tr -s '_' | sed -E 's/^_+//; s/_+$//')
    COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config > ".internal/compose_config_${slug}.yml" || true
    COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services > ".internal/services_${slug}.txt" || true
    echo -e "${GREEN}${EMOJI_OK} Итоговая конфигурация сохранена: .internal/compose_config_${slug}.yml${NC}"
    echo -e "${GREEN}${EMOJI_OK} Список сервисов сохранён: .internal/services_${slug}.txt${NC}"
    echo -e "${BLUE}Режим проверки завершён. Запуск контейнеров не выполнялся.${NC}"
    exit 0
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
            echo -e "${CYAN}Файл .env соответствует схеме ${schema_file} — продолжаю без запроса.${NC}"
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

COMPOSE_FILES_ARGS=""
# Build COMPOSE_FILES_ARGS dynamically: include base docker-compose.yml and
# any overlay files in ./compose/ that match the selected profile names
# (this ensures overlays like compose/gpu-compose.yml are included when the
# user requests the gpu profile).
compose_files=()
# Always include base compose file so default services are present
compose_files+=("docker-compose.yml")

# Collect include: paths already referenced by the base compose to avoid
# duplicates when we also add overlays via -f flags.
base_includes=()
if [ -f "docker-compose.yml" ]; then
    # Extract lines with "path: <file>" under any include block
    mapfile -t base_includes < <(grep -Eo 'path:\s*\.?/?[A-Za-z0-9_./-]+\.(yml|yaml)' docker-compose.yml | awk '{print $2}' | sed 's#^\./##g' | sort -u)
fi

# Split PROFILE (comma-separated) into array and search for matching files
IFS=',' read -ra _profs <<< "$PROFILE"
for _p in "${_profs[@]}"; do
    # trim whitespace
    _p_trim=$(echo "$_p" | xargs)
    if [ -z "$_p_trim" ]; then
        continue
    fi
    # check several common naming patterns
    for _f in "compose/${_p_trim}.yml" "compose/${_p_trim}-compose.yml" compose/*"${_p_trim}"*.yml; do
        if [ -f "$_f" ]; then
            # Skip if already included from the base compose include:
            skip_inc=0
            for inc in "${base_includes[@]}"; do
                # Normalize both paths for comparison
                inc_norm=$(echo "$inc" | sed 's#^\./##')
                f_norm=$(echo "$_f" | sed 's#^\./##')
                if [ "$inc_norm" = "$f_norm" ]; then
                    skip_inc=1
                    break
                fi
            done
            if [ $skip_inc -eq 0 ]; then
                compose_files+=("$_f")
            fi
        fi
    done
done

# AMD specific overlay should still be applied when detected
if [ "$AMD_OVERRIDE" -eq 1 ] && [ -f "./compose/gpu-amd.override.yml" ]; then
    compose_files+=("compose/gpu-amd.override.yml")
fi

# Deduplicate while preserving order
unique_files=()
for _f in "${compose_files[@]}"; do
    skip=0
    for _u in "${unique_files[@]}"; do
        if [ "$_u" = "$_f" ]; then
            skip=1
            break
        fi
    done
    if [ $skip -eq 0 ]; then
        unique_files+=("$_f")
    fi
done

if [ ${#unique_files[@]} -gt 0 ]; then
    COMPOSE_FILES_ARGS=""
    for _f in "${unique_files[@]}"; do
        COMPOSE_FILES_ARGS="$COMPOSE_FILES_ARGS -f $_f"
    done
    # trim leading space
    COMPOSE_FILES_ARGS=$(echo "$COMPOSE_FILES_ARGS" | sed -E 's/^ //')
    echo -e "${CYAN}Compose overlay files: ${COMPOSE_FILES_ARGS}${NC}"
fi

# Helper: attempt to run `docker compose config --services`, and if it fails
# due to undefined dependent services (e.g. "depends on undefined service \"redis\""),
# try to locate compose files under ./compose/ that define the missing service(s),
# add them to the compose file list and retry (up to a few attempts).
resolve_compose_services_with_auto_includes() {
    local attempts=0
    local max_attempts=3
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
    echo "${CYAN}Попытка выполнить: COMPOSE_PROFILES=\"$PROFILE\" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services (попытка $attempts)${NC}"
    svc_out=$(COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services 2>&1)
        rc=$?
        if [ $rc -eq 0 ]; then
            echo "$svc_out"
            return 0
        fi

        # If docker compose returns a 'depends on undefined service' error, try to auto-include files
        missing=$(echo "$svc_out" | grep -oE 'depends on undefined service "[^"]+"' | sed -E 's/.*"([^"]+)"/\1/' | sort -u | tr '\n' ' ')
        if [ -z "$missing" ]; then
            # Not the specific error we can auto-resolve — print and return failure
            echo "$svc_out"
            return $rc
        fi

    echo -e "${YELLOW}Найдены отсутствующие сервисы в конфигурации: ${missing} — пытаюсь найти определяющие файлы в ./compose/...${NC}"

        # For each missing service, search compose/ and root docker-compose.* files for a service definition
        for svc in $missing; do
            # Look for lines like '  redis:' or '^redis:' in yaml files under compose/
            matches=$(grep -R -nE "^[[:space:]]*${svc}:" compose/ 2>/dev/null || true)
            # Also check top-level docker-compose.yml and any other yml in workspace root
            if [ -z "$matches" ]; then
                matches=$(grep -R -nE "^[[:space:]]*${svc}:" docker-compose.yml 2>/dev/null || true)
            fi

            if [ -n "$matches" ]; then
                # Extract unique filenames and add them to unique_files if not present
                while IFS= read -r mf; do
                    skip=0
                    # Skip if already in unique_files
                    for _u in "${unique_files[@]}"; do
                        if [ "$_u" = "$mf" ]; then
                            skip=1; break
                        fi
                    done
                    # Skip if the file is already included by base docker-compose.yml include:
                    if [ $skip -eq 0 ] && [ ${#base_includes[@]} -gt 0 ]; then
                        for inc in "${base_includes[@]}"; do
                            inc_norm=$(echo "$inc" | sed 's#^\./##')
                            mf_norm=$(echo "$mf" | sed 's#^\./##')
                            if [ "$inc_norm" = "$mf_norm" ]; then
                                skip=1; break
                            fi
                        done
                    fi
                    if [ $skip -eq 0 ]; then
                        echo -e "  ${CYAN}Автоматически включаю файл: $mf${NC}"
                        unique_files+=("$mf")
                    fi
                done < <(echo "$matches" | cut -d: -f1 | sort -u)
            else
                echo -e "  ${YELLOW}Не найден файл с определением сервиса '$svc' в ./compose/ или docker-compose.yml${NC}"
            fi
        done

        # Rebuild COMPOSE_FILES_ARGS from updated unique_files
        COMPOSE_FILES_ARGS=""
        for _f in "${unique_files[@]}"; do
            COMPOSE_FILES_ARGS="$COMPOSE_FILES_ARGS -f $_f"
        done
        COMPOSE_FILES_ARGS=$(echo "$COMPOSE_FILES_ARGS" | sed -E 's/^ //')
        echo -e "${CYAN}Новый список Compose overlay файлов: ${COMPOSE_FILES_ARGS}${NC}"
        # Loop will retry
    done

    # if we reach here, attempts exhausted — run once more to show final error
    echo "$svc_out"
    return 1
}

# Ensure traefik ACME volume exists and contains acme.json with proper perms
ensure_traefik_volume() {
    local base_name="traefik_letsencrypt"
    # look for any existing volume that ends with traefik_letsencrypt (project-scoped or global)
    local found_vol
    found_vol=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E '(^|_)traefik_letsencrypt$' | head -n1 || true)
    if [ -z "$found_vol" ]; then
        echo -e "${CYAN}Том для Traefik ACME не найден — создаю docker volume ${base_name}...${NC}"
        docker volume create "$base_name" >/dev/null 2>&1 || {
            echo -e "${YELLOW}${EMOJI_WARN} Не удалось создать том $base_name напрямую — продолжу, Docker Compose может создать project-scoped том.${NC}"
        }
        # find again (either newly created global or project-scoped will be created by compose)
        found_vol=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E '(^|_)traefik_letsencrypt$' | head -n1 || true)
    fi

    if [ -n "$found_vol" ]; then
        # Ensure acme.json exists and has 600 permissions inside the volume
        echo -e "${CYAN}Проверяю /acme.json в томе $found_vol...${NC}"
        docker run --rm -v "$found_vol":/data alpine sh -c 'touch /data/acme.json && chmod 600 /data/acme.json' >/dev/null 2>&1 || true
        echo -e "${GREEN}${EMOJI_OK} Том $found_vol готов (acme.json присутствует с правами 600).${NC}"
    else
        echo -e "${YELLOW}${EMOJI_WARN} Том traefik_letsencrypt не обнаружен и не удалось создать — Docker Compose при старте может создать project-scoped том автоматически.${NC}"
    fi
}

# create traefik volume proactively to avoid interactive prompts
ensure_traefik_volume



# Собираем список образов из результата `docker compose config` и подтягиваем их заранее
pull_required_images() {
    # Allow operator to skip pre-pull with env var
    if [ "${SKIP_PRE_PULL:-}" = "true" ]; then
        echo -e "${YELLOW}SKIP_PRE_PULL=true — пропускаю предварительную загрузку образов.${NC}"
        return 0
    fi

    echo -e "${CYAN}Анализируем конфигурацию Compose и подтягиваем нужные образы (pre-pull)...${NC}"

    # Используем COMPOSE_PROFILES для активации профилей во всех вызовах docker compose

    # Try the simple and robust path first: let docker compose resolve and pull
    # images for the selected profiles. This respects env-file and compose logic.
    # Honor PREFERRED_COMPOSE_PULL env var: if explicitly set to "false", skip this
    # automated compose pull attempt and use manual extraction instead. If set to
    # "true" or unset, attempt compose pull and fall back on error.
    if [ "${PREFERRED_COMPOSE_PULL:-}" != "false" ]; then
    pull_cmd="COMPOSE_PROFILES=\"$PROFILE\" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} pull"
        echo -e "${CYAN}Попытка: ${pull_cmd}${NC}"
        # Execute and capture both output and real exit code
        tmp_pull_out=$(mktemp 2>/dev/null || echo "/tmp/pull.$$.$RANDOM.out")
    if COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} pull >"$tmp_pull_out" 2>&1; then
            pull_rc=0
        else
            pull_rc=$?
        fi
        pull_output=$(cat "$tmp_pull_out" 2>/dev/null || true)
        rm -f "$tmp_pull_out" 2>/dev/null || true

        # Show the raw output to the operator for transparency
        if [ -n "$pull_output" ]; then
            echo "$pull_output"
        fi

        # Parse the output for known failure patterns regardless of exit code
        FAILED_PULLS=()
        # 1) explicit 'pull access denied for <image>' lines
        mapfile -t _f1 < <(printf '%s\n' "$pull_output" | grep -Eo 'pull access denied for [^, ]+' | awk '{print $4}' | sort -u)
        if [ ${#_f1[@]} -gt 0 ]; then
            for i in "${_f1[@]}"; do FAILED_PULLS+=("$i"); done
        fi
        # 2) common daemon error lines containing a registry/image reference
        mapfile -t _f2 < <(printf '%s\n' "$pull_output" | grep -Eo '([a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+)(:[a-zA-Z0-9._-]+)?' | sort -u)
        if [ ${#_f2[@]} -gt 0 ]; then
            for i in "${_f2[@]}"; do
                skip=false
                for existing in "${FAILED_PULLS[@]}"; do
                    if [ "$existing" = "$i" ]; then skip=true; break; fi
                done
                if [ "$skip" = false ] && echo "$pull_output" | grep -i -qE "denied|not found|repository does not exist|access is denied|unauthorized|forbidden|manifest unknown"; then
                    FAILED_PULLS+=("$i")
                fi
            done
        fi

        if [ ${#FAILED_PULLS[@]} -gt 0 ]; then
            echo -e "\n${RED}${EMOJI_ERROR} Обнаружены ошибки при предварительной загрузке образов (docker compose pull):${NC}"
            for f in "${FAILED_PULLS[@]}"; do
                echo -e "  - ${f}"
            done
            if [ "${CONTINUE_ON_PULL_FAILURE:-}" != "true" ]; then
                echo -e "\n${YELLOW}Запуск остановлён до docker compose up из-за неудачных загрузок образов.\nЕсли вы хотите продолжить несмотря на ошибки, установите: ${CYAN}export CONTINUE_ON_PULL_FAILURE=true${NC}"
                return 1
            else
                echo -e "${YELLOW}CONTINUE_ON_PULL_FAILURE=true — продолжаю, несмотря на ошибки предварительной загрузки образов.${NC}"
            fi
        fi

        if [ $pull_rc -eq 0 ]; then
            echo -e "${GREEN}docker compose pull успешно завершён для профилей:${NC} ${PROFILE}"
            return 0
        fi

        echo -e "${YELLOW}docker compose pull вернул ошибку или не поддерживается в этой версии — откат к ручному извлечению образов.${NC}"
    else
        echo -e "${YELLOW}PREFERRED_COMPOSE_PULL=false — пропускаю автоматический 'docker compose pull' и перехожу к ручному извлечению образов.${NC}"
    fi

    images=""

    # Prefer JSON output if supported (newer compose releases)
    config_json=$(COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --format json 2>/dev/null || true)
    if [ -n "$config_json" ]; then
        # Prefer jq for robust JSON parsing
        if command -v jq >/dev/null 2>&1; then
            images=$(printf '%s' "$config_json" | jq -r '.services[]?.image // empty' | sort -u)
        elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
            py=$(command -v python3 >/dev/null 2>&1 && echo python3 || echo python)
            images=$(printf '%s' "$config_json" | $py - <<'PY' 2>/dev/null
import sys, json
try:
    data = json.load(sys.stdin)
    imgs = []
    for s in data.get('services', {}).values():
        img = s.get('image')
        if img:
            imgs.append(img)
    for i in sorted(set(imgs)):
        print(i)
except Exception:
    sys.exit(0)
PY
)
        else
            # Fallback: parse YAML-ish output for lines with "image:"
            config_txt=$(COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config 2>/dev/null || true)
            if [ -n "$config_txt" ]; then
                images=$(echo "$config_txt" | grep -E '^[[:space:]]*image:[[:space:]]*' | sed -E 's/^[[:space:]]*image:[[:space:]]*(.*)/\1/' | sed 's/^"//;s/"$//' | sort -u)
            fi
        fi
    else
        # If JSON not available, fallback to YAML-ish parsing
    config_txt=$(COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config 2>/dev/null || true)
        if [ -n "$config_txt" ]; then
            images=$(echo "$config_txt" | grep -E '^[[:space:]]*image:[[:space:]]*' | sed -E 's/^[[:space:]]*image:[[:space:]]*(.*)/\1/' | sed 's/^"//;s/"$//' | sort -u)
        fi
    fi

    if [ -z "$images" ]; then
        echo -e "${YELLOW}Не найдено явных образов в конфигурации Compose — пропускаю pre-pull.${NC}"
        return 0
    fi

    echo -e "${BLUE}Найденные образы для подтягивания (до подстановки переменных):${NC}"
    echo "$images" | sed 's/^/  - /'

    # Pull images one by one, resolving env vars like ${MY_IMAGE} or $MY_IMAGE
    FAILED_PULLS=()
    for img in $images; do
        # Skip empty lines
        if [ -z "$img" ]; then
            continue
        fi

        resolved="$img"

        # If image contains env var patterns, attempt substitution using envsubst or eval
        if echo "$img" | grep -q '\$\{|\$[A-Za-z_]'; then
            # Prefer envsubst if available (safer than eval for simple substitutions)
            if command -v envsubst >/dev/null 2>&1; then
                # envsubst only substitutes $VAR or ${VAR} for variables present in the environment
                resolved=$(printf '%s' "$img" | envsubst 2>/dev/null || echo "$img")
            else
                # Fallback to eval echo — note: this evaluates shell expansions, so only use
                # after minimal validation. We wrap in printf and suppress errors.
                resolved=$(eval "echo \"$img\"" 2>/dev/null || echo "$img")
            fi

            # If substitution left an unsubstituted ${...} token, warn and skip
            if echo "$resolved" | grep -q '\$\{'; then
                echo -e "${YELLOW}Не удалось полностью разрешить переменные в образе: $img -> $resolved — пропускаю.${NC}"
                continue
            fi

            # If resolved changed, show it
            if [ "$resolved" != "$img" ]; then
                echo -e "${CYAN}Разрешён: ${img} -> ${resolved}${NC}"
            fi
        fi

        echo -e "${CYAN}Подтягиваю образ: ${resolved}${NC}"
        if docker pull "$resolved"; then
            echo -e "${GREEN}Образ $resolved успешно загружен${NC}"
        else
            echo -e "${YELLOW}Не удалось загрузить $resolved — продолжу, но запуск может завершиться ожиданием загрузки образа при docker compose up${NC}"
            FAILED_PULLS+=("$resolved")
        fi
    done

    # If any pulls failed, summarize and suggest actions
    if [ ${#FAILED_PULLS[@]} -gt 0 ]; then
        echo -e "\n${RED}${EMOJI_ERROR} Не удалось загрузить некоторые образы:${NC}"
        for f in "${FAILED_PULLS[@]}"; do
            echo -e "  - ${f}"
        done
        echo -e "\n${YELLOW}Возможные действия: ${NC}"
        echo -e "  - Войти в приватный реестр: ${CYAN}docker login <registry>${NC}"
        echo -e "  - Повторить попытку: ${CYAN}docker pull <image>${NC}"
        echo -e "  - Пропустить предварительную загрузку, установив: ${CYAN}export SKIP_PRE_PULL=true${NC}"
    fi

    return 0
}

if [ -n "$COMPOSE_FILES_ARGS" ]; then
    echo -e "${BLUE}Команда запуска:${NC} COMPOSE_PROFILES=\"$PROFILE\" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} up -d"
    echo -e "${BLUE}Services that compose will consider (config --services):${NC}"
    if ! resolve_compose_services_with_auto_includes; then
        echo -e "${RED}${EMOJI_ERROR} Не удалось получить список сервисов из docker compose (ошибка конфигурации).${NC}"
    fi
    # Pre-pull images required by the compose stack to reduce long image-pull time during up
    if ! pull_required_images; then
        echo -e "${RED}${EMOJI_ERROR} Предварительная загрузка образов завершилась с ошибками. Останавливаю запуск до устранения проблем.${NC}"
        echo -e "${YELLOW}Подсказка: установите ${CYAN}export CONTINUE_ON_PULL_FAILURE=true${NC}, чтобы продолжить запуск несмотря на ошибки (не рекомендуется).${NC}"
        exit 1
    fi
    COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} up -d
else
    echo -e "${BLUE}Команда запуска:${NC} COMPOSE_PROFILES=\"$PROFILE\" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} up -d"
    echo -e "${BLUE}Services that compose will consider (config --services):${NC}"
    if ! resolve_compose_services_with_auto_includes; then
        echo -e "${RED}${EMOJI_ERROR} Не удалось получить список сервисов из docker compose (ошибка конфигурации).${NC}"
    fi
    # Pre-pull images required by the compose stack to reduce long image-pull time during up
    if ! pull_required_images; then
        echo -e "${RED}${EMOJI_ERROR} Предварительная загрузка образов завершилась с ошибками. Останавливаю запуск до устранения проблем.${NC}"
        echo -e "${YELLOW}Подсказка: установите ${CYAN}export CONTINUE_ON_PULL_FAILURE=true${NC}, чтобы продолжить запуск несмотря на ошибки (не рекомендуется).${NC}"
        exit 1
    fi
    COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} up -d
fi

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
    # Dynamic endpoint printer: show public domain (if set), host-published ports and service list
    print_endpoints() {
        echo -e "${BLUE}Доступ к сервисам:${NC}"

        # Try to read domain/port from .env if present
        if [ -f .env ]; then
            N8N_DOMAIN_VAL=$(grep -E '^N8N_DOMAIN=' .env | tail -n1 | cut -d'=' -f2-)
            N8N_PORT_VAL=$(grep -E '^N8N_PORT=' .env | tail -n1 | cut -d'=' -f2-)
        fi
        N8N_PORT_VAL=${N8N_PORT_VAL:-5678}

        if [ -n "${N8N_DOMAIN_VAL}" ]; then
            echo -e "  🌐 N8N (public): ${YELLOW}https://${N8N_DOMAIN_VAL}${NC}"

            # Check domain reachability (HTTPS preferred). Use curl if available.
            if command -v curl >/dev/null 2>&1; then
                    # Prefer HTTPS, fallback to HTTP if HTTPS fails
                    http_code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 7 "https://${N8N_DOMAIN_VAL}" 2>/dev/null || echo "000")
                    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                        echo -e "    ${GREEN}${EMOJI_OK} Публичный домен отвечает по HTTPS: HTTP ${http_code}${NC}"
                    else
                        # Try HTTP as fallback
                        http_code_http=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 5 "http://${N8N_DOMAIN_VAL}" 2>/dev/null || echo "000")
                        if [ "$http_code_http" = "200" ] || [ "$http_code_http" = "301" ] || [ "$http_code_http" = "302" ]; then
                            echo -e "    ${YELLOW}${EMOJI_WARN} HTTPS недоступен, но HTTP отвечает: HTTP ${http_code_http} — проверьте конфиг TLS/Traefik${NC}"
                        else
                            echo -e "    ${YELLOW}${EMOJI_WARN} Публичный домен недоступен (HTTPS код: ${http_code}, HTTP код: ${http_code_http}) — проверьте Traefik/DNS${NC}"
                        fi
                    fi
                else
                    echo -e "    ${YELLOW}curl не установлен — пропущена проверка доступности публичного домена${NC}"
                fi
        fi

        # If the service port is published on the host, show host:port
        hostport=$(docker compose port n8n ${N8N_PORT_VAL} 2>/dev/null || echo "")
        if [ -n "$hostport" ]; then
            echo -e "  🌐 N8N (host): ${YELLOW}http://${hostport}${NC}"
        else
            echo -e "  🌐 N8N (internal): ${YELLOW}http://localhost:${N8N_PORT_VAL}${NC}"
        fi

        # List all services and their published ports (if any)
    services=$(COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services 2>/dev/null || echo "")

        # If Traefik API returned a response, extract exposed services from its JSON
        exposed_services=""
        if [ -n "$tr_resp" ]; then
            # Try to extract service names from the routers JSON if possible
            exposed_services=$(echo "$tr_resp" | grep -o '"service"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"service"[[:space:]]*:[[:space:]]*"([^"]*)"/\1/' | sort -u | tr '\n' ' ')
        fi

        if [ -n "$services" ]; then
            echo -e "${BLUE}  Все сервисы и опубликованные порты:${NC}"
            for s in $services; do
                ports=$(docker ps --filter "name=${s}" --format '{{.Ports}}' | sed 's/,$//' )
                if [ -z "$ports" ]; then
                    marker="${YELLOW}internal${NC}"
                else
                    marker="${YELLOW}${ports}${NC}"
                fi

                # Mark service as public if Traefik exposes it
                if [ -n "$exposed_services" ] && echo " $exposed_services " | grep -qw "${s}"; then
                    echo -e "    - ${s}: ${marker} ${GREEN}(public via Traefik)${NC}"
                else
                    echo -e "    - ${s}: ${marker}"
                fi
            done
        else
            echo -e "  ${YELLOW}Не удалось получить список сервисов (docker compose config вернул ошибку)${NC}"
        fi

        # Traefik dashboard hint
        echo -e "  🚦 Traefik dashboard: ${YELLOW}http://localhost:8080${NC} (проверьте Traefik для публичных роутов)"

        # Try to query Traefik API for routers if curl is available
        if command -v curl >/dev/null 2>&1; then
            echo -e "${BLUE}  Попытка получить роуты из Traefik API...${NC}"
            tr_resp=$(curl -sS --max-time 5 "http://localhost:8080/api/http/routers" 2>/dev/null || echo "")
            if [ -n "$tr_resp" ]; then
                # Show routers that mention the domain (simple text search)
                echo "$tr_resp" | tr -d '\\n' | sed 's/},{/}\n{/g' | grep -i "Host(\`" -n | sed -n '1,10p' || echo -e "    ${YELLOW}Traefik API ответил, но роуты с Host не найдены${NC}"
                # If N8N_DOMAIN_VAL is set, try to find matching router by domain
                if [ -n "${N8N_DOMAIN_VAL}" ]; then
                    matches=$(echo "$tr_resp" | grep -o "Host(\\\`[^\\\`]*\\\`)" | grep -i "${N8N_DOMAIN_VAL}" || true)
                    if [ -n "$matches" ]; then
                        echo -e "    ${GREEN}${EMOJI_OK} Найдены Traefik-роуты для ${N8N_DOMAIN_VAL}:${NC}"
                        echo "$matches" | sed 's/^/      /'
                    else
                        echo -e "    ${YELLOW}Не найдены Traefik-роуты, совпадающие с ${N8N_DOMAIN_VAL}${NC}"
                    fi
                fi
            else
                echo -e "    ${YELLOW}Не удалось получить ответ от Traefik API на localhost:8080 — вероятно dashboard недоступен${NC}"
            fi
        else
            echo -e "    ${YELLOW}curl не установлен — пропущена проверка Traefik API${NC}"
        fi
    }

    # Call the dynamic printer
    print_endpoints

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
        # Optional: auto-create credentials from env before importing workflows
        if [ "${N8N_AUTO_CREATE_CREDENTIALS:-false}" = "true" ]; then
            if [ -x "./scripts/create_n8n_credential.sh" ]; then
                echo -e "${CYAN}${EMOJI_SETUP} Автоматическое создание credential из переменных окружения включено${NC}"
                # Example: create Qdrant credential if QDRANT_URL or QDRANT_API_KEY present
                if [ -n "${QDRANT_URL:-}" ] || [ -n "${QDRANT_API_KEY:-}" ]; then
                    echo "Creating Qdrant credential from env..."
                    set +e
                    ./scripts/create_n8n_credential.sh --token "${N8N_ADMIN_TOKEN:-}" --type qdrantApi --name "${N8N_QDRANT_CREDENTIAL_NAME:-Qdrant API}" --n8n-url "http://${N8N_PROBE_HOST:-127.0.0.1}:${N8N_PORT:-5678}" || true
                    set -e
                fi
                # Add other known credential types here as needed (e.g., S3, redis).
            else
                echo -e "${YELLOW}${EMOJI_WARN} Скрипт ./scripts/create_n8n_credential.sh не найден или не исполняем — пропускаю автоматическое создание credential.${NC}"
            fi
        fi
        if [ "${N8N_AUTO_IMPORT:-false}" != "true" ]; then
            if [ -t 0 ]; then
                echo -e "${YELLOW}${EMOJI_NOTE} Автоматический импорт отключён (N8N_AUTO_IMPORT!=true).${NC}"
                read -r -p "Запустить импорт workflows один раз сейчас? (y/N): " run_import_choice
                run_import_choice=${run_import_choice:-N}
                if [[ "$run_import_choice" =~ ^[Yy]$ ]]; then
                    # prefer local importer script if available
                    LOCAL_IMPORTER="./scripts/import_workflows_to_n8n.sh"
                    if [ -x "$LOCAL_IMPORTER" ]; then
                        echo -e "${BLUE}${EMOJI_SETUP} Запуск локального импортера: $LOCAL_IMPORTER...${NC}"
                        set +e
                        "$LOCAL_IMPORTER" --dir "./n8n/workflows/imported" --token "${N8N_ADMIN_TOKEN:-}" --n8n-url "http://${N8N_PROBE_HOST:-127.0.0.1}:${N8N_PORT:-5678}"
                        rc=$?
                        set -e
                        if [ $rc -eq 0 ]; then
                            echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                        else
                            echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows (локально, код=$rc).${NC}"
                        fi
                    elif COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services 2>/dev/null | grep -q '^n8n-importer$'; then
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
            if COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services 2>/dev/null | grep -q '^n8n-importer$'; then
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
                        # prefer local importer script if available
                        LOCAL_IMPORTER="./scripts/import_workflows_to_n8n.sh"
                        if [ -x "$LOCAL_IMPORTER" ]; then
                            echo -e "${BLUE}${EMOJI_SETUP} Запуск локального импортера: $LOCAL_IMPORTER...${NC}"
                            set +e
                            "$LOCAL_IMPORTER" --dir "./n8n/workflows/imported" --token "${N8N_ADMIN_TOKEN:-}" --n8n-url "http://${N8N_PROBE_HOST:-127.0.0.1}:${N8N_PORT:-5678}"
                            rc=$?
                            set -e
                            if [ $rc -eq 0 ]; then
                                echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                            else
                                echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows (локально, код=$rc).${NC}"
                            fi
                        elif COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services 2>/dev/null | grep -q '^n8n-importer$'; then
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
                    # prefer local importer script if available
                    LOCAL_IMPORTER="./scripts/import_workflows_to_n8n.sh"
                    if [ -x "$LOCAL_IMPORTER" ]; then
                        echo -e "${BLUE}${EMOJI_SETUP} Запуск локального импортера: $LOCAL_IMPORTER...${NC}"
                        set +e
                        "$LOCAL_IMPORTER" --dir "./n8n/workflows/imported" --token "${N8N_ADMIN_TOKEN:-}" --n8n-url "http://${N8N_PROBE_HOST:-127.0.0.1}:${N8N_PORT:-5678}"
                        rc=$?
                        set -e
                        if [ $rc -eq 0 ]; then
                            echo -e "${GREEN}${EMOJI_OK} Импорт workflows успешно завершен.${NC}"
                        else
                            echo -e "${RED}${EMOJI_ERROR} Ошибка во время импорта workflows (локально, код=$rc).${NC}"
                        fi
                    elif COMPOSE_PROFILES="$PROFILE" $DOCKER_COMPOSE_CMD ${ENV_FILE_ARG} ${COMPOSE_FILES_ARGS} config --services 2>/dev/null | grep -q '^n8n-importer$'; then
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
