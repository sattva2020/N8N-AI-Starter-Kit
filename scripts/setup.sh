#!/bin/bash
# filepath: scripts/setup.sh
# Версия: 1.5.1 - Исправленная версия с устранением ошибок и улучшенной поддержкой ОС и проверками системы

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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
  # Регулярное выражение для проверки домена
  # Простое выражение: может содержать буквы, цифры, дефисы и точки, не начинается/заканчивается дефисом, содержит хотя бы одну точку
  local domain_regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
  
  if [[ $domain =~ $domain_regex ]]; then
    return 0  # Валидный домен
  else
    return 1  # Невалидный домен
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
    read -p "Продолжить установку? (y/n): " continue_setup
    if [ "$continue_setup" != "y" ]; then
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
      print_info "Рекомендуется выбрать минимальный профиль: --profile minimal"
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
      print_info "Рекомендуется выбрать минимальный профиль: --profile minimal"
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
      print_info "Рекомендуется выбрать минимальный профиль: --profile minimal"
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
      print_info "Рекомендуется выбрать минимальный профиль: --profile minimal"
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
  - Используйте минимальный профиль: \`docker compose --profile minimal up -d\`
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
check_docker_health() {
  print_info "Проверка состояния Docker..."
  
  if ! command -v docker &> /dev/null; then
    print_error "Docker не установлен или не доступен в PATH."
    return 1
  fi
  
  # Проверка запущен ли демон Docker
  if ! docker info &> /dev/null; then
    print_error "Демон Docker не запущен или у вас нет прав для его использования."
    
    if [ "$(uname)" == "Darwin" ]; then
      print_info "Для macOS: Запустите приложение Docker Desktop."
    else
      print_info "Попробуйте выполнить: sudo systemctl start docker"
      print_info "Или добавьте текущего пользователя в группу docker: sudo usermod -aG docker $USER"
      print_info "После добавления в группу выполните: newgrp docker"
    fi
    
    return 1
  fi
  
  # Проверка наличия прав у текущего пользователя
  if ! docker ps &> /dev/null; then
    print_error "У вас недостаточно прав для использования Docker."
    print_info "Добавьте текущего пользователя в группу docker: sudo usermod -aG docker $USER"
    print_info "Затем перезагрузите систему или выполните: newgrp docker"
    return 1
  fi
  
  # Проверка возможности загрузки образов
  if ! docker pull hello-world &> /dev/null; then
    print_warning "Не удалось загрузить тестовый образ. Возможны проблемы с сетью или Docker Hub."
    print_info "Проверьте настройки сети и доступность Docker Hub."
    return 2
  else
    # Удаляем тестовый образ после проверки
    docker rmi hello-world &> /dev/null
  fi
  
  print_success "Docker работает корректно!"
  return 0
}

# Основная логика скрипта
print_banner
detect_os

# Вызов функции установки утилит
install_required_utils

# Проверки системы и окружения
if command -v curl &> /dev/null; then
  check_network_connectivity
else
  print_warning "Команда curl не найдена. Пропускаем проверку сетевого подключения."
fi

if command -v docker &> /dev/null; then
  check_docker_health
fi

# Проверка доступности портов
if command -v ss &> /dev/null || command -v netstat &> /dev/null || command -v lsof &> /dev/null; then
  check_port_availability
else
  print_warning "Не удалось проверить доступность портов 80 и 443. Убедитесь, что они не заняты другими программами."
fi

# Проверка системных ресурсов
check_memory_requirements
check_cpu_resources

# Проверяем наличие OpenSSL
command -v openssl >/dev/null 2>&1 || { print_error "Требуется openssl, но он не установлен. Установите openssl и повторите попытку."; exit 1; }

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
    print_error "Docker необходим для работы N8N AI Starter Kit. Установите Docker и повторите попытку."
    exit 1
  fi
else
  print_success "Docker уже установлен: $(docker --version)"
fi

# Проверка Docker Compose
print_info "Проверка версии Docker Compose..."
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  # Новая команда docker compose (без дефиса) доступна
  DC_CMD="docker compose"
  print_success "Обнаружена команда docker compose (новый формат)"
elif command -v docker-compose >/dev/null 2>&1; then
  # Используем старую команду docker-compose (с дефисом)
  DC_CMD="docker-compose"
  print_success "Обнаружена команда docker-compose (старый формат)"
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

# Создание .env файла
if [ -f .env ]; then
  print_warning "Файл .env уже существует."
  print_info "Рекомендуется создать резервную копию перед перезаписью."
  read -p "Создать резервную копию и перезаписать? (y/n): " overwrite
  
  if [ "$overwrite" = "y" ]; then
    # Создаем резервную копию
    backup_existing_config
  else
    print_info "Сохранение существующего файла .env"
    exit 0
  fi
fi

# Ввод базовых настроек
print_info "\n--- Настройка основных параметров ---"
read -p "Введите основное доменное имя (например, example.com): " domain_name
while [ -z "$domain_name" ] || ! validate_domain_name "$domain_name"; do
  print_error "Доменное имя не может быть пустым и должно иметь корректный формат (например, example.com)."
  read -p "Введите основное доменное имя (например, example.com): " domain_name
done

# Проверка корректности доменного имени
validate_domain_name "$domain_name"
while [ $? -ne 0 ]; do
  print_error "Некорректное доменное имя: $domain_name"
  read -p "Введите корректное доменное имя (например, example.com): " domain_name
  validate_domain_name "$domain_name"
done

read -p "Введите ваш email (для Let's Encrypt и уведомлений): " email
while [ -z "$email" ] || ! validate_email "$email"; do
  print_error "Введите корректный email адрес."
  read -p "Введите ваш email (для Let's Encrypt и уведомлений): " email
done

# Генерация паролей и ключей
print_info "Генерация безопасных паролей и ключей..."
postgres_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
n8n_encryption_key=$(openssl rand -base64 32 | tr -d "=" | tr -d "/+")
n8n_jwt_secret=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")
supabase_postgres_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
supabase_anon_key=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")
supabase_service_role_key=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")
supabase_jwt_secret=$(openssl rand -base64 32 | tr -d "=" | tr -d "/+")
minio_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
pgadmin_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
zep_api_secret=$(openssl rand -base64 48 | tr -d "=" | tr -d "/+")
grafana_pwd=$(openssl rand -base64 16 | tr -d "=" | tr -d "/+")
jupyter_ds_token=$(openssl rand -base64 24 | tr -d "=" | tr -d "/+")

# Генерация хэша пароля для Traefik Dashboard
read -p "Введите пароль для панели управления Traefik (оставьте пустым для автогенерации): " traefik_pwd
# Проверка на пустой пароль
if [ -z "$traefik_pwd" ]; then
  print_info "Внимание: Пароль не указан. Установка безопасного пароля..."
  traefik_pwd=$(openssl rand -base64 12 | tr -d "=" | tr -d "/+")
  print_info "Сгенерирован случайный пароль: ${BOLD}$traefik_pwd${NC} (сохраните его в безопасном месте)"
fi
# Используем двойные кавычки для обработки спецсимволов в пароле
traefik_pwd_hash=$(openssl passwd -apr1 "$traefik_pwd")
# Проверка успешности генерации хэша
if [ -z "$traefik_pwd_hash" ]; then
  print_error "Ошибка: Не удалось сгенерировать хэш пароля."
  print_info "Пробуем альтернативный метод генерации хэша..."
  
  # Альтернативный метод с использованием htpasswd, если он доступен
  if command -v htpasswd &> /dev/null; then
    traefik_pwd_hash=$(htpasswd -nbB admin "$traefik_pwd" | cut -d ":" -f 2)
  else
    # Простая резервная опция без хеширования (не рекомендуется)
    print_warning "Не удалось создать хэш пароля. Возможно, потребуется установить apache2-utils."
    print_error "Установка продолжится, но безопасность Traefik может быть скомпрометирована."
    traefik_pwd_hash="$traefik_pwd"
  fi
fi
print_info "Сгенерированный хэш пароля: $traefik_pwd_hash"

# Запрос API ключа OpenAI
read -p "Введите ваш OpenAI API ключ (или оставьте пустым, чтобы настроить позже): " openai_key

# Создание файла .env
cat > .env << EOF
# =============================================
# N8N AI Starter Kit - Конфигурация окружения
# =============================================
# Создано автоматически $(date)
# Версия: 1.0.1

# ---- БАЗОВЫЕ НАСТРОЙКИ ----
DOMAIN_NAME=${domain_name}

# ---- POSTGRESQL ----
# Main Database для n8n
POSTGRES_USER=root
POSTGRES_PASSWORD=${postgres_pwd}
POSTGRES_DB=n8n

# ---- N8N НАСТРОЙКИ ----
N8N_ENCRYPTION_KEY=${n8n_encryption_key}
N8N_USER_MANAGEMENT_JWT_SECRET=${n8n_jwt_secret}
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# ---- SUPABASE НАСТРОЙКИ ----
SUPABASE_POSTGRES_PASSWORD=${supabase_postgres_pwd}
SUPABASE_ANON_KEY=${supabase_anon_key}
SUPABASE_SERVICE_ROLE_KEY=${supabase_service_role_key}
SUPABASE_JWT_SECRET=${supabase_jwt_secret}

# ---- MINIO НАСТРОЙКИ ----
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=${minio_pwd}

# ---- PGADMIN НАСТРОЙКИ ----
PGADMIN_DEFAULT_EMAIL=${email}
PGADMIN_DEFAULT_PASSWORD=${pgadmin_pwd}

# ---- TRAEFIK НАСТРОЙКИ ----
ACME_EMAIL=${email}
TRAEFIK_USERNAME=admin
TRAEFIK_PASSWORD_HASHED=${traefik_pwd_hash}

# ---- ZEP НАСТРОЙКИ ----
ZEP_POSTGRES_USER=postgres
ZEP_POSTGRES_PASSWORD=postgres
ZEP_POSTGRES_DB=postgres
ZEP_API_SECRET=${zep_api_secret}

# ---- GRAPHITI НАСТРОЙКИ ----
OPENAI_API_KEY=${openai_key}

# ---- GRAFANA НАСТРОЙКИ ----
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=${grafana_pwd}

# ---- JUPYTER DATA SCIENCE НАСТРОЙКИ ----
JUPYTER_DS_TOKEN=${jupyter_ds_token}

# ---- ДОМЕНЫ СЕРВИСОВ ----
N8N_DOMAIN=n8n.${domain_name}
OLLAMA_DOMAIN=ollama.${domain_name}
QDRANT_DOMAIN=qdrant.${domain_name}
SUPABASE_STUDIO_DOMAIN=supabase.${domain_name}
SUPABASE_API_DOMAIN=api.supabase.${domain_name}
MINIO_API_DOMAIN=minio.${domain_name}
MINIO_CONSOLE_DOMAIN=minio-console.${domain_name}
PGADMIN_DOMAIN=pgadmin.${domain_name}
JUPYTER_DOMAIN=jupyter.${domain_name}
TRAEFIK_DASHBOARD_DOMAIN=traefik.${domain_name}
ZEP_DOMAIN=zep.${domain_name}
GRAPHITI_DOMAIN=graphiti.${domain_name}

# ---- ДОПОЛНИТЕЛЬНЫЕ ДОМЕНЫ СЕРВИСОВ ----
PROMETHEUS_DOMAIN=prometheus.${domain_name}
GRAFANA_DOMAIN=grafana.${domain_name}
CADVISOR_DOMAIN=cadvisor.${domain_name}
LOKI_DOMAIN=loki.${domain_name}
KIBANA_DOMAIN=kibana.${domain_name}
JUPYTER_DS_DOMAIN=jupyter-ds.${domain_name}
LANGSMITH_DOMAIN=langsmith.${domain_name}
WANDB_DOMAIN=wandb.${domain_name}
EOF

print_success "Файл .env успешно создан!"
print_warning "ВАЖНО: Сохраните копию файла .env в безопасном месте!"

# Создаем файл с советами по устранению неполадок
create_troubleshooting_file

# Запуск сервисов
print_info "Теперь вы можете запустить N8N AI Starter Kit с помощью команды:"
print_info "${BOLD}$DC_CMD up -d${NC}"

print_info "\nДополнительные команды:"
print_info "${BOLD}$DC_CMD --profile cpu up -d${NC} - Запуск с процессорными AI-сервисами"
print_info "${BOLD}$DC_CMD --profile gpu up -d${NC} - Запуск с GPU-ускоренными AI-сервисами"
print_info "${BOLD}$DC_CMD --profile minimal up -d${NC} - Запуск только базовых сервисов"

print_info "\nПосле запуска, доступ к сервисам будет по адресам:"
print_info "N8N: https://n8n.${domain_name}"
print_info "Ollama: https://ollama.${domain_name}"
print_info "Qdrant: https://qdrant.${domain_name}"
print_info "Traefik Dashboard: https://traefik.${domain_name}"

print_success "Установка успешно завершена!"
print_info "Полная документация: https://github.com/n8n-io/n8n-ai-starter-kit"
