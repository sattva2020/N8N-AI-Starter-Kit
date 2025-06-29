# 📁 N8N Workflows Directory Structure
## Организованная структура workflows для N8N AI Starter Kit v1.2.0

**Последнее обновление:** 24 июня 2025  
**Статус:** ✅ РЕОРГАНИЗОВАНО  

---

## 📂 СТРУКТУРА ПАПОК

```
n8n/workflows/
├── production/           # 🚀 PRODUCTION workflows (автоимпорт)
├── testing/              # 🧪 TESTING workflows  
├── examples/             # 📚 EXAMPLE workflows
└── README.md            # Данная документация

n8n/demo-data/
├── workflows-legacy/     # 📦 LEGACY workflows (архив)
└── credentials/          # Credentials данные
```

---

## 📋 ОПИСАНИЕ ПАПОК

### 🚀 **production/** 
**Назначение:** Production-ready workflows для автоматического импорта  
**Автоимпорт:** ✅ ДА (при запуске docker-compose)  
**Содержимое:**
- `advanced-rag-automation-v1.2.0.json` - Основной RAG automation workflow

**Требования:**
- Workflows должны быть полностью протестированы
- Готовы к production использованию
- Содержат error handling
- Документированы

### 🧪 **testing/**
**Назначение:** Workflows для тестирования и разработки  
**Автоимпорт:** ✅ ДА (для тестирования системы)  
**Содержимое:**
- `quick-rag-test.json` - Быстрое тестирование RAG pipeline
- `advanced-rag-pipeline-test.json` - Полное тестирование системы

**Требования:**
- Workflows для проверки функциональности
- Могут содержать test data
- Безопасны для автоматического запуска

### 📚 **examples/**
**Назначение:** Примеры workflows для обучения и шаблонов  
**Автоимпорт:** ✅ ДА (как templates)  
**Содержимое:**
- `example-ai-basic.json` - Базовый AI workflow пример
- `example-telegram-integration.json` - Пример Telegram интеграции

**Требования:**
- Образовательные workflows
- Хорошо документированы
- Могут использоваться как templates

### 📦 **demo-data/workflows-legacy/**
**Назначение:** Архив старых workflows  
**Автоимпорт:** ❌ НЕТ (архивные данные)  
**Содержимое:** 30+ старых workflow файлов

**Статус:** Архивные данные, не используются в текущей версии

---

## 🔄 АВТОМАТИЧЕСКИЙ ИМПОРТ

### **Как работает:**
```yaml
# docker-compose.yml
n8n-workflows-importer:
  volumes:
    - ./n8n/workflows:/workflows:ro  # Импортирует ВСЕ workflows
```

### **Что импортируется:**
- ✅ `production/*` - Production workflows
- ✅ `testing/*` - Testing workflows  
- ✅ `examples/*` - Example workflows
- ❌ `../demo-data/workflows-legacy/*` - НЕ импортируется

### **Порядок импорта:**
1. Production workflows (приоритет)
2. Testing workflows
3. Example workflows

---

## 📝 ДОБАВЛЕНИЕ НОВЫХ WORKFLOWS

### **1. Production Workflow:**
```bash
# Поместить в production/
cp my-new-workflow.json n8n/workflows/production/

# Перезапустить автоимпорт
docker-compose restart n8n-workflows-importer
```

### **2. Testing Workflow:**
```bash
# Поместить в testing/
cp my-test-workflow.json n8n/workflows/testing/
```

### **3. Example Workflow:**
```bash
# Поместить в examples/
cp my-example-workflow.json n8n/workflows/examples/
```

---

## 🔍 СТАНДАРТЫ КАЧЕСТВА

### **Production Workflows:**
- [ ] Полное тестирование
- [ ] Error handling
- [ ] Logging
- [ ] Documentation
- [ ] Performance optimization
- [ ] Security review

### **Testing Workflows:**
- [ ] Test coverage
- [ ] Mock data setup
- [ ] Assertions
- [ ] Cleanup procedures

### **Example Workflows:**
- [ ] Clear documentation
- [ ] Step-by-step comments
- [ ] Easy to understand
- [ ] Reusable components

---

## 🛠️ УПРАВЛЕНИЕ WORKFLOWS

### **Просмотр импортированных workflows:**
```bash
# Проверить статус автоимпорта
bash scripts/check-auto-import-status.sh

# Логи импорта
docker-compose logs n8n-workflows-importer
```

### **Ручной импорт:**
```bash
# Принудительный переимпорт
docker-compose up n8n-workflows-importer --force-recreate
```

### **Backup workflows:**
```bash
# Экспорт всех workflows из N8N
curl "http://localhost:5678/rest/workflows" > workflows-backup.json
```

---

## 📊 СТАТИСТИКА

### **Текущее состояние:**
- **Production:** 1 workflow
- **Testing:** 2 workflows  
- **Examples:** 2 workflows
- **Legacy:** 30+ workflows (архив)

### **Автоимпорт статус:**
- ✅ Активен для `n8n/workflows/`
- ❌ Отключен для `demo-data/workflows-legacy/`

---

## 🔄 МИГРАЦИЯ LEGACY WORKFLOWS

Если нужно восстановить старый workflow из legacy:

```bash
# 1. Найти нужный файл
ls n8n/demo-data/workflows-legacy/

# 2. Скопировать в нужную папку
cp n8n/demo-data/workflows-legacy/FILENAME.json n8n/workflows/examples/

# 3. Переименовать с префиксом
mv n8n/workflows/examples/FILENAME.json n8n/workflows/examples/example-FILENAME.json

# 4. Перезапустить автоимпорт
docker-compose restart n8n-workflows-importer
```

---

## 📞 ПОДДЕРЖКА

**Документация:**
- `N8N_WORKFLOWS_IMPORT_GUIDE.md` - Руководство по импорту
- `WORKFLOWS_CLEANUP_PLAN.md` - План реорганизации

**Скрипты:**
- `scripts/check-auto-import-status.sh` - Проверка статуса
- `scripts/quick-import-test.sh` - Быстрое тестирование

---

**✅ Структура workflows приведена в порядок и готова к использованию!**

**N8N Workflows Structure v1.2.0**  
**Status:** ✅ ORGANIZED  
**Auto-Import:** ✅ ACTIVE
