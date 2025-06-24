# ADVANCED N8N WORKFLOWS v1.2.0 - ДОКУМЕНТАЦИЯ

## 🎯 ОБЗОР РЕАЛИЗОВАННЫХ WORKFLOWS

В рамках **Этапа 2: Advanced N8N Workflows** было создано **6 продвинутых production workflows**, обеспечивающих полную автоматизацию AI-системы.

---

## 📋 СПИСОК PRODUCTION WORKFLOWS

### 1. **Document Processing Pipeline v1.2.0**
**Файл:** `document-processing-pipeline-v1.2.0.json`

**Назначение:** Автоматизированная обработка документов через webhook API

**Основные функции:**
- ✅ Прием документов через webhook `/document-upload`
- ✅ Валидация входных данных
- ✅ Автоматическая обработка через Document Processor
- ✅ Извлечение метаданных (страницы, слова, чанки)
- ✅ Сохранение в Qdrant Vector DB
- ✅ Отправка уведомлений
- ✅ Обработка ошибок с автоответом

**Endpoints:**
- `POST /webhook/document-upload` - загрузка документа

**Пример запроса:**
```json
{
  "file_path": "/path/to/document.pdf",
  "document_type": "auto",
  "user_id": "user123"
}
```

---

### 2. **RAG Query Automation v1.2.0**
**Файл:** `rag-query-automation-v1.2.0.json`

**Назначение:** Автоматизированная обработка поисковых запросов

**Основные функции:**
- ✅ Прием запросов через webhook `/rag-query`
- ✅ Валидация и предобработка запросов
- ✅ Классификация типа запроса (question/search/general)
- ✅ Поиск по векторной базе
- ✅ Обработка результатов с оценкой релевантности
- ✅ Генерация ответов с контекстом
- ✅ Логирование запросов
- ✅ Периодические health checks (каждую минуту)

**Endpoints:**
- `POST /webhook/rag-query` - поиск по документам

**Пример запроса:**
```json
{
  "query": "Как настроить SSL сертификаты?",
  "max_results": 5,
  "include_metadata": true,
  "user_id": "user123"
}
```

---

### 3. **Batch Document Processing v1.2.0**
**Файл:** `batch-processing-v1.2.0.json`

**Назначение:** Массовая обработка документов

**Основные функции:**
- ✅ Прием массива файлов через webhook `/batch-process`
- ✅ Валидация батча (макс. 50 файлов)
- ✅ Последовательная обработка файлов
- ✅ Отслеживание прогресса (успешные/неудачные)
- ✅ Уведомление о завершении
- ✅ Автоочистка старых батчей (каждый час)

**Endpoints:**
- `POST /webhook/batch-process` - массовая обработка

**Пример запроса:**
```json
{
  "files": [
    "/path/to/doc1.pdf",
    "/path/to/doc2.docx",
    "/path/to/doc3.txt"
  ],
  "user_id": "user123",
  "priority": "normal",
  "notify_on_complete": true
}
```

---

### 4. **Error Handling & Notifications v1.2.0**
**Файл:** `error-handling-notifications-v1.2.0.json`

**Назначение:** Централизованная обработка ошибок и уведомлений

**Основные функции:**
- ✅ Прием ошибок через webhook `/error-handler`
- ✅ Классификация ошибок (network/auth/resource/validation/data)
- ✅ Приоритизация по критичности (critical/high/medium)
- ✅ Автоматические уведомления:
  - 🚨 Critical → Email + Slack + Webhook
  - ⚠️ High → Email + Slack
  - 📝 Medium → Логирование
- ✅ Автовосстановление для простых ошибок
- ✅ Ежедневная сводка ошибок (09:00)

**Endpoints:**
- `POST /webhook/error-handler` - отправка ошибки

**Пример запроса:**
```json
{
  "error": "Connection timeout to Qdrant service",
  "source": "document-processor",
  "severity": "high",
  "user_id": "user123",
  "context": {"timeout": 30, "retry_count": 3}
}
```

---

### 5. **System Monitoring & Health Check v1.2.0**
**Файл:** `system-monitoring-v1.2.0.json`

**Назначение:** Мониторинг состояния всех сервисов системы

**Основные функции:**
- ✅ Автоматические health checks (каждые 5 минут):
  - 🌐 Web Interface (port 8001)
  - 📄 Document Processor (port 8000)  
  - 🗄️ Qdrant Vector DB (port 6333)
  - 🔄 N8N API (port 5678)
- ✅ Агрегация статуса системы
- ✅ Автоматические алерты при проблемах
- ✅ Детальный мониторинг (каждые 15 минут):
  - 💾 Дисковое пространство
  - 🧠 Использование памяти
  - ⚡ CPU нагрузка
- ✅ Метрики производительности

**Статусы системы:**
- 🟢 `healthy` - все сервисы работают
- 🟡 `degraded` - часть сервисов недоступна
- 🔴 `critical` - все сервисы недоступны

---

### 6. **Email Integration & Notifications v1.2.0**
**Файл:** `email-integration-v1.2.0.json`

**Назначение:** Система email уведомлений с шаблонами

**Основные функции:**
- ✅ Прием запросов на отправку через webhook `/send-email`
- ✅ Валидация email адресов
- ✅ 4 готовых шаблона:
  - 📄 `document_processed` - документ обработан
  - 📦 `batch_complete` - батч завершен
  - 🚨 `system_alert` - системные алерты
  - ❌ `error_report` - отчеты об ошибках
- ✅ HTML и текстовые версии писем
- ✅ Логирование отправленных писем
- ✅ Ежедневная статистика (18:00)

**Endpoints:**
- `POST /webhook/send-email` - отправка email

**Пример запроса:**
```json
{
  "to": "user@example.com",
  "template": "document_processed",
  "template_data": {
    "document_name": "report.pdf",
    "pages": 15,
    "word_count": 3500,
    "chunks_created": 12,
    "processing_time": 45
  },
  "user_id": "user123"
}
```

---

## 🔗 ИНТЕГРАЦИЯ WORKFLOWS

### Workflow Communication Chain:
```
Document Upload → Processing Pipeline → Email Notification
                ↓
Error Occurs → Error Handler → Email Alert → System Monitor
                ↓
Batch Processing → Progress Tracking → Completion Email
                ↓
RAG Query → Search Results → Usage Logging
```

### Webhook Endpoints Summary:
- `/webhook/document-upload` - загрузка документа
- `/webhook/rag-query` - поиск по документам  
- `/webhook/batch-process` - массовая обработка
- `/webhook/error-handler` - обработка ошибок
- `/webhook/send-email` - отправка email

---

## 📊 МОНИТОРИНГ И МЕТРИКИ

### Автоматические расписания:
- ⏰ **Health Checks** - каждые 5 минут
- ⏰ **Deep Monitoring** - каждые 15 минут  
- ⏰ **Batch Cleanup** - каждый час
- ⏰ **Error Summary** - ежедневно в 09:00
- ⏰ **Email Report** - ежедневно в 18:00

### Collected Metrics:
- 📈 System health percentage
- 📈 Service response times
- 📈 Document processing statistics
- 📈 Error rates by type and severity
- 📈 Email delivery statistics
- 📈 RAG query performance

---

## 🚀 DEPLOYMENT ИНСТРУКЦИИ

### 1. Автоматический импорт:
```bash
# Workflows будут автоматически импортированы при запуске
docker-compose up -d
```

### 2. Ручной импорт:
```bash
# Запуск импорта вручную
docker-compose exec n8n-importer python /app/import-workflows.py
```

### 3. Проверка workflows:
```bash
# Проверка статуса workflows в N8N
curl http://localhost:5678/api/v1/workflows
```

---

## 🔧 КОНФИГУРАЦИЯ

### Environment Variables:
```env
# Email Configuration (в .env файле)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Notification Settings
ALERT_EMAIL=admin@example.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/...

# Monitoring Settings
HEALTH_CHECK_INTERVAL=300  # 5 minutes
DEEP_MONITORING_INTERVAL=900  # 15 minutes
```

---

## 🎯 СЛЕДУЮЩИЕ ШАГИ

После успешного внедрения Advanced N8N Workflows, следующие этапы согласно плану:

### 📊 **Этап 3: Enhanced Monitoring & Analytics**
- Prometheus integration
- Grafana dashboards  
- Centralized logging
- Analytics dashboard

### 🔧 **Этап 4: DevOps & CI/CD**
- GitHub Actions
- Automated testing
- Deploy automation
- Version management

---

## ✅ СТАТУС ЗАВЕРШЕНИЯ

**🎉 ЭТАП 2 ПОЛНОСТЬЮ ЗАВЕРШЕН!**

- ✅ 6 Advanced Production Workflows созданы
- ✅ Все workflows протестированы и валидны
- ✅ Автоимпорт настроен и работает
- ✅ Полная документация подготовлена
- ✅ Интеграция между workflows реализована

**Проект готов к следующему этапу развития!** 🚀
