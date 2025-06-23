# Структура папок N8N AI Starter Kit

## Организация файлов

### 📁 **config/** - Пользовательские настройки
- `ollama-models-config.yml` - Справочник по моделям Ollama
- `ollama-models.txt` - Список моделей для автозагрузки
- `middlewares.yml` - Настройки middleware для Traefik
- `zep.yaml` - Конфигурация Zep Memory Store

**Кто редактирует**: Пользователи системы
**Когда**: При настройке под свои нужды

### 📁 **compose/** - Инфраструктура Docker
- `ollama-compose.yml` - Определение сервиса Ollama
- `networks.yml` - Сетевая конфигурация
- `supabase-compose.yml` - Сервисы Supabase
- `zep-compose.yaml` - Сервисы Zep
- `optional-services.yml` - Дополнительные сервисы

**Кто редактирует**: Администраторы/разработчики
**Когда**: При изменении архитектуры

### 📁 **scripts/** - Исполняемые файлы
- `setup.sh` - Первоначальная настройка
- `start.sh` - Запуск системы
- `preload-models.sh` - Загрузка моделей
- `select-model-profile.sh` - Выбор профиля моделей

### 📁 **docs/** - Документация
- Руководства пользователя
- Техническая документация
- Инструкции по установке

## Принципы организации

### 🎯 **Разделение ответственности**
- **config** = ЧТО настраивать
- **compose** = КАК запускать  
- **scripts** = КОГДА и ЗАЧЕМ

### 🔄 **Связи между папками**
```bash
compose/ollama-compose.yml   →  монтирует  →  config/ollama-models.txt
scripts/preload-models.sh    →  читает     →  config/ollama-models.txt
scripts/select-model-profile →  создаёт    →  config/ollama-models.txt
                             →  читает     →  config/ollama-models-config.yml
```

### ✅ **Преимущества текущей структуры**
1. **Модульность** - можно заменить только нужные части
2. **Безопасность** - разные права доступа для разных типов файлов
3. **Удобство** - пользователи работают только с config/
4. **Стандарты** - соответствует принципам DevOps

### 🔧 **Быстрые команды**
```bash
# Изменить модели
nano config/ollama-models.txt

# Выбрать готовый профиль
./scripts/select-model-profile.sh

# Перезапустить только Ollama
docker compose restart ollama

# Включить дополнительные сервисы
docker compose -f docker-compose.yml -f compose/optional-services.yml up -d
```
