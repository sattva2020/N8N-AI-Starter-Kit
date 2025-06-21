# Быстрый запуск публикации N8N AI Starter Kit

> **⚠️ Важное примечание**: Скрипты исправления проблем (`fix-*.sh`, `fix-*.ps1`) предназначены только для локального использования и автоматически исключены из публикации через `.gitignore`. Они помогают подготовить проект к публикации, но не являются частью итогового продукта.

##### 5. Добавление недостающих переменных окружения:
```bash
# Linux/macOS
chmod +x scripts/add-missing-env-vars.sh
./scripts/add-missing-env-vars.sh
```

### 6. После исправлений повторите публикацию:🚀 Автоматическая публикация (рекомендуется)

### Linux/macOS:
```bash
chmod +x scripts/publish-to-github.sh
./scripts/publish-to-github.sh
```

### Windows:
```powershell
.\scripts\publish-to-github.ps1
```

## 🛠️ Если возникают ошибки при публикации:

### 1. Исправление переменных окружения:
```bash
# Linux/macOS
./scripts/fix-env-issues.sh

# Windows
.\scripts\fix-env-issues.ps1
```

### 2. Исправление Docker Compose конфигурации:
```bash
# Linux/macOS  
./scripts/fix-docker-compose.sh

# Windows
.\scripts\fix-docker-compose.ps1
```

### 3. Исправление YAML anchors:
```bash
# Linux/macOS
chmod +x scripts/fix-yaml-anchors.sh
./scripts/fix-yaml-anchors.sh
```

### 4. Исправление дублирующих ключей:
```bash
# Linux/macOS
chmod +x scripts/fix-duplicate-keys.sh
./scripts/fix-duplicate-keys.sh

# Windows
.\scripts\fix-duplicate-keys.ps1
```

### 6. После исправлений повторите публикацию:
```bash
./scripts/publish-to-github.sh
```

## ✨ Что произойдет:

1. **Проверка тегов**: Скрипт автоматически найдет существующий v1.0.6 в вашем репозитории
2. **Предложение версий**: Будут предложены варианты:
   - v1.0.7 (patch update)
   - v1.1.0 (minor update) 
   - v2.0.0 (major update)
   - Ввод вручную
3. **Проверка конфликтов**: Убедится, что новая версия не существует
4. **Исправление YAML**: Автоматическое исправление anchors и дублирующих ключей
5. **Публикация**: Создание нового релиза на GitHub
4. **Обновление документации**: Автоматически обновит README.md и CHANGELOG.md
5. **Публикация**: Создаст коммит, тег и опубликует на GitHub

## 🛡️ Защита от ошибок:

- ✅ Никаких дублирующих тегов
- ✅ Проверка формата версий
- ✅ Возможность отмены на любом этапе
- ✅ Автоматические резервные копии

## 📋 После публикации:

1. Перейдите в ваш репозиторий на GitHub
2. Создайте релиз из нового тега
3. Скопируйте описание из обновленного CHANGELOG.md
4. Опубликуйте релиз

**Время выполнения:** ~2-3 минуты ⏱️