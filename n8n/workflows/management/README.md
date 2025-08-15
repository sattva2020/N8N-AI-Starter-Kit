# 🔄 N8N Workflow Management Tools

Эта директория содержит инструменты для управления N8N workflows, включая импорт из внешних источников.

## 📁 Содержимое

### 🔧 Основные скрипты

| Файл | Описание |
|------|----------|
| `workflow-import-cli.py` | 🎯 **Главный CLI интерфейс** для интерактивного импорта workflow |
| `import-zie619-workflows.py` | 📥 Импорт workflow из репозитория [Zie619/n8n-workflows](https://github.com/Zie619/n8n-workflows) |
| `import-to-n8n.py` | 🔗 Интеграция и импорт workflow непосредственно в N8N через API |
| `setup-workflow-import.py` | ⚙️ Настройка зависимостей и конфигурации для импорта |

### 📋 Конфигурация

| Файл | Описание |
|------|----------|
| `requirements-workflow-import.txt` | 📦 Python зависимости для работы с workflow |

## 🚀 Быстрый старт

### 1. Установка зависимостей

```bash
# Из корня проекта
cd n8n/workflows/management
pip install -r requirements-workflow-import.txt
```

### 2. Запуск интерактивного импорта

```bash
python workflow-import-cli.py
```

### 3. Прямой импорт из Zie619

```bash
python import-zie619-workflows.py --category ai_ml --limit 50
```

## 🎯 Возможности

### 📊 Категории workflow для импорта

- 🤖 **AI & Machine Learning** - ChatGPT, OpenAI, Anthropic
- 💼 **Business Automation** - Email, messaging, project management  
- ⚙️ **Developer Tools** - Webhooks, APIs, GitHub integrations
- 📊 **Data Processing** - Database operations, analytics
- 🚀 **Starter Pack** - Простые workflow для изучения

### 🔍 Фильтры импорта

- **По категориям** - Фильтрация по типу задач
- **По сложности** - Low/Medium/High complexity
- **По количеству узлов** - Минимум/максимум узлов
- **По ключевым словам** - Поиск по содержимому
- **Лимиты** - Ограничение количества импортируемых workflow

### 🔗 Интеграция с N8N

- **API импорт** - Прямой импорт через N8N API
- **Проверка статуса** - Автоматическая проверка подключения к N8N
- **Batch операции** - Массовый импорт workflow
- **Валидация** - Проверка корректности workflow перед импортом

## 📖 Примеры использования

### Интерактивный режим

```bash
python workflow-import-cli.py
# Следуйте интерактивным инструкциям
```

### Программный импорт

```python
from import_zie619_workflows import Zie619WorkflowImporter

importer = Zie619WorkflowImporter()
result = importer.import_workflows(
    filters={"category": "ai_ml", "min_nodes": 3},
    limit=25
)
```

### Интеграция с N8N

```python
from import_to_n8n import N8NWorkflowManager

manager = N8NWorkflowManager()
if manager.check_n8n_connection():
    manager.batch_import_workflows("./imported/")
```

## 🔧 Конфигурация

### Переменные окружения

```bash
# N8N API настройки
N8N_API_URL=http://localhost:5678
N8N_API_KEY=your-api-key

# Настройки импорта
WORKFLOW_IMPORT_DIR=./imported
MAX_IMPORT_BATCH=50
```

### Структура импортированных workflow

```
n8n/workflows/
├── imported/           # Импортированные workflow
│   ├── ai_ml/         # По категориям
│   ├── business/
│   └── development/
├── production/        # Production workflow
├── testing/          # Тестовые workflow
└── examples/         # Примеры workflow
```

## ⚠️ Важные замечания

1. **Учетные данные** - После импорта workflow настройте credentials для внешних сервисов
2. **Webhook URLs** - Обновите webhook URLs согласно вашему окружению
3. **Тестирование** - Обязательно протестируйте workflow перед активацией
4. **Лицензии** - Проверьте лицензии импортированных workflow

## 🆘 Поддержка

При возникновении проблем:

1. Проверьте подключение к N8N: `python import-to-n8n.py --check`
2. Проверьте зависимости: `pip install -r requirements-workflow-import.txt`
3. Просмотрите логи в `logs/workflow-import.log`
4. Обратитесь к документации в `docs/WORKFLOW_MANAGEMENT.md`

## 🔗 Связанные документы

- [📚 Основная документация](../../../docs/)
- [🔧 Системные скрипты](../../../scripts/)
- [🐳 Docker конфигурация](../../../docker-compose.yml)
