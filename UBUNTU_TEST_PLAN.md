# Исправления для тестирования на Ubuntu 24

## Выполненные изменения

### 1. Исправлен ключ шифрования N8N
- **Проблема**: Ошибка "Mismatching encryption keys" - ключ в .env не совпадал с ключом в контейнере
- **Решение**: 
  - Сгенерирован новый безопасный ключ: `thCylTG+CZZ+49tGDS2FmOpca1Cc2oc1N2Mb+C4jeXY=`
  - Обновлен `N8N_ENCRYPTION_KEY` в .env файле
  - Удален volume `n8n-ai-starter-kit_n8n_storage` для сброса старого ключа

### 2. Добавлен проброс портов для N8N
- **Проблема**: N8N не был доступен с хоста
- **Решение**: Добавлен `ports: - "5678:5678"` в docker-compose.yml

### 3. Исправлен конфликт портов Zep/Graphiti
- **Проблема**: И Zep, и Graphiti использовали порт 8000
- **Решение**: Изменен порт Graphiti на 8001 (`"8001:8000"`)

### 4. Исправлен YAML синтаксис
- **Проблема**: Поврежденный YAML в zep-compose.yaml
- **Решение**: Исправлены отступы и структура файла

### 5. Исправлена сеть PostgreSQL 
- **Проблема**: N8N и PostgreSQL в разных сетях - `getaddrinfo ENOTFOUND postgres`
- **Решение**: Добавлен PostgreSQL в сеть `backend` для связи с N8N

## Команды для тестирования на Ubuntu 24

```bash
# 1. Обновить код
cd ~/N8N-AI-Starter-Kit
git pull

# 2. Остановить все контейнеры
docker compose -f docker-compose.yml -f compose/ollama-compose.yml -f compose/zep-compose.yaml -f compose/supabase-compose.yml down

# 3. Удалить volume N8N (если еще не удален)
docker volume rm n8n-ai-starter-kit_n8n_storage

# 4. Запустить основные сервисы
docker compose -f docker-compose.yml -f compose/ollama-compose.yml up -d

# 5. Проверить статус
docker ps

# 6. Проверить логи N8N
docker compose logs n8n --tail=20

# 7. Проверить доступность
curl http://localhost:5678/healthz
curl http://localhost:11434/api/version
curl http://localhost:6333/
```

## Ожидаемые результаты

1. **N8N** - должен запуститься без ошибок ключа шифрования
2. **Ollama** - должен работать на порту 11434
3. **Qdrant** - должен работать на порту 6333
4. **Порты доступны**: 5678 (N8N), 11434 (Ollama), 6333 (Qdrant)

## Результаты тестирования

### ✅ Успешно протестированы:
1. **N8N**: `curl http://localhost:5678/healthz` → `{"status":"ok"}`
2. **Ollama**: `curl http://localhost:11434/api/version` → `{"version":"0.9.2"}`
3. **Qdrant**: `curl http://localhost:6333/` → `{"title":"qdrant - vector search engine","version":"1.14.1"}`
4. **PostgreSQL**: Подключение N8N к базе данных работает

### 🔄 Следующие шаги - тестирование Zep/Graphiti

```bash
# 1. Запустить Zep и Graphiti сервисы
docker compose -f compose/zep-compose.yaml up -d

# 2. Проверить статус контейнеров
docker ps | grep -E "(zep|graphiti)"

# 3. Проверить логи
docker compose -f compose/zep-compose.yaml logs graphiti --tail=20
docker compose -f compose/zep-compose.yaml logs zep --tail=20

# 4. Проверить доступность API
curl -s http://localhost:8001/health && echo " - Graphiti OK" || echo " - Graphiti FAIL"
curl -s http://localhost:8000/healthz && echo " - Zep OK" || echo " - Zep FAIL"

# 5. Если есть проблемы, проверить детальные логи
docker logs $(docker ps -q --filter "name=graphiti") --tail=50
docker logs $(docker ps -q --filter "name=zep") --tail=50
```

### 🔄 После Zep/Graphiti - тестирование Supabase

```bash
# 1. Запустить Supabase
docker compose -f compose/supabase-compose.yml up -d

# 2. Проверить статус
docker ps | grep supabase

# 3. Проверить API Supabase
curl -s http://localhost:8000/rest/v1/ && echo " - Supabase REST OK" || echo " - Supabase REST FAIL"
curl -s http://localhost:3000/ && echo " - Supabase Studio OK" || echo " - Supabase Studio FAIL"
```

### 🔄 Финальное тестирование - все сервисы

```bash
# Запустить все сервисы одновременно
docker compose -f docker-compose.yml -f compose/ollama-compose.yml -f compose/zep-compose.yaml -f compose/supabase-compose.yml up -d

# Проверить все API endpoints
echo "=== Проверка всех сервисов ==="
curl -s http://localhost:5678/healthz && echo " - N8N OK" || echo " - N8N FAIL"
curl -s http://localhost:11434/api/version && echo " - Ollama OK" || echo " - Ollama FAIL"
curl -s http://localhost:6333/ && echo " - Qdrant OK" || echo " - Qdrant FAIL"
curl -s http://localhost:8001/health && echo " - Graphiti OK" || echo " - Graphiti FAIL"
curl -s http://localhost:8000/healthz && echo " - Zep OK" || echo " - Zep FAIL"
curl -s http://localhost:3000/ && echo " - Supabase Studio OK" || echo " - Supabase Studio FAIL"

# Проверить использование ресурсов
docker stats --no-stream
```
