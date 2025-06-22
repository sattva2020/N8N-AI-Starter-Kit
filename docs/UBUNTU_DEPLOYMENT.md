# 🚀 Развертывание n8n-ai-starter-kit на Ubuntu

## 📋 Системные требования

### Минимальные требования:
- **OS**: Ubuntu 20.04+ (рекомендуется 22.04 LTS)
- **RAM**: 4GB (рекомендуется 8GB+)
- **CPU**: 2 ядра (рекомендуется 4+)
- **Диск**: 20GB свободного места
- **Сеть**: Интернет соединение

### Рекомендуемые требования:
- **RAM**: 16GB+ для всех сервисов
- **CPU**: 8+ ядер для GPU профиля
- **Диск**: 50GB+ SSD

---

## 🔧 Установка зависимостей

### 1. Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Установка Docker
```bash
# Удаление старых версий (если есть)
sudo apt remove docker docker-engine docker.io containerd runc

# Установка зависимостей
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавление GPG ключа Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавление репозитория Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# Перезапуск сессии для применения изменений
newgrp docker

# Проверка установки
docker --version
docker compose version
```

### 3. Установка дополнительных утилит
```bash
sudo apt install -y git curl wget htop tree
```

---

## 📥 Клонирование проекта

### 1. Клонирование репозитория
```bash
# Переход в домашнюю директорию
cd ~

# Клонирование проекта
git clone https://github.com/YOUR_USERNAME/n8n-ai-starter-kit.git

# Переход в директорию проекта
cd n8n-ai-starter-kit

# Проверка структуры
ls -la
```

### 2. Проверка готовности системы
```bash
# Запуск диагностики
./scripts/diagnose.sh

# Если скрипт не исполняется, сделайте его исполняемым
chmod +x scripts/*.sh
chmod +x start.sh

# Повторный запуск диагностики
./scripts/diagnose.sh
```

---

## ⚙️ Настройка проекта

### 1. Интерактивная настройка
```bash
# Запуск мастера настройки
./scripts/setup.sh
```

Мастер настройки запросит:
- **Email для Let's Encrypt** (для SSL сертификатов)
- **Доменное имя** (или localhost для локального использования)
- **OpenAI API ключ** (обязательно)
- **Anthropic API ключ** (опционально)
- **Пароли для сервисов** (будут сгенерированы автоматически)

### 2. Ручная настройка (альтернатива)
```bash
# Копирование шаблона конфигурации
cp template.env .env

# Редактирование конфигурации
nano .env
```

Основные переменные для настройки:
```bash
# Домен (для локального использования)
DOMAIN_NAME=localhost
N8N_HOST=localhost
N8N_PROTOCOL=http

# OpenAI API (обязательно)
OPENAI_API_KEY=your_openai_api_key_here

# Email для SSL (если используете домен)
ACME_EMAIL=your@email.com

# Пароли (будут сгенерированы setup.sh)
POSTGRES_PASSWORD=secure_password
N8N_ENCRYPTION_KEY=secure_32_char_key
```

---

## 🚀 Запуск проекта

### 1. Быстрый запуск
```bash
# Запуск всех сервисов
./start.sh
```

### 2. Выбор профиля запуска
```bash
# CPU профиль (рекомендуется для большинства случаев)
docker compose --profile cpu up -d

# Полный профиль (все сервисы)
docker compose --profile default up -d

# Профиль разработчика (с дополнительными инструментами)
docker compose --profile developer up -d
```

### 3. Проверка статуса
```bash
# Проверка запущенных контейнеров
docker compose ps

# Проверка логов
docker compose logs -f n8n

# Проверка системы
./scripts/diagnose.sh
```

---

## 🌐 Доступ к сервисам

После успешного запуска сервисы будут доступны по адресам:

### Локальное развертывание (localhost):
- **n8n**: http://localhost:5678
- **Qdrant**: http://localhost:6333
- **Traefik Dashboard**: http://localhost:8080
- **pgAdmin**: http://localhost:5050 (профиль developer)

### Развертывание с доменом:
- **n8n**: https://n8n.yourdomain.com
- **Qdrant**: https://qdrant.yourdomain.com  
- **Traefik Dashboard**: https://traefik.yourdomain.com
- **Другие сервисы**: согласно настройкам в .env

---

## 🔧 Управление проектом

### Остановка сервисов
```bash
# Остановка всех сервисов
docker compose down

# Остановка с удалением volumes (осторожно!)
docker compose down -v
```

### Обновление проекта
```bash
# Обновление кода
git pull origin main

# Пересборка и перезапуск
docker compose down
docker compose pull
docker compose up -d
```

### Резервное копирование
```bash
# Создание backup
./scripts/backup.sh

# Backup будет сохранен в папке backups/
```

### Мониторинг
```bash
# Мониторинг ресурсов
./scripts/monitor.sh

# Проверка логов
docker compose logs -f [service_name]

# Статистика Docker
docker stats
```

---

## 🔍 Решение проблем

### Частые проблемы и решения:

#### 1. Ошибки прав доступа
```bash
# Исправление прав на скрипты
chmod +x scripts/*.sh start.sh

# Исправление прав Docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Проблемы с портами
```bash
# Проверка занятых портов
sudo netstat -tulpn | grep :5678
sudo netstat -tulpn | grep :6333

# Остановка конфликтующих сервисов
sudo systemctl stop apache2  # если используется
sudo systemctl stop nginx    # если используется
```

#### 3. Недостаток памяти
```bash
# Запуск только основных сервисов
docker compose --profile cpu up -d n8n postgres qdrant

# Мониторинг памяти
free -h
docker stats
```

#### 4. Проблемы с .env
```bash
# Автоматическое исправление
./scripts/fix-env-vars.sh

# Повторная настройка
./scripts/setup.sh
```

#### 5. Проблемы с SSL/доменами
```bash
# Для локального использования измените в .env:
N8N_PROTOCOL=http
N8N_HOST=localhost
WEBHOOK_URL=http://localhost:5678/
```

---

## 📖 Дополнительные ресурсы

### Документация:
- `docs/SETUP_SCRIPT.md` - подробное описание setup.sh
- `docs/COMMON_ISSUES.md` - частые проблемы
- `TROUBLESHOOTING.md` - решение проблем
- `README.md` - общее описание проекта

### Полезные команды:
```bash
# Проверка системы
./scripts/diagnose.sh

# Валидация проекта  
./scripts/validate.sh

# Очистка Docker
./scripts/clean-docker.sh

# Обновление системы
./scripts/update.sh
```

---

## 🎯 Первые шаги после установки

1. **Откройте n8n**: http://localhost:5678
2. **Создайте аккаунт администратора**
3. **Настройте первый workflow**
4. **Подключите API ключи** в настройках n8n
5. **Изучите примеры** в папке `n8n/demo-data/`

**Проект готов к использованию!** 🎉
