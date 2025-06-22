# N8N + PostgreSQL Production Management Guide

## 🎯 Обзор

Этот документ описывает новые инструменты для управления production-ready окружением N8N + PostgreSQL. Все скрипты разработаны для обеспечения максимальной надежности и автоматизации обслуживания.

## 📂 Новые скрипты и инструменты

### 1. init-postgres.sh
**Назначение:** Автоматическая инициализация PostgreSQL для N8N
**Расположение:** `scripts/init-postgres.sh`

```bash
# Автоматическая настройка PostgreSQL для N8N
./scripts/init-postgres.sh
```

**Функции:**
- Создание базы данных N8N
- Создание пользователя с правильными правами
- Настройка схемы public
- Проверка подключения
- Создание тестовых таблиц

### 2. diagnose-n8n-postgres.sh
**Назначение:** Комплексная диагностика связки N8N + PostgreSQL
**Расположение:** `scripts/diagnose-n8n-postgres.sh`

```bash
# Полная диагностика системы
./scripts/diagnose-n8n-postgres.sh
```

**Проверки:**
- ✅ Переменные окружения
- ✅ Статус контейнеров
- ✅ Доступность PostgreSQL
- ✅ Сетевая связность
- ✅ Логи N8N
- ✅ API N8N

### 3. reset-n8n-postgres.sh
**Назначение:** Полный сброс и переинициализация
**Расположение:** `scripts/reset-n8n-postgres.sh`

```bash
# ВНИМАНИЕ: Удаляет ВСЕ данные!
./scripts/reset-n8n-postgres.sh
```

**Действия:**
- Остановка сервисов
- Удаление контейнеров и volumes
- Генерация нового ключа шифрования
- Переинициализация PostgreSQL
- Запуск и проверка N8N

### 4. monitor-n8n.sh
**Назначение:** Мониторинг и автоматическое восстановление
**Расположение:** `scripts/monitor-n8n.sh`

```bash
# Непрерывный мониторинг
./scripts/monitor-n8n.sh monitor

# Однократная проверка
./scripts/monitor-n8n.sh check

# Статистика системы
./scripts/monitor-n8n.sh stats

# Перезапуск сервисов
./scripts/monitor-n8n.sh restart-n8n
./scripts/monitor-n8n.sh restart-postgres
./scripts/monitor-n8n.sh restart-all
```

**Возможности:**
- Мониторинг здоровья сервисов
- Автоматический перезапуск при проблемах
- Мониторинг ресурсов
- Логирование и алерты
- Cooldown периоды для предотвращения циклических перезапусков

### 5. init-n8n-user.sql
**Назначение:** SQL скрипт для автоматической инициализации
**Расположение:** `scripts/init-n8n-user.sql`

Автоматически выполняется при первом запуске PostgreSQL:
- Создание пользователя N8N
- Создание базы данных
- Настройка прав доступа
- Установка расширений (uuid-ossp, pg_trgm, vector)

## 🚀 Пошаговое руководство

### Первоначальная настройка

1. **Проверка конфигурации:**
```bash
./scripts/diagnose-n8n-postgres.sh
```

2. **При проблемах с инициализацией:**
```bash
./scripts/init-postgres.sh
```

3. **Для полного сброса (если нужно):**
```bash
./scripts/reset-n8n-postgres.sh
```

### Ежедневное обслуживание

1. **Проверка состояния системы:**
```bash
./scripts/monitor-n8n.sh check
```

2. **Просмотр статистики:**
```bash
./scripts/monitor-n8n.sh stats
```

3. **При проблемах с N8N:**
```bash
./scripts/monitor-n8n.sh restart-n8n
```

### Production мониторинг

1. **Запуск непрерывного мониторинга:**
```bash
# В фоновом режиме
nohup ./scripts/monitor-n8n.sh monitor > /tmp/n8n-monitor.log 2>&1 &
```

2. **Настройка systemd сервиса (Linux):**
```bash
# Создание файла сервиса
sudo tee /etc/systemd/system/n8n-monitor.service << EOF
[Unit]
Description=N8N Health Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/n8n-ai-starter-kit
ExecStart=/path/to/n8n-ai-starter-kit/scripts/monitor-n8n.sh monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Активация сервиса
sudo systemctl enable n8n-monitor
sudo systemctl start n8n-monitor
```

## 🔧 Улучшения в docker-compose.yml

### Обновленная конфигурация PostgreSQL

```yaml
postgres:
  image: postgres:latest
  environment:
    - POSTGRES_INITDB_ARGS="--encoding=UTF8 --lc-collate=C --lc-ctype=C"
  volumes:
    - ./scripts/init-n8n-user.sql:/docker-entrypoint-initdb.d/02-init-n8n-user.sql:ro
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} || pg_isready -U postgres"]
    start_period: 10s
```

### Улучшенный healthcheck для N8N

```yaml
n8n:
  depends_on:
    postgres:
      condition: service_healthy
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:5678/healthz || exit 1"]
    start_period: 60s
    retries: 5
```

## 📊 Мониторинг и логирование

### Файлы логов

- **Основные логи:** `/tmp/n8n-health-monitor.log`
- **Алерты:** `/tmp/n8n-health-alerts.log`
- **Docker логи:** `docker logs n8n-ai-starter-kit-n8n-1`
- **PostgreSQL логи:** `docker logs n8n-ai-starter-kit-postgres-1`

### Просмотр логов в реальном времени

```bash
# Логи N8N
docker logs n8n-ai-starter-kit-n8n-1 -f

# Логи PostgreSQL
docker logs n8n-ai-starter-kit-postgres-1 -f

# Логи мониторинга
tail -f /tmp/n8n-health-monitor.log

# Алерты
tail -f /tmp/n8n-health-alerts.log
```

## 🚨 Устранение типичных проблем

### 1. N8N не может подключиться к PostgreSQL

**Диагностика:**
```bash
./scripts/diagnose-n8n-postgres.sh
```

**Решение:**
```bash
./scripts/init-postgres.sh
docker compose restart n8n
```

### 2. Ошибки шифрования N8N

**Решение:**
```bash
./scripts/reset-n8n-postgres.sh
```

### 3. Проблемы с производительностью

**Мониторинг ресурсов:**
```bash
./scripts/monitor-n8n.sh stats
docker stats
```

**Увеличение лимитов в docker-compose.yml:**
```yaml
deploy:
  resources:
    limits:
      memory: 4G  # Увеличить с 2G
      cpus: '4'   # Увеличить с 2
```

### 4. Автоматическое восстановление не работает

**Проверка cooldown:**
```bash
ls -la /tmp/n8n-restart-*
```

**Принудительный перезапуск:**
```bash
rm -f /tmp/n8n-restart-*
./scripts/monitor-n8n.sh restart-all
```

## ⚡ Best Practices

### 1. Регулярное обслуживание

- Запускайте диагностику еженедельно
- Мониторьте логи на предмет ошибок
- Проверяйте использование ресурсов

### 2. Backup стратегия

```bash
# Backup базы данных
docker exec n8n-ai-starter-kit-postgres-1 pg_dump -U root n8n > backup_$(date +%Y%m%d).sql

# Backup конфигурации
cp .env .env.backup.$(date +%Y%m%d)
```

### 3. Настройка алертов

Отредактируйте функцию `send_alert()` в `monitor-n8n.sh` для интеграции с:
- Slack
- Discord
- Email
- PagerDuty
- Другими системами уведомлений

### 4. Производительность

- Настройте PostgreSQL параметры в docker-compose.yml
- Мониторьте использование памяти и CPU
- Используйте SSD для volumes

## 🔒 Безопасность

### 1. Обновление паролей

```bash
# Генерация новых паролей
openssl rand -base64 32  # Для N8N_ENCRYPTION_KEY
openssl rand -base64 16  # Для паролей
```

### 2. Ограничение доступа

- Настройте firewall для ограничения доступа к портам
- Используйте Traefik для SSL/TLS терминации
- Регулярно обновляйте образы Docker

### 3. Аудит

- Ведите логи всех операций
- Мониторьте подозрительную активность
- Настройте ротацию логов

## 📞 Поддержка

При возникновении проблем:

1. Запустите полную диагностику
2. Проверьте логи всех сервисов
3. Обратитесь к разделу устранения неполадок
4. При необходимости выполните полный сброс

Все скрипты включают подробное логирование и информативные сообщения об ошибках для облегчения диагностики.
