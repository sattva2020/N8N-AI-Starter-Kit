# 🔧 UBUNTU DOCKER COMPOSE ISSUE FIX

## ❌ Проблема:
```bash
root@n8n:~/N8N-AI-Starter-Kit# docker-compose --profile cpu up -d
Command 'docker-compose' not found, but can be installed with:
apt install docker-compose
```

## ✅ Решение:

### **1. Используйте новую команду (РЕКОМЕНДУЕМО):**
```bash
# Вместо docker-compose используйте docker compose:
docker compose --profile cpu up -d
```

### **2. Или установите старую версию (НЕ РЕКОМЕНДУЕТСЯ):**
```bash
sudo apt install docker-compose
```

## 🎯 Правильные команды для Ubuntu:

### **Запуск сервисов:**
```bash
# Основные сервисы + Ollama (рекомендуемо)
docker compose --profile cpu up -d

# Только основные сервисы
docker compose --profile default up -d

# Все сервисы для разработки
docker compose --profile developer up -d
```

### **Управление:**
```bash
# Посмотреть статус
docker compose ps

# Остановить сервисы
docker compose --profile cpu down

# Перезапустить
docker compose --profile cpu restart

# Обновить образы
docker compose --profile cpu pull
```

### **Проверка:**
```bash
# Быстрая проверка
./scripts/quick-check.sh

# Полная валидация
./scripts/comprehensive-container-check.sh

# Проверка API
curl http://localhost:5678   # N8N
curl http://localhost:11434  # Ollama
curl http://localhost:6333   # Qdrant
```

## 📊 Разница между версиями:

| Старая версия | Новая версия |
|---------------|--------------|
| `docker-compose` (с дефисом) | `docker compose` (без дефиса) |
| Отдельная установка | Встроено в Docker |
| `apt install docker-compose` | Уже включено |

## ✅ Проверка версии Docker:

```bash
# Проверить версию Docker
docker --version
docker compose version

# Если команда работает - всё готово!
```

## 🚀 Быстрый старт:

```bash
cd ~/N8N-AI-Starter-Kit
git pull origin main
chmod +x scripts/*.sh
docker compose --profile cpu up -d
./scripts/quick-check.sh
```

---

**💡 Совет:** Новая команда `docker compose` работает быстрее и надёжнее старой `docker-compose`!
