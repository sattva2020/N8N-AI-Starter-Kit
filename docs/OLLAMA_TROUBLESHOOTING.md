# Диагностика и решение проблемы с Ollama

## 🚨 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ (Июнь 2025): Health Check Ollama

### ❌ **Обнаружена проблема:**
- **Health check Ollama падает** с ошибкой `curl: executable file not found`
- **Контейнер показывает `unhealthy`** статус
- **API Ollama работает корректно** (`curl http://localhost:11434/api/version` отвечает)

### ✅ **Решение применено:**
```yaml
# БЫЛО (не работает):
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:11434/api/version"]

# СТАЛО (работает):
healthcheck:
  test: ["CMD", "/bin/ollama", "ps"]
```

### 🚀 **Команды для применения исправления:**
```bash
# 1. Получить исправления
git pull origin main

# 2. Перезапустить с новым health check
docker compose down && docker compose --profile cpu up -d

# 3. Проверить статус (должен стать healthy)
docker ps | grep ollama

# 4. Проверить health check изнутри
docker exec ollama /bin/ollama ps
```

---

## 🎉 ОБНОВЛЕНИЕ: Проблема найдена и исправлена!

### ✅ Диагностика завершена:
- **Проблема**: Отсутствуют проброшенные порты в конфигурации
- **Ollama**: Работает внутри контейнера, но порт 11434 не проброшен
- **Qdrant**: Работает внутри контейнера, но порт 6333 не проброшен

### 🔧 Исправления внесены:
- ✅ Добавлен `ports: ["11434:11434"]` в ollama-compose.yml
- ✅ Добавлен `ports: ["6333:6333"]` в docker-compose.yml

### 🚀 Команды для применения исправлений:

```bash
# 1. Получить исправления
git pull origin main

# 2. Перезапустить сервисы с новой конфигурацией
docker compose down
docker compose --profile cpu up -d

# 3. Проверить порты (должны появиться)
docker port ollama
docker port n8n-ai-starter-kit-qdrant-1

# 4. Проверить API (должны работать)
curl http://localhost:11434/api/version
curl http://localhost:6333/health
```

### 🔍 Текущая диагностика показывает:

**Работающие сервисы:**
- ✅ **Graphiti**: Успешно запущен на порту 8000
- ✅ **Qdrant**: Успешно запущен на порту 6333 
- ✅ **PostgreSQL, Neo4j, Minio**: Здоровый статус

**Проблемы:**
- 🔄 **Ollama**: Запущен, но API недоступен (возможно порт не проброшен)
- 🔄 **N8N**: Перезапускается из-за зависимостей
- 🔄 **Supabase**: Проблемы с конфигурацией

### 🔧 Дополнительная диагностика Ollama:

```bash
# Проверить порты Ollama контейнера
docker port ollama

# Проверить логи Ollama подробнее
docker compose logs --tail=20 ollama

# Проверить сетевые подключения в контейнере
docker exec ollama netstat -tlnp

# Проверить внутренний API Ollama
docker exec ollama curl -f http://localhost:11434/api/version

# Проверить Qdrant (должен работать)
curl -f http://localhost:6333/health

# Проверить доступные порты на хосте
sudo netstat -tlnp | grep -E "(11434|6333|8000)"
```

### 🔧 Возможные решения для Ollama:

1. **Проверить проброс портов в docker-compose:**
```bash
# Найти конфигурацию Ollama
grep -r "11434" compose/ docker-compose.yml
```

2. **Если порт не проброшен, добавить в ollama-compose.yml:**
```yaml
ports:
  - "11434:11434"
```

3. **Перезапустить только Ollama:**
```bash
docker compose restart ollama
```

## 🚀 Если Ollama работает корректно:

### Проверить API Ollama:
```bash
# Проверить версию
curl http://localhost:11434/api/version

# Проверить список моделей
curl http://localhost:11434/api/tags
```

### Если остальные сервисы не запускаются:
```bash
# Попробовать запустить без Graphiti (минимальный профиль)
docker compose down
docker compose --profile cpu up -d ollama qdrant n8n traefik

# Или использовать базовый профиль
./start.sh developer
```

## 🔍 Диагностика показала:

### Основные проблемы:
1. **Ollama**: `Restarting (126)` - ошибка entrypoint скрипта
2. **N8N**: `Restarting (2)` - зависит от Ollama
3. **Supabase Storage**: `Restarting (1)` - возможные проблемы с зависимостями
4. **Qdrant**: `unhealthy` - проблемы с health check
5. **Traefik**: `unhealthy` - проблемы с конфигурацией

### Основная причина:
Ошибка `/entrypoint.sh: /entrypoint.sh: Is a directory` в контейнере Ollama из-за неправильного монтирования кастомного entrypoint скрипта.

## ✅ Решение

### 1. Остановить все контейнеры
```bash
docker compose down
```

### 2. Обновить конфигурацию (уже исправлено)
```bash
git pull origin main
```

### 3. Очистить Docker ресурсы
```bash
docker system prune -f
docker volume prune -f
```

### 4. Перезапустить систему
```bash
./start.sh cpu
```

## 🚀 Ожидаемый результат

После исправления все сервисы должны запуститься корректно:

- ✅ **Ollama**: здоровый статус, доступен на порту 11434
- ✅ **N8N**: запустится после успешного запуска Ollama
- ✅ **Supabase**: все компоненты работают
- ✅ **Qdrant**: здоровый статус
- ✅ **Traefik**: правильная маршрутизация

## 🔧 Дополнительные команды для проверки

### Проверка статуса после исправления:
```bash
# Статус всех контейнеров
docker compose ps

# Проверка здоровья Ollama
curl -f http://localhost:11434/api/version

# Проверка логов Ollama
docker compose logs ollama

# Полная диагностика
./scripts/diagnose.sh
```

### Настройка OpenAI API ключа (по желанию):
```bash
# Отредактировать .env файл
nano .env

# Добавить строку:
OPENAI_API_KEY=your_actual_api_key_here
```

## 📝 Что было исправлено

1. **Удален кастомный entrypoint** из конфигурации Ollama
2. **Убрано монтирование** проблемного скрипта
3. **Возвращен стандартный entrypoint** Ollama образа

Теперь Ollama будет использовать стандартный механизм запуска без кастомных скриптов, что должно решить проблему с зависимостями.

## 🎯 Команды для применения исправления

```bash
# Перейти в папку проекта
cd ~/N8N-AI-Starter-Kit

# Получить исправления
git pull origin main

# Остановить и очистить
docker compose down
docker system prune -f

# Запустить заново
./start.sh cpu
```

После выполнения этих команд все сервисы должны работать корректно!

## 🏥 ПРОБЛЕМЫ С HEALTH CHECK СЕРВИСОВ

### Qdrant Health Check
**Проблема:** Qdrant показывает статус `unhealthy`
**Решение:** 
```bash
# Проверить правильный endpoint
curl http://localhost:6333/

# НЕ используйте (возвращает 404):
curl http://localhost:6333/health

# Проверить dashboard
curl http://localhost:6333/dashboard
```

**Исправление:** В `docker-compose.yml` health check должен использовать `/`:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:6333/"]
```

### Graphiti Health Check
**Проблема:** Graphiti показывает статус `unhealthy`
**Решение:**
```bash
# Проверить правильный endpoint
curl http://localhost:8000/health

# Также проверить основной endpoint
curl http://localhost:8000/
```

### Универсальная диагностика Health Check
```bash
# Проверить все сервисы
docker compose ps

# Посмотреть логи конкретного сервиса
docker compose logs [SERVICE_NAME]

# Принудительная проверка health check
docker exec [CONTAINER_NAME] curl -f http://localhost:[PORT]/[ENDPOINT]
```

### 🛠️ Исправление Health Check для Ollama (Июнь 2025):

**Проблема**: Docker health check для Ollama использовал curl, который отсутствует в контейнере

**Симптомы**:
- Контейнер Ollama помечен как `unhealthy` в `docker ps`
- Ошибка: `exec: "curl": executable file not found in $PATH`
- API работает корректно при прямых запросах
- Другие сервисы могут падать из-за dependency на unhealthy Ollama

**Решение**:
```yaml
healthcheck:
  test: ["CMD", "/bin/ollama", "ps"]
  interval: 30s
  timeout: 15s
  retries: 5
  start_period: 60s
```

**Проверка исправления**:
```bash
# Перезапустить сервисы
docker compose down && docker compose --profile cpu up -d

# Проверить health status (должен быть healthy)
docker ps | grep ollama

# Проверить health check логи
docker inspect ollama | grep -A 10 Health

# Проверить работу команды health check
docker exec ollama /bin/ollama ps
```

### 🛠️ Исправление Health Check для Ollama (Декабрь 2024):

**Проблема**: Docker health check для Ollama использовал `curl`, которая отсутствует в контейнере

**Симптомы**:
- Контейнер Ollama помечен как `unhealthy` в `docker ps`
- Ошибка: `exec: "curl": executable file not found in $PATH`
- API работает корректно при прямых запросах
- Другие сервисы могут падать из-за dependency на unhealthy Ollama

**Решение**:
```yaml
healthcheck:
  test: ["CMD", "/bin/ollama", "ps"]
  interval: 30s
  timeout: 15s
  retries: 5
  start_period: 60s
```

**Проверка исправления**:
```bash
# Перезапустить сервисы
docker compose down && docker compose --profile cpu up -d

# Проверить health status (должен быть healthy)
docker ps | grep ollama

# Проверить health check изнутри контейнера
docker exec ollama /bin/ollama ps
```
