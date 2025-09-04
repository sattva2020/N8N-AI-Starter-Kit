# Setup Guide

Краткое руководство по установке и настройке N8N AI Starter Kit.

## Что добавлено в этом релизе

- Автоматическое форматирование YAML файлов (встроенный форматтер `scripts/format-yaml.py`).
- Файл `requirements.txt` с зависимостью `PyYAML>=6.0` для форматтера.
- CI: обновлён workflow для установки зависимостей и `shellcheck` на раннерах.
- Pre-commit: добавлен хук форматирования YAML и проверки содержимого репозитория.

## Быстрая установка зависимостей (локально)

1. Установите Python (рекомендуется Python 3.8+). На Windows убедитесь, что `python` доступен в PATH.
2. Установите зависимости:

```bash
python -m pip install -r requirements.txt
```

1. Установите `pre-commit` и активируйте хуки:

```bash
pip install pre-commit
pre-commit install --install-hooks
```

## Примечания для разработчиков

- Если у вас нет `python3` в системе, скрипты используют `python` как fallback.
- На CI раннерах `shellcheck` устанавливается автоматически; на Windows можно использовать встроенную проверку `bash -n` как fallback для shell-скриптов.

- Добавлено: опциональная передача переменных окружения для `lightrag` (LLM/EMBEDDING/LIGHTRAG_VECTOR_STORAGE) через `compose/optional-services.yml` — можно настроить в `.env`.

## Контакты

Если возникли проблемы — откройте issue в репозитории или напишите в обсуждения.
