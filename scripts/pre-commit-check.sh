#!/bin/bash
# =============================================================================
# PRE-COMMIT CHECK SCRIPT
# =============================================================================
# Автоматическая проверка и очистка перед коммитом
# Предотвращает попадание в публичный репозиторий файлов для разработки

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Счетчики
ISSUES_FOUND=0
FILES_TO_IGNORE=0
FILES_TO_DELETE=0

print_header() { echo -e "${CYAN}${BOLD}$1${NC}"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

print_banner() {
    echo
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}                    PRE-COMMIT CLEANUP & VALIDATION${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${GREEN}  Проверяем проект на наличие файлов не предназначенных для публикации${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo
}

# Паттерны пустых файлов, которые допускаются (плейсхолдеры)
declare -a EMPTY_FILE_EXCLUSIONS=(
    ".gitkeep"
    ".keep"
    ".placeholder"
)

# Определение рабочего Python интерпретатора. Устанавливает PYTHON_CMD и PYTHON_ARGS.
detect_python_cmd() {
    PYTHON_CMD=""
    PYTHON_ARGS=""
    # Prefer Windows launcher py -3, then python, then python3
    if command -v py >/dev/null 2>&1; then
        if py -3 -c "import sys" >/dev/null 2>&1; then
            PYTHON_CMD=py
            PYTHON_ARGS='-3'
            return 0
        fi
    fi
    if command -v python >/dev/null 2>&1; then
        if python -c "import sys" >/dev/null 2>&1; then
            PYTHON_CMD=python
            PYTHON_ARGS=''
            return 0
        fi
    fi
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import sys" >/dev/null 2>&1; then
            PYTHON_CMD=python3
            PYTHON_ARGS=''
            return 0
        fi
    fi
    return 1
}

# Предложить и/или запустить Windows bootstrap скрипт (если доступен)
offer_bootstrap() {
    # Only for interactive or AUTO_YES
    if [[ ! -f "scripts/bootstrap-windows.ps1" ]]; then
        return 0
    fi

    # find powershell runner
    POWERSHELL_CMD=""
    if command -v pwsh >/dev/null 2>&1; then
        POWERSHELL_CMD=pwsh
    elif command -v powershell >/dev/null 2>&1; then
        POWERSHELL_CMD=powershell
    fi

    if [[ -z "$POWERSHELL_CMD" ]]; then
        print_warning "Скрипт bootstrap присутствует, но pwsh/powershell не найден — запустите вручную"
        return 0
    fi

    if [[ "${AUTO_YES:-0}" -eq 1 ]]; then
        print_info "AUTO: запускаю bootstrap non-interactive"
        $POWERSHELL_CMD -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-windows.ps1 -Yes || print_warning "bootstrap вернул ошибку"
        return $?
    fi

    read -p "Не найдены требуемые инструменты. Запустить scripts/bootstrap-windows.ps1 сейчас? [y/N]: " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
        $POWERSHELL_CMD -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-windows.ps1 || print_warning "bootstrap вернул ошибку"
    else
        print_warning "bootstrap пропущен пользователем"
    fi
}

# Проверить наличие основных инструментов и при отсутствии предложить bootstrap
ensure_tools_or_offer_bootstrap() {
    local need_bootstrap=0
    if ! detect_python_cmd; then
        print_warning "Python не найден/нерабочий"
        need_bootstrap=1
    fi
    if ! command -v shellcheck >/dev/null 2>&1; then
        print_warning "shellcheck не найден"
        need_bootstrap=1
    fi
    if [[ $need_bootstrap -eq 1 ]]; then
        offer_bootstrap
    fi
}

# Массивы для определения файлов только для разработки
declare -a DEV_ONLY_PATTERNS=(
    # Временные и отладочные файлы
    "*_COMPLETE.md"
    "*_TEST*.md"
    "*_DEBUG*.md"
    "*_TRACE*.md"
    "test_*.sh"
    "debug_*.sh"
    "*.tmp"
    "*.temp"
    "*.bak"

    # Файлы разработчика
    "*TODO*.md"
    "*NOTES*.md"
    "*DRAFT*.md"
    "LOCAL_*.md"
    "MY_*.md"
    "*_local.*"
    "*_temp.*"
    "*_draft.*"

    # Отчеты и логи разработки
    "*_v[0-9]*.md"
    "*SUCCESS*.md"
    "*FINAL*.md"
    "*REPORT*.md"
    "*STAGE*.md"
    "*PLAN*.md"
    "*COMPLETION*.md"
    "*ACCOMPLISHED*.md"
    "*RESOLVED*.md"
    "MISSION_*.md"
    "CRITICAL_*.md"

    # Логи и трассировки
    "*.log"
    "*trace*.log"
    "setup_trace.log"
    "placeholders.log"
    "replacements.txt"

    # Инструкции разработчика
    "copilot-instructions.md"
    "AI_AGENT_GUIDE.md"
    "frontend_analysis_prompt.md"

    # Внутренние скрипты и конфигурации
    "bfg.jar"
    "*.ppk"
    "plink.exe"
    "puttygen.exe"

    # Backup файлы
    "*.yml.bak*"
    "*.yaml.bak*"
    "*.json.bak*"
    "*.md.backup"

    # PowerShell scripts для локального использования
    "scripts/fix-*.ps1"
    "scripts/publish-*.ps1"
    "scripts/*-local.ps1"
)

declare -a DEV_ONLY_DIRECTORIES=(
    "backup/"
    "backups/"
    ".internal/"
    "logs/"
    "ai-instructions/"
    ".github/instructions/"
    "volumes/"
    "data/"
    "n8n/"
    "qdrant_data/"
)

declare -a SENSITIVE_PATTERNS=(
    ".env"
    ".env.*"
    "*.ppk"
    "*password*"
    "*secret*"
    "*key*.pem"
    "*credentials*"
)

# Проверка на пустые файлы
check_empty_files() {
    print_header "🧹 Поиск пустых файлов"

    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")
    if [[ -z "$staged_files" ]]; then
        staged_files=$(git diff --name-only --diff-filter=ACM 2>/dev/null || echo "")
    fi

    if [[ -z "$staged_files" ]]; then
        print_info "Нет файлов для проверки на пустоту"
        return 0
    fi

    local found=0
    echo "$staged_files" | while read -r file; do
        [[ -z "$file" ]] && continue
        # пропускаем явные исключения
        for ex in "${EMPTY_FILE_EXCLUSIONS[@]}"; do
            if [[ "$(basename -- "$file")" == "$ex" ]]; then
                continue 2
            fi
        done
        if [[ -f "$file" && ! -s "$file" ]]; then
            print_warning "Пустой файл: $file"
            ((FILES_TO_DELETE++))
            ((ISSUES_FOUND++))
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        print_success "Пустых файлов не обнаружено"
    else
        mkdir -p .internal
        # Сохраним список пустых файлов для удобства
        git ls-files -z | xargs -0 -I{} bash -c '[[ -f "{}" && ! -s "{}" ]] && echo "{}"' \
            | grep -v -E "($(IFS='|'; echo "${EMPTY_FILE_EXCLUSIONS[*]//./\\.}"))$" \
            > .internal/empty-files.txt 2>/dev/null || true
        print_info "Список пустых файлов (если есть) записан в .internal/empty-files.txt"
    fi
}

# Функция проверки файлов для разработки
check_dev_only_files() {
    print_header "🔍 Проверка файлов только для разработки"

    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null || echo "")

    if [[ -z "$staged_files" ]]; then
        print_warning "Нет файлов в staging area. Проверяем все измененные файлы..."
        staged_files=$(git diff --name-only 2>/dev/null || echo "")
        if [[ -z "$staged_files" ]]; then
            staged_files=$(find . -type f -name "*" | grep -v ".git/" | head -50)
        fi
    fi

    echo "Проверяемые файлы:"
    echo "$staged_files" | head -10
    if [[ $(echo "$staged_files" | wc -l) -gt 10 ]]; then
        echo "... и еще $(($(echo "$staged_files" | wc -l) - 10)) файлов"
    fi
    echo

    # Проверка на файлы только для разработки
    for pattern in "${DEV_ONLY_PATTERNS[@]}"; do
        local matches
        matches=$(echo "$staged_files" | grep -E "$(echo "$pattern" | sed 's/\*/.*/')" || true)

        if [[ -n "$matches" ]]; then
            print_warning "Найдены файлы для разработки (pattern: $pattern):"
            echo "$matches" | while read -r file; do
                if [[ -f "$file" ]]; then
                    echo "  📄 $file"
                    ((FILES_TO_IGNORE++))
                fi
            done
            ((ISSUES_FOUND++))
        fi
    done

    # Проверка директорий только для разработки
    for dir in "${DEV_ONLY_DIRECTORIES[@]}"; do
        local matches
        matches=$(echo "$staged_files" | grep "^$dir" || true)

        if [[ -n "$matches" ]]; then
            print_warning "Найдены файлы в директории для разработки: $dir"
            echo "$matches" | while read -r file; do
                echo "  📁 $file"
                ((FILES_TO_IGNORE++))
            done
            ((ISSUES_FOUND++))
        fi
    done
}

# Функция проверки чувствительных данных
check_sensitive_files() {
    print_header "🔐 Проверка чувствительных данных"

    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null || true)

    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        local matches
        matches=$(echo "$staged_files" | grep -E "$(echo "$pattern" | sed 's/\*/.*/')" || true)

        if [[ -n "$matches" ]]; then
            # filter out common script filenames that include 'env' etc. but are not sensitive
            local filtered_matches
            filtered_matches=$(echo "$matches" | grep -v '^scripts/' || true)
            if [[ -n "$filtered_matches" ]]; then
                print_error "КРИТИЧНО: Найдены чувствительные файлы (pattern: $pattern):"
                echo "$filtered_matches" | while read -r file; do
                    if [[ -f "$file" ]]; then
                        echo "  🔒 $file"
                        ((FILES_TO_IGNORE++))
                    fi
                done
                ((ISSUES_FOUND++))
            fi
        fi
    done
}

# Функция проверки содержимого файлов на чувствительные данные
check_file_content() {
    print_header "📄 Проверка содержимого файлов"

    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null | grep -E "\.(md|yml|yaml|json|sh|ps1|env)$" || true)

    if [[ -z "$staged_files" ]]; then
        return 0
    fi

    local sensitive_keywords=(
        "password.*="
        "secret.*="
        "key.*="
        "token.*="
        "api_key.*="
        "localhost"
        "127.0.0.1"
        "TODO:"
        "FIXME:"
        "DEBUG:"
        "HACK:"
        "TEMP:"
    )

    for file in $staged_files; do
        # Skip scanning internal tooling scripts
        if [[ "$file" == scripts/* ]]; then
            continue
        fi
        if [[ -f "$file" ]]; then
            for keyword in "${sensitive_keywords[@]}"; do
                if grep -q "$keyword" "$file" 2>/dev/null; then
                    print_warning "Найдено подозрительное содержимое в $file: $keyword"
                    grep -n "$keyword" "$file" | head -3 | sed 's/^/    /'
                    ((ISSUES_FOUND++))
                fi
            done
        fi
    done
}

# Форматирование YAML файлов (автоисправление)
format_yaml_files() {
    print_header "🔧 Форматирование YAML файлов"

    # Собираем изменённые/staged yaml файлы
    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null | grep -E "\.(yml|yaml)$" || true)
    if [[ -z "$staged_files" ]]; then
        staged_files=$(git diff --name-only 2>/dev/null | grep -E "\.(yml|yaml)$" || true)
    fi

    if [[ -z "$staged_files" ]]; then
        print_info "Нет изменений в YAML файлах"
        return 0
    fi

    # Determine python command (py -3, python, python3)
    if ! detect_python_cmd; then
        print_warning "Python не найден или нерабочий — пропускаем форматирование YAML"
        return 0
    fi

    if [[ ! -f "scripts/format-yaml.py" ]]; then
        print_warning "Форматтер scripts/format-yaml.py не найден — пропускаем"
        return 0
    fi

    local changed=0
    echo "$staged_files" | while read -r f; do
        if [[ -f "$f" ]]; then
            print_info "Форматирование $f"
            if ! $PYTHON_CMD $PYTHON_ARGS scripts/format-yaml.py "$f"; then
                print_warning "Форматирование файла $f не удалось — убедитесь, что установлен python и PyYAML; продолжим"
                # don't treat formatter failure as a hard issue to avoid blocking commits on dev machines
            fi
            git add "$f" 2>/dev/null || true
            changed=1
        fi
    done

    if [[ $changed -eq 1 ]]; then
        print_success "YAML файлы форматированы и добавлены в индекс"
    fi
}

# Функция автоматического исправления .gitignore
update_gitignore() {
    print_header "📝 Обновление .gitignore"

    if [[ ! -f .gitignore ]]; then
        print_warning ".gitignore не найден, создаем..."
        touch .gitignore
    fi

    # Проверяем что важные паттерны есть в .gitignore
    local important_patterns=(
        "*.log"
        "*.tmp"
        "*.temp"
        "*.bak"
        "*_local.*"
        "*_temp.*"
        "*_draft.*"
        "*TODO*.md"
        "*NOTES*.md"
        "*DRAFT*.md"
        "LOCAL_*.md"
        "copilot-instructions.md"
        "ai-instructions/"
        "backup/"
        ".internal/"
        "tests/"
        "*.ppk"
        ".env"
        ".env.*"
        "!.env.example"
    )

    local added_patterns=0
    for pattern in "${important_patterns[@]}"; do
        if ! grep -q "^$pattern$" .gitignore 2>/dev/null; then
            echo "$pattern" >> .gitignore
            print_info "Добавлен паттерн в .gitignore: $pattern"
            ((added_patterns++))
        fi
    done

    if [[ $added_patterns -gt 0 ]]; then
        print_success "Добавлено $added_patterns паттернов в .gitignore"
    else
        print_success ".gitignore актуален"
    fi
}

# Функция создания отчета
generate_report() {
    print_header "📊 Отчет о проверке"

    local report_file=".internal/pre-commit-report-$(date +%Y%m%d_%H%M%S).md"
    mkdir -p .internal

    cat > "$report_file" << EOF
# Pre-Commit Check Report

Дата: $(date)
Ветка: $(git branch --show-current 2>/dev/null || echo "unknown")

## Статистика
- Найдено проблем: $ISSUES_FOUND
- Файлов для игнорирования: $FILES_TO_IGNORE
- Файлов для удаления: $FILES_TO_DELETE

## Рекомендации
$(if [[ $ISSUES_FOUND -gt 0 ]]; then
    echo "- Проверьте найденные файлы"
    echo "- Добавьте их в .gitignore если нужно"
    echo "- Удалите временные файлы"
else
    echo "- Все проверки пройдены успешно"
fi)

## Проверенные файлы
\`\`\`
$(git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null || echo "No files")
\`\`\`
EOF

    print_info "Отчет сохранен: $report_file"
}

# Функция интерактивного исправления
interactive_fix() {
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        print_success "Проблем не найдено!"
        return 0
    fi

    print_header "🛠️ Интерактивное исправление"
    echo "Найдено проблем: $ISSUES_FOUND"
    echo
    echo "Выберите действие:"
    echo "1) Показать рекомендации"
    echo "2) Автоматически обновить .gitignore"
    echo "3) Создать список файлов для ручной проверки"
    echo "4) Продолжить без исправлений"
    echo "5) Отменить коммит"

    read -p "Ваш выбор (1-5): " choice

    case $choice in
        1)
            print_info "Рекомендации по исправлению:"
            echo "- Добавьте найденные файлы в .gitignore"
            echo "- Удалите временные файлы командой: git clean -fd"
            echo "- Проверьте содержимое файлов на чувствительные данные"
            ;;
        2)
            update_gitignore
            print_success "Обновлен .gitignore. Запустите проверку заново."
            ;;
        3)
            echo "Создаем список файлов для проверки..."
            git diff --cached --name-only > .internal/files-to-check.txt 2>/dev/null || true
            git diff --name-only >> .internal/files-to-check.txt 2>/dev/null || true
            print_info "Список сохранен в .internal/files-to-check.txt"
            ;;
        4)
            print_warning "Продолжаем без исправлений..."
            return 0
            ;;
        5)
            print_error "Коммит отменен пользователем"
            exit 1
            ;;
        *)
            print_error "Неверный выбор"
            exit 1
            ;;
    esac
}

# Основная функция
install_deps() {
    print_header "⚙️ Установка зависимостей (python, pip, PyYAML, shellcheck)"

    # only run interactively unless AUTO_YES is set
    if [[ ! -t 0 && "${AUTO_YES:-0}" -ne 1 ]]; then
        print_warning "Неинтерактивная среда и не задан --yes — пропускаем попытку установки зависимостей"
        return 0
    fi

    # detect platform
    UNAME=$(uname -s 2>/dev/null || echo "")
    IS_WINDOWS=0
    if echo "$UNAME" | grep -qiE "mingw|msys|cygwin"; then
        IS_WINDOWS=1
    fi

    # helper to run commands with confirmation
    ask_and_run() {
        local cmd="$1"
        echo
        print_info "Будет выполнена команда: $cmd"
        if [[ "${AUTO_YES:-0}" -eq 1 ]]; then
            print_info "Запуск в неинтерактивном режиме (--yes)"
            set +e
            eval "$cmd"
            local rc=$?
            set -euo pipefail
            if [[ $rc -ne 0 ]]; then
                print_warning "Команда вернула код $rc"
            else
                print_success "Команда выполнена успешно"
            fi
            return
        fi
        read -p "Выполнить? [y/N]: " yn
        if [[ "$yn" =~ ^[Yy] ]]; then
            set +e
            eval "$cmd"
            local rc=$?
            set -euo pipefail
            if [[ $rc -ne 0 ]]; then
                print_warning "Команда вернула код $rc"
            else
                print_success "Команда выполнена успешно"
            fi
        else
            print_warning "Пропущено пользователем"
        fi
    }

    # Python
    if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || command -v py >/dev/null 2>&1; then
        print_info "Python уже установлен"
    else
        if [[ $IS_WINDOWS -eq 1 ]]; then
            if command -v winget >/dev/null 2>&1; then
                ask_and_run "winget install --id=Python.Python.3 --source=winget"
            elif command -v choco >/dev/null 2>&1; then
                ask_and_run "choco install python -y"
            else
                print_warning "Не найден winget/choco. Установите Python вручную: https://www.python.org/downloads/"
            fi
        else
            if command -v apt-get >/dev/null 2>&1; then
                ask_and_run "sudo apt-get update && sudo apt-get install -y python3 python3-pip"
            else
                print_warning "Автоустановка Python не поддерживается для этой ОС. Установите вручную."
            fi
        fi
    fi

    # shellcheck
    if command -v shellcheck >/dev/null 2>&1; then
        print_info "shellcheck уже установлен"
    else
        if [[ $IS_WINDOWS -eq 1 ]]; then
            if command -v scoop >/dev/null 2>&1; then
                ask_and_run "scoop install shellcheck"
            elif command -v choco >/dev/null 2>&1; then
                ask_and_run "choco install shellcheck -y"
            elif command -v winget >/dev/null 2>&1; then
                ask_and_run "winget install --id=ShellCheck.ShellCheck -s winget"
            else
                print_warning "Не найден менеджер пакетов (scoop/choco/winget). Установите shellcheck вручную."
            fi
        else
            if command -v apt-get >/dev/null 2>&1; then
                ask_and_run "sudo apt-get install -y shellcheck"
            else
                print_warning "Автоустановка shellcheck не поддерживается для этой ОС. Установите вручную."
            fi
        fi
    fi

    # PyYAML via requirements using detected python
    if detect_python_cmd; then
        if [[ -f requirements.txt ]]; then
            ask_and_run "$PYTHON_CMD $PYTHON_ARGS -m pip install --upgrade pip && $PYTHON_CMD $PYTHON_ARGS -m pip install -r requirements.txt"
        else
            ask_and_run "$PYTHON_CMD $PYTHON_ARGS -m pip install PyYAML"
        fi
    else
        print_warning "Python не найден, пропускаем установку PyYAML"
    fi

    print_success "Попытка установки зависимостей завершена (см. выше результаты)."
}

main() {
    print_banner
        # Parse flags
        AUTO_YES=0
        INSTALL_DEPS=0
        for arg in "$@"; do
            case "$arg" in
                --install-deps)
                    INSTALL_DEPS=1
                    ;;
                --yes|-y|--non-interactive)
                    AUTO_YES=1
                    ;;
                *)
                    ;;
            esac
        done

        if [[ "${INSTALL_DEPS:-0}" -eq 1 ]]; then
            install_deps
        fi

    # Проверки
    format_yaml_files
    check_dev_only_files
    check_empty_files
    check_sensitive_files
    check_file_content

    # Генерация отчета
    generate_report

    # Интерактивное исправление
    if [[ "${1:-}" != "--auto" ]]; then
        interactive_fix
    fi

    # Финальная проверка
    if [[ $ISSUES_FOUND -gt 0 ]]; then
        print_warning "Найдены проблемы. Рекомендуется исправить их перед коммитом."
        if [[ "${1:-}" == "--strict" ]]; then
            print_error "Строгий режим: коммит заблокирован"
            exit 1
        fi
    else
        print_success "Все проверки пройдены! Можно делать коммит."
    fi

    echo
    print_info "Для автоматической проверки добавьте в pre-commit hook:"
    print_info "echo './scripts/pre-commit-check.sh --auto' > .git/hooks/pre-commit"
    print_info "chmod +x .git/hooks/pre-commit"
}

# Запуск
main "$@"


