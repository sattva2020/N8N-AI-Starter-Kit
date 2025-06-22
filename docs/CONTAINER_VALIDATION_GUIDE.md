# 🔍 Полная проверка всех контейнеров N8N AI Starter Kit

## Скрипты для проверки контейнеров

### 1. 🚀 Быстрая проверка всех сервисов
```bash
chmod +x scripts/comprehensive-container-check.sh
./scripts/comprehensive-container-check.sh
```

**Что проверяет:**
- ✅ Статус каждого контейнера (running/stopped)
- 🏥 Health checks всех сервисов
- 📋 Анализ логов на наличие ошибок
- 🌐 Доступность портов (5678, 11434, 6333, и др.)
- 📊 Общая статистика Docker

### 2. ⚡ Быстрая проверка основных сервисов
```bash
chmod +x scripts/quick-check.sh
./scripts/quick-check.sh
```

**Что проверяет:**
- 📦 Статус основных контейнеров
- 🌐 HTTP доступность сервисов
- ⚡ Быстрые curl-тесты

### 3. 📋 Анализ ошибок в логах
```bash
chmod +x scripts/analyze-logs.sh
./scripts/analyze-logs.sh [container_name] [lines]
```

**Примеры:**
```bash
./scripts/analyze-logs.sh n8n-ai-starter-kit-n8n-1 100
./scripts/analyze-logs.sh n8n-ai-starter-kit-ollama-1
```

### 4. 🔧 Полная проверка всех сервисов
```bash
chmod +x scripts/validate-all-services.sh
./scripts/validate-all-services.sh
```

## 🎯 Пошаговая диагностика

### Шаг 1: Общая проверка
```bash
# 1. Проверяем Docker
docker --version
docker-compose --version

# 2. Проверяем запущенные контейнеры
docker ps

# 3. Запускаем комплексную проверку
./scripts/comprehensive-container-check.sh
```

### Шаг 2: Если найдены ошибки
```bash
# 1. Смотрим логи проблемного контейнера
docker logs [container_name] --tail 100

# 2. Анализируем конкретные ошибки
./scripts/analyze-logs.sh [container_name] 200

# 3. Перезапускаем проблемный сервис
docker-compose restart [service_name]
```

### Шаг 3: Проверка конкретных сервисов

#### N8N + PostgreSQL:
```bash
# Проверка связки N8N + PostgreSQL
./scripts/diagnose-n8n-postgres.sh

# Мониторинг N8N
./scripts/monitor-n8n.sh

# Если нужен сброс
./scripts/reset-n8n-postgres.sh
```

#### Ollama:
```bash
# Проверка Ollama
curl http://localhost:11434
curl http://localhost:11434/api/version

# Список моделей
curl http://localhost:11434/api/tags

# Логи Ollama
docker logs n8n-ai-starter-kit-ollama-1 --tail 50
```

#### Qdrant:
```bash
# Проверка Qdrant
curl http://localhost:6333
curl http://localhost:6333/collections

# Логи Qdrant  
docker logs n8n-ai-starter-kit-qdrant-1 --tail 50
```

## 🚨 Типичные проблемы и решения

### ❌ Контейнер не запускается
```bash
# 1. Проверить логи
docker logs [container_name]

# 2. Проверить ресурсы
docker system df
docker system prune

# 3. Перезапустить
docker-compose down && docker-compose up -d
```

### ❌ Health check failed
```bash
# 1. Проверить конфигурацию healthcheck
docker inspect [container_name] | grep -A 10 Health

# 2. Проверить внутренние порты
docker exec [container_name] netstat -tlnp

# 3. Тестировать healthcheck вручную
docker exec [container_name] [healthcheck_command]
```

### ❌ Порт недоступен
```bash
# 1. Проверить проброс портов
docker port [container_name]

# 2. Проверить сетевые настройки
docker network ls
docker network inspect [network_name]

# 3. Проверить firewall
sudo ufw status
sudo netstat -tlnp | grep [port]
```

## 📊 Ожидаемые результаты

### ✅ Все работает корректно:
```
🔍 COMPREHENSIVE CONTAINER VALIDATION
==================================================================
📊 ИТОГОВАЯ СТАТИСТИКА
   📦 Всего проверено: 9
   ✅ Работают корректно: 9
   ❌ С ошибками: 0

🎉 ВСЕ КОНТЕЙНЕРЫ РАБОТАЮТ КОРРЕКТНО!
```

### ⚠️ Найдены проблемы:
```
📊 ИТОГОВАЯ СТАТИСТИКА
   📦 Всего проверено: 9
   ✅ Работают корректно: 7
   ❌ С ошибками: 2

⚠️ ОБНАРУЖЕНЫ ПРОБЛЕМЫ В 2 КОНТЕЙНЕРАХ
💡 Рекомендации:
   1. Проверьте логи проблемных контейнеров
   2. Перезапустите контейнеры с ошибками
   ...
```

## 🎯 Полная последовательность проверки

```bash
# 1. Убедиться что все сервисы запущены
docker-compose up -d

# 2. Запустить комплексную проверку
./scripts/comprehensive-container-check.sh

# 3. Проверить основные API
curl http://localhost:5678   # N8N
curl http://localhost:11434  # Ollama
curl http://localhost:6333   # Qdrant

# 4. Если нужна диагностика N8N
./scripts/diagnose-n8n-postgres.sh

# 5. Мониторинг в реальном времени
./scripts/monitor-n8n.sh
```

---

**🎯 Цель:** Убедиться что все контейнеры запускаются и работают без ошибок  
**✅ Результат:** Полная уверенность в стабильности всех сервисов
