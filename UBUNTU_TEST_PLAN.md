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

## Следующие шаги после успешного теста

1. Запустить Zep/Graphiti сервисы
2. Проверить Supabase
3. Протестировать Traefik
4. Убедиться в доступности всех API и дашбордов
