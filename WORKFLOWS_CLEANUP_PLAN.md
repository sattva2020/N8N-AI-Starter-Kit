# 📁 N8N WORKFLOWS STRUCTURE CLEANUP
## Приведение структуры workflows в порядок

**Дата:** 24 июня 2025  
**Задача:** Cleanup и организация workflows папок  

---

## 🎯 ТЕКУЩАЯ ПРОБЛЕМА

### Обнаруженные папки:
```
n8n/
├── workflows/                    # ✅ ACTIVE (автоимпорт v1.2.0)
│   ├── quick-rag-test.json
│   ├── advanced-rag-pipeline-test.json
│   └── advanced-rag-automation-v1.2.0.json
│
└── demo-data/
    └── workflows/                # ❌ LEGACY (старые demo files)
        ├── AI.json
        ├── Telegram.json
        ├── SHABLON_INSTAGRAM_*.json
        └── ... (30+ старых файлов)
```

### Проблемы:
- **Дублирование структуры** workflows
- **Старые файлы** не используются
- **Путаница** какие workflows активны
- **Автоимпорт** работает только с `n8n/workflows/`

---

## ✅ ПЛАН РЕШЕНИЯ

### **ЭТАП 1: Реорганизация структуры**
```
n8n/
├── workflows/                    # 🎯 PRODUCTION (автоимпорт)
│   ├── production/
│   │   └── advanced-rag-automation-v1.2.0.json
│   ├── testing/
│   │   ├── quick-rag-test.json
│   │   └── advanced-rag-pipeline-test.json
│   └── examples/
│       └── (переместить лучшие из demo-data)
│
├── demo-data/                    # 📚 ARCHIVE (legacy)
│   ├── workflows-legacy/         # Переименовать в legacy
│   └── credentials/
│
└── documentation/
    ├── WORKFLOWS_GUIDE.md
    └── IMPORT_INSTRUCTIONS.md
```

### **ЭТАП 2: Селекция полезных workflows**
- Анализировать `demo-data/workflows/`  
- Отобрать полезные для examples
- Архивировать устаревшие
- Обновить до v1.2.0 стандартов

### **ЭТАП 3: Обновление документации**
- Четкое описание структуры
- Инструкции по использованию
- Примеры создания новых workflows

---

## 🚀 РЕАЛИЗАЦИЯ

Начинаем cleanup и реорганизацию...
