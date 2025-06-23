# 🚀 Руководство по развертыванию n8n-ai-starter-kit на Ubuntu VM

## 🎯 Цель
Подготовка production-ready окружения для Ubuntu VM с минимальным набором сервисов (без MinIO/S3 и без Supabase).

## 📋 Системные требования

### Минимальные требования Ubuntu VM:
- **OS**: Ubuntu 20.04+ (рекомендуется 22.04 LTS)
- **RAM**: 6GB (для базового тестирования)
- **CPU**: 4 ядра
- **Диск**: 30GB свободного места
- **Сеть**: Интернет соединение

### Рекомендуемые требования:
- **RAM**: 8GB+ (для включения Ollama)
- **CPU**: 6+ ядер
- **Диск**: 50GB+ SSD

---

## 🔧 Этап 1: Подготовка Ubuntu VM

### 1.1 Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip htop
```

### 1.2 Установка Docker и Docker Compose
```bash
# Удаление старых версий
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
newgrp docker

# Проверка установки
docker --version
docker compose version
```

### 1.3 Настройка системы
```bash
# Увеличение лимитов для контейнеров
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Настройка swap (рекомендуется для VM с малой RAM)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 🚀 Этап 2: Развертывание проекта

### 2.1 Клонирование репозитория
```bash
cd ~
git clone https://github.com/your-username/n8n-ai-starter-kit.git
cd n8n-ai-starter-kit
```

### 2.2 Подготовка окружения
```bash
# Копирование шаблона конфигурации
cp template.env .env

# Настройка прав на выполнение скриптов
chmod +x scripts/*.sh
chmod +x start.sh

# Создание необходимых директорий
mkdir -p data/n8n-files data/n8n-workflows logs
```

### 2.3 Настройка переменных окружения
```bash
# Редактирование .env файла
nano .env

# Минимальные обязательные параметры:
# DOMAIN=localhost
# N8N_HOST=localhost
# N8N_PORT=5678
# POSTGRES_DB=n8n
# POSTGRES_USER=n8n_user
# POSTGRES_PASSWORD=n8n_secure_password
# POSTGRES_NON_ROOT_USER=n8n_user
# POSTGRES_NON_ROOT_PASSWORD=n8n_secure_password
# N8N_ENCRYPTION_KEY=<будет сгенерирован автоматически>
```

---

## 🧪 Этап 3: Тестирование конфигураций

### 3.1 Минимальная конфигурация (только базовые сервисы)
```bash
# Запуск минимальной конфигурации
docker compose -f compose/test-minimal.yml --profile test up -d

# Проверка статуса
docker compose -f compose/test-minimal.yml ps

# Проверка логов
docker compose -f compose/test-minimal.yml logs -f
```

**Что тестируется:**
- ✅ N8N (базовая функциональность)
- ✅ PostgreSQL (подключение и база данных)
- ✅ Traefik (прокси без SSL)

### 3.2 Конфигурация с Qdrant (добавление векторной БД)
```bash
# Остановка минимальной конфигурации
docker compose -f compose/test-minimal.yml down

# Запуск с Qdrant
docker compose -f compose/test-minimal.yml --profile test --profile test-qdrant up -d

# Проверка Qdrant
curl -X GET 'http://localhost:6333/collections'
```

### 3.3 Конфигурация с Ollama (добавление AI)
```bash
# Запуск с AI сервисами
docker compose -f compose/test-minimal.yml --profile test --profile test-ai up -d

# Проверка Ollama
docker compose -f compose/test-minimal.yml logs ollama-test

# Загрузка тестовой модели
docker compose -f compose/test-minimal.yml exec ollama-test ollama pull llama3.1:8b
```

---

## 🔍 Этап 4: Диагностика и проверки

### 4.1 Автоматическая диагностика
```bash
# Запуск комплексной диагностики
./scripts/comprehensive-container-check.sh

# Проверка конкретных сервисов
./scripts/diagnose.sh
./scripts/check-ollama.sh
```

### 4.2 Ручная проверка сервисов

**N8N интерфейс:**
```bash
# Доступ через браузер
echo "N8N доступен по адресу: http://$(hostname -I | awk '{print $1}'):5678"
```

**PostgreSQL подключение:**
```bash
# Проверка подключения к БД
docker compose exec postgres-test psql -U n8n_user -d n8n -c "\dt"
```

**Traefik dashboard:**
```bash
echo "Traefik dashboard: http://$(hostname -I | awk '{print $1}'):80/dashboard/"
```

### 4.3 Тестирование функциональности

**Создание тестового workflow в N8N:**
1. Открыть N8N интерфейс
2. Создать простой workflow (HTTP Request → Set → Respond)
3. Активировать workflow
4. Протестировать выполнение

**Проверка взаимодействия с Qdrant (если включён):**
```bash
# Создание коллекции
curl -X PUT 'http://localhost:6333/collections/test' \
    -H 'Content-Type: application/json' \
    -d '{
        "vectors": {
            "size": 4,
            "distance": "Dot"
        }
    }'

# Проверка коллекции
curl -X GET 'http://localhost:6333/collections/test'
```

---

## 📊 Этап 5: Анализ необходимости сервисов

### 5.1 Анализ зависимостей

**Вопросы для анализа:**
1. **Требуется ли Qdrant?**
   - Планируется ли работа с векторными данными?
   - Нужна ли семантическая обработка текста?
   
2. **Требуется ли Supabase?**
   - Нужна ли дополнительная БД кроме PostgreSQL?
   - Планируется ли использование Supabase Auth/Storage?

3. **Требуется ли Ollama?**
   - Планируется ли локальная обработка AI?
   - Достаточно ли внешних AI API?

### 5.2 Рекомендации по конфигурации

**Минимальная production конфигурация:**
```bash
# Только базовые сервисы
docker compose --profile main up -d n8n postgres traefik
```

**Расширенная конфигурация с AI:**
```bash
# С Ollama и Qdrant
docker compose --profile main --profile ollama --profile qdrant up -d
```

---

## 🛠️ Этап 6: Production развертывание

### 6.1 Подготовка к production
```bash
# Очистка тестовых контейнеров
docker compose -f compose/test-minimal.yml down -v

# Очистка системы
./scripts/clean-docker.sh

# Запуск production конфигурации
./scripts/setup.sh
./start.sh
```

### 6.2 Настройка мониторинга
```bash
# Создание скрипта мониторинга
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== Статус сервисов ==="
docker compose ps

echo -e "\n=== Использование ресурсов ==="
docker stats --no-stream

echo -e "\n=== Дисковое пространство ==="
df -h

echo -e "\n=== Память ==="
free -h
EOF

chmod +x monitor.sh

# Запуск мониторинга
./monitor.sh
```

### 6.3 Настройка автозапуска
```bash
# Создание systemd сервиса
sudo tee /etc/systemd/system/n8n-ai-kit.service > /dev/null << EOF
[Unit]
Description=N8N AI Starter Kit
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Активация сервиса
sudo systemctl enable n8n-ai-kit.service
sudo systemctl start n8n-ai-kit.service
```

---

## ✅ Контрольный список

### Перед развертыванием:
- [ ] Ubuntu VM подготовлена (Docker установлен)
- [ ] Системные требования соблюдены
- [ ] Репозиторий клонирован
- [ ] Переменные окружения настроены

### Тестирование:
- [ ] Минимальная конфигурация работает
- [ ] N8N интерфейс доступен
- [ ] PostgreSQL подключается
- [ ] Traefik проксирует запросы
- [ ] (Опционально) Qdrant отвечает на API запросы
- [ ] (Опционально) Ollama загружает модели

### Production:
- [ ] Все тесты пройдены
- [ ] Мониторинг настроен
- [ ] Автозапуск включён
- [ ] Резервное копирование настроено
- [ ] Логирование работает

---

## 🚨 Устранение неполадок

### Типичные проблемы:

**Проблема: N8N не подключается к PostgreSQL**
```bash
# Проверка переменных окружения
grep POSTGRES .env

# Проверка логов PostgreSQL
docker compose logs postgres

# Пересоздание контейнера PostgreSQL
docker compose down postgres
docker compose up -d postgres
```

**Проблема: Недостаточно памяти**
```bash
# Проверка использования памяти
free -h
docker stats

# Настройка swap
sudo swapon --show
```

**Проблема: Порты заняты**
```bash
# Проверка занятых портов
netstat -tlnp | grep ':5678\|:80\|:5432'

# Остановка конфликтующих сервисов
sudo systemctl stop apache2 nginx
```

---

## 📞 Поддержка

При возникновении проблем:
1. Запустите `./scripts/diagnose.sh`
2. Проверьте логи: `docker compose logs -f`
3. Изучите документацию в папке `docs/`
4. Создайте issue в репозитории с выводом диагностики

---

**Дата создания:** $(date)
**Версия:** v1.1.2
**Статус:** Production Ready
