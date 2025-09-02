# 🛡️ Система предотвращения попадания файлов разработчика в публичный репозиторий

## 📋 Обзор

Эта система автоматически проверяет и предотвращает попадание в публичный репозиторий файлов, предназначенных только для локальной разработки:

- ✅ **Временные файлы** (_.tmp, _.bak, _\_draft._)
- ✅ **Файлы разработчика** (_TODO_.md, _NOTES_.md, LOCAL\__._)
- ✅ **Логи и отчеты** (*.log, *REPORT*.md, *SUCCESS\*.md)
- ✅ **Чувствительные данные** (.env, *.ppk, *password\*)
- ✅ **Инструкции ИИ** (copilot-instructions.md, ai-instructions/)

## 🚀 Быстрый старт

### 1. Автоматическая установка

```bash
# Для Linux/macOS
./scripts/install-pre-commit-hook.sh

# Для Windows
.\scripts\install-pre-commit-hook.ps1
```

### 2. Ручная проверка

```bash
# Для Linux/macOS
./scripts/pre-commit-check.sh

# Для Windows
.\scripts\pre-commit-check.ps1
```

### 3. Проверка с автоматическим исправлением

```bash
# Строгий режим (блокирует коммит при проблемах)
./scripts/pre-commit-check.sh --strict

# Автоматический режим (без интерактивных запросов)
./scripts/pre-commit-check.sh --auto
```

## 🔧 Конфигурация

Настройки хранятся в файле `scripts/pre-commit-config.yml`:

```yaml
# Файлы только для разработки
dev_only_patterns:
  - "*TODO*.md"
  - "*_draft.*"
  - "*.tmp"

# Чувствительные данные
sensitive_patterns:
  - ".env"
  - "*.ppk"
  - "*password*"
```

## 📝 Что проверяется

### 🗂️ Файлы только для разработки

- **Временные файлы**: `*.tmp`, `*.temp`, `*.bak`
- **Заметки разработчика**: `*TODO*.md`, `*NOTES*.md`, `*DRAFT*.md`
- **Локальные файлы**: `LOCAL_*.md`, `MY_*.md`, `*_local.*`
- **Отчеты разработки**: `*REPORT*.md`, `*SUCCESS*.md`, `*FINAL*.md`
- **Логи**: `*.log`, `setup_trace.log`, `placeholders.log`
- **Инструкции ИИ**: `copilot-instructions.md`, `AI_AGENT_GUIDE.md`

### 🔒 Чувствительные данные

- **Переменные окружения**: `.env`, `.env.*`
- **SSH ключи**: `*.ppk`, `*key*.pem`
- **Пароли**: `*password*`, `*secret*`, `*credentials*`

### 📁 Директории для разработки

- `backup/`, `backups/`, `.internal/`
- `logs/`, `tests/`, `ai-instructions/`
- `volumes/`, `data/`, `n8n/`

### 📄 Содержимое файлов

Сканирует `.md`, `.yml`, `.json`, `.sh`, `.ps1` файлы на:

- Пароли и ключи API
- Адреса localhost
- Комментарии разработчика (TODO, FIXME, HACK)

## 🛠️ Автоматические исправления

### 📋 Обновление .gitignore

Автоматически добавляет отсутствующие паттерны:

```gitignore
*.log
*.tmp
*TODO*.md
*_local.*
.env
ai-instructions/
backup/
```

### 📊 Отчеты

Создает детальные отчеты в `.internal/pre-commit-report-YYYYMMDD_HHMMSS.md`

## 🔄 Интеграция с Git

### Pre-commit Hook

Автоматически запускается перед каждым коммитом:

```bash
# Установка
./scripts/install-pre-commit-hook.sh

# Обход проверки (только в крайних случаях)
git commit --no-verify
```

### Workflow

1. **git add** - добавляете файлы
2. **Автоматическая проверка** - запускается pre-commit hook
3. **Интерактивное исправление** - если найдены проблемы
4. **git commit** - коммит разрешен только после исправления

## 📋 Примеры использования

### Проверка текущих изменений

```bash
# Быстрая проверка
./scripts/pre-commit-check.sh

# С автоматическим обновлением .gitignore
./scripts/pre-commit-check.sh --auto
```

### Конфигурирование исключений

```yaml
# scripts/pre-commit-config.yml
exceptions:
  files:
    - "README.md" # Всегда разрешен
    - "LICENSE" # Всегда разрешен
  directories:
    - ".git/" # Игнорировать
```

### Отключение отдельных проверок

```yaml
# scripts/pre-commit-config.yml
check_settings:
  check_file_content: false # Отключить проверку содержимого
  auto_update_gitignore: false # Не обновлять .gitignore
  strict_mode: true # Блокировать коммит при проблемах
```

## 🚨 Что делать при срабатывании

### 1. Найдены файлы разработчика

```
⚠ Найдены файлы для разработки: *TODO*.md
  📄 MY_NOTES.md
  📄 DEBUG_INFO.md
```

**Решение**: Добавьте файлы в `.gitignore` или удалите их

### 2. Найдены чувствительные данные

```
✗ КРИТИЧНО: Найдены чувствительные файлы: .env
  🔒 .env
```

**Решение**: Немедленно удалите из staging: `git reset HEAD .env`

### 3. Подозрительное содержимое

```
⚠ Найдено подозрительное содержимое в config.yml: password=
    5: database_password=secret123
```

**Решение**: Замените на переменную окружения или удалите

## 🔧 Расширенные настройки

### Добавление новых паттернов

```yaml
# scripts/pre-commit-config.yml
dev_only_patterns:
  - "my_custom_pattern_*.md"
  - "*experimental*"
```

### Настройка строгости

```yaml
check_settings:
  strict_mode: true # Блокировать коммит
  max_files_to_check: 200 # Увеличить лимит файлов
  generate_reports: false # Отключить отчеты
```

## 🤝 Команда и поддержка

### Обход системы

```bash
# Только в критических ситуациях!
git commit --no-verify -m "emergency fix"
```

### Обновление правил

1. Отредактируйте `scripts/pre-commit-config.yml`
2. Протестируйте: `./scripts/pre-commit-check.sh`
3. Зафиксируйте изменения

### Совместная работа

- Все члены команды должны установить pre-commit hook
- Регулярно синхронизируйте правила в `pre-commit-config.yml`
- Обсуждайте исключения в команде

## 📚 Дополнительные ресурсы

- 📖 **Конфигурация**: `scripts/pre-commit-config.yml`
- 📊 **Отчеты**: `.internal/pre-commit-report-*.md`
- 🔧 **Логи**: При ошибках смотрите вывод скрипта

---

**🎯 Цель**: Поддерживать чистоту публичного репозитория и предотвращать утечку чувствительных данных.
