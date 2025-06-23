# 🚀 Полное руководство по развертыванию на Ubuntu VM

## Шаг 1: Подготовка Ubuntu VM

### Минимальные требования
- Ubuntu 20.04 LTS или новее
- 4GB RAM (рекомендуется 8GB)
- 20GB свободного места на диске
- Доступ к интернету

### Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
```

## Шаг 2: Создание пользователя для развертывания

### Вариант A: Автоматическое создание (Рекомендуется)

1. Клонируйте проект (временно под root или admin пользователем):
```bash
git clone https://github.com/your-repo/n8n-ai-starter-kit.git
cd n8n-ai-starter-kit
```

2. Запустите скрипт создания пользователя:
```bash
sudo bash scripts/create-user.sh
```

3. Переключитесь на созданного пользователя:
```bash
su - n8nuser
```

### Вариант B: Ручное создание

```bash
# Создание пользователя
sudo adduser n8nuser

# Добавление в группы
sudo usermod -aG sudo n8nuser
sudo usermod -aG docker n8nuser  # Если Docker уже установлен

# Переключение на пользователя
su - n8nuser
```

## Шаг 3: Клонирование проекта под пользователем

```bash
# Убедитесь, что вы работаете под обычным пользователем
whoami  # Должно показать имя пользователя, НЕ root

# Клонирование проекта
cd ~
git clone https://github.com/your-repo/n8n-ai-starter-kit.git
cd n8n-ai-starter-kit

# Переключение на стабильную версию
git checkout v1.1.2
```

## Шаг 4: Запуск развертывания

```bash
# Сделать скрипт исполняемым
chmod +x scripts/ubuntu-vm-deploy.sh

# Запуск развертывания
./scripts/ubuntu-vm-deploy.sh
```

Скрипт автоматически:
- ✅ Установит все необходимые пакеты
- ✅ Установит Docker и Docker Compose
- ✅ Настроит окружение
- ✅ Запустит все сервисы
- ✅ Проведет диагностику

## Шаг 5: Проверка развертывания

### Проверка статуса сервисов
```bash
# Проверка контейнеров
docker ps

# Проверка логов
docker logs n8n-ai-starter-kit-n8n-1

# Диагностика системы
./scripts/analyze-services.sh
```

### Доступ к сервисам

- **N8N Web UI**: http://<VM_IP>:5678
- **Qdrant Dashboard**: http://<VM_IP>:6333/dashboard
- **Ollama API**: http://<VM_IP>:11434

## Шаг 6: Настройка переменных окружения

Отредактируйте файл `.env` при необходимости:
```bash
cp template.env .env
nano .env
```

Важные переменные:
```env
# Основные настройки
N8N_HOST=0.0.0.0
N8N_PORT=5678

# База данных
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<ваш_пароль>

# Модели Ollama
OLLAMA_MODELS=llama3.2:3b,nomic-embed-text:latest
```

## 🚨 Важные моменты безопасности

### ❌ Что НЕ делать:
- Не запускать скрипт от root: `sudo ./scripts/ubuntu-vm-deploy.sh`
- Не устанавливать Docker от root без настройки групп
- Не оставлять стандартные пароли в production

### ✅ Что делать:
- Использовать обычного пользователя с sudo правами
- Изменить стандартные пароли в `.env`
- Настроить firewall для production использования

## 🔧 Устранение проблем

### Проблема: "Permission denied" для Docker
```bash
# Добавить пользователя в группу docker
sudo usermod -aG docker $USER

# Выйти и войти заново или выполнить
newgrp docker
```

### Проблема: Порты заняты
```bash
# Проверить занятые порты
sudo netstat -tulpn | grep :5678

# Остановить конфликтующие сервисы
sudo systemctl stop service_name
```

### Проблема: Недостаточно памяти
```bash
# Проверить использование памяти
free -h

# Остановить ненужные сервисы
sudo systemctl stop snapd
sudo systemctl stop unattended-upgrades
```

## 📊 Мониторинг и обслуживание

### Регулярные проверки
```bash
# Проверка здоровья сервисов
docker ps
docker stats

# Проверка логов
docker logs -f n8n-ai-starter-kit-n8n-1

# Резервное копирование
./scripts/backup.sh
```

### Обновление системы
```bash
# Остановка сервисов
docker-compose down

# Обновление кода
git pull origin main

# Запуск сервисов
docker-compose up -d
```

## 🎯 Следующие шаги

После успешного развертывания:

1. **Настройте N8N**: Откройте Web UI и создайте первый workflow
2. **Загрузите модели Ollama**: `docker exec ollama ollama pull llama3.2:3b`
3. **Настройте мониторинг**: Используйте скрипты диагностики
4. **Создайте резервные копии**: Настройте автоматическое резервное копирование

## 📚 Дополнительные ресурсы

- [Документация N8N](https://docs.n8n.io/)
- [Документация Ollama](https://ollama.ai/docs)
- [Документация Qdrant](https://qdrant.tech/documentation/)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
