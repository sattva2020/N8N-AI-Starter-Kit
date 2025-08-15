# Инструкции по работе с компонентами v1.2.0

## 📋 Обзор новых компонентов

Данный документ содержит специфические инструкции для AI-агентов по работе с новыми компонентами, введенными в версии 1.2.0 проекта N8N AI Starter Kit.

## 🔄 Автоматический импорт N8N Workflows

### Структура файлов
```
services/n8n-importer/
├── import-workflows.py      # Основной скрипт импорта
├── requirements.txt         # Зависимости Python
└── README.md               # Документация сервиса

n8n/workflows/
├── production/             # Production-ready workflows
├── testing/               # Тестовые workflows
├── examples/              # Примеры workflows
└── README.md              # Описание структуры
```

### Принципы работы
1. **Приоритетность**: production > testing > examples
2. **Рекурсивный импорт**: Сканирование всех подпапок
3. **Валидация JSON**: Проверка синтаксиса перед импортом
4. **Логирование**: Подробные логи процесса импорта
5. **Error handling**: Обработка ошибок с продолжением работы

### Ключевые скрипты для диагностики
- `scripts/check-auto-import-status.sh` — проверка статуса импорта
- `scripts/quick-import-test.sh` — быстрое тестирование
- `tests/test_workflow_importer.py` — автоматизированные тесты

## 🧠 Система памяти Graphiti

### Миграция с Zep
- **Статус**: Полная замена Zep на Graphiti
- **Конфигурация**: `compose/graphiti-compose.yaml`
- **Преимущества**: Граф знаний, улучшенная память, современная архитектура

### Интеграция с N8N
- Использование в production workflows
- Сохранение контекста разговоров
- Управление графом знаний
- API-интеграция через HTTP-запросы

## 🌊 Advanced N8N Workflows

### Production Workflows (6 компонентов)

#### 1. Document Processing Pipeline
- **Файл**: `document-processing-pipeline-v1.2.0.json`
- **Назначение**: Автоматическая обработка загружаемых документов
- **Компоненты**: File trigger, PDF processor, metadata extraction, vectorization

#### 2. RAG Query Automation
- **Файл**: `rag-query-automation-v1.2.0.json`
- **Назначение**: Автоматизированные запросы к базе знаний
- **Компоненты**: Query handler, vector search, LLM integration, response formatting

#### 3. Batch Processing
- **Файл**: `batch-processing-v1.2.0.json`
- **Назначение**: Пакетная обработка больших объемов данных
- **Компоненты**: Queue manager, parallel processing, progress tracking, result aggregation

#### 4. Error Handling & Notifications
- **Файл**: `error-handling-notifications-v1.2.0.json`
- **Назначение**: Централизованная обработка ошибок
- **Компоненты**: Error catching, logging, notification dispatch, escalation

#### 5. System Monitoring
- **Файл**: `system-monitoring-v1.2.0.json`
- **Назначение**: Мониторинг состояния всех сервисов
- **Компоненты**: Health checks, performance metrics, alerting, dashboards

#### 6. Email Integration
- **Файл**: `email-integration-v1.2.0.json`
- **Назначение**: Автоматизация email-процессов
- **Компоненты**: Email parser, template engine, campaign automation, analytics

## 🛠️ Дополнительные сервисы

### Document Processor
- **Путь**: `services/document-processor/`
- **Назначение**: Обработка и анализ документов
- **Возможности**: PDF parsing, text extraction, metadata analysis
- **Интеграция**: API endpoints для N8N workflows

### Web Interface
- **Путь**: `services/web-interface/`
- **Назначение**: Веб-интерфейс управления проектом
- **Возможности**: Monitoring dashboard, configuration management
- **Доступ**: http://localhost (при включении сервиса)

## 🔒 Production Security

### SSL/TLS конфигурация
- **Документация**: `docs/SSL_PRODUCTION_GUIDE.md`
- **Скрипты**: `scripts/deploy-production.sh/.ps1`
- **Компоненты**: Traefik SSL, Let's Encrypt, security headers

### Переменные окружения
- **Production template**: `.env.production.template`
- **Безопасность**: Secure defaults, encryption settings
- **Домены**: Multi-domain configuration support

## 🧪 Тестирование и валидация

### Автоматизированные тесты
```bash
# Запуск тестов импорта workflows
python tests/test_workflow_importer.py

# Быстрое тестирование
./scripts/quick-import-test.sh

# Проверка статуса
./scripts/check-auto-import-status.sh
```

### Тестовые данные
- `tests/test-*.txt` — различные типы документов для тестирования
- `n8n/workflows/testing/` — тестовые workflows
- Automated validation в CI/CD

## 📊 Мониторинг и диагностика

### Скрипты мониторинга
- `scripts/analyze-logs.sh` — анализ логов системы
- `scripts/healthcheck.sh` — проверка здоровья сервисов
- `scripts/monitor.sh` — continuous monitoring

### Метрики для отслеживания
1. **Import success rate**: Процент успешных импортов workflows
2. **Service health**: Состояние всех сервисов Docker
3. **Response times**: Время ответа API endpoints
4. **Error rates**: Частота ошибок по компонентам
5. **Resource usage**: Использование CPU/RAM/Disk

## 🔧 Troubleshooting Guide

### Частые проблемы и решения

#### 1. Проблемы с автоимпортом
```bash
# Проверка логов
docker logs n8n-ai-starter-kit-n8n-importer-1

# Ручной запуск импорта
./scripts/quick-import-test.sh

# Проверка структуры workflows
python tests/test_workflow_importer.py
```

#### 2. Ошибки Graphiti
```bash
# Проверка состояния Graphiti
docker logs n8n-ai-starter-kit-graphiti-1

# Рестарт сервиса
docker compose restart graphiti
```

#### 3. SSL/Production issues
```bash
# Проверка SSL конфигурации
./scripts/analyze-logs.sh

# Валидация production setup
./scripts/deploy-production.sh --check
```

## 📚 Документация

### Обязательные документы для изучения
1. `docs/ADVANCED_N8N_WORKFLOWS_v1.2.0.md` — детальная документация workflows
2. `docs/SSL_PRODUCTION_GUIDE.md` — настройка SSL в production
3. `n8n/workflows/README.md` — структура и организация workflows
4. `services/n8n-importer/README.md` — техническая документация импорта

### Отчеты и планы
- `ADVANCED_WORKFLOWS_COMPLETION_REPORT_v1.2.0.md` — отчет о завершении этапа
- `NEXT_IMPROVEMENTS_PLAN_v1.2.0.md` — план дальнейшего развития
- `ai-instructions/AI_MODERNIZATION_ROADMAP_v1.2.0.md` — roadmap AI развития

## ⚠️ Важные замечания

1. **Backwards compatibility**: Новые компоненты совместимы с предыдущими версиями
2. **Migration path**: Четкий путь миграции с Zep на Graphiti
3. **Production readiness**: Все компоненты протестированы для production
4. **Auto-recovery**: Встроенные механизмы восстановления после ошибок
5. **Monitoring**: Comprehensive monitoring и alerting system

## 🚀 Следующие шаги развития

### Планируемые улучшения (v1.3.0+)
1. **Enhanced Monitoring & Analytics** — расширенная аналитика
2. **CI/CD Integration** — полная автоматизация развертывания
3. **Multi-tenant Support** — поддержка множественных пользователей
4. **Advanced Security** — дополнительные меры безопасности
5. **Performance Optimization** — оптимизация производительности

---

*Инструкции обновлены для v1.2.0 (29 декабря 2024)*
*Для получения актуальной информации см. основную документацию проекта*
