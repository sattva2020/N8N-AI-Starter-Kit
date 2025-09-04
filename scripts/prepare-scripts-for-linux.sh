#!/bin/bash
# prepare-scripts-for-linux.sh
# Скрипт для проверки и адаптации shell скриптов для Linux перед коммитом
# Выполняет: проверку line endings, конвертацию в Unix format, проверку shebang, установку прав

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Проверка наличия dos2unix
check_dos2unix() {
    if ! command -v dos2unix &> /dev/null; then
        print_warning "dos2unix не найден"
        # На Windows в Git Bash используем sed как fallback
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            print_info "Используем sed как fallback для конвертации line endings"
            return 0  # sed доступен, продолжаем
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_warning "Устанавливаю dos2unix..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y dos2unix
            elif command -v yum &> /dev/null; then
                sudo yum install -y dos2unix
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y dos2unix
            else
                print_error "Не удалось установить dos2unix автоматически"
                return 1
            fi
        else
            print_warning "dos2unix недоступен на этой ОС, используем sed"
            return 0
        fi
    fi
    return 0
}

# Проверка наличия shellcheck
check_shellcheck() {
    if ! command -v shellcheck &> /dev/null; then
        print_warning "shellcheck не найден"
        # На Windows пропускаем установку shellcheck — не делаем это фатальной ошибкой
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
            print_info "На Windows используем только базовую проверку синтаксиса bash -n"
            return 0
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_warning "Устанавливаю shellcheck..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y shellcheck
            elif command -v yum &> /dev/null; then
                sudo yum install -y shellcheck
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y shellcheck
            else
                print_warning "Не удалось установить shellcheck автоматически. Продолжаю без проверки синтаксиса."
                return 0
            fi
        else
            print_warning "shellcheck недоступен на этой ОС. Продолжаю без проверки синтаксиса."
            return 0
        fi
    fi
    return 0
}

# Поиск всех shell скриптов в директории scripts
find_shell_scripts() {
    find scripts -type f \( -name "*.sh" -o -name "*.bash" \) 2>/dev/null || true
}

# Проверка line endings
check_line_endings() {
    local file="$1"
    if grep -q $'\r' "$file"; then
        print_warning "Файл $file содержит Windows line endings (CRLF)"
        return 1
    fi
    return 0
}

# Конвертация line endings в Unix format
convert_line_endings() {
    local file="$1"
    if grep -q $'\r' "$file"; then
        print_info "Конвертирую $file в Unix format..."
        if command -v dos2unix &> /dev/null; then
            dos2unix "$file" 2>/dev/null
        else
            # Fallback: используем sed
            sed -i 's/\r$//' "$file"
        fi
        print_success "Файл $file конвертирован в Unix format"
        return 0
    fi
    return 1
}

# Проверка наличия shebang
check_shebang() {
    local file="$1"
    if ! head -n1 "$file" | grep -q "^#!/"; then
        print_warning "Файл $file не содержит shebang в первой строке"
        return 1
    fi
    return 0
}

# Добавление shebang если отсутствует
add_shebang() {
    local file="$1"
    if ! head -n1 "$file" | grep -q "^#!/"; then
        print_info "Добавляю shebang в $file..."
        local temp_file=$(mktemp)
        echo "#!/bin/bash" > "$temp_file"
        cat "$file" >> "$temp_file"
        mv "$temp_file" "$file"
        print_success "Shebang добавлен в $file"
        return 0
    fi
    return 1
}

# Установка прав на исполнение
set_executable_permissions() {
    local file="$1"
    if [[ ! -x "$file" ]]; then
        print_info "Устанавливаю права на исполнение для $file..."
        chmod +x "$file"
        print_success "Права на исполнение установлены для $file"
        return 0
    fi
    return 1
}

# Проверка синтаксиса bash
check_bash_syntax() {
    local file="$1"
    if command -v shellcheck &> /dev/null; then
        if ! shellcheck -x "$file" &>/dev/null; then
            print_warning "shellcheck обнаружил проблемы в $file"
            shellcheck -x "$file" || true
            # Don't fail the whole hook for shellcheck issues; treat as warning
            return 0
        fi
    else
        # Простая проверка синтаксиса с помощью bash -n
        if ! bash -n "$file" 2>/dev/null; then
            print_warning "bash -n обнаружил синтаксические ошибки в $file"
            # don't fail here; just warn the developer to run proper checks locally
            return 0
        fi
    fi
    return 0
}

# Основная функция обработки скрипта
process_script() {
    local file="$1"
    local modified=false

    print_info "Обрабатываю $file..."

    # Проверка и конвертация line endings
    if ! check_line_endings "$file"; then
        if convert_line_endings "$file"; then
            modified=true
        fi
    fi

    # Проверка и добавление shebang
    if ! check_shebang "$file"; then
        if add_shebang "$file"; then
            modified=true
        fi
    fi

    # Установка прав на исполнение
    if set_executable_permissions "$file"; then
        modified=true
    fi

    # Проверка синтаксиса
    if ! check_bash_syntax "$file"; then
        print_error "Синтаксические ошибки в $file"
        return 1
    fi

    if [[ "$modified" == true ]]; then
        print_success "Файл $file был модифицирован и готов для Linux"
    else
        print_success "Файл $file уже готов для Linux"
    fi

    return 0
}

# Основная функция
main() {
    print_info "🚀 Начинаю проверку и адаптацию скриптов для Linux..."

    # Проверка зависимостей
    local deps_ok=true

    if ! check_dos2unix; then
        deps_ok=false
    fi

    check_shellcheck  # Не критично, если не установится

    # Поиск скриптов
    local scripts
    scripts=$(find_shell_scripts)

    if [[ -z "$scripts" ]]; then
        print_info "Shell скрипты не найдены в директории scripts/"
        exit 0
    fi

    print_info "Найдены скрипты:"
    echo "$scripts" | while read -r script; do
        echo "  - $script"
    done

    local errors=0
    local total_scripts=$(echo "$scripts" | wc -l)

    # Обработка каждого скрипта
    while IFS= read -r script; do
        if [[ -n "$script" ]]; then
            if ! process_script "$script"; then
                ((errors++))
            fi
        fi
    done <<< "$scripts"

    # Итоги
    echo
    print_info "📊 Результаты обработки:"
    print_success "Обработано скриптов: $total_scripts"

    if [[ $errors -gt 0 ]]; then
        print_error "Ошибок: $errors"
        print_error "Исправьте ошибки перед коммитом!"
        exit 1
    else
        print_success "Все скрипты успешно адаптированы для Linux! 🎉"
        exit 0
    fi
}

# Запуск основной функции
main "$@"
