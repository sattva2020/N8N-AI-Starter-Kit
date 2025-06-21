#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\tests\ubuntu_24_testing.sh

# Скрипт для автоматизированного тестирования N8N AI Starter Kit на Ubuntu 24.01
# Основан на документе UBUNTU_24_TESTING.md

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Файл для отчета
LOG_FILE="$(pwd)/test_report_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="$(pwd)/test_report_$(date +%Y%m%d_%H%M%S).md"

# Функция для логирования
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Функция для создания отчета
report() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"
    
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ ${test_name}: Успешно${NC}"
        echo "- **${test_name}**: ✅ Успешно" >> "$REPORT_FILE"
    else
        echo -e "${RED}❌ ${test_name}: Неуспешно${NC}"
        echo "- **${test_name}**: ❌ Неуспешно" >> "$REPORT_FILE"
    fi
    
    if [ -n "$details" ]; then
        echo -e "   ${details}"
        echo "  - Детали: ${details}" >> "$REPORT_FILE"
    fi
}

# Функция запуска теста с измерением времени
run_test() {
    local test_name="$1"
    local command="$2"
    local description="${3:-Выполнение команды}"
    
    echo -e "\n${BLUE}==== Тест: ${test_name} ====${NC}"
    echo -e "${YELLOW}${description}${NC}"
    log "Начало теста: ${test_name}"
    
    local start_time=$(date +%s)
    
    # Выполнение команды и перехват вывода и кода возврата
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Завершение теста: ${test_name}, продолжительность: ${duration}с, код возврата: ${exit_code}"
    
    if [ $exit_code -eq 0 ]; then
        report "$test_name" "SUCCESS" "Время выполнения: ${duration}с"
    else
        report "$test_name" "FAILURE" "Код ошибки: ${exit_code}, Время выполнения: ${duration}с"
        log "Ошибка при выполнении теста: ${test_name}. Вывод: ${output}" "ERROR"
    fi
    
    # Добавление вывода команды в лог
    log "Вывод команды: ${output}" "OUTPUT"
    
    return $exit_code
}

# Инициализация отчета
initialize_report() {
    echo "# Отчет о тестировании N8N AI Starter Kit на Ubuntu 24.01" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Дата:** $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "**Система:** $(lsb_release -d | cut -f2)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "## Результаты тестов" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Вывод финального отчета
finalize_report() {
    local success_count=$(grep -c "✅ Успешно" "$REPORT_FILE")
    local failure_count=$(grep -c "❌ Неуспешно" "$REPORT_FILE")
    local total_count=$((success_count + failure_count))
    
    echo "" >> "$REPORT_FILE"
    echo "## Сводка" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- **Всего тестов:** ${total_count}" >> "$REPORT_FILE"
    echo "- **Успешно:** ${success_count}" >> "$REPORT_FILE"
    echo "- **Неуспешно:** ${failure_count}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Полные логи доступны в файле: $LOG_FILE" >> "$REPORT_FILE"
    
    echo -e "\n${BLUE}============ Тестирование завершено ============${NC}"
    echo -e "${BLUE}Всего тестов: ${total_count}${NC}"
    echo -e "${GREEN}Успешно: ${success_count}${NC}"
    echo -e "${RED}Неуспешно: ${failure_count}${NC}"
    echo -e "${BLUE}Отчет сохранен в: ${REPORT_FILE}${NC}"
    echo -e "${BLUE}Полные логи доступны в: ${LOG_FILE}${NC}"
}

# Проверка, что скрипт запущен под Ubuntu
check_ubuntu() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            log "Система: Ubuntu $VERSION_ID"
            return 0
        fi
    fi
    
    log "Этот скрипт предназначен для Ubuntu. Текущая ОС: $(cat /etc/os-release | grep PRETTY_NAME)" "ERROR"
    return 1
}

# Раздел 1: Проверка системных требований
check_system_requirements() {
    echo -e "\n${BLUE}============ Проверка системных требований ============${NC}"
    
    # Проверка версии Ubuntu
    run_test "Проверка версии Ubuntu" "lsb_release -a" "Проверка версии Ubuntu"
    
    # Проверка доступной памяти
    local total_memory=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_memory" -lt 8000 ]; then
        run_test "Проверка памяти" "echo 'Доступно ${total_memory}MB RAM, рекомендуется не менее 8GB'" "Проверка доступной памяти"
    else
        run_test "Проверка памяти" "free -h" "Проверка доступной памяти"
    fi
    
    # Проверка свободного места на диске
    local free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 20000 ]; then
        run_test "Проверка места на диске" "echo 'Свободно ${free_space}MB, рекомендуется не менее 20GB'" "Проверка свободного места"
    else
        run_test "Проверка места на диске" "df -h /" "Проверка свободного места"
    fi
    
    # Проверка процессора
    run_test "Проверка процессора" "lscpu" "Проверка информации о процессоре"
    
    # Проверка GPU (если есть)
    if command -v nvidia-smi &> /dev/null; then
        run_test "Проверка GPU" "nvidia-smi" "Проверка наличия и статуса NVIDIA GPU"
    else
        log "Команда nvidia-smi не найдена. NVIDIA GPU не установлен или драйверы отсутствуют." "WARN"
        echo -e "${YELLOW}Внимание: NVIDIA GPU не обнаружен. Тесты GPU будут пропущены.${NC}"
    fi
}

# Раздел 2: Установка Docker и Docker Compose
install_docker() {
    echo -e "\n${BLUE}============ Установка Docker и Docker Compose ============${NC}"
    
    # Проверка, установлен ли Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker уже установлен:${NC} $(docker --version)"
        log "Docker уже установлен: $(docker --version)"
    else
        # Установка Docker
        echo -e "${YELLOW}Установка Docker...${NC}"
        run_test "Установка зависимостей Docker" "sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl software-properties-common" "Установка необходимых пакетов"
        run_test "Добавление GPG-ключа Docker" "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -" "Добавление официального GPG-ключа Docker"
        run_test "Добавление репозитория Docker" "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"" "Добавление репозитория Docker"
        run_test "Обновление списка пакетов" "sudo apt update" "Обновление списка пакетов"
        run_test "Установка Docker" "sudo apt install -y docker-ce docker-ce-cli containerd.io" "Установка Docker Engine"
    fi
    
    # Проверка, установлен ли Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo -e "${GREEN}Docker Compose уже установлен${NC}"
        log "Docker Compose уже установлен"
    else
        # Установка Docker Compose
        echo -e "${YELLOW}Установка Docker Compose...${NC}"
        run_test "Установка Docker Compose" "sudo apt install -y docker-compose-plugin" "Установка Docker Compose плагина"
    fi
    
    # Добавление пользователя в группу docker
    run_test "Добавление пользователя в группу docker" "sudo usermod -aG docker $USER" "Настройка прав доступа"
    
    echo -e "${YELLOW}Важно: Перезапустите терминал или выполните 'newgrp docker', чтобы применить изменения группы.${NC}"
    log "Пользователь добавлен в группу docker. Требуется перезапуск терминала или выполнить 'newgrp docker'"
}

# Раздел 3: Клонирование репозитория и настройка проекта
clone_repository() {
    echo -e "\n${BLUE}============ Клонирование репозитория ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он клонировать репозиторий
    read -p "Клонировать репозиторий N8N AI Starter Kit? (y/n): " clone_repo
    
    if [[ "$clone_repo" =~ ^[Yy]$ ]]; then
        # Спрашиваем у пользователя, в какую директорию клонировать
        read -p "Введите путь для клонирования (или нажмите Enter для текущей директории): " clone_dir
        
        if [ -z "$clone_dir" ]; then
            clone_dir="./N8N-AI-Starter-Kit"
        fi
        
        # Клонирование репозитория
        run_test "Клонирование репозитория" "git clone --branch v1.0.6 https://github.com/sattva2020/N8N-AI-Starter-Kit.git \"$clone_dir\"" "Клонирование репозитория с тегом v1.0.6"
        
        # Переход в директорию проекта
        cd "$clone_dir" || { log "Не удалось перейти в директорию $clone_dir" "ERROR"; return 1; }
        
        # Установка прав на выполнение для скриптов
        run_test "Установка прав на скрипты" "chmod +x scripts/*.sh" "Установка прав на выполнение для скриптов"
    else
        echo -e "${YELLOW}Пропуск клонирования репозитория.${NC}"
        log "Пропуск клонирования репозитория по запросу пользователя."
    fi
}

# Раздел 4: Тестирование запуска и компонентов
run_setup_script() {
    echo -e "\n${BLUE}============ Запуск скрипта установки ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он запустить скрипт установки
    read -p "Запустить скрипт установки setup.sh? (y/n): " run_setup
    
    if [[ "$run_setup" =~ ^[Yy]$ ]]; then
        # Запуск скрипта установки
        run_test "Запуск скрипта установки" "./scripts/setup.sh" "Запуск скрипта автоматической установки"
    else
        echo -e "${YELLOW}Пропуск скрипта установки.${NC}"
        log "Пропуск скрипта установки по запросу пользователя."
    fi
}

# Запуск профиля CPU
run_cpu_profile() {
    echo -e "\n${BLUE}============ Тестирование профиля CPU ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он запустить профиль CPU
    read -p "Запустить систему с профилем CPU? (y/n): " run_cpu
    
    if [[ "$run_cpu" =~ ^[Yy]$ ]]; then
        # Запуск с профилем CPU
        run_test "Запуск профиля CPU" "./scripts/start.sh cpu" "Запуск системы с профилем CPU"
        
        # Проверка запущенных контейнеров
        run_test "Проверка контейнеров" "docker ps" "Проверка запущенных контейнеров"
        
        # Спрашиваем, хочет ли пользователь проверить логи Ollama
        read -p "Проверить логи контейнера Ollama? (y/n): " check_logs
        
        if [[ "$check_logs" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Отображение логов Ollama (Ctrl+C для выхода)...${NC}"
            docker logs n8n-ai-starter-kit-ollama-1 -f
        fi
    else
        echo -e "${YELLOW}Пропуск запуска профиля CPU.${NC}"
        log "Пропуск запуска профиля CPU по запросу пользователя."
    fi
}

# Загрузка моделей Ollama
preload_models() {
    echo -e "\n${BLUE}============ Загрузка моделей Ollama ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он загрузить модели
    read -p "Загрузить модели для Ollama? (y/n): " load_models
    
    if [[ "$load_models" =~ ^[Yy]$ ]]; then
        # Запуск скрипта предзагрузки моделей
        run_test "Загрузка моделей Ollama" "./scripts/preload-models.sh" "Использование скрипта предзагрузки моделей"
    else
        echo -e "${YELLOW}Пропуск загрузки моделей.${NC}"
        log "Пропуск загрузки моделей по запросу пользователя."
    fi
}

# Тестирование GPU (если доступен)
test_gpu_profile() {
    echo -e "\n${BLUE}============ Тестирование профиля GPU ============${NC}"
    
    # Проверка доступности NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        # Спрашиваем пользователя, хочет ли он протестировать профиль GPU
        read -p "Тестировать профиль GPU-NVIDIA? (y/n): " test_gpu
        
        if [[ "$test_gpu" =~ ^[Yy]$ ]]; then
            # Остановка текущих контейнеров
            run_test "Остановка контейнеров" "docker compose down" "Остановка запущенных контейнеров"
            
            # Запуск с профилем GPU-NVIDIA
            run_test "Запуск профиля GPU-NVIDIA" "./scripts/start.sh gpu-nvidia" "Запуск системы с профилем GPU-NVIDIA"
            
            # Проверка логов на наличие упоминаний GPU
            run_test "Проверка использования GPU" "docker logs n8n-ai-starter-kit-ollama-1 | grep -i \"gpu\"" "Проверка логов Ollama для подтверждения использования GPU"
        else
            echo -e "${YELLOW}Пропуск тестирования профиля GPU-NVIDIA.${NC}"
            log "Пропуск тестирования профиля GPU-NVIDIA по запросу пользователя."
        fi
    else
        echo -e "${YELLOW}NVIDIA GPU не обнаружен. Пропуск тестов GPU.${NC}"
        log "NVIDIA GPU не обнаружен. Пропуск тестов GPU." "WARN"
    fi
}

# Тестирование обновления
test_update() {
    echo -e "\n${BLUE}============ Тестирование обновления ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он протестировать обновление
    read -p "Тестировать обновление системы? (y/n): " test_update
    
    if [[ "$test_update" =~ ^[Yy]$ ]]; then
        # Обновление сервисов
        run_test "Обновление системы" "./scripts/update.sh cpu" "Обновление всех сервисов"
    else
        echo -e "${YELLOW}Пропуск тестирования обновления.${NC}"
        log "Пропуск тестирования обновления по запросу пользователя."
    fi
}

# Тестирование резервного копирования
test_backup() {
    echo -e "\n${BLUE}============ Тестирование резервного копирования ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он протестировать резервное копирование
    read -p "Тестировать резервное копирование? (y/n): " test_backup
    
    if [[ "$test_backup" =~ ^[Yy]$ ]]; then
        # Создание резервной копии
        run_test "Создание резервной копии" "./scripts/backup.sh" "Создание резервной копии"
        
        # Проверка создания файлов резервных копий
        run_test "Проверка файлов резервных копий" "ls -la backups/" "Проверка создания файлов резервных копий"
    else
        echo -e "${YELLOW}Пропуск тестирования резервного копирования.${NC}"
        log "Пропуск тестирования резервного копирования по запросу пользователя."
    fi
}

# Тестирование автоматических исправлений
test_fix_scripts() {
    echo -e "\n${BLUE}============ Тестирование скриптов исправления ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он протестировать скрипты исправления
    read -p "Тестировать скрипты автоматического исправления? (y/n): " test_fix
    
    if [[ "$test_fix" =~ ^[Yy]$ ]]; then
        # Остановка всех сервисов
        run_test "Остановка сервисов" "docker compose down" "Остановка всех сервисов"
        
        # Запуск с автоматическим исправлением проблем
        run_test "Запуск с исправлением проблем" "./scripts/fix-and-start.sh" "Запуск с автоматическим исправлением проблем"
    else
        echo -e "${YELLOW}Пропуск тестирования скриптов исправления.${NC}"
        log "Пропуск тестирования скриптов исправления по запросу пользователя."
    fi
}

# Тестирование профиля developer
test_developer_profile() {
    echo -e "\n${BLUE}============ Тестирование профиля developer ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он протестировать профиль developer
    read -p "Тестировать профиль developer? (y/n): " test_dev
    
    if [[ "$test_dev" =~ ^[Yy]$ ]]; then
        # Остановка всех сервисов
        run_test "Остановка сервисов" "docker compose down" "Остановка всех сервисов"
        
        # Запуск с профилем developer
        run_test "Запуск профиля developer" "./scripts/start.sh developer" "Запуск с профилем developer"
        
        # Проверка дополнительных сервисов
        run_test "Проверка дополнительных сервисов" "docker ps | grep -E 'pgadmin|jupyter'" "Проверка дополнительных сервисов"
    else
        echo -e "${YELLOW}Пропуск тестирования профиля developer.${NC}"
        log "Пропуск тестирования профиля developer по запросу пользователя."
    fi
}

# Тестирование чистой установки
test_clean_install() {
    echo -e "\n${BLUE}============ Тестирование чистой установки ============${NC}"
    
    # Спрашиваем пользователя, хочет ли он протестировать чистую установку
    read -p "Тестировать чистую установку (все данные будут удалены)? (y/n): " test_clean
    
    if [[ "$test_clean" =~ ^[Yy]$ ]]; then
        # Подтверждение
        read -p "Это действие удалит все данные. Вы уверены? (y/n): " confirm_clean
        
        if [[ "$confirm_clean" =~ ^[Yy]$ ]]; then
            # Полная остановка и удаление всех контейнеров, сетей и томов
            run_test "Удаление всех ресурсов" "docker compose down -v" "Полная остановка и удаление всех контейнеров, сетей и томов"
            
            # Очистка неиспользуемых ресурсов Docker
            run_test "Очистка ресурсов Docker" "./scripts/clean-docker.sh" "Очистка неиспользуемых ресурсов Docker"
            
            # Повторная установка с нуля
            run_test "Повторная установка" "./scripts/setup.sh" "Повторная установка с нуля"
            run_test "Запуск после чистой установки" "./scripts/start.sh cpu" "Запуск после чистой установки"
        else
            echo -e "${YELLOW}Операция отменена.${NC}"
            log "Тестирование чистой установки отменено пользователем."
        fi
    else
        echo -e "${YELLOW}Пропуск тестирования чистой установки.${NC}"
        log "Пропуск тестирования чистой установки по запросу пользователя."
    fi
}

# Основная функция
main() {
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}     Тестирование N8N AI Starter Kit        ${NC}"
    echo -e "${BLUE}     на Ubuntu 24.01                        ${NC}"
    echo -e "${BLUE}=============================================${NC}"
    
    # Проверка, что скрипт запущен под Ubuntu
    if ! check_ubuntu; then
        echo -e "${RED}Этот скрипт предназначен для Ubuntu. Выход.${NC}"
        exit 1
    fi
    
    # Инициализация отчета
    initialize_report
    
    # Проверка системных требований
    check_system_requirements
    
    # Установка Docker и Docker Compose
    install_docker
    
    # Спрашиваем пользователя, продолжать ли тестирование
    read -p "Продолжить тестирование? (y/n): " continue_testing
    
    if [[ "$continue_testing" =~ ^[Yy]$ ]]; then
        # Клонирование репозитория и настройка проекта
        clone_repository
        
        # Запуск скрипта установки
        run_setup_script
        
        # Запуск профиля CPU
        run_cpu_profile
        
        # Загрузка моделей Ollama
        preload_models
        
        # Тестирование GPU (если доступен)
        test_gpu_profile
        
        # Тестирование обновления
        test_update
        
        # Тестирование резервного копирования
        test_backup
        
        # Тестирование автоматических исправлений
        test_fix_scripts
        
        # Тестирование профиля developer
        test_developer_profile
        
        # Тестирование чистой установки
        test_clean_install
    else
        echo -e "${YELLOW}Тестирование прервано пользователем.${NC}"
        log "Тестирование прервано пользователем."
    fi
    
    # Финализация отчета
    finalize_report
}

# Запуск основной функции
main