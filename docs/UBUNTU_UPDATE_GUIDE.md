# 🔄 Обновление N8N AI Starter Kit на Ubuntu

## 📋 Пошаговая инструкция обновления

### 🚨 **ВАЖНО: Создайте бэкап перед обновлением!**

---

## 📦 Метод 1: Обновление через Git (Рекомендуется)

### 1️⃣ **Остановка сервисов**
```bash
cd ~/N8N-AI-Starter-Kit  # или путь к вашему проекту
docker compose down
```

### 2️⃣ **Создание бэкапа данных**
```bash
# Создать папку для бэкапов
mkdir -p ~/backups/$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backups/$(date +%Y%m%d_%H%M%S)

# Бэкап Docker volumes
docker run --rm -v n8n-ai-starter-kit_n8n_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/n8n_storage.tar.gz -C /data .
docker run --rm -v n8n-ai-starter-kit_postgres_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/postgres_storage.tar.gz -C /data .
docker run --rm -v n8n-ai-starter-kit_qdrant_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/qdrant_storage.tar.gz -C /data .

# Бэкап конфигурации
cp .env $BACKUP_DIR/
cp -r n8n/ $BACKUP_DIR/ 2>/dev/null || true

echo "✅ Бэкап создан в: $BACKUP_DIR"
```

### 3️⃣ **Сохранение текущей конфигурации**
```bash
# Сохранить .env файл
cp .env .env.backup

# Сохранить кастомные настройки (если есть)
cp docker-compose.override.yml docker-compose.override.yml.backup 2>/dev/null || true
```

### 4️⃣ **Получение обновлений**
```bash
# Проверить статус Git
git status

# Сохранить локальные изменения (если есть)
git stash push -m "Локальные изменения перед обновлением $(date)"

# Получить последние изменения
git fetch origin main

# Посмотреть что изменилось
git log --oneline HEAD..origin/main

# Обновиться до последней версии
git pull origin main
```

### 5️⃣ **Восстановление конфигурации**
```bash
# Восстановить .env (проверить совместимость)
if [ -f .env.backup ]; then
    echo "⚠️  Проверьте совместимость .env файла:"
    echo "   Новый template.env vs ваш .env.backup"
    
    # Показать различия
    diff template.env .env.backup || true
    
    # Выберите один из вариантов:
    # Вариант A: Использовать старый .env
    cp .env.backup .env
    
    # Вариант B: Обновить на основе нового template.env
    # cp template.env .env
    # nano .env  # отредактировать под ваши настройки
fi
```

### 6️⃣ **Обновление Docker образов**
```bash
# Получить последние образы
docker compose pull

# Пересобрать если нужно
docker compose build --no-cache
```

### 7️⃣ **Запуск обновленной системы**
```bash
# Запустить с нужным профилем
docker compose --profile cpu up -d

# Проверить статус
docker compose ps

# Проверить логи
docker compose logs -f
```

---

## 🔄 Метод 2: Полная переустановка

### 1️⃣ **Полная остановка и очистка**
```bash
cd ~/N8N-AI-Starter-Kit

# Остановить все сервисы
docker compose down

# Удалить все связанные контейнеры и образы (ОСТОРОЖНО!)
docker system prune -a --volumes --force
```

### 2️⃣ **Скачивание новой версии**
```bash
# Переименовать старую папку
mv ~/N8N-AI-Starter-Kit ~/N8N-AI-Starter-Kit.old

# Клонировать новую версию
git clone https://github.com/your-repo/N8N-AI-Starter-Kit.git ~/N8N-AI-Starter-Kit
cd ~/N8N-AI-Starter-Kit
```

### 3️⃣ **Восстановление данных**
```bash
# Восстановить конфигурацию
cp ~/N8N-AI-Starter-Kit.old/.env .env 2>/dev/null || cp template.env .env

# Восстановить пользовательские данные
cp -r ~/N8N-AI-Starter-Kit.old/n8n/ ./ 2>/dev/null || true
```

---

## 🚀 Метод 3: Автоматическое обновление (скрипт)

### Создайте скрипт автообновления:
```bash
cat > ~/update-n8n-kit.sh << 'EOF'
#!/bin/bash

# Настройки
PROJECT_DIR="$HOME/N8N-AI-Starter-Kit"
BACKUP_DIR="$HOME/backups/$(date +%Y%m%d_%H%M%S)"
PROFILE="cpu"  # Измените на ваш профиль

echo "🔄 Начинаем обновление N8N AI Starter Kit..."

# Переход в папку проекта
cd "$PROJECT_DIR" || exit 1

# Остановка сервисов
echo "⏹️  Остановка сервисов..."
docker compose down

# Создание бэкапа
echo "💾 Создание бэкапа..."
mkdir -p "$BACKUP_DIR"
cp .env "$BACKUP_DIR/" 2>/dev/null || true
docker run --rm -v n8n-ai-starter-kit_n8n_storage:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/n8n_storage.tar.gz -C /data . 2>/dev/null || true

# Сохранение локальных изменений
echo "📝 Сохранение локальных изменений..."
git stash push -m "Auto-backup $(date)"

# Обновление кода
echo "📥 Получение обновлений..."
git fetch origin main
git pull origin main

# Обновление образов
echo "🐳 Обновление Docker образов..."
docker compose pull

# Запуск сервисов
echo "🚀 Запуск обновленных сервисов..."
docker compose --profile "$PROFILE" up -d

# Проверка статуса
echo "✅ Проверка статуса сервисов..."
sleep 10
docker compose ps

echo "🎉 Обновление завершено!"
echo "📁 Бэкап сохранен в: $BACKUP_DIR"
EOF

# Сделать скрипт исполняемым
chmod +x ~/update-n8n-kit.sh
```

### Использование скрипта:
```bash
# Запустить обновление
~/update-n8n-kit.sh
```

---

## 🛠️ Диагностика после обновления

### 1️⃣ **Проверка сервисов**
```bash
# Статус всех сервисов
docker compose ps

# Логи всех сервисов
docker compose logs

# Проверка конкретного сервиса
docker compose logs n8n
docker compose logs qdrant
docker compose logs ollama
```

### 2️⃣ **Проверка API endpoints**
```bash
# Qdrant
curl http://localhost:6333/
curl http://localhost:6333/dashboard

# Ollama
curl http://localhost:11434/api/tags

# N8N (если запущен)
curl http://localhost:5678/healthz
```

### 3️⃣ **Проверка health checks**
```bash
# Все сервисы должны быть healthy
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
```

---

## 🚨 ДИАГНОСТИКА ПРОБЛЕМ ПОСЛЕ ОБНОВЛЕНИЯ

### Основные проблемы и их решения:

#### 1️⃣ **N8N Encryption Key Mismatch**
```bash
# Проблема: "Mismatching encryption keys"
# РЕШЕНИЕ A: Сбросить N8N конфигурацию (ПОТЕРЯ ДАННЫХ!)
docker compose down
sudo rm -rf /var/lib/docker/volumes/n8n-ai-starter-kit_n8n_storage/_data/config
docker compose --profile cpu up -d

# РЕШЕНИЕ B: Синхронизировать ключи
docker exec n8n-ai-starter-kit-n8n-1 cat /home/node/.n8n/config
# Скопировать значение encryptionKey из config в .env файл как N8N_ENCRYPTION_KEY
```

#### 2️⃣ **Ollama Unhealthy**
```bash
# Проверить статус Ollama
docker compose logs ollama

# Перезапустить Ollama
docker compose restart ollama

# Проверить health check
docker exec ollama curl -f http://localhost:11434/api/tags
```

#### 3️⃣ **Graphiti/Supabase Dependency Failed**
```bash
# Остановить все и запустить поэтапно
docker compose down

# Запустить только базовые сервисы
docker compose up -d traefik postgres minio

# Добавить Qdrant
docker compose up -d qdrant

# Добавить Ollama
docker compose up -d ollama

# Запустить все остальное
docker compose --profile cpu up -d
```

#### 4️⃣ **PostgreSQL Role Errors**
```bash
# Проблема: "role 'root' does not exist"
# Проверить переменные окружения
grep POSTGRES .env

# Убедиться что переменные установлены правильно:
# POSTGRES_USER=postgres (не root!)
# POSTGRES_PASSWORD=<ваш_пароль>
# POSTGRES_DB=n8n
```

### 🔧 **Быстрая диагностика:**
```bash
# Проверить статус всех сервисов
docker compose ps

# Проверить какие сервисы healthy/unhealthy
docker compose ps --format "table {{.Service}}\t{{.Status}}"

# Проверить логи проблемных сервисов
docker compose logs n8n
docker compose logs ollama
docker compose logs qdrant
docker compose logs graphiti
```

### ⚡ **Быстрое исправление:**
```bash
# Создать скрипт быстрого исправления
cat > ~/fix-n8n-kit.sh << 'EOF'
#!/bin/bash
echo "🔧 Исправление проблем N8N AI Starter Kit..."

cd ~/N8N-AI-Starter-Kit

# Остановка всех сервисов
echo "⏹️  Остановка сервисов..."
docker compose down

# Проверка .env файла
if ! grep -q "POSTGRES_USER=postgres" .env; then
    echo "📝 Исправление POSTGRES_USER в .env..."
    sed -i 's/POSTGRES_USER=.*/POSTGRES_USER=postgres/' .env
fi

# Очистка проблемных контейнеров
echo "🧹 Очистка проблемных контейнеров..."
docker compose rm -f n8n x-service-n8n

# Поэтапный запуск
echo "🚀 Поэтапный запуск сервисов..."
docker compose up -d traefik postgres minio
sleep 10
docker compose up -d qdrant
sleep 5
docker compose up -d ollama
sleep 10
docker compose --profile cpu up -d

echo "✅ Исправление завершено! Проверьте статус:"
docker compose ps
EOF

chmod +x ~/fix-n8n-kit.sh
```

---

## 🔄 Откат к предыдущей версии

### Если что-то пошло не так:
```bash
# Остановить текущие сервисы
docker compose down

# Вернуться к предыдущему коммиту
git log --oneline -10  # найти нужный коммит
git checkout <COMMIT_HASH>

# Или восстановить из stash
git stash list
git stash apply stash@{0}

# Запустить старую версию
docker compose --profile cpu up -d
```

---

## 📅 Регулярное обновление

### Настройка автоматических обновлений через cron:
```bash
# Добавить в crontab
crontab -e

# Добавить строку (обновление каждое воскресенье в 3:00)
0 3 * * 0 /home/$(whoami)/update-n8n-kit.sh >> /var/log/n8n-update.log 2>&1
```

---

## ⚠️ Важные замечания

### 🔐 **Безопасность:**
- Всегда создавайте бэкап перед обновлением
- Проверяйте .env файл на новые переменные
- Тестируйте обновления в dev-среде

### 🚨 **Troubleshooting:**
- Если сервисы не запускаются - проверьте логи
- При ошибках портов - убедитесь что порты свободны  
- При проблемах с образами - выполните `docker system prune -a`

### 📞 **Поддержка:**
- Документация: `docs/TROUBLESHOOTING.md`
- Логи: `docker compose logs [service]`
- Диагностика: `scripts/diagnose.sh`

---

✅ **Готово!** Ваш N8N AI Starter Kit обновлен до последней версии!
