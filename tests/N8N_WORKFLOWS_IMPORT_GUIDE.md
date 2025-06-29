# N8N WORKFLOWS IMPORT GUIDE

## Импорт workflows в N8N v1.2.0

### Доступные workflows:
1. **Advanced RAG Pipeline Test** - тестирование функциональности RAG Pipeline
2. **Advanced RAG Pipeline Automation v1.2.0** - автоматизация обработки документов

### Шаги для импорта:

#### 1. Откройте N8N веб-интерфейс
```
http://localhost:5678
```

#### 2. Импорт через веб-интерфейс

**Метод 1: Через меню Import**
1. Нажмите на кнопку "Import" в верхнем меню
2. Выберите "From File"
3. Загрузите файл workflow из папки `n8n/workflows/`

**Метод 2: Через Drag & Drop**
1. Откройте файл workflow в текстовом редакторе
2. Скопируйте весь JSON контент
3. В N8N нажмите Ctrl+A, затем Ctrl+V для вставки

#### 3. Настройка credentials (если требуется)

Для работы с API endpoints может потребоваться настройка credentials:
- HTTP Basic Auth для Document Processor
- Webhook настройки для автоматизации

### Файлы workflows:

#### advanced-rag-pipeline-test.json
- **Назначение**: Тестирование полной функциональности
- **Триггер**: Manual (ручной запуск)
- **Функции**:
  - Загрузка тестового документа
  - Обработка и индексация
  - Поиск по документу
  - Валидация результатов

#### advanced-rag-automation-v1.2.0.json  
- **Назначение**: Автоматизация обработки документов
- **Триггер**: Webhook (`/webhook/rag-automation`)
- **Функции**:
  - Автоматическая обработка входящих документов
  - Пакетная индексация
  - Мониторинг статуса
  - Уведомления об ошибках

### Проверка работы workflows:

#### После импорта:
1. Активируйте workflow (переключатель в правом верхнем углу)
2. Для тестового workflow - нажмите "Execute Workflow"
3. Для автоматизации - отправьте POST запрос на webhook URL

#### Тестирование automation workflow:
```bash
curl -X POST http://localhost:5678/webhook/rag-automation \
  -H "Content-Type: application/json" \
  -d '{"action": "process_queue", "priority": "high"}'
```

### Мониторинг выполнения:
- Откройте вкладку "Executions" для просмотра истории
- Проверьте логи в случае ошибок
- Используйте Debug режим для детальной диагностики

### Настройка окружения:
Убедитесь, что все сервисы доступны:
- Document Processor: http://document-processor:8001
- Qdrant: http://qdrant:6333
- PostgreSQL: доступен на порту 5432

---
**Дата создания:** 24 июня 2025  
**Версия:** v1.2.0
