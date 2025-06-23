# 🚀 Руководство по развертыванию N8N AI Starter Kit на Ubuntu VM

## 📋 Содержание
- [Требования к системе](#требования-к-системе)
- [Быстрое развертывание](#быстрое-развертывание)
- [Анализ необходимых сервисов](#анализ-необходимых-сервисов)
- [Конфигурационные профили](#конфигурационные-профили)
- [Пошаговое развертывание](#пошаговое-развертывание)
- [Диагностика и устранение неполадок](#диагностика-и-устранение-неполадок)

## 📊 Требования к системе

### Минимальные требования
- **ОС**: Ubuntu 20.04+ (рекомендуется 22.04 LTS)
- **RAM**: 4GB (минимум для базовых сервисов)
- **CPU**: 2 ядра
- **Диск**: 20GB свободного места
- **Сеть**: Доступ к интернету для загрузки образов

### Рекомендуемые требования
- **RAM**: 8GB+ (для полных AI возможностей)
- **CPU**: 4+ ядер
- **Диск**: 50GB+ (для AI моделей)

### Профили по ресурсам

| Профиль | RAM | CPU | Диск | Сервисы |
|---------|-----|-----|------|---------|
| `minimal` | 2-4GB | 2 ядра | 20GB | N8N + PostgreSQL |
| `default` | 4-6GB | 2-4 ядра | 30GB | + Qdrant + Traefik |
| `test-ai` | 4-6GB | 2-4 ядра | 40GB | + Ollama (ограниченно) |
| `cpu` | 8GB+ | 4+ ядер | 50GB+ | Полная AI конфигурация |

## ⚡ Быстрое развертывание

### 1. Подготовка системы
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка необходимых пакетов
sudo apt install -y curl git wget unzip

# Создание рабочей директории
mkdir -p ~/n8n-deployment && cd ~/n8n-deployment
```

### 2. Загрузка проекта
```bash
# Клонирование репозитория
git clone https://github.com/your-repo/n8n-ai-starter-kit.git
cd n8n-ai-starter-kit

# Переключение на стабильную версию
git checkout v1.1.2
```

### 3. Автоматический анализ и развертывание
```bash
# Анализ системы и генерация рекомендаций
chmod +x scripts/analyze-services.sh
./scripts/analyze-services.sh

# Запуск рекомендуемой конфигурации
./quick-start.sh
```

## 🔍 Анализ необходимых сервисов

### Интерактивный анализ
Скрипт `analyze-services.sh` проводит комплексный анализ:

1. **Системные ресурсы** - RAM, CPU, диск
2. **Цели использования** - автоматизация, AI, векторные операции
3. **Текущие workflow** - анализ существующих автоматизаций
4. **Рекомендации** - оптимальная конфигурация для ваших задач

### Пример вывода анализа
```
💻 АНАЛИЗ СИСТЕМНЫХ РЕСУРСОВ
Память:
  - Всего: 6GB
  - Доступно: 4GB
⚠️ Память ограничена. Рекомендуется выборочное включение AI сервисов

💡 РЕКОМЕНДАЦИИ ПО КОНФИГУРАЦИИ
✓ Базовые сервисы (обязательно)
⚠️ Ollama (тестовый режим)
  ⚠️ Ограниченные ресурсы - только для тестирования
  ✓ Профиль test-ai с лимитом 4GB памяти
```

## 🎯 Конфигурационные профили

### `default` - Базовая конфигурация
**Сервисы**: N8N, PostgreSQL, Traefik, Qdrant
```bash
docker compose --profile default up -d
```
**Ресурсы**: 4-6GB RAM, доступ по http://IP:5678

### `test-ai` - Тестирование AI (ограниченно)
**Сервисы**: Базовые + Ollama с лимитами
```bash
docker compose --profile default --profile test-ai up -d
```
**Особенности**:
- Ollama ограничен 4GB памяти
- Только компактные модели (phi-3-mini, llama3.2:1b)
- Подходит для тестирования AI функций

### `cpu` - Полная AI конфигурация
**Сервисы**: Все основные сервисы без ограничений
```bash
docker compose --profile default --profile cpu up -d
```
**Ресурсы**: 8GB+ RAM для эффективной работы

### Кастомная конфигурация
Для тонкой настройки создайте `docker-compose.override.yml`:
```yaml
services:
  ollama:
    deploy:
      resources:
        limits:
          memory: 2G  # Ваш лимит
        reservations:
          memory: 1G
```

## 📚 Пошаговое развертывание

### Шаг 1: Подготовка Ubuntu VM

#### Создание пользователя (если нужно)
```bash
# Создание пользователя для N8N
sudo adduser n8n
sudo usermod -aG sudo n8n
su - n8n
```

#### Установка Docker
```bash
# Автоматическая установка
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Проверка установки
docker --version
docker compose version
```

### Шаг 2: Настройка сети и безопасности

#### Настройка ufw (если используется)
```bash
# Открытие необходимых портов
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5678/tcp  # N8N (временно для тестирования)

# Включение firewall
sudo ufw enable
```

#### Настройка swap (рекомендуется для систем с <8GB RAM)
```bash
# Создание swap файла 4GB
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Автомонтирование при загрузке
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Шаг 3: Развертывание проекта

#### Загрузка и настройка
```bash
# Клонирование
cd ~
git clone https://github.com/your-repo/n8n-ai-starter-kit.git
cd n8n-ai-starter-kit

# Анализ системы
chmod +x scripts/*.sh
./scripts/analyze-services.sh

# Интерактивная настройка
./scripts/setup.sh
```

#### Первый запуск
```bash
# Запуск рекомендуемой конфигурации
./quick-start.sh

# Или вручную выбрать профиль
docker compose --profile default up -d

# Проверка статуса
docker compose ps
```

### Шаг 4: Проверка работоспособности

#### Базовая диагностика
```bash
# Статус контейнеров
docker compose ps

# Логи сервисов
docker compose logs n8n
docker compose logs postgres

# Проверка доступности
curl http://localhost:5678/healthz
```

#### Тестирование AI сервисов (если включены)
```bash
# Проверка Ollama
curl http://localhost:11434/api/version

# Проверка Qdrant
curl http://localhost:6333/

# Список доступных моделей Ollama
curl http://localhost:11434/api/tags
```

## 🔧 Диагностика и устранение неполадок

### Проблемы с памятью

#### Симптомы
- Контейнеры постоянно перезапускаются
- OOMKilled в логах
- Медленная работа системы

#### Решения
```bash
# Проверка использования памяти
free -h
docker stats

# Настройка лимитов для Ollama
cat > docker-compose.override.yml << EOF
services:
  ollama:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
EOF

# Перезапуск с новыми лимитами
docker compose down
docker compose --profile test-ai up -d
```

### Проблемы с AI моделями

#### Загрузка компактных моделей для test-ai профиля
```bash
# Подключение к контейнеру Ollama
docker exec -it n8n-ai-starter-kit-ollama-1 ollama pull phi3-mini

# Или более компактная модель
docker exec -it n8n-ai-starter-kit-ollama-1 ollama pull llama3.2:1b

# Проверка загруженных моделей
docker exec -it n8n-ai-starter-kit-ollama-1 ollama list
```

### Мониторинг ресурсов

#### Создание скрипта мониторинга
```bash
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== $(date) ==="
echo "Использование памяти:"
free -h
echo -e "\nТоп процессы по памяти:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo -e "\nСтатус контейнеров:"
docker compose ps
EOF

chmod +x monitor.sh
```

#### Автоматический мониторинг
```bash
# Запуск каждые 5 минут
echo "*/5 * * * * cd ~/n8n-ai-starter-kit && ./monitor.sh >> logs/monitor.log" | crontab -
```

## 📋 Чек-лист развертывания

### ✅ Подготовка системы
- [ ] Ubuntu 20.04+ установлена и обновлена
- [ ] Docker и Docker Compose установлены
- [ ] Пользователь добавлен в группу docker
- [ ] Настроен swap (для систем <8GB RAM)
- [ ] Открыты необходимые порты

### ✅ Развертывание проекта
- [ ] Репозиторий клонирован
- [ ] Переключение на стабильную версию (tag)
- [ ] Выполнен анализ системы
- [ ] Настроен .env файл
- [ ] Выбран подходящий профиль

### ✅ Проверка работоспособности
- [ ] Все контейнеры запущены (healthy)
- [ ] N8N доступен по http://IP:5678
- [ ] PostgreSQL принимает подключения
- [ ] AI сервисы отвечают (если включены)

### ✅ Оптимизация
- [ ] Настроены лимиты ресурсов
- [ ] Загружены подходящие AI модели
- [ ] Настроен мониторинг
- [ ] Созданы резервные копии .env

## 🔗 Полезные ссылки

- [Основная документация](../README.md)
- [Устранение неполадок](../TROUBLESHOOTING.md)
- [Конфигурационные профили](DOCKER_PROFILES_GUIDE.md)
- [Скрипты автоматизации](AUTOMATION_SCRIPTS.md)

## 📞 Поддержка

При возникновении проблем:
1. Выполните диагностику: `./scripts/analyze-services.sh`
2. Проверьте логи: `docker compose logs [service_name]`
3. Обратитесь к документации по устранению неполадок
4. Создайте issue с подробным описанием проблемы

---
*Создано: 23 июня 2025*  
*Версия проекта: v1.1.2+*
