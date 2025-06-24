# N8N WORKFLOWS АКТИВАЦИЯ - ПОШАГОВАЯ ИНСТРУКЦИЯ

## Статус: ✅ Готово к импорту

### Предварительная проверка завершена:
- ✅ N8N доступен на http://localhost:5678
- ✅ Document Processor работает (http://localhost:8001)
- ✅ Web Interface активен (http://localhost:8002)  
- ✅ Qdrant Vector DB готов (http://localhost:6333)
- ✅ PostgreSQL подключен
- ✅ Workflows подготовлены (3 файла)

---

## ШАГИ ДЛЯ ИМПОРТА WORKFLOWS

### 1. Откройте N8N веб-интерфейс
```
http://localhost:5678
```

### 2. Импорт Quick Test Workflow (рекомендуется начать с этого)

**Файл:** `n8n/workflows/quick-rag-test.json`

**Действия:**
1. В N8N нажмите кнопку **"Import"** (или "+")
2. Выберите **"From File"** 
3. Загрузите файл `quick-rag-test.json`
4. Нажмите **"Import"**
5. **Активируйте workflow** (переключатель в верхнем правом углу)
6. Нажмите **"Execute Workflow"** для тестирования

**Ожидаемый результат:**
- Проверка health всех сервисов
- Получение статуса Document Processor, Web Interface, Qdrant
- Зеленые индикаторы выполнения

### 3. Импорт Test Pipeline Workflow

**Файл:** `n8n/workflows/advanced-rag-pipeline-test.json`

**Функциональность:**
- Загрузка тестового документа
- Обработка и создание эмбеддингов
- Поиск по документу
- Валидация результатов

**Действия:**
1. Повторите шаги импорта для файла `advanced-rag-pipeline-test.json`
2. Активируйте workflow
3. Выполните тестирование

### 4. Импорт Automation Workflow

**Файл:** `n8n/workflows/advanced-rag-automation-v1.2.0.json`

**Функциональность:**
- Webhook для автоматической обработки
- Пакетная индексация документов
- Мониторинг и уведомления

**Действия:**
1. Импортируйте файл `advanced-rag-automation-v1.2.0.json`
2. Активируйте workflow
3. Проверьте webhook URL: `http://localhost:5678/webhook/rag-automation`

---

## ТЕСТИРОВАНИЕ WORKFLOWS

### Quick Test
```bash
# Выполняется через веб-интерфейс кнопкой "Execute Workflow"
```

### Pipeline Test  
```bash
# Автоматически загружает и тестирует обработку документа
# Выполняется через веб-интерфейс кнопкой "Execute Workflow"
```

### Automation Webhook
```bash
curl -X POST http://localhost:5678/webhook/rag-automation \
  -H "Content-Type: application/json" \
  -d '{"action": "process_queue", "priority": "high"}'
```

---

## МОНИТОРИНГ ВЫПОЛНЕНИЯ

### В N8N интерфейсе:
1. Откройте вкладку **"Executions"**
2. Просматривайте историю выполнения
3. Анализируйте ошибки (если есть)
4. Используйте Debug режим для детального анализа

### Через API:
```bash
# Проверка статуса сервисов
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:6333/collections
```

---

## УСТРАНЕНИЕ ВОЗМОЖНЫХ ПРОБЛЕМ

### Если workflow не импортируется:
1. Проверьте валидность JSON
2. Убедитесь что N8N активен
3. Попробуйте импорт через copy-paste

### Если workflow не выполняется:
1. Проверьте активацию (переключатель)
2. Убедитесь в доступности всех сервисов
3. Проверьте логи в разделе "Executions"

### Если API endpoints недоступны:
```bash
# Перезапуск сервисов
docker-compose restart document-processor web-interface
```

---

## ФИНАЛЬНАЯ ПРОВЕРКА

После успешного импорта и активации всех workflows:

✅ **Quick Test** - проверка health всех сервисов  
✅ **Pipeline Test** - полный тест обработки документов  
✅ **Automation** - webhook автоматизации активен  

🎯 **Результат:** N8N workflows полностью интегрированы в Advanced RAG Pipeline v1.2.0

---

**Дата:** 24 июня 2025  
**Статус:** Production Ready  
**Версия:** v1.2.0
