# Памятка по проекту N8N AI Starter Kit для AI-ассистентов (v1.2.0)

## 📋 Общее описание проекта

**N8N AI Starter Kit** — это готовое self-hosted решение для быстрого развертывания локальной среды AI-разработки на базе Docker Compose. Проект позволяет создавать комплексные AI-решения без зависимости от внешних облачных API, с возможностью запуска языковых моделей локально.

**Дата последнего обновления:** 29 декабря 2024 года
**Текущая версия:** 1.2.0 (подготовка к релизу v1.1.4)
**Репозиторий:** [https://github.com/sattva2020/n8n-ai-starter-kit](https://github.com/sattva2020/n8n-ai-starter-kit)

## 🎯 Назначение и преимущества

- **Self-hosted AI**: Запуск языковых моделей и AI-компонентов локально
- **Low-code разработка**: Создание AI-решений без глубоких знаний программирования
- **Контроль данных**: Все данные хранятся локально, без передачи внешним API
- **Масштабируемость**: От легких процессов на CPU до продвинутых решений на GPU
- **Полный стек**: Включает все необходимое от LLM до баз данных

## 🧩 Ключевые компоненты системы (v1.2.0)

| Компонент | Назначение | Взаимодействие | Статус |
|----------|------------|---------------|--------|
| **n8n** | Платформа автоматизации (ядро системы) | Интегрируется со всеми остальными компонентами | ✅ |
| **Ollama** | Локальное выполнение языковых моделей | Используется n8n для генерации текста | ✅ |
| **Qdrant** | Векторная база данных | Хранит эмбеддинги для RAG-приложений | ✅ |
| **Graphiti** | Модернизированная система памяти (замена Zep) | Сохраняет контекст и граф знаний | 🆕 |
| **PostgreSQL** | Реляционная база данных | Хранит настройки n8n и данные приложений | ✅ |
| **Supabase** | Self-hosted Firebase альтернатива | Предоставляет хранилище, аутентификацию, базы данных | ✅ |
| **Traefik** | Обратный прокси и маршрутизатор | Обеспечивает доступ к компонентам через единую точку | ✅ |
| **N8N Workflows Auto-Import** | Автоматический импорт workflows | Импортирует workflows при запуске системы | 🆕 |
| **Document Processor** | Обработка документов | Анализ и извлечение данных из документов | 🆕 |
| **Web Interface** | Веб-интерфейс проекта | Управление и мониторинг системы | 🆕 |

### 🆕 Новые компоненты v1.2.0
- **Graphiti** — замена Zep с улучшенными возможностями работы с графом знаний
- **Auto-Import System** — автоматический импорт N8N workflows при запуске
- **Production Security** — SSL/TLS, доменная конфигурация, security headers
- **Advanced Workflows** — 6 новых production-ready workflows для AI задач
- **Enhanced Monitoring** — улучшенный мониторинг и диагностика

## 🗂️ Структура файлов и директорий (v1.2.0)

### Основные файлы конфигурации
- **`docker-compose.yml`** — Основной файл для оркестрации всех сервисов
- **`compose/*.yml`** — Модульные конфигурации для отдельных компонентов
- **`.env`** — Переменные окружения (создается из `template.env`)
- **`.env.production.template`** — Шаблон для production развертывания
- **`.env.example`** — Пример файла переменных окружения

### Скрипты автоматизации (обновлено v1.2.0)
- **`scripts/setup.sh`** — Начальная настройка и создание .env
- **`scripts/deploy-production.sh/.ps1`** — Развертывание в production
- **`scripts/check-auto-import-status.sh`** — Проверка статуса автоимпорта
- **`scripts/quick-import-test.sh`** — Быстрое тестирование импорта workflows
- **`scripts/analyze-logs.sh`** — Анализ логов системы
- **`scripts/healthcheck.sh`** — Проверка здоровья сервисов
- **`scripts/fix-*.sh/ps1`** — Исправление распространенных проблем
- **`scripts/start*.sh/ps1`** — Запуск системы с разными профилями

### N8N Workflows (новая структура v1.2.0)
- **`n8n/workflows/production/`** — Production-ready workflows с расширенными AI возможностями
  - `document-processing-pipeline-v1.2.0.json` — Обработка документов
  - `rag-query-automation-v1.2.0.json` — RAG запросы
  - `batch-processing-v1.2.0.json` — Пакетная обработка
  - `error-handling-notifications-v1.2.0.json` — Обработка ошибок
  - `system-monitoring-v1.2.0.json` — Мониторинг системы
  - `email-integration-v1.2.0.json` — Интеграция с email
- **`n8n/workflows/testing/`** — Тестовые workflows для валидации
- **`n8n/workflows/examples/`** — Примеры workflows для обучения
- **`n8n/demo-data/workflows/`** — Готовые примеры рабочих процессов
- **`n8n/demo-data/credentials/`** — Предустановленные учетные данные

### Дополнительные сервисы (новое в v1.2.0)
- **`services/n8n-importer/`** — Автоматический импортер workflows
- **`services/document-processor/`** — Сервис обработки документов
- **`services/web-interface/`** — Веб-интерфейс проекта

### Документация и руководства (обновлено)
- **`README.md`** — Основная документация по проекту
- **`docs/ADVANCED_N8N_WORKFLOWS_v1.2.0.md`** — Документация по новым workflows
- **`docs/SSL_PRODUCTION_GUIDE.md`** — Руководство по SSL в production
- **`TROUBLESHOOTING.md`** — Руководство по устранению неполадок
- **`CHANGELOG.md`** — История изменений проекта
- **`ai-instructions/AI_MODERNIZATION_ROADMAP_v1.2.0.md`** — План развития AI

### Тестирование (новое в v1.2.0)
- **`tests/test_workflow_importer.py`** — Тесты автоимпорта workflows
- **`tests/test-*.txt`** — Тестовые документы для проверки

## ⚙️ Профили запуска

Система поддерживает несколько профилей запуска через Docker Compose:

1. **cpu** — Базовый набор для систем без GPU
   ```
   docker compose --profile cpu up -d
   ```

2. **gpu-nvidia** — С поддержкой GPU NVIDIA для ускорения Ollama
   ```
   docker compose --profile gpu-nvidia up -d
   ```

3. **gpu-amd** — С поддержкой GPU AMD (только Linux)
   ```
   docker compose --profile gpu-amd up -d
   ```

4. **developer** — Расширенный набор с инструментами разработки
   ```
   docker compose --profile developer up -d
   ```

5. **minimal** — Минимальный набор компонентов для тестирования
   ```
   docker compose --profile minimal up -d
   ```

## 🔄 Алгоритм работы системы (v1.2.0)

1. **Initialization Phase**: Система запускается с автоматическим импортом workflows
2. **Auto-Import**: N8N-importer сервис автоматически загружает workflows из структурированных папок
3. **Routing**: Traefik маршрутизирует запросы к соответствующим сервисам
4. **Processing**: N8N выполняет автоматизированные рабочие процессы
5. **AI Integration**: Ollama обрабатывает запросы к языковым моделям
6. **Vector Operations**: Qdrant выполняет операции с векторными эмбеддингами для RAG
7. **Memory & Knowledge**: Graphiti сохраняет историю и управляет графом знаний
8. **Data Persistence**: PostgreSQL хранит рабочие процессы n8n и данные приложений
9. **Document Processing**: Document-processor анализирует и извлекает данные из файлов
10. **Monitoring**: System-monitoring workflow отслеживает состояние всех компонентов

## 🛠️ Решение распространенных проблем

### Конфликты сетей Docker
Решается через скрипт:
```powershell
.\scripts\fix-and-start.ps1
```

### Проблемы с переменными окружения
Решается через скрипт:
```powershell
.\scripts\fix-env-vars.ps1
```

### Ошибка "concurrent map writes"
Решается через:
```powershell
$env:COMPOSE_PARALLEL_LIMIT=1; docker compose --profile cpu up -d
```
или
```powershell
.\scripts\start-with-limited-parallelism.ps1
```

### Проблемы с загрузкой моделей Ollama
- Проверить логи: `docker logs n8n-ai-starter-kit-ollama-1`
- Использовать скрипт: `.\scripts\preload-models.sh`

## 📊 Архитектура взаимодействия компонентов

```
                            ┌─────────┐
                  ┌────────►│ Ollama  │◄──────┐
                  │         └─────────┘       │
┌─────────┐       │         ┌─────────┐       │
│ Traefik │◄─────►│─────────► Qdrant  │       │
└─────────┘       │         └─────────┘       │
    ▲             │         ┌─────────┐       │
    │       ┌─────┴────┐    │         │       │
    └───────┤   n8n    ├────►   Zep   │       │
            └─────┬────┘    │         │       │
                  │         └─────────┘       │
                  │         ┌─────────┐       │
                  ├────────►│Postgres │       │
                  │         └─────────┘       │
                  │         ┌──────────┐      │
                  └────────►│ Supabase │      │
                            └──────────┘      │
                            ┌──────────┐      │
                            │Open WebUI├──────┘
                            └──────────┘
```

## 🚀 Типичные сценарии использования (v1.2.0)

### Базовые сценарии
1. **Чат-боты с памятью**: Использование n8n + Ollama + Graphiti
2. **RAG-приложения**: Комбинация n8n + Qdrant + Ollama + Document Processor
3. **Обработка документов**: n8n + Document Processor + Ollama + pgvector
4. **Интеграции с мессенджерами**: n8n + Telegram/Discord/WhatsApp + Email Integration
5. **Генерация контента**: n8n + Ollama + внешние API

### Расширенные сценарии (новые в v1.2.0)
6. **Document Processing Pipeline**: Автоматическая обработка загружаемых документов с извлечением метаданных
7. **RAG Query Automation**: Автоматизированные запросы к базе знаний с контекстным поиском
8. **Batch Processing**: Пакетная обработка больших объемов данных с мониторингом прогресса
9. **Error Handling & Notifications**: Централизованная обработка ошибок с уведомлениями
10. **System Monitoring**: Непрерывный мониторинг состояния всех сервисов системы
11. **Email Integration Workflows**: Автоматизация email-кампаний и обработки входящих писем

## 📝 Важные замечания (v1.2.0)

1. **Версионирование**: Все сервисы используют тег `latest` (с мая 2025)
2. **Порты**: Система использует стандартные порты (80, 443, 5678)
3. **Безопасность**: Реализована production-ready security конфигурация с SSL/TLS
4. **Автоимпорт**: Workflows автоматически импортируются при запуске системы
5. **Структура workflows**: Организованы по папкам production/testing/examples
6. **Резервное копирование**: Реализовано через `scripts/backup.sh`
7. **Production готовность**: Система готова для production развертывания с SSL
8. **Мониторинг**: Встроенные системы мониторинга и health checks
9. **Mac/Apple Silicon**: Предусмотрена специальная конфигурация local-ollama.yml
10. **Документация**: Полная документация по новым workflows в docs/

## 🔍 Советы для работы с проектом (v1.2.0)

1. **Стабильные версии**: Лучше использовать стабильные тегированные версии: `git checkout v1.1.3`
2. **Первый запуск**: При первом запуске система загружает языковые модели и импортирует workflows
3. **Доступ к инструментам**: 
   - N8N: http://localhost:5678
   - Web Interface: http://localhost (при включении)
   - Ollama API: http://localhost:11434
4. **GPU поддержка**: При работе с GPU убедитесь, что установлены правильные драйверы
5. **Требования**: Docker и Docker Compose обязательны
6. **Автоимпорт**: Workflows автоматически импортируются из структурированных папок
7. **Production**: Используйте скрипты deploy-production.* для production развертывания
8. **Мониторинг**: Регулярно проверяйте статус с помощью check-auto-import-status.sh
9. **Тестирование**: Используйте quick-import-test.sh для быстрой проверки
10. **SSL**: Для production обязательно настройте SSL согласно docs/SSL_PRODUCTION_GUIDE.md

## 📑 Ссылки на документацию (v1.2.0)

### Основная документация
1. [`README.md`](../README.md) — Основная документация проекта
2. [`TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) — Устранение неполадок
3. [`CHANGELOG.md`](../CHANGELOG.md) — История изменений

### Документация по AI и workflows
4. [`docs/ADVANCED_N8N_WORKFLOWS_v1.2.0.md`](../docs/ADVANCED_N8N_WORKFLOWS_v1.2.0.md) — Документация по новым workflows
5. [`docs/SSL_PRODUCTION_GUIDE.md`](../docs/SSL_PRODUCTION_GUIDE.md) — SSL в production
6. [`ai-instructions/AI_MODERNIZATION_ROADMAP_v1.2.0.md`](./AI_MODERNIZATION_ROADMAP_v1.2.0.md) — План развития AI

### Техническая документация
7. [`docs/COMMON_ISSUES.md`](../docs/COMMON_ISSUES.md) — Распространенные проблемы
8. [`docs/SETUP_SCRIPT.md`](../docs/SETUP_SCRIPT.md) — Подробное руководство по установке
9. [`n8n/workflows/README.md`](../n8n/workflows/README.md) — Структура workflows

### Отчёты и планы
10. [`ADVANCED_WORKFLOWS_COMPLETION_REPORT_v1.2.0.md`](../ADVANCED_WORKFLOWS_COMPLETION_REPORT_v1.2.0.md) — Отчёт о завершении этапа
11. [`NEXT_IMPROVEMENTS_PLAN_v1.2.0.md`](../NEXT_IMPROVEMENTS_PLAN_v1.2.0.md) — План дальнейших улучшений
12. [`ai-instructions/PRE_PUBLISH_CLEANUP_GUIDE.md`](./PRE_PUBLISH_CLEANUP_GUIDE.md) — Руководство по очистке перед публикацией

## 🔄 Последние обновления (v1.2.0)

### Новые возможности
- **🔄 Автоматический импорт workflows**: Система автоматически импортирует N8N workflows при запуске
- **🧠 Миграция на Graphiti**: Замена Zep на более современную систему памяти и графа знаний
- **🔒 Production Security**: SSL/TLS, доменная конфигурация, security headers для production
- **🌊 Advanced N8N Workflows**: 6 новых production-ready workflows для AI задач
- **🛠️ Дополнительные сервисы**: Document processor, web interface, n8n-importer
- **📊 Enhanced Monitoring**: Улучшенный мониторинг и диагностика системы
- **🏗️ Структурированные workflows**: Организация по папкам production/testing/examples

### Улучшения инфраструктуры
- **🚀 Production deployment**: Автоматизированные скрипты развертывания в production
- **✅ Health checks**: Расширенные проверки состояния сервисов
- **📋 Automated testing**: Тесты для валидации автоимпорта workflows
- **📚 Документация**: Полная документация по новым возможностям
- **🧹 Cleanup automation**: Автоматизированная очистка проекта

### Исправления и оптимизации
- **🔧 Import system**: Исправлены проблемы с синтаксисом в import-workflows.py
- **📁 Folder structure**: Упорядочена структура папок workflows
- **🔍 Error handling**: Улучшенная обработка ошибок в автоимпорте
- **⚡ Performance**: Оптимизация производительности импорта
- **📖 Documentation**: Обновлена документация по структуре проекта

## 📦 Структура репозитория (v1.2.0)

```
n8n-ai-starter-kit/
├── docker-compose.yml           # Основной файл конфигурации
├── .env.production.template     # Шаблон для production развертывания
├── compose/                     # Модульные compose-файлы
│   ├── local-ollama.yml         # Конфигурация для Mac/Apple Silicon
│   ├── networks.yml             # Определение Docker-сетей
│   ├── graphiti-compose.yaml    # Конфигурация Graphiti (новое)
│   ├── ollama-compose.yml       # Конфигурация Ollama
│   ├── optional-services.yml    # Дополнительные сервисы
│   └── supabase-compose.yml     # Конфигурация Supabase
├── config/                      # Файлы конфигурации
│   ├── middlewares.yml          # Настройки Traefik
│   ├── ollama-models.txt        # Список моделей для загрузки
│   └── traefik/                 # SSL и security конфигурации
├── scripts/                     # Скрипты автоматизации (расширено)
│   ├── deploy-production.sh/.ps1 # Скрипты production развертывания
│   ├── check-auto-import-status.sh # Проверка автоимпорта
│   ├── quick-import-test.sh     # Быстрое тестирование
│   ├── analyze-logs.sh          # Анализ логов
│   ├── healthcheck.sh           # Health checks
│   └── setup.sh                 # Основной скрипт установки
├── services/                    # Новые микросервисы
│   ├── n8n-importer/            # Автоимпорт workflows
│   ├── document-processor/      # Обработка документов
│   └── web-interface/           # Веб-интерфейс
├── docs/                        # Документация (расширена)
│   ├── ADVANCED_N8N_WORKFLOWS_v1.2.0.md # Документация workflows
│   ├── SSL_PRODUCTION_GUIDE.md  # SSL руководство
│   └── ENHANCED_FEATURES.md     # Описание возможностей
├── n8n/                         # Данные N8N (реструктурировано)
│   ├── workflows/               # Структурированные workflows
│   │   ├── production/          # Production workflows
│   │   ├── testing/             # Тестовые workflows
│   │   └── examples/            # Примеры workflows
│   └── demo-data/               # Демо-данные
├── tests/                       # Тестирование (новое)
│   ├── test_workflow_importer.py # Тесты автоимпорта
│   └── test-*.txt               # Тестовые документы
└── ai-instructions/             # AI инструкции (обновлено)
    ├── AI_MODERNIZATION_ROADMAP_v1.2.0.md # План развития
    ├── AI_AGENT_GUIDE.md        # Памятка для AI-агентов
    └── PRE_PUBLISH_CLEANUP_GUIDE.md # Руководство по очистке
```

---

*Эта памятка обновлена для версии v1.2.0 (29 декабря 2024) и предназначена для использования AI-агентами, работающими с проектом N8N AI Starter Kit.*
*Последнее обновление: 29 декабря 2024*
