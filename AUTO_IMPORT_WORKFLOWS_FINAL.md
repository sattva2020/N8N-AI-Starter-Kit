# АВТОМАТИЧЕСКИЙ ИМПОРТ N8N WORKFLOWS - ФИНАЛЬНАЯ ВЕРСИЯ

## 🚀 Автоматический импорт при развертывании

При развертывании проекта с помощью `docker-compose up` все workflows автоматически импортируются в N8N без вашего участия.

### Как это работает:

1. **Автозапуск:** При старте `docker-compose` автоматически запускается сервис `n8n-workflows-importer`
2. **Ожидание готовности:** Импортер ждет полной готовности N8N (до 5 минут)
3. **Автоматический импорт:** Все файлы `*.json` из папки `n8n/workflows/` импортируются автоматически
4. **Активация:** Workflows автоматически активируются после импорта
5. **Обновление:** Если workflow уже существует - он обновляется новой версией

---

## 📁 Структура workflows

```
n8n/workflows/
├── quick-rag-test.json                 # Быстрая проверка системы
├── advanced-rag-pipeline-test.json     # Полное тестирование RAG
└── advanced-rag-automation-v1.2.0.json # Production автоматизация
```

---

## 🔧 Использование

### Стандартный запуск (с автоимпортом):
```bash
docker-compose up -d
```

### Проверка статуса импорта:
```bash
# Проверка логов импорта
docker-compose logs n8n-workflows-importer

# Автоматическая проверка статуса
bash scripts/check-auto-import-status.sh
```

### Принудительный переимпорт:
```bash
# Перезапуск только импортера
docker-compose up n8n-workflows-importer --force-recreate

# Полный перезапуск
docker-compose down
docker-compose up -d
```

---

## 📊 Что происходит при импорте

### 1. Ожидание готовности N8N
- Импортер ждет отклика от `http://n8n:5678/healthz`
- Максимальное время ожидания: 5 минут
- Интервал проверки: 5 секунд

### 2. Импорт workflows
- Сканирование папки `/workflows` в контейнере
- Загрузка и валидация JSON файлов
- Проверка существующих workflows
- Импорт новых или обновление существующих

### 3. Активация workflows
- Автоматическая активация после импорта
- Логирование результатов

---

## 🔍 Мониторинг и диагностика

### Логи импорта:
```bash
# Последние логи
docker-compose logs n8n-workflows-importer

# Следить за логами в реальном времени
docker-compose logs -f n8n-workflows-importer
```

### Проверка результата:
```bash
# Автоматическая проверка
bash scripts/check-auto-import-status.sh

# Ручная проверка через API
curl -s "http://localhost:5678/rest/workflows" | jq '.data[] | {name, id, active}'
```

### Типичные сообщения в логах:

✅ **Успешный импорт:**
```
✅ quick-rag-test успешно импортирован
🟢 Workflow 'quick-rag-test' активирован
📥 Новых импортировано: 3
🎉 Автоматический импорт завершен успешно!
```

⚠️ **Обновление существующих:**
```
📋 Workflow 'quick-rag-test' уже существует, обновляем...
✅ quick-rag-test успешно импортирован/обновлен
🔄 Обновлено: 3
```

❌ **Ошибки:**
```
❌ Ошибка импорта quick-rag-test: 400 - Invalid workflow data
❌ Ошибок: 1
⚠️ Импорт завершен с частичными ошибками
```

---

## ⚙️ Настройки

### Переменные окружения:
- `N8N_URL`: URL N8N сервиса (по умолчанию: `http://n8n:5678`)
- `PYTHONUNBUFFERED`: Логирование в реальном времени

### Ресурсы контейнера:
- **Память:** 256MB
- **CPU:** 0.5 cores
- **Restart policy:** no (запускается один раз)

---

## 🛠️ Добавление новых workflows

### 1. Добавить файл workflow:
```bash
# Сохранить новый workflow в папку
cp my-new-workflow.json n8n/workflows/
```

### 2. Перезапустить импорт:
```bash
docker-compose up n8n-workflows-importer --force-recreate
```

### 3. Проверить результат:
```bash
bash scripts/check-auto-import-status.sh
```

---

## 🔧 Технические детали

### Dockerfile импортера:
```dockerfile
FROM python:3.11-alpine
RUN apk add --no-cache curl jq bash
RUN pip install --no-cache-dir requests
COPY services/n8n-importer/import-workflows.py /app/
ENTRYPOINT ["python3", "/app/import-workflows.py"]
```

### Docker-compose конфигурация:
```yaml
n8n-workflows-importer:
  build:
    context: .
    dockerfile: services/n8n-importer/Dockerfile
  depends_on:
    n8n:
      condition: service_healthy
  volumes:
    - ./n8n/workflows:/workflows:ro
    - n8n_import_logs:/app/logs
  restart: "no"
```

---

## 🐛 Устранение проблем

### Проблема: Импорт не запускается
```bash
# Проверить состояние контейнеров
docker-compose ps

# Проверить зависимости
docker-compose logs n8n
```

### Проблема: N8N недоступен
```bash
# Проверить здоровье N8N
curl http://localhost:5678/healthz

# Увеличить время ожидания
# (изменить max_wait в import-workflows.py)
```

### Проблема: Workflows не импортируются
```bash
# Проверить права доступа к файлам
ls -la n8n/workflows/

# Проверить валидность JSON
jq . n8n/workflows/quick-rag-test.json
```

---

## 📋 Чеклист готовности

- [x] N8N запущен и доступен
- [x] Папка `n8n/workflows/` содержит JSON файлы
- [x] Docker-compose включает сервис `n8n-workflows-importer`
- [x] Контейнер импорта запускается после готовности N8N
- [x] Python скрипт импорта создан и протестирован
- [x] Логирование настроено
- [x] Скрипт проверки статуса создан

---

## 🎯 Преимущества автоимпорта

✅ **Удобство:** Нет необходимости в ручном импорте  
✅ **Надежность:** Автоматическая проверка и валидация  
✅ **Воспроизводимость:** Одинаковый результат на всех окружениях  
✅ **Масштабируемость:** Легко добавлять новые workflows  
✅ **DevOps-ready:** Интеграция с CI/CD пайплайнами  

---

**Автоматический импорт N8N Workflows v1.2.0**  
**Статус:** Production Ready  
**Дата:** 24 июня 2025
