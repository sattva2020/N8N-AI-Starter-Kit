# 🛡️ Pre-Commit Cleanup System

Автоматическая система предотвращения попадания файлов разработчика в публичный репозиторий.

## 🚀 Быстрая установка

```bash
# Linux/macOS
./scripts/install-pre-commit-hook.sh

# Windows
.\scripts\install-pre-commit-hook.ps1
```

## ✅ Что проверяется

- **Временные файлы**: `*.tmp`, `*.bak`, `*_draft.*`
- **Файлы разработчика**: `*TODO*.md`, `*NOTES*.md`, `LOCAL_*.*`
- **Чувствительные данные**: `.env`, `*.ppk`, `*password*`
- **Инструкции ИИ**: `copilot-instructions.md`, `ai-instructions/`
- **Логи и отчеты**: `*.log`, `*REPORT*.md`, `*SUCCESS*.md`

## 🔧 Ручная проверка

```bash
# Проверить текущие изменения
./scripts/pre-commit-check.sh

# Автоматическое исправление
./scripts/pre-commit-check.sh --auto
```

## ⚙️ Настройка

Конфигурация: `scripts/pre-commit-config.yml`

Полная документация: `docs/PRE_COMMIT_CLEANUP_GUIDE.md`
