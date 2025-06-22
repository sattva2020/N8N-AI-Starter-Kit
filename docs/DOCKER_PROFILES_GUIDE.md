# 🔧 ПРОФИЛИ DOCKER COMPOSE В N8N AI STARTER KIT

## 📋 Доступные профили:

### 🚀 **default** - Основные сервисы
```bash
docker compose --profile default up -d
```
**Включает:**
- N8N (веб-интерфейс автоматизации)
- PostgreSQL (база данных)
- Qdrant (векторная база)
- MinIO (объектное хранилище)
- Traefik (reverse proxy)

**Не включает:** Ollama, PgAdmin, JupyterLab

---

### 🧠 **cpu** - Основные + CPU Ollama (РЕКОМЕНДУЕМЫЙ)
```bash
docker compose --profile cpu up -d
```
**Включает:** Все из default +
- Ollama (локальные LLM модели на CPU)
- Ollama-pull (автоматическая загрузка моделей)

**Лучший выбор для:** Production использования

---

### 👨‍💻 **developer** - Полный набор для разработки
```bash
docker compose --profile developer up -d
```
**Включает:** Все из cpu +
- PgAdmin (управление PostgreSQL)
- JupyterLab (ноутбуки для анализа данных)

**Лучший выбор для:** Разработки и отладки

---

## 🚀 Дополнительные сервисы (отдельные compose файлы):

### **Zep + Graphiti** (память для AI):
```bash
docker compose -f compose/zep-compose.yaml up -d
```

### **Supabase** (альтернативная база):
```bash
docker compose -f compose/supabase-compose.yml up -d
```

### **Только Ollama** (если нужен отдельно):
```bash
docker compose -f compose/ollama-compose.yml up -d
```

---

## 🎯 Рекомендации по выбору профиля:

### 🏢 **Production (продакшен):**
```bash
docker compose --profile cpu up -d
```
Оптимальный баланс функций и ресурсов

### 🧪 **Testing (тестирование):**
```bash
docker compose --profile default up -d
```
Минимальный набор для проверки работоспособности

### 🔬 **Development (разработка):**
```bash
docker compose --profile developer up -d
```
Полный набор инструментов для разработки

---

## 📊 Проверка запущенных сервисов:

```bash
# Посмотреть что запущено
docker compose ps

# Проверить профиль сервисов
docker compose --profile cpu ps

# Быстрая проверка API
./scripts/quick-check.sh              # Linux
scripts\quick-check-windows.bat       # Windows
```

---

## ⚡ Полезные команды:

```bash
# Остановить все сервисы
docker compose --profile cpu down

# Перезапустить с новым профилем
docker compose --profile cpu down
docker compose --profile developer up -d

# Обновить и перезапустить
git pull origin main
docker compose --profile cpu down
docker compose --profile cpu pull
docker compose --profile cpu up -d
```

---

**💡 Совет:** Начните с профиля `cpu` - он содержит все необходимое для полноценной работы N8N с AI возможностями!

## ⚠️ **Важно для Ubuntu:**

В новых версиях Docker используется команда `docker compose` (без дефиса), а не старая `docker-compose`. 

**Если получаете ошибку "Command 'docker-compose' not found":**
```bash
# Используйте новую команду (рекомендуемо):
docker compose --profile cpu up -d

# Или установите старую версию (не рекомендуется):
sudo apt install docker-compose
```
