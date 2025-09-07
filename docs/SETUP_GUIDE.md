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

## Изменение конфигурации Prometheus

В этой ветке целевой адрес для самого Prometheus в `config/prometheus/prometheus.yml` был обновлён на `prometheus:9090` — это использует сетевое имя контейнера внутри Docker Compose.

Если вы разворачиваете систему вне Docker и вам нужно другое значение хоста/порта, измените целевой адрес в конфигурации по необходимости.

```bash
pip install pre-commit
pre-commit install --install-hooks
```

## Примечания для разработчиков

- Если у вас нет `python3` в системе, скрипты используют `python` как fallback.
- На CI раннерах `shellcheck` устанавливается автоматически; на Windows можно использовать встроенную проверку `bash -n` как fallback для shell-скриптов.

- Добавлено: опциональная передача переменных окружения для `lightrag` (LLM/EMBEDDING/LIGHTRAG_VECTOR_STORAGE) через `compose/optional-services.yml` — можно настроить в `.env`.
- Обновлено: генератор `.env` теперь включает параметры `LLM_BINDING`, `EMBEDDING_BINDING`, `LLM_MODEL`, `EMBEDDING_MODEL`, `LIGHTRAG_VECTOR_STORAGE` для автоматической настройки LightRAG (см. `scripts/setup.sh`).

## Контакты

Если возникли проблемы — откройте issue в репозитории или напишите в обсуждения.
