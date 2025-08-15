#!/bin/bash
# filepath: scripts/setup.sh
# Версия: 1.0.6

# Set parallel container limit to prevent concurrent map writes error
export COMPOSE_PARALLEL_LIMIT=1

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Определяем команду timeout (для совместимости с разными системами)
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"  # macOS with coreutils
else
  TIMEOUT_CMD=""  # Будем использовать без таймаута
fi

# Определяем команду docker compose в зависимости от установленной версии - в начале скрипта
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  # Новая команда docker compose (без дефиса) доступна
  DC_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  # Используем старую команду docker-compose (с дефисом)
  DC_CMD="docker-compose"
else
  # По умолчанию используем новый формат, но переопределим позже если нужно
  DC_CMD="docker compose"
fi

print_banner() {
  echo -e "${BLUE}====================================================${NC}"
  echo -e "${BOLD}     N8N AI Starter Kit - Установка и настройка     ${NC}"
  echo -e "${BLUE}====================================================${NC}"
  echo -e "📋 ${YELLOW}Этот скрипт настроит все необходимое для работы N8N AI Starter Kit${NC}\n"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Функция для отображения индикатора прогресса
show_spinner() {
  local pid=$1
  local message=$2
  local delay=0.1
  local spinstr='|/-\'
  echo -e -n "${BLUE}$message${NC} "
  
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "[%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Функция для запуска команды с отображением индикатора прогресса
run_with_spinner() {
  local command="$1"
  local message="$2"
  
  # Запуск команды в фоновом режиме
  eval "$command" &>/dev/null &
  local pid=$!
  
  # Отображение индикатора прогресса
  show_spinner $pid "$message"
  
  # Ожидание завершения команды
  wait $pid
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    print_success "$message: Выполнено!"
  else
    print_error "$message: Ошибка (код $exit_code)"
    return $exit_code
  fi
}

# Определение типа ОС
detect_os() {
  if [ -f /etc/os-release ]; then
    # Загрузка переменных из файла OS-release
    . /etc/os-release
    OS_TYPE=$NAME
    OS_VERSION=$VERSION_ID
    print_info "Обнаружена ОС: $OS_TYPE $OS_VERSION"
  elif [ "$(uname)" == "Darwin" ]; then
    OS_TYPE="macOS"
    OS_VERSION=$(sw_vers -productVersion)
    print_info "Обнаружена ОС: $OS_TYPE $OS_VERSION"
  else
    OS_TYPE="Unknown"
    print_warning "Не удалось определить тип ОС. Будет использован общий метод установки."
  fi
}

# Функция для проверки корректности формата доменного имени
validate_domain_name() {
  local domain=$1
  # Новое регулярное выражение для проверки домена
  local domain_regex="^([a-zA-Z0-9](-?[a-zA-Z0-9]){0,62}\.)+[a-zA-Z]{2,}$"
  if [[ $domain =~ $domain_regex ]]; then
    return 0
  else
    return 1
  fi
}

# Функция для проверки email адреса
validate_email() {
  local email=$1
  # Более строгое регулярное выражение для проверки email
  local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  
  if [[ $email =~ $email_regex ]]; then
    return 0  # Валидный email
  else
    return 1  # Невалидный email
  fi
}

# Функция для создания резервной копии существующей конфигурации
backup_existing_config() {
  if [ -f .env ]; then
    print_info "Создание резервной копии файла .env..."
    local backup_dir="./backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp .env "$backup_dir/.env.backup"
    print_success "Резервная копия .env сохранена в $backup_dir"
    
    # Если существуют другие важные файлы конфигурации, копируем их тоже
    if [ -f docker-compose.override.yml ]; then
      cp docker-compose.override.yml "$backup_dir/docker-compose.override.yml.backup"
      print_success "Резервная копия docker-compose.override.yml сохранена"
    fi
    
    return 0  # Успешное создание резервной копии
  else
    print_info "Файла .env не существует, резервная копия не требуется"
    return 1  # Резервная копия не создана, так как файла нет
  fi
}

# Функция для установки необходимых утилит
install_required_utils() {
  print_info "Проверка и установка необходимых утилит..."
  
  # Список необходимых утилит
  local utils=("curl" "openssl")
  local missing_utils=()
  
  # Проверяем наличие каждой утилиты
  for util in "${utils[@]}"; do
    if ! command -v "$util" &> /dev/null; then
      missing_utils+=("$util")
    fi
  done
  
  # Если есть отсутствующие утилиты, устанавливаем их
  if [ ${#missing_utils[@]} -gt 0 ]; then
    print_warning "Отсутствуют следующие утилиты: ${missing_utils[*]}"
    read -p "Установить отсутствующие утилиты? (y/n): " install_utils
    
    if [ "$install_utils" = "y" ]; then
      if [[ "$OS_TYPE" == *"Ubuntu"* ]] || [[ "$OS_TYPE" == *"Debian"* ]]; then
        print_info "Установка утилит на Ubuntu/Debian..."
        run_with_spinner "sudo apt-get update" "Обновление списка пакетов"
        run_with_spinner "sudo apt-get install -y ${missing_utils[*]}" "Установка утилит"
      elif [[ "$OS_TYPE" == *"CentOS"* ]] || [[ "$OS_TYPE" == *"RHEL"* ]]; then
        print_info "Установка утилит на CentOS/RHEL..."
        run_with_spinner "sudo yum install -y ${missing_utils[*]}" "Установка утилит"
      elif [[ "$OS_TYPE" == *"Fedora"* ]]; then
        print_info "Установка утилит на Fedora..."
        run_with_spinner "sudo dnf install -y ${missing_utils[*]}" "Установка утилит"
      elif [[ "$OS_TYPE" == "macOS" ]]; then
        if command -v brew &> /dev/null; then
          print_info "Установка утилит на macOS с помощью Homebrew..."
          run_with_spinner "brew install ${missing_utils[*]}" "Установка утилит"
        else
          print_warning "Homebrew не установлен. Рекомендуется установить Homebrew для простой установки пакетов на macOS."
          print_info "Установите Homebrew: https://brew.sh"
        fi
      else
        print_error "Не удаётся определить, как установить утилиты на вашей ОС."
        print_info "Пожалуйста, установите следующие утилиты вручную: ${missing_utils[*]}"
      fi
    else
      print_warning "Установка отменена пользователем. Скрипт может работать некорректно без необходимых утилит."
    fi
  else
    print_success "Все необходимые утилиты установлены!"
  fi
}

# Функция для проверки сетевого подключения
check_network_connectivity() {
  print_info "Проверка сетевого подключения..."
  
  # Проверка доступности Docker Hub
  if curl -s --connect-timeout 5 https://registry.hub.docker.com/_ping > /dev/null; then
    print_success "Соединение с Docker Hub: OK"
  else
    print_warning "Не удается подключиться к Docker Hub. Это может вызвать проблемы при загрузке образов."
  fi
  
  # Проверка доступности GitHub (для загрузки Docker Compose)
  if curl -s --connect-timeout 5 https://api.github.com > /dev/null; then
    print_success "Соединение с GitHub: OK"
  else
    print_warning "Не удается подключиться к GitHub. Это может вызвать проблемы при установке Docker Compose."
  fi
  
  # Проверка доступности Let's Encrypt (для SSL-сертификатов)
  if curl -s --connect-timeout 5 https://acme-v02.api.letsencrypt.org/directory > /dev/null; then
    print_success "Соединение с Let's Encrypt: OK"
  else
    print_warning "Не удается подключиться к Let's Encrypt. Это может вызвать проблемы при получении SSL-сертификатов."
  fi
}

# Функция для проверки доступности портов
check_port_availability() {
  print_info "Проверка доступности портов..."
  
  local port_issues=false
  
  # Проверяем порты 80 и 443, необходимые для Traefik и Let's Encrypt
  for port in 80 443; do
    print_info "Проверка порта $port..."
    
    # На Linux используем ss или netstat
    if command -v ss &> /dev/null; then
      if ss -tuln | grep -q ":$port "; then
        print_error "Порт $port уже используется другой программой."
        port_issues=true
      else
        print_success "Порт $port доступен."
      fi
    elif command -v netstat &> /dev/null; then
      if netstat -tuln | grep -q ":$port "; then
        print_error "Порт $port уже используется другой программой."
        port_issues=true
      else
        print_success "Порт $port доступен."
      fi
    # В macOS проверяем через lsof
    elif command -v lsof &> /dev/null; then
      if lsof -i :$port -sTCP:LISTEN &> /dev/null; then
        print_error "Порт $port уже используется другой программой."
        port_issues=true
      else
        print_success "Порт $port доступен."
      fi
    else
      print_warning "Не удалось проверить доступность порта $port. Убедитесь, что порты 80 и 443 не заняты другими программами."
    fi
  done
  
  if [ "$port_issues" = true ]; then
    print_warning "Обнаружены проблемы с портами. Traefik требует доступные порты 80 и 443 для работы с Let's Encrypt и SSL."
    print_info "Вы можете продолжить установку, но могут возникнуть проблемы с SSL-сертификатами."
    
    # В интерактивном режиме более подробно объясняем
    if [ "$SETUP_MODE" = "interactive" ]; then
      print_info "💡 В интерактивном режиме вы сможете настроить альтернативные порты или отключить SSL."
      read -p "Продолжить установку? (Y/n): " continue_setup
      continue_setup=${continue_setup:-Y}  # По умолчанию Y
    else
      read -p "Продолжить установку? (y/n): " continue_setup
    fi
    
    if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
      print_info "Установка прервана пользователем."
      exit 1
    fi
  fi
}

# Проверка доступной памяти
check_memory_requirements() {
  print_info "Проверка доступной памяти..."
  
  if command -v free &> /dev/null; then
    # На Linux используем free
    total_mem=$(free -m | awk '/^Mem:/ {print $2}')
    print_info "Доступная память: ${total_mem} МБ"
    
    if [ "$total_mem" -lt 4000 ]; then
      print_warning "У вас меньше 4 ГБ памяти. Это может вызвать проблемы при запуске нескольких сервисов."
      print_info "Рекомендуется использовать базовый профиль: --profile cpu"
    elif [ "$total_mem" -lt 8000 ]; then
      print_info "У вас 4-8 ГБ памяти. Это достаточно для основных сервисов."
      print_info "Рекомендуется стандартный профиль: --profile cpu"
    else
      print_success "У вас более 8 ГБ памяти. Отлично подходит для всех профилей."
    fi
  elif command -v sysctl &> /dev/null && [ "$(uname)" == "Darwin" ]; then
    # На macOS используем sysctl
    total_mem=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024)}')
    print_info "Доступная память: ${total_mem} МБ"
    
    if [ "$total_mem" -lt 4000 ]; then
      print_warning "У вас меньше 4 ГБ памяти. Это может вызвать проблемы при запуске нескольких сервисов."
      print_info "Рекомендуется использовать базовый профиль: --profile cpu"
    elif [ "$total_mem" -lt 8000 ]; then
      print_info "У вас 4-8 ГБ памяти. Это достаточно для основных сервисов."
      print_info "Рекомендуется стандартный профиль: --profile cpu"
    else
      print_success "У вас более 8 ГБ памяти. Отлично подходит для всех профилей."
    fi
  else
    print_warning "Не удалось определить доступную память."
    print_info "Рекомендуется минимум 4 ГБ для базовых профилей и 8+ ГБ для расширенных профилей."
  fi
}

# Проверка CPU ресурсов
check_cpu_resources() {
  print_info "Проверка CPU ресурсов..."
  
  if command -v nproc &> /dev/null; then
    # На Linux используем nproc
    cpu_cores=$(nproc)
    print_info "Доступно CPU ядер: ${cpu_cores}"
    
    if [ "$cpu_cores" -lt 2 ]; then
      print_warning "У вас менее 2 ядер CPU. Это может вызвать проблемы с производительностью."
      print_info "Рекомендуется использовать базовый профиль: --profile cpu"
    elif [ "$cpu_cores" -lt 4 ]; then
      print_info "У вас 2-3 ядра CPU. Это достаточно для основных сервисов."
      print_info "Рекомендуется стандартный профиль: --profile cpu"
    else
      print_success "У вас ${cpu_cores} ядер CPU. Отлично подходит для всех профилей."
    fi
  elif command -v sysctl &> /dev/null && [ "$(uname)" == "Darwin" ]; then
    # На macOS используем sysctl
    cpu_cores=$(sysctl -n hw.ncpu)
    print_info "Доступно CPU ядер: ${cpu_cores}"
    
    if [ "$cpu_cores" -lt 2 ]; then
      print_warning "У вас менее 2 ядер CPU. Это может вызвать проблемы с производительностью."
      print_info "Рекомендуется использовать базовый профиль: --profile cpu"
    elif [ "$cpu_cores" -lt 4 ]; then
      print_info "У вас 2-3 ядра CPU. Это достаточно для основных сервисов."
      print_info "Рекомендуется стандартный профиль: --profile cpu"
    else
      print_success "У вас ${cpu_cores} ядер CPU. Отлично подходит для всех профилей."
    fi
  else
    print_warning "Не удалось определить количество CPU ядер."
    print_info "Рекомендуется минимум 2 ядра для базовых и 4+ ядра для расширенных профилей."
  fi
}

# Функция для клонирования дополнительных репозиториев с workflow'ами
clone_official_workflows() {
  print_info "📥 Клонирование официального репозитория n8n workflows..."
  
  # Официальный репозиторий с workflow'ами от Zie619
  local repo_url="https://github.com/Zie619/n8n-workflows.git"
  local target_dir="n8n-workflows"
  
  if [ -d "$target_dir" ]; then
    print_info "📁 Репозиторий уже существует, обновляем..."
    cd "$target_dir"
    if git pull origin main >/dev/null 2>&1; then
      print_success "✅ Репозиторий обновлен: $target_dir"
    else
      print_warning "⚠️ Не удалось обновить репозиторий $target_dir"
    fi
    cd ..
  else
    print_info "📥 Клонирование репозитория n8n-workflows..."
    if git clone "$repo_url" "$target_dir" >/dev/null 2>&1; then
      print_success "✅ Успешно склонирован репозиторий: $target_dir"
      
      # Проверяем наличие папки workflows
      if [ -d "$target_dir/workflows" ]; then
        local workflow_count=$(find "$target_dir/workflows" -name "*.json" | wc -l)
        print_info "📊 Найдено $workflow_count workflow'ов"
      fi
    else
      print_warning "⚠️ Не удалось клонировать репозиторий $repo_url"
      print_info "🔍 Проверьте подключение к интернету или доступность репозитория"
    fi
  fi
  
  # Копирование workflows в n8n директорию
  print_info "📋 Копирование workflows в n8n директорию..."
  mkdir -p n8n/workflows
  if [ -d "$target_dir/workflows" ]; then
    cp -r "$target_dir/workflows/"* n8n/workflows/ 2>/dev/null || print_warning "⚠️ Нет workflows для копирования"
    print_success "✅ Workflows скопированы в n8n/workflows/"
  fi
  
  # Создание credentials директории
  mkdir -p n8n/credentials
  print_success "✅ Workflows готовы к импорту"
  
  # Запуск веб-сервиса документации
  print_info "🌐 Запуск веб-сервиса документации workflows..."
  if docker compose build workflows-doc >/dev/null 2>&1; then
    print_success "✅ Образ workflows-doc собран"
    print_info "📖 Веб-интерфейс будет доступен по адресу: http://localhost:8000"
    print_info "🔍 Используйте веб-интерфейс для просмотра и поиска workflow'ов"
  else
    print_warning "⚠️ Не удалось собрать образ workflows-doc"
  fi
}

# Функция для создания файла с советами по устранению неполадок
create_troubleshooting_file() {
  print_info "Создание файла с советами по устранению неполадок..."
  
  cat > TROUBLESHOOTING.local.md << EOF
# Устранение неполадок N8N AI Starter Kit

## Общие проблемы и решения

### Docker и Docker Compose

- **Ошибка "Permission denied"**
  - Убедитесь, что пользователь добавлен в группу docker: \`sudo usermod -aG docker \$USER\`
  - Перезагрузите систему или выполните: \`newgrp docker\`

- **Проблемы с DNS в контейнерах**
  - Создайте/измените файл \`/etc/docker/daemon.json\`:
    \`\`\`json
    {
      "dns": ["8.8.8.8", "8.8.4.4"]
    }
    \`\`\`
  - Перезапустите Docker: \`sudo systemctl restart docker\`

- **Ошибка "Error starting userland proxy"**
  - Порты уже используются другими приложениями
  - Проверьте занятые порты: \`netstat -tuln\` или \`lsof -i :80\` (для порта 80)

### Traefik и SSL

- **Проблемы с получением SSL-сертификатов**
  - Убедитесь, что порты 80 и 443 доступны из интернета
  - Проверьте правильность настройки DNS для вашего домена
  - Используйте staging-режим Let's Encrypt (добавьте \`--acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory\` в параметры Traefik)

- **Ошибка "too many certificates already issued"**
  - У Let's Encrypt есть ограничения на количество сертификатов. Подождите неделю или используйте другой домен

### N8N и другие сервисы

- **N8N не может подключиться к Postgres**
  - Убедитесь, что контейнер postgres запущен: \`docker ps | grep postgres\`
  - Проверьте логи postgres: \`docker logs n8n-ai-starter-kit-postgres\`

- **Проблемы с Ollama**
  - Для работы с GPU убедитесь, что установлен nvidia-container-toolkit
  - Для больших моделей увеличьте лимиты памяти в docker-compose.override.yml

- **Недостаточно памяти или CPU**
  - Используйте базовый профиль: \`docker compose --profile cpu up -d\`
  - Закройте другие ресурсоемкие программы
  - Увеличьте размер swap-файла в Linux

## Полезные команды

- Просмотр логов: \`docker compose logs -f [service_name]\`
- Перезапуск сервиса: \`docker compose restart [service_name]\`
- Проверка статуса контейнеров: \`docker compose ps\`
- Проверка сети Docker: \`docker network inspect n8n-ai-starter-kit_default\`
- Проверка использования ресурсов: \`docker stats\`

## Контактная информация

- GitHub: https://github.com/n8n-io/n8n
- Документация: https://docs.n8n.io/
- Telegram: https://t.me/n8n_ru

Создан $(date)
EOF

  print_success "Файл TROUBLESHOOTING.local.md успешно создан!"
}

# Проверка здоровья Docker
# Проверка здоровья Docker
docker_error_help() {
  if [ "$(uname)" == "Darwin" ]; then
    print_info "Для macOS: Запустите приложение Docker Desktop."
  elif [[ "$(uname -r)" == *"microsoft"* ]] || [[ "$(uname -r)" == *"WSL"* ]]; then
    print_info "Для WSL: Запустите Docker Desktop в Windows."
    print_info "Убедитесь, что в настройках Docker Desktop включен 'Use the WSL 2 based engine'."
  else
    print_info "Попробуйте выполнить: sudo systemctl start docker"
    print_info "Или добавьте текущего пользователя в группу docker: sudo usermod -aG docker $USER"
    print_info "После добавления в группу выполните: newgrp docker"
  fi
}

docker_permission_help() {
  if [[ "$(uname -r)" == *"microsoft"* ]] || [[ "$(uname -r)" == *"WSL"* ]]; then
    print_info "Для WSL: Убедитесь, что Docker Desktop запущен в Windows."
  else
    print_info "Добавьте текущего пользователя в группу docker: sudo usermod -aG docker $USER"
    print_info "Затем перезагрузите систему или выполните: newgrp docker"
  fi
}

check_docker_health() {
  print_info "Проверка состояния Docker..."
  if ! command -v docker &> /dev/null; then
    print_error "Docker не установлен или не доступен в PATH."
    return 1
  fi
  
  # Проверка запущен ли демон Docker с таймаутом
  print_info "Проверка демона Docker (таймаут 10 сек)..."
  if [ -n "$TIMEOUT_CMD" ]; then
    if $TIMEOUT_CMD 10 docker info &> /dev/null; then
      print_success "Демон Docker работает!"
    else
      print_error "Демон Docker не запущен или недоступен."
      docker_error_help
      return 1
    fi
  else
    # Без таймаута
    if docker info &> /dev/null; then
      print_success "Демон Docker работает!"
    else
      print_error "Демон Docker не запущен или недоступен."
      docker_error_help
      return 1
    fi
  fi
  # Проверка наличия прав у текущего пользователя с таймаутом
  print_info "Проверка прав пользователя Docker (таймаут 5 сек)..."
  if [ -n "$TIMEOUT_CMD" ]; then
    if $TIMEOUT_CMD 5 docker ps &> /dev/null; then
      print_success "Права пользователя Docker корректны!"
    else
      print_error "У вас недостаточно прав для использования Docker."
      docker_permission_help
      return 1
    fi
  else
    # Без таймаута
    if docker ps &> /dev/null; then
      print_success "Права пользователя Docker корректны!"
    else
      print_error "У вас недостаточно прав для использования Docker."
      docker_permission_help
      return 1
    fi
  fi
  # Быстрая проверка возможности запуска контейнеров (опционально)
  print_info "Быстрая проверка возможности запуска контейнеров..."
  if [ -n "$TIMEOUT_CMD" ]; then
    if $TIMEOUT_CMD 15 docker run --rm hello-world &> /dev/null; then
      print_success "Docker полностью функционален!"
      docker rmi hello-world &> /dev/null 2>&1
    else
      print_warning "Тест запуска контейнера не прошёл, но Docker может работать."
      print_info "Это может быть связано с сетью или настройками Docker Hub."
      print_info "Попробуйте запустить проект - основной функционал может работать."
    fi
  else
    # Без таймаута - пропускаем эту проверку
    print_warning "Пропуск теста контейнера (timeout недоступен)."
    print_info "Основные проверки Docker прошли успешно."
  fi
  
  print_success "Проверка Docker завершена!"
  return 0
}

# Функция выбора режима работы
choose_setup_mode() {
  echo ""
  print_info "Выберите режим настройки N8N AI Starter Kit:"
  echo ""
  echo "1. 🎯 Интерактивный режим (рекомендуется для новых пользователей)"
  echo "   - Пошаговая настройка всех параметров"
  echo "   - Ввод доменов, паролей и API ключей"
  echo "   - Автоматическая генерация безопасных паролей"
  echo ""
  echo "2. ⚡ Быстрый режим (template.env)"
  echo "   - Использование предустановленных шаблонов"
  echo "   - Подходит для разработки и тестирования"  
  echo "   - Автоматическая настройка с доменами sattva-ai.top"
  echo ""
  
  while true; do
    read -p "Введите номер режима (1-2): " setup_mode
    case $setup_mode in
      1)
        print_success "Выбран интерактивный режим"
        SETUP_MODE="interactive"
        break
        ;;
      2)
        print_success "Выбран быстрый режим (template.env)"
        SETUP_MODE="template"
        break
        ;;
      *)
        print_error "Пожалуйста, выберите 1 или 2"
        continue
        ;;
    esac
  done
}

# Функция для создания .env из template.env
create_env_from_template() {
  # Prefer env.schema.md (new), fall back to template.env for backwards compatibility
  SCHEMA_FILE="env.schema.md"
  if [ ! -f "$SCHEMA_FILE" ]; then
    # Backwards compatibility: try template.env
    if [ -f template.env ]; then
      SCHEMA_FILE="template.env"
    else
      print_error "Файл env.schema.md (или template.env) не найден!"
      print_info "Убедитесь, что вы запускаете скрипт из корневой директории проекта"
      exit 1
    fi
  fi

  print_info "Создание .env файла из $SCHEMA_FILE..."
  
  # Создаем резервную копию если .env уже существует
  if [ -f .env ]; then
    backup_existing_config
  fi
  
  # ВАЖНО: Обработка существующих volumes при создании нового .env
  # Если тома уже существуют, пользователь должен выбрать поведение — синхронизировать
  # существующий пароль из работающего контейнера (без потери данных) или удалить томы
  # и инициализировать БД заново (приведёт к потере данных).
  print_info "Проверка существующих Docker volumes..."
  if docker volume ls | grep -q "postgres_storage"; then
    print_warning "Найден том postgres_storage. Postgres уже инициализирован."
    echo "1) Синхронизировать .env с текущим паролем в работающем контейнере Postgres (без удаления данных)"
    echo "2) Удалить томы и инициализировать БД заново (ВНИМАНИЕ: потеря данных)"
    read -p "Выберите действие (1/2, по-умолчанию 1): " vol_choice
    vol_choice=${vol_choice:-1}

    if [ "$vol_choice" = "2" ]; then
      print_warning "Будут удалены тома n8n_storage и postgres_storage (потеря данных)."
      read -p "Подтвердите удаление томов (type 'DELETE' to confirm): " confirm_del
      if [ "$confirm_del" = "DELETE" ]; then
        if docker volume ls | grep -q "n8n_storage"; then
          docker volume rm n8n-ai-starter-kit_n8n_storage 2>/dev/null || true
          print_success "Данные N8N очищены"
        fi
        docker volume rm n8n-ai-starter-kit_postgres_storage 2>/dev/null || true
        print_success "Данные PostgreSQL очищены"
      else
        print_info "Удаление томов отменено пользователем. Будем пытаться синхронизировать пароль с существующей БД."
        vol_choice=1
      fi
    fi

    if [ "$vol_choice" = "1" ]; then
      # Попытка получить пароль из работающего контейнера Postgres
      existing_pass=""
      # Находим контейнер Postgres запущенный в текущем проекте
      pg_container=$(docker ps --filter "ancestor=pgvector/pgvector:pg17" --format "{{.ID}}" | head -n 1 2>/dev/null || true)
      if [ -z "$pg_container" ]; then
        # Альтернативный поиск по имени контейнера содержащему "postgres"
        pg_container=$(docker ps --filter "name=postgres" --format "{{.ID}}" | head -n 1 2>/dev/null || true)
      fi
      if [ -n "$pg_container" ]; then
        existing_pass=$(docker exec "$pg_container" printenv POSTGRES_PASSWORD 2>/dev/null || true)
      fi

      if [ -n "$existing_pass" ]; then
        print_info "Синхронизируем PostgreSQL пароль из работающего контейнера"
        postgres_pwd="$existing_pass"
      else
        print_warning "Не удалось получить пароль из работающего контейнера Postgres. Будет использован новый сгенерированный пароль."
      fi
    fi
  fi
  
  # Генерируем случайные значения для безопасных переменных
  print_info "Генерация безопасных паролей и ключей..."
  
  # Генерируем пароли и ключи. Если пароль PostgreSQL уже был синхронизирован
  # из работающего контейнера выше (переменная postgres_pwd установлена), не
  # перезаписываем его — используем существующее значение.
  if [ -z "${postgres_pwd:-}" ]; then
    postgres_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
  fi
  n8n_encryption_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
  n8n_api_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
  n8n_jwt_secret=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
  pgadmin_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
  traefik_pwd=$(openssl rand -base64 16 | tr -cd '[:alnum:]' | cut -c1-12)
  traefik_pwd_hash=$(echo -n "${traefik_pwd}" | md5sum | cut -d' ' -f1)
  
  # Создаём .env. Если шаблон template.env существует, используем его и
  # заменяем плейсхолдеры; иначе генерируем полный .env непосредственно.
  if [ -f template.env ]; then
    cp template.env .env
    # Заменяем placeholder значения (глобально с флагом /g)
    sed -i "s/change_this_secure_password_123/${postgres_pwd}/g" .env
    sed -i "s/your_32_char_encryption_key_here_/${n8n_encryption_key}/g" .env
    sed -i "s/your_n8n_api_key_here/${n8n_api_key}/g" .env
    sed -i "s/your_jwt_secret_key_here_min_32_chars/${n8n_jwt_secret}/g" .env
    sed -i "s/pgadmin_secure_password_123/${pgadmin_pwd}/g" .env
    sed -i "s/admin@example.com/admin@sattva-ai.top/g" .env
    sed -i "s/traefik_password_hash_placeholder/${traefik_pwd_hash}/g" .env
    print_success "Файл .env создан из template.env"
  else
    print_info "template.env не найден — создаём .env напрямую"
    cat > .env <<EOF
# Generated .env - N8N AI Starter Kit
DOMAIN_NAME=${DOMAIN_NAME:-sattva-ai.top}

# POSTGRES
POSTGRES_USER=${POSTGRES_USER:-n8n}
POSTGRES_PASSWORD=${postgres_pwd}
POSTGRES_DB=${POSTGRES_DB:-n8n}
POSTGRES_HOST=${POSTGRES_HOST:-postgres}
POSTGRES_PORT=${POSTGRES_PORT:-5432}

# N8N
N8N_ENCRYPTION_KEY=${n8n_encryption_key}
N8N_USER_MANAGEMENT_JWT_SECRET=${n8n_jwt_secret}
N8N_DEFAULT_BINARY_DATA_MODE=filesystem
N8N_HOST=n8n.
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_SECURE_COOKIE=false
WEBHOOK_URL=http://n8n.
N8N_API_KEY=${n8n_api_key}
N8N_API_AUTH_ACTIVE=true

# PGADMIN
PGADMIN_DEFAULT_EMAIL=admin@sattva-ai.top
PGADMIN_DEFAULT_PASSWORD=${pgadmin_pwd}

# TRAEFIK
ACME_EMAIL=admin@sattva-ai.top
TRAEFIK_USERNAME=admin
TRAEFIK_PASSWORD_HASHED=${traefik_pwd_hash}

# GRAPHITI / OPENAI
OPENAI_API_KEY=your_openai_api_key_here

# DB settings for n8n
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=${postgres_pwd}

GENERIC_TIMEZONE=UTC
NODE_ENV=production
COMPOSE_PROJECT_NAME=n8n-ai-starter-kit

EOF
    print_success ".env создан напрямую"
    # Также поместим основные значения обратно в template.env для трассировки
    echo "# Auto-generated template from setup.sh" > template.env || true
    echo "POSTGRES_PASSWORD=${postgres_pwd}" >> template.env || true
    echo "N8N_API_KEY=${n8n_api_key}" >> template.env || true
    echo "N8N_ENCRYPTION_KEY=${n8n_encryption_key}" >> template.env || true
  fi
  
  # Проверяем что файл создался правильно
  if [ ! -f .env ]; then
    print_error "Ошибка: .env файл не был создан!"
    exit 1
  fi
  
  # Проверяем что placeholder значения заменены
  if grep -q "your_32_char_encryption_key_here_" .env; then
    print_error "Ошибка: N8N encryption key не был заменен!"
    exit 1
  fi
  
  if grep -q "change_this_secure_password_123" .env; then
    print_error "Ошибка: PostgreSQL пароль не был заменен!"
    exit 1
  fi
  
  if grep -q "pgladmin_secure_password_123" .env; then
    print_error "Ошибка: PgAdmin пароль не был заменен!"
    exit 1
  fi
  
  # Проверяем что пароли PostgreSQL синхронизированы
  # Обновляем template.env чтобы сохранить сгенерированный/синхронизированный
  # пароль как источник истины. Записываем как POSTGRES_PASSWORD и N8N_PASSWORD
  # (некоторые конфиги ожидают оба варианта).
  if grep -q "^POSTGRES_PASSWORD=" template.env; then
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${postgres_pwd}/" template.env || true
  else
    echo "POSTGRES_PASSWORD=${postgres_pwd}" >> template.env || true
  fi

  if grep -q "^N8N_PASSWORD=" template.env; then
    sed -i "s/^N8N_PASSWORD=.*/N8N_PASSWORD=${postgres_pwd}/" template.env || true
  else
    echo "N8N_PASSWORD=${postgres_pwd}" >> template.env || true
  fi

  postgres_pwd_count=$(grep -c "${postgres_pwd}" .env || true)
  if [ "$postgres_pwd_count" -lt 1 ]; then
    print_error "Ошибка: PostgreSQL пароль не найден в .env!"
    print_info "Найдено вхождений: $postgres_pwd_count"
    exit 1
  fi
  
  print_info "Сгенерированные пароли:"
  echo "  PostgreSQL: ${BOLD}${postgres_pwd}${NC}"
  echo "  N8N Encryption Key: ${BOLD}${n8n_encryption_key}${NC}"
  echo "  N8N API Key: ${BOLD}${n8n_api_key}${NC}"
  echo "  N8N JWT Secret: ${BOLD}${n8n_jwt_secret}${NC}"
  echo "  PgAdmin: ${BOLD}${pgadmin_pwd}${NC}" 
  echo "  Traefik Dashboard: ${BOLD}${traefik_pwd}${NC}"
  echo ""
  print_warning "Сохраните эти пароли в безопасном месте!"
  echo ""
}

# Функция ожидания готовности PostgreSQL
wait_for_postgres() {
  print_info "Ожидание готовности PostgreSQL..."
  
  local max_attempts=30
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then
      print_success "PostgreSQL готов к работе"
      return 0
    fi
    
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
  done
  
  print_error "PostgreSQL не готов после $max_attempts попыток"
  return 1
}

# Функция для обновления конфигурации Traefik с правильными доменами
update_traefik_config() {
  if [ ! -f ".env" ]; then
    print_warning "Файл .env не найден, пропускаем обновление конфигурации Traefik"
    return 0
  fi

  # Загружаем переменные из .env
  source .env

  if [ -z "$DOMAIN_NAME" ]; then
    print_warning "DOMAIN_NAME не задан в .env, пропускаем обновление Traefik"
    return 0
  fi

  print_info "Обновление конфигурации Traefik для домена: $DOMAIN_NAME"

  # Обновляем ssl-security.yml если он существует
  if [ -f "config/traefik/dynamic/ssl-security.yml" ]; then
    print_info "Обновляем ssl-security.yml..."
    
    # Создаем резервную копию если ее еще нет
    if [ ! -f "config/traefik/dynamic/ssl-security.yml.backup" ]; then
      cp config/traefik/dynamic/ssl-security.yml config/traefik/dynamic/ssl-security.yml.backup
    fi
    
    # Заменяем старые домены на новые
    sed -i "s/yourdomain\.com/${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/n8n\.yourdomain\.com/n8n.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/api\.yourdomain\.com/api.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/monitor\.yourdomain\.com/monitor.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    sed -i "s/admin\.yourdomain\.com/admin.${DOMAIN_NAME}/g" config/traefik/dynamic/ssl-security.yml
    
    print_success "ssl-security.yml обновлен"
  fi

  # Обновляем development.yml если есть жестко заданные домены
  if [ -f "config/traefik/dynamic/development.yml" ]; then
    if grep -q "yourdomain\.com\|sattva-ai\.top" config/traefik/dynamic/development.yml; then
      if [ ! -f "config/traefik/dynamic/development.yml.backup" ]; then
        cp config/traefik/dynamic/development.yml config/traefik/dynamic/development.yml.backup
      fi
      sed -i "s/sattva-ai\.top/${DOMAIN_NAME}/g" config/traefik/dynamic/development.yml
      sed -i "s/yourdomain\.com/${DOMAIN_NAME}/g" config/traefik/dynamic/development.yml
      print_success "development.yml обновлен"
    fi
  fi

  print_success "Конфигурация Traefik обновлена для домена: $DOMAIN_NAME"
}

# Функция для обновления существующего .env файла с интерактивными настройками
update_existing_env_with_interactive_settings() {
  print_info "Обновление существующего .env файла с новыми настройками..."
  
  # Обновляем домен
  if [ -n "$domain_name" ]; then
    sed -i "s/^DOMAIN_NAME=.*/DOMAIN_NAME=$domain_name/" .env
    sed -i "s/^N8N_HOST=.*/N8N_HOST=n8n.$domain_name/" .env
    sed -i "s/^N8N_DOMAIN=.*/N8N_DOMAIN=n8n.$domain_name/" .env
    sed -i "s/^TRAEFIK_DASHBOARD_DOMAIN=.*/TRAEFIK_DASHBOARD_DOMAIN=traefik.$domain_name/" .env
    sed -i "s/^QDRANT_DOMAIN=.*/QDRANT_DOMAIN=qdrant.$domain_name/" .env
    sed -i "s/^DOCUMENT_PROCESSOR_DOMAIN=.*/DOCUMENT_PROCESSOR_DOMAIN=doc-processor.$domain_name/" .env
    sed -i "s/^WEB_INTERFACE_DOMAIN=.*/WEB_INTERFACE_DOMAIN=web.$domain_name/" .env
    sed -i "s/^OLLAMA_DOMAIN=.*/OLLAMA_DOMAIN=ollama.$domain_name/" .env
    print_success "Домены обновлены на: $domain_name"
  fi
  
  # Обновляем email для Let's Encrypt
  if [ -n "$acme_email" ]; then
    if grep -q "^ACME_EMAIL=" .env; then
      sed -i "s/^ACME_EMAIL=.*/ACME_EMAIL=$acme_email/" .env
    else
      echo "ACME_EMAIL=$acme_email" >> .env
    fi
    print_success "Email для Let's Encrypt обновлен: $acme_email"
  fi
  
  # Обновляем API ключи
  if [ -n "$openai_api_key" ]; then
    if grep -q "^OPENAI_API_KEY=" .env; then
      sed -i "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=$openai_api_key/" .env
    else
      echo "OPENAI_API_KEY=$openai_api_key" >> .env
    fi
    print_success "OpenAI API ключ обновлен"
  fi
  
  # Обновляем конфигурацию Traefik после изменения доменов
  update_traefik_config
}

interactive_setup() {
  print_info "Интерактивная настройка N8N AI Starter Kit"
  echo ""
  
  # Запрашиваем домен
  read -p "Введите ваш основной домен (например, example.com): " domain_name
  while [ -z "$domain_name" ]; do
    print_error "Домен не может быть пустым!"
    read -p "Введите ваш основной домен (например, example.com): " domain_name
  done
  
  # Запрашиваем email для Let's Encrypt
  read -p "Введите email для Let's Encrypt (для SSL сертификатов): " acme_email
  while [ -z "$acme_email" ]; do
    print_error "Email не может быть пустым!"
    read -p "Введите email для Let's Encrypt (для SSL сертификатов): " acme_email
  done
  
  # Запрашиваем API ключи (опционально)
  echo ""
  print_info "API ключи (оставьте пустым если не используете):"
  
  read -p "OpenAI API ключ (для Graphiti): " openai_api_key
  read -p "Другие API ключи (через запятую): " other_api_keys
  
  # Подтверждение
  echo ""
  print_info "Настройки:"
  echo "  Домен: $domain_name"
  echo "  Email для Let's Encrypt: $acme_email"
  if [ -n "$openai_api_key" ]; then
    echo "  OpenAI API ключ: Задан"
  else
    echo "  OpenAI API ключ: Не задан"
  fi
  echo ""
  
  read -p "Продолжить с этими настройками? (y/N): " confirm
  case $confirm in
    [Yy]* ) ;;
    * ) 
      print_info "Настройка отменена"
      exit 0
      ;;
  esac
  
  # Обновляем template.env с новыми значениями
  update_template_with_user_settings "$domain_name" "$acme_email" "$openai_api_key"
}

update_template_with_user_settings() {
  local domain_name=$1
  local acme_email=$2
  local openai_api_key=$3
  
  print_info "Обновление template.env с пользовательскими настройками..."
  
  # Создаем временную копию template.env
  cp template.env template.env.tmp
  
  # Обновляем домен
  sed -i "s/DOMAIN_NAME=sattva-ai.top/DOMAIN_NAME=${domain_name}/g" template.env.tmp
  
  # Обновляем email для Let's Encrypt
  sed -i "s/ACME_EMAIL=admin@example.com/ACME_EMAIL=${acme_email}/g" template.env.tmp
  sed -i "s/PGADMIN_DEFAULT_EMAIL=admin@example.com/PGADMIN_DEFAULT_EMAIL=${acme_email}/g" template.env.tmp
  
  # Обновляем домены
  sed -i "s/n8n.sattva-ai.top/n8n.${domain_name}/g" template.env.tmp
  sed -i "s/web.sattva-ai.top/web.${domain_name}/g" template.env.tmp
  sed -i "s/doc-processor.sattva-ai.top/doc-processor.${domain_name}/g" template.env.tmp
  sed -i "s/qdrant.sattva-ai.top/qdrant.${domain_name}/g" template.env.tmp
  sed -i "s/ollama.sattva-ai.top/ollama.${domain_name}/g" template.env.tmp
  sed -i "s/traefik.sattva-ai.top/traefik.${domain_name}/g" template.env.tmp
  sed -i "s/supabase.sattva-ai.top/supabase.${domain_name}/g" template.env.tmp
  sed -i "s/api.sattva-ai.top/api.${domain_name}/g" template.env.tmp
  sed -i "s/pgadmin.sattva-ai.top/pgadmin.${domain_name}/g" template.env.tmp
  sed -i "s/jupyter.sattva-ai.top/jupyter.${domain_name}/g" template.env.tmp
  sed -i "s/zep.sattva-ai.top/zep.${domain_name}/g" template.env.tmp
  sed -i "s/graphiti.sattva-ai.top/graphiti.${domain_name}/g" template.env.tmp
  
  # Обновляем OpenAI API ключ если задан
  if [ -n "$openai_api_key" ]; then
    sed -i "s/OPENAI_API_KEY=your_openai_api_key_here/OPENAI_API_KEY=${openai_api_key}/g" template.env.tmp
  fi
  
  # Перемещаем обновленный файл
  mv template.env.tmp template.env
  
  print_success "Template.env обновлен успешно!"
  
  # Также обновляем конфигурацию Traefik, если .env уже существует
  if [ -f ".env" ]; then
    update_traefik_config
  fi
}

# Основная логика скрипта
print_banner
choose_setup_mode

# Проверяем что режим установлен корректно
if [ -z "$SETUP_MODE" ]; then
  print_error "Режим установки не определен! Установлен интерактивный режим по умолчанию."
  SETUP_MODE="interactive"
fi

print_info "Выбранный режим: $SETUP_MODE"

detect_os

# Проверка Docker Desktop на macOS
if [[ "$OS_TYPE" == "macOS" && ! -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]]; then
  print_error "Docker Desktop не установлен. Установите с https://www.docker.com/products/docker-desktop "
  exit 1
fi

# Клонирование дополнительных репозиториев с workflow'ами
  clone_official_workflows

# Вызов функции установки утилит
install_required_utils

# Проверки системы и окружения
if command -v curl &> /dev/null; then
  check_network_connectivity
else
  print_warning "Команда curl не найдена. Пропускаем проверку сетевого подключения."
fi

if command -v docker &> /dev/null; then
  if ! check_docker_health; then
    print_error "Docker не готов. Завершение установки."
    exit 1
  fi
fi

# Проверка доступности портов
if command -v ss &> /dev/null || command -v netstat &> /dev/null || command -v lsof &> /dev/null; then
  check_port_availability
  # Проверка lsof на macOS
  if [[ "$OS_TYPE" == "macOS" && ! -x "$(command -v lsof)" ]]; then
    print_warning "lsof не установлен. Проверьте занятые порты вручную: sudo lsof -i :80"
  fi
else
  print_warning "Не удалось проверить доступность портов 80 и 443. Убедитесь, что они не заняты другими программами."
fi

# Проверка системных ресурсов
check_memory_requirements
check_cpu_resources

# Проверяем наличие OpenSSL
command -v openssl >/dev/null 2>&1 || { print_error "Требуется openssl, но он не установлен. Установите openssl и повторите попытку."; exit 1; }

# Проверка Homebrew на macOS
if [[ "$OS_TYPE" == "macOS" ]] && ! command -v brew &> /dev/null; then
  print_warning "Homebrew не установлен. Установите его: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh )\""
  exit 1
fi

# Проверка зависимостей
print_info "Проверка зависимостей..."

# Проверяем наличие Docker
if ! command -v docker >/dev/null 2>&1; then
  print_warning "Docker не установлен. Хотите установить Docker? (y/n): "
  read install_docker

  if [ "$install_docker" = "y" ]; then
    print_info "Установка Docker..."
    
    if [[ "$OS_TYPE" == *"Ubuntu"* ]]; then
      print_info "Установка Docker на Ubuntu..."
      
      # Установим необходимые пакеты
      run_with_spinner "sudo apt-get update" "Обновление списка пакетов"
      run_with_spinner "sudo apt-get install -y ca-certificates curl gnupg" "Установка необходимых пакетов"
      
      # Добавим официальный GPG ключ Docker
      sudo install -m 0755 -d /etc/apt/keyrings
      run_with_spinner "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg" "Добавление GPG ключа Docker"
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      
      # Добавим репозиторий Docker
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
      # Обновим базу пакетов
      run_with_spinner "sudo apt-get update" "Обновление списка пакетов"
      
      # Установим Docker
      run_with_spinner "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Установка Docker"
      
      # Добавим текущего пользователя в группу docker
      run_with_spinner "sudo usermod -aG docker $USER" "Добавление пользователя в группу docker"
      
      print_success "Docker успешно установлен!"
      print_warning "Чтобы применить изменения групп, перезагрузите систему или выполните: newgrp docker"
    
    elif [[ "$OS_TYPE" == *"Debian"* ]]; then
      print_info "Установка Docker на Debian..."
      
      # Установка необходимых пакетов
      run_with_spinner "sudo apt-get update" "Обновление списка пакетов"
      run_with_spinner "sudo apt-get install -y ca-certificates curl gnupg" "Установка необходимых пакетов"
      
      # Добавление официального GPG ключа Docker
      sudo install -m 0755 -d /etc/apt/keyrings
      run_with_spinner "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg" "Добавление GPG ключа Docker"
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      
      # Добавление репозитория Docker
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
      # Обновление базы пакетов
      run_with_spinner "sudo apt-get update" "Обновление списка пакетов"
      
      # Установка Docker
      run_with_spinner "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Установка Docker"
      
      # Добавление текущего пользователя в группу docker
      run_with_spinner "sudo usermod -aG docker $USER" "Добавление пользователя в группу docker"
      
      print_success "Docker успешно установлен!"
      print_warning "Чтобы применить изменения групп, перезагрузите систему или выполните: newgrp docker"
    
    elif [[ "$OS_TYPE" == *"CentOS"* ]] || [[ "$OS_TYPE" == *"RHEL"* ]]; then
      print_info "Установка Docker на CentOS/RHEL..."
      
      # Установка необходимых пакетов
      run_with_spinner "sudo yum install -y yum-utils" "Установка yum-utils"
      
      # Настройка репозитория Docker
      run_with_spinner "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo" "Добавление репозитория Docker"
      
      # Установка Docker
      run_with_spinner "sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Установка Docker"
      
      # Включение и запуск Docker
      run_with_spinner "sudo systemctl enable docker" "Включение службы Docker"
      run_with_spinner "sudo systemctl start docker" "Запуск службы Docker"
      
      # Добавление текущего пользователя в группу docker
      run_with_spinner "sudo usermod -aG docker $USER" "Добавление пользователя в группу docker"
      
      print_success "Docker успешно установлен!"
      print_warning "Чтобы применить изменения групп, перезагрузите систему или выполните: newgrp docker"
    
    elif [[ "$OS_TYPE" == *"Fedora"* ]]; then
      print_info "Установка Docker на Fedora..."
      
      # Установка необходимых пакетов
      run_with_spinner "sudo dnf -y install dnf-plugins-core" "Установка dnf-plugins-core"
      
      # Настройка репозитория Docker
      run_with_spinner "sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo" "Добавление репозитория Docker"
      
      # Установка Docker
      run_with_spinner "sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Установка Docker"
      
      # Включение и запуск Docker
      run_with_spinner "sudo systemctl enable docker" "Включение службы Docker"
      run_with_spinner "sudo systemctl start docker" "Запуск службы Docker"
      
      # Добавление текущего пользователя в группу docker
      run_with_spinner "sudo usermod -aG docker $USER" "Добавление пользователя в группу docker"
      
      print_success "Docker успешно установлен!"
      print_warning "Чтобы применить изменения групп, перезагрузите систему или выполните: newgrp docker"
    
    elif [[ "$OS_TYPE" == "macOS" ]]; then
      print_info "Для macOS рекомендуется установить Docker Desktop с официального сайта:"
      print_info "https://www.docker.com/products/docker-desktop"
      print_error "Установка Docker для macOS не может быть выполнена автоматически."
      exit 1
      
    else
      print_error "Автоматическая установка Docker не поддерживается для вашей ОС."
      print_info "Посетите официальный сайт Docker для инструкций по установке:"
      print_info "https://docs.docker.com/engine/install/"
      exit 1
    fi
    
    # Проверка установки Docker
    if command -v docker &> /dev/null; then
      print_success "Проверка Docker: $(docker --version)"
    else
      print_error "Установка Docker не удалась. Посетите https://docs.docker.com/engine/install/ для ручной установки."
      exit 1
    fi
  else
    print_success "Docker уже установлен: $(docker --version)"
  fi
fi

# Проверка Docker Compose
print_info "Проверка версии Docker Compose..."
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  # Новая команда docker compose (без дефиса) доступна
  DC_CMD="docker compose"
  print_success "Обнаружена команда docker compose (новый формат)"
  compose_version=$(docker compose version | awk '{print $3}')
  if [[ "$compose_version" < "v2.23.0" ]]; then
    print_warning "Версия Docker Compose слишком старая для использования профилей."
  fi
elif command -v docker-compose >/dev/null 2>&1; then
  # Используем старую команду docker-compose (с дефисом)
  DC_CMD="docker-compose"
  print_success "Обнаружена команда docker-compose (старый формат)"
  compose_version=$(docker-compose version --short)
  if [[ "$compose_version" < "1.28.0" ]]; then
    print_warning "Docker Compose слишком старый для использования профилей."
  fi
else
  print_warning "Docker Compose не обнаружен. Хотите установить Docker Compose? (y/n)"
  read install_compose
  
  if [ "$install_compose" = "y" ]; then
    print_info "Установка Docker Compose..."
    
    if [[ "$OS_TYPE" == *"Ubuntu"* ]] || [[ "$OS_TYPE" == *"Debian"* ]]; then
      # Проверка, установлен ли Docker с установщиком apt
      if sudo apt-get list --installed docker-ce-cli &> /dev/null; then
        print_info "Docker установлен через apt, пытаемся установить docker-compose-plugin..."
        run_with_spinner "sudo apt-get update" "Обновление списка пакетов"
        run_with_spinner "sudo apt-get install -y docker-compose-plugin" "Установка docker-compose-plugin"
      else
        # Ручная установка Docker Compose
        print_info "Загрузка последней версии Docker Compose..."
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        run_with_spinner "sudo curl -L \"https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "Загрузка Docker Compose"
        run_with_spinner "sudo chmod +x /usr/local/bin/docker-compose" "Установка прав доступа"
      fi
    
    elif [[ "$OS_TYPE" == *"CentOS"* ]] || [[ "$OS_TYPE" == *"RHEL"* ]] || [[ "$OS_TYPE" == *"Fedora"* ]]; then
      # Проверка, установлен ли Docker с установщиком yum/dnf
      if sudo yum list installed docker-ce-cli &> /dev/null || sudo dnf list installed docker-ce-cli &> /dev/null; then
        print_info "Docker установлен через yum/dnf, пытаемся установить docker-compose-plugin..."
        if [[ "$OS_TYPE" == *"Fedora"* ]]; then
          run_with_spinner "sudo dnf install -y docker-compose-plugin" "Установка docker-compose-plugin через dnf"
        else
          run_with_spinner "sudo yum install -y docker-compose-plugin" "Установка docker-compose-plugin через yum"
        fi
      else
        # Ручная установка Docker Compose
        print_info "Загрузка последней версии Docker Compose..."
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        run_with_spinner "sudo curl -L \"https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "Загрузка Docker Compose"
        run_with_spinner "sudo chmod +x /usr/local/bin/docker-compose" "Установка прав доступа"
      fi
    
    else
      # Общий метод установки для остальных ОС
      print_info "Загрузка последней версии Docker Compose для вашей системы..."
      COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
      run_with_spinner "sudo curl -L \"https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "Загрузка Docker Compose"
      run_with_spinner "sudo chmod +x /usr/local/bin/docker-compose" "Установка прав доступа"
    fi
    
    print_info "Docker Compose установлен, используем команду docker-compose"
    DC_CMD="docker-compose"
  else
    print_error "Docker Compose необходим для работы. Установите Docker Compose и повторите."
    exit 1
  fi
fi

# Создание .env файла в зависимости от выбранного режима
print_info "Создание .env файла в режиме: $SETUP_MODE"

if [ "$SETUP_MODE" = "template" ]; then
  print_info "Выполняется быстрый режим (template.env)..."
  # Быстрый режим - используем template.env
  if [ -f .env ]; then
    print_warning "Файл .env уже существует."
    read -p "Создать резервную копию и перезаписать? (y/n): " overwrite
    
    if [ "$overwrite" = "y" ]; then
      backup_existing_config
    else
      print_info "Сохранение существующего файла .env"
      exit 0
    fi
  fi
  
  create_env_from_template
  print_success "Быстрый режим завершен успешно"
  
elif [ "$SETUP_MODE" = "interactive" ]; then
  # Интерактивный режим - запрашиваем все параметры
  print_info "🎯 Интерактивный режим настройки"
  
  # Сначала запускаем интерактивную настройку
  interactive_setup
  
  # Проверяем существующий .env файл ПОСЛЕ получения настроек
  if [ -f .env ]; then
    print_warning "Файл .env уже существует."
    print_info "Рекомендуется создать резервную копию перед перезаписью."
    read -p "Создать резервную копию и перезаписать? (y/n): " overwrite
    
    if [ "$overwrite" = "y" ]; then
      # Создаем резервную копию
      backup_existing_config
    else
      print_info "Использование существующего .env файла с новыми настройками"
      # Применяем новые настройки к существующему файлу
      update_existing_env_with_interactive_settings
      print_success "Интерактивная настройка завершена!"
      return 0
    fi
  fi

  # Создаем новый .env файл на основе template.env с интерактивными настройками
  print_info "Создание нового .env файла с вашими настройками..."
  
  # Копируем схему в .env
  cp "$SCHEMA_FILE" .env
  
  # Применяем интерактивные настройки
  update_existing_env_with_interactive_settings

  # Генерация паролей и ключей для интерактивного режима
  print_info "Генерация безопасных паролей и ключей..."

  # Проверяем существующий N8N_ENCRYPTION_KEY если .env файл существует
  existing_encryption_key=""
  if [ -f .env.backup ] && [ -f .env ]; then
    existing_encryption_key=$(grep -E "^N8N_ENCRYPTION_KEY=" .env.backup 2>/dev/null | cut -d '=' -f2)
    if [ -n "$existing_encryption_key" ]; then
      print_success "Найден существующий ключ шифрования N8N, будет использован для сохранения совместимости"
    fi
  fi

  # Используем только алфавитно-цифровые символы
  postgres_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)

  # Используем существующий ключ шифрования или генерируем новый
  if [ -n "$existing_encryption_key" ]; then
    n8n_encryption_key="$existing_encryption_key"
    print_info "Используется существующий ключ шифрования N8N"
  else
    n8n_encryption_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
    print_info "Сгенерирован новый ключ шифрования N8N"
  fi
  n8n_jwt_secret=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
  supabase_postgres_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
  supabase_anon_key=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
  supabase_service_role_key=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
  supabase_jwt_secret=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
  jwt_expiry="3600"
  logflare_api_key=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
  secret_key_base=$(openssl rand -base64 96 | tr -cd '[:alnum:]' | cut -c1-64)
  vault_enc_key=$(openssl rand -base64 48 | tr -cd '[:alnum:]' | cut -c1-32)
  pooler_tenant_id="n8n_$(openssl rand -hex 8)"
  pooler_default_pool_size="20"
  pooler_max_client_conn="100"
  pooler_proxy_port_transaction="6543"
  pgadmin_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
  zep_api_secret=$(openssl rand -base64 64 | tr -cd '[:alnum:]' | cut -c1-48)
  grafana_pwd=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-16)
  jupyter_ds_token=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)
  dashboard_password=$(openssl rand -base64 24 | tr -cd '[:alnum:]' | cut -c1-12)

  # Генерация хэша пароля для Traefik Dashboard
  read -p "Введите пароль для панели управления Traefik (оставьте пустым для автогенерации): " traefik_pwd
  if [ -z "$traefik_pwd" ]; then
    traefik_pwd=$(openssl rand -base64 16 | tr -cd '[:alnum:]' | cut -c1-12)
    print_info "Сгенерирован случайный пароль: ${BOLD}$traefik_pwd${NC} (сохраните его в безопасном месте)"
  fi

  # Генерация хэша пароля с улучшенной обработкой ошибок
  # Используем простой MD5-хэш вместо сложного Apache-хэша для избежания проблем с экранированием
  traefik_pwd_hash=$(echo -n "${traefik_pwd}" | md5sum | cut -d' ' -f1)
  if [ -z "$traefik_pwd_hash" ]; then
    # Fallback метод с базовым хэшированием
    traefik_pwd_hash=$(echo -n "${traefik_pwd}salt" | sha256sum | cut -c1-32)
  fi
  print_info "Сгенерированный хэш пароля: $traefik_pwd_hash"

  # Создание файла .env из template.env в интерактивном режиме
  print_info "Создание файла .env из шаблона template.env..."

  # Проверяем существование template.env
  if [ ! -f "template.env" ]; then
    print_error "Файл template.env не найден!"
    exit 1
  fi

  # Копируем template.env в .env
  cp template.env .env

  # Добавляем метку времени создания
  sed -i "1i# Создано автоматически $(date)" .env
  sed -i "2i# Версия: 1.0.6\n" .env

  # Заменяем плейсхолдеры на сгенерированные значения в интерактивном режиме
  sed -i "s/change_this_secure_password_123/${postgres_pwd}/g" .env
  sed -i "s/your_32_char_encryption_key_here_/${n8n_encryption_key}/" .env
  sed -i "s/your_jwt_secret_key_here_min_32_chars/${n8n_jwt_secret}/" .env
  sed -i "s/supabase_secure_password_123/${supabase_postgres_pwd}/" .env
  sed -i "s/your_supabase_anon_key_here/${supabase_anon_key}/g" .env
  sed -i "s/your_supabase_service_role_key_here/${supabase_service_role_key}/g" .env
  sed -i "s/your_supabase_jwt_secret_32_chars_min/${supabase_jwt_secret}/g" .env
  sed -i "s/admin@sattva-ai.top/${acme_email}/g" .env
  sed -i "s/pgadmin_secure_password_123/${pgadmin_pwd}/" .env
  sed -i "s/traefik_password_hash_placeholder/${traefik_pwd_hash}/" .env
  sed -i "s/your_openai_api_key_here/${openai_api_key:-}/" .env

  # Генерируем недостающие значения и добавляем их
  echo "" >> .env
  echo "# ---- ДОПОЛНИТЕЛЬНЫЕ СГЕНЕРИРОВАННЫЕ ПЕРЕМЕННЫЕ ----" >> .env
  echo "ZEP_API_SECRET=${zep_api_secret}" >> .env
  echo "GRAFANA_ADMIN_PASSWORD=${grafana_pwd}" >> .env
  echo "JUPYTER_DS_TOKEN=${jupyter_ds_token}" >> .env
  echo "DASHBOARD_PASSWORD=${dashboard_password}" >> .env
  echo "SECRET_KEY_BASE=${secret_key_base}" >> .env
  echo "VAULT_ENC_KEY=${vault_enc_key}" >> .env
  echo "POOLER_TENANT_ID=${pooler_tenant_id}" >> .env
  echo "LOGFLARE_API_KEY=${logflare_api_key}" >> .env
  echo "QDRANT_API_KEY=$(openssl rand -base64 32 | tr -cd '[:alnum:]' | cut -c1-24)" >> .env

  # Обновляем домены на пользовательские
  sed -i "s/sattva-ai.top/${domain_name}/g" .env

  # Обновляем template.env чтобы сохранить сгенерированный пароль как источник истины
  if grep -q "change_this_secure_password_123" template.env; then
    sed -i "s/change_this_secure_password_123/${postgres_pwd}/g" template.env || true
  fi

  print_success "Файл .env успешно создан!"
  print_warning "ВАЖНО: Сохраните копию файла .env в безопасном месте!"

  # Отображение важной информации
  echo -e "\n${BLUE}===============================================${NC}"
  echo -e "${BOLD}Важная информация о паролях и ключах:${NC}"
  echo -e "${BLUE}===============================================${NC}"
  echo -e "${YELLOW}Traefik Dashboard пароль:${NC} ${BOLD}$traefik_pwd${NC}"
  echo -e "${YELLOW}PgAdmin пароль:${NC} ${BOLD}$pgadmin_pwd${NC}"
  echo -e "${YELLOW}Grafana пароль:${NC} ${BOLD}$grafana_pwd${NC}"
  echo -e "${YELLOW}Jupyter Token:${NC} ${BOLD}$jupyter_ds_token${NC}"
  # Проверяем, настроен ли OpenAI: либо интерактивно (openai_api_key), либо в .env
  openai_configured=false
  if [ -n "${openai_api_key:-}" ]; then
    openai_configured=true
  elif [ -f .env ]; then
    if grep -q '^OPENAI_API_KEY=' .env 2>/dev/null; then
      # считается настроенным, если значение не содержит плейсхолдера
      if ! grep -q 'your_openai_api_key_here' .env 2>/dev/null; then
        openai_configured=true
      fi
    fi
  fi

  if [ "$openai_configured" = true ]; then
    echo -e "${YELLOW}OpenAI API:${NC} ${GREEN}✅ Настроен${NC}"
  else
    echo -e "${YELLOW}OpenAI API:${NC} ${RED}❌ Не настроен${NC} (добавьте позже в .env)"
  fi
  if [ -n "$anthropic_key" ]; then
    echo -e "${YELLOW}Anthropic API:${NC} ${GREEN}✅ Настроен${NC}"
  fi
  echo -e "${BLUE}===============================================${NC}"

  # Создаем файл с советами по устранению неполадок
  create_troubleshooting_file

  # Предложение предзагрузки моделей
  echo -e "\n${BLUE}===============================================${NC}"
  echo -e "${BOLD}Предварительная загрузка моделей для Ollama${NC}"
  echo -e "${BLUE}===============================================${NC}"
  echo -e "Загрузка моделей сейчас позволит избежать ожидания при первом запуске системы."

  read -p "Хотите загрузить модели Ollama сейчас? (y/n): " preload_models

  if [[ "$preload_models" =~ ^[Yy]$ ]]; then
    if [ -f "./scripts/preload-models.sh" ]; then
      chmod +x ./scripts/preload-models.sh
      ./scripts/preload-models.sh
    else
      print_warning "Скрипт preload-models.sh не найден."
    fi
  fi

fi # Закрываем блок интерактивного режима

# Создаем файл с советами по устранению неполадок (общий для всех режимов)
create_troubleshooting_file

# Запуск сервисов
print_info "Теперь вы можете запустить N8N AI Starter Kit с помощью команды:"
print_info "${BOLD}$DC_CMD up -d${NC} или используйте ./start.sh"

print_info "\nДополнительные команды для разных профилей:"
print_info "${BOLD}$DC_CMD --profile cpu up -d${NC} - Запуск с процессорными AI-сервисами"
print_info "${BOLD}$DC_CMD --profile gpu-nvidia up -d${NC} - Запуск с NVIDIA GPU AI-сервисами"
print_info "${BOLD}$DC_CMD --profile gpu-amd up -d${NC} - Запуск с AMD GPU AI-сервисами"
print_info "${BOLD}$DC_CMD --profile developer up -d${NC} - Полный набор инструментов разработчика"

print_info "\nИли используйте улучшенный скрипт запуска:"
print_info "${BOLD}./start.sh${NC} - Автоматический выбор оптимального профиля"
print_info "${BOLD}./start.sh cpu${NC} - Запуск с процессорными AI-сервисами"
print_info "${BOLD}./start.sh gpu-nvidia${NC} - Запуск с NVIDIA GPU AI-сервисами"

# Показываем адреса в зависимости от режима
if [ "$SETUP_MODE" = "template" ]; then
  print_info "\nПосле запуска доступ к сервисам по адресам:"
  print_info "N8N: http://n8n.sattva-ai.top"
  print_info "Traefik Dashboard: http://traefik.sattva-ai.top"
  print_info "Qdrant: http://qdrant.sattva-ai.top"
  print_info "Document Processor: http://doc-processor.sattva-ai.top"
  print_info "Web Interface: http://web.sattva-ai.top"
  print_info ""
elif [ "$SETUP_MODE" = "interactive" ]; then
  print_info "\nПосле запуска, доступ к сервисам будет по адресам:"
  print_info "N8N: https://n8n.${domain_name}"
  print_info "Traefik Dashboard: http://traefik.${domain_name}"
  print_info "Qdrant: http://qdrant.${domain_name}"
  print_info "Document Processor: http://doc-processor.${domain_name}"
fi

print_success "Установка успешно завершена!"
print_info "Полная документация: https://github.com/n8n-io/n8n-ai-starter-kit"

# Функция для клонирования официального репозитория n8n workflows
clone_official_workflows() {
  print_info "📥 Клонирование официального репозитория n8n workflows..."
  
  # Официальный репозиторий с workflow'ами от Zie619
  local repo_url="https://github.com/Zie619/n8n-workflows.git"
  local target_dir="n8n-workflows"
  
  if [ -d "$target_dir" ]; then
    print_info "📁 Репозиторий уже существует, обновляем..."
    cd "$target_dir"
    if git pull origin main >/dev/null 2>&1; then
      print_success "✅ Репозиторий обновлен: $target_dir"
    else
      print_warning "⚠️ Не удалось обновить репозиторий $target_dir"
    fi
    cd ..
  else
    print_info "📥 Клонирование репозитория n8n-workflows..."
    if git clone "$repo_url" "$target_dir" >/dev/null 2>&1; then
      print_success "✅ Успешно склонирован репозиторий: $target_dir"
      
      # Проверяем наличие папки workflows
      if [ -d "$target_dir/workflows" ]; then
        local workflow_count=$(find "$target_dir/workflows" -name "*.json" | wc -l)
        print_info "📊 Найдено $workflow_count workflow'ов"
      fi
    else
      print_warning "⚠️ Не удалось клонировать репозиторий $repo_url"
      print_info "🔍 Проверьте подключение к интернету или доступность репозитория"
    fi
  fi
  
  # Копирование workflows в n8n директорию
  print_info "📋 Копирование workflows в n8n директорию..."
  mkdir -p n8n/workflows
  if [ -d "$target_dir/workflows" ]; then
    cp -r "$target_dir/workflows/"* n8n/workflows/ 2>/dev/null || print_warning "⚠️ Нет workflows для копирования"
    print_success "✅ Workflows скопированы в n8n/workflows/"
  fi
  
  # Создание credentials директории
  mkdir -p n8n/credentials
  print_success "✅ Workflows готовы к импорту"
  
  # Запуск веб-сервиса документации
  print_info "🌐 Запуск веб-сервиса документации workflows..."
  if docker compose build workflows-doc >/dev/null 2>&1; then
    print_success "✅ Образ workflows-doc собран"
    print_info "📖 Веб-интерфейс будет доступен по адресу: http://localhost:8000"
    print_info "🔍 Используйте веб-интерфейс для просмотра и поиска workflow'ов"
  else
    print_warning "⚠️ Не удалось собрать образ workflows-doc"
  fi
}
