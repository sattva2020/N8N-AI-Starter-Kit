# Миграция с Zep на Graphiti

## Обзор изменений

**Дата:** 23 июня 2025  
**Статус:** Завершено  

### Причина миграции

1. **Zep Community Edition архивирован** - проект больше не поддерживается командой разработчиков
2. **Graphiti - официальная замена** - новое решение от той же команды для работы с векторными базами данных и памятью
3. **Стабильность** - Graphiti работает стабильно и имеет активную поддержку

### Что изменилось

#### Удалённые компоненты:
- ❌ Zep container (зависал и не запускался)
- ❌ Zep configuration files
- ❌ Zep-specific environment variables

#### Сохранённые компоненты:
- ✅ **Graphiti** - основной сервис для работы с векторами и memory
- ✅ **Neo4j** - база данных графов для Graphiti
- ✅ **PostgreSQL с pgvector** - векторная база данных
- ✅ **N8N** - основной рабочий процесс

### Текущая архитектура

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     N8N     │    │  Graphiti   │    │   Neo4j     │
│             │◄──►│             │◄──►│             │
│  Workflows  │    │ Memory API  │    │ Graph DB    │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────────────────────────┐
│     PostgreSQL + pgvector       │
│        Vector Database          │
└─────────────────────────────────┘
```

### API доступ

- **Graphiti API:** http://localhost:8001
- **Graphiti Docs:** http://localhost:8001/docs
- **Neo4j Browser:** http://localhost:7474

### Преимущества Graphiti над Zep

1. **Активная разработка** - не архивирован
2. **Стабильность** - нет проблем с запуском
3. **Лучшая интеграция** - работает с Neo4j из коробки
4. **FastAPI** - современный REST API
5. **Совместимость** - от той же команды разработчиков

### Настройки окружения

Следующие переменные больше не используются:
```bash
# Удалённые Zep переменные
ZEP_POSTGRES_USER=zep_user
ZEP_POSTGRES_PASSWORD=zep_password_123
ZEP_POSTGRES_DB=zep
ZEP_API_SECRET=zep_api_secret_key_here
```

Актуальные переменные для Graphiti:
```bash
# Graphiti настройки
OPENAI_API_KEY=your_openai_api_key_here
NEO4J_URI=bolt://neo4j-zep:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=zepzepzep
GRAPHITI_DOMAIN=localhost:8001
```

### Команды для работы

```bash
# Запуск только Graphiti и зависимостей
docker compose up -d neo4j graphiti

# Проверка статуса
docker compose ps graphiti neo4j

# Просмотр логов
docker compose logs graphiti

# Тестирование API
curl http://localhost:8001/docs
```

### Следующие шаги

1. ✅ Zep остановлен и исключён из production
2. ✅ Graphiti работает стабильно
3. ⏳ Обновить документацию N8N workflows для использования Graphiti API
4. ⏳ Обновить примеры интеграции
5. ⏳ Создать тестовые сценарии для Graphiti

### Заметки разработчика

- Graphiti использует Neo4j для хранения графов знаний
- API совместим с современными стандартами (OpenAPI/Swagger)
- Нет проблем с правами на расширения PostgreSQL
- Healthcheck работает корректно
- Готов к production использованию

---

**Статус миграции:** ✅ **ЗАВЕРШЕНО**  
**Рекомендация:** Продолжить разработку с Graphiti как основным решением для memory/векторов.
