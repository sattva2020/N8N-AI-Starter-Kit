# ⚙️ Конфигурация N8N AI Starter Kit

Полное руководство по настройке всех компонентов платформы. Правильная конфигурация гарантирует стабильную и безопасную работу.

## 📋 Быстрый старт

### Генерация конфигурации

```bash
# Рекомендуемый способ - автоматическая генерация
./scripts/setup.sh

# Или ручная настройка
cp env.schema .env
nano .env
```

### Основные требования

**Обязательные переменные для запуска:**
- `DOMAIN_NAME` - ваш основной домен
- `N8N_ENCRYPTION_KEY` - ключ шифрования (32+ символов)
- `POSTGRES_PASSWORD` - пароль базы данных
- `ACME_EMAIL` - email для SSL-сертификатов

## 🐳 Профили Docker Compose

Гибкая система запуска сервисов по ролям:

| Профиль | Сервисы | Назначение |
|---------|---------|------------|
| `default` | n8n, postgres, traefik, ollama, qdrant, graphiti, neo4j | Базовая AI-автоматизация |
| `monitoring` | prometheus, grafana, alertmanager, exporters | Мониторинг и метрики |
| `logging` | elasticsearch, kibana, logstash | Централизованное логирование |
| `analytics` | superset, clickhouse, redis | Бизнес-аналитика |
| `developer` | pgadmin, jupyterlab | Инструменты разработки |

### Примеры запуска

```bash
# Только базовые сервисы
COMPOSE_PROFILES=default

# Полный стек
COMPOSE_PROFILES=default,monitoring,logging,analytics

# С инструментами разработчика
COMPOSE_PROFILES=default,developer
```

## 🔧 Переменные окружения

### Основные настройки

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `DOMAIN_NAME` | Основной домен для всех сервисов | **Да** | `example.com` |
| `COMPOSE_PROJECT_NAME` | Имя проекта Docker Compose | Нет | `n8n-ai-starter-kit` |
| `GENERIC_TIMEZONE` | Временная зона контейнеров | Нет | `UTC` |

### PostgreSQL

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `POSTGRES_USER` | Пользователь базы данных | Нет | `n8n` |
| `POSTGRES_PASSWORD` | Пароль PostgreSQL | **Да** | `gH4tL9jK1oP3` |
| `POSTGRES_DB` | Имя базы данных | Нет | `n8n` |
| `POSTGRES_HOST` | Хост сервиса | Нет | `postgres` |
| `POSTGRES_PORT` | Порт сервиса | Нет | `5432` |

### N8N - Основные настройки

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `N8N_ENCRYPTION_KEY` | Ключ шифрования учетных данных | **Да** | `your_32_char_encryption_key_here_` |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | JWT секрет для управления пользователями | Нет | `your_jwt_secret_key_here_min_32_chars` |
| `N8N_HOST` | Домен n8n | **Да** | `n8n.example.com` |
| `N8N_PORT` | Порт n8n | Нет | `5678` |
| `N8N_PROTOCOL` | Протокол (http/https) | Нет | `http` |
| `N8N_SECURE_COOKIE` | Безопасные cookies | Нет | `false` |
| `WEBHOOK_URL` | URL для вебхуков | Нет | `http://n8n.example.com/` |
| `N8N_API_KEY` | Ключ API n8n | Нет | `your_n8n_api_key_here` |
| `N8N_ADMIN_TOKEN` | Админ токен для API | **Да** | `n8n-pat-....` |

### N8N - Дополнительные настройки

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `N8N_DEFAULT_BINARY_DATA_MODE` | Режим хранения бинарных данных | Нет | `filesystem` |
| `N8N_API_AUTH_ACTIVE` | Активация API аутентификации | Нет | `true` |
| `N8N_METRICS` | Включить метрики | Нет | `true` |
| `N8N_RESET` | Сброс настроек при запуске | Нет | `false` |
| `N8N_RUNNERS_ENABLED` | Включить task runners | Нет | `true` |

### Traefik (Reverse Proxy)

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `ACME_EMAIL` | Email для Let's Encrypt | **Да** | `admin@example.com` |
| `TRAEFIK_USERNAME` | Логин дашборда Traefik | Нет | `admin` |
| `TRAEFIK_PASSWORD_HASHED` | Хеш пароля (htpasswd) | Нет | `$apr1$...` |
| `TRAEFIK_DASHBOARD_DOMAIN` | Домен дашборда | Нет | `traefik.example.com` |

### AI Сервисы

#### Ollama
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `OLLAMA_DOMAIN` | Домен Ollama API | **Да** | `ollama.example.com` |
| `OLLAMA_HOST` | Хост внутри Docker | Нет | `ollama` |

#### Graphiti / OpenAI
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `GRAPHITI_DOMAIN` | Домен Graphiti API | **Да** | `graphiti.example.com` |
| `OPENAI_API_KEY` | Ключ OpenAI API | Нет | `sk-...` |

#### Neo4j
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `NEO4J_URI` | URI подключения Neo4j | Нет | `bolt://neo4j-graphiti:7687` |
| `NEO4J_USER` | Пользователь Neo4j | Нет | `neo4j` |
| `NEO4J_PASSWORD` | Пароль Neo4j | **Да** | `gH4tL9jK1oP3` |
| `NEO4J_HOST` | Хост Neo4j | Нет | `neo4j-graphiti` |
| `NEO4J_PORT` | Порт Neo4j | Нет | `7687` |

#### Qdrant
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `QDRANT_DOMAIN` | Домен Qdrant | **Да** | `qdrant.example.com` |
| `QDRANT_URL` | URL Qdrant | Нет | `http://qdrant:6333` |

#### LightRAG
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `LIGHRAG_DOMAIN` | Домен LightRAG | **Авто** | `lightrag.example.com` |
| `LIGHRAG_PORT` | Порт LightRAG | **Авто** | `9621` |
| `LIGHTRAG_API_KEY` | API ключ LightRAG | **Авто** | `strong_api_key_here` |
| `TOKEN_SECRET` | Секрет для JWT | **Авто** | `strong_token_secret` |
| `ALLOW_ANONYMOUS_ACCESS` | Разрешить анонимный доступ | **Авто** | `false` |

> **ℹ️ Примечание:** Переменные LightRAG генерируются автоматически скриптом `setup.sh` во всех режимах установки. Ручная настройка не требуется.

### Обработка документов

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `DOCUMENT_PROCESSOR_DOMAIN` | Домен обработчика документов | Нет | `doc-processor.example.com` |
| `DOCUMENT_PROCESSOR_MAX_FILE_SIZE` | Максимальный размер файла | Нет | `100MB` |
| `DOCUMENT_PROCESSOR_SUPPORTED_FORMATS` | Поддерживаемые форматы | Нет | `pdf,docx,txt,md,rtf` |
| `DOCUMENT_PROCESSOR_CHUNK_SIZE` | Размер чанка | Нет | `512` |
| `DOCUMENT_PROCESSOR_OVERLAP` | Перекрытие чанков | Нет | `50` |
| `DOCUMENT_PROCESSOR_TIMEOUT` | Таймаут обработки | Нет | `300` |

### Рабочие процессы

| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `WORKFLOWS_DOC_DOMAIN` | Домен документации workflows | Нет | `workflows.example.com` |
| `WORKFLOWS_MANAGER_DOMAIN` | Домен менеджера workflows | Нет | `workflows-manager.example.com` |
| `WORKFLOWS_MANAGER_API_KEY` | API ключ менеджера | Нет | `your_api_key_here` |

### Мониторинг и аналитика

#### Grafana
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `GRAFANA_ADMIN_USER` | Админ пользователь Grafana | Нет | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Пароль админа Grafana | Нет | `secure_password` |

#### Elasticsearch
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `ELASTIC_PASSWORD` | Пароль Elasticsearch | Нет | `secure_elastic_password` |

#### Superset
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `SUPERSET_SECRET_KEY` | Секретный ключ Superset | Нет | `strong_secret_key` |

#### ClickHouse
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `CLICKHOUSE_PASSWORD` | Пароль ClickHouse | Нет | `secure_clickhouse_password` |

### Инструменты разработчика

#### pgAdmin
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `PGADMIN_DEFAULT_EMAIL` | Email для pgAdmin | Нет | `admin@example.com` |
| `PGADMIN_DEFAULT_PASSWORD` | Пароль pgAdmin | Нет | `secure_pgadmin_password` |

#### JupyterLab
| Переменная | Описание | Обязательно | Пример |
|------------|----------|-------------|---------|
| `JUPYTER_TOKEN` | Токен Jupyter | Нет | `your_jupyter_token` |

## 🔐 Генерация секретных ключей

### Рекомендуемые команды генерации

```bash
# Ключ шифрования n8n (32+ символов)
openssl rand -base64 32

# JWT секрет (48+ символов)
openssl rand -base64 48

# Пароли баз данных (24+ символов)
openssl rand -base64 24

# API ключи (32+ символов)
openssl rand -hex 32

# Хеш пароля для Traefik
htpasswd -nb username password
```

### Автоматическая генерация

```bash
# Используйте скрипт setup.sh для автоматической генерации
./scripts/setup.sh
```

## 🚀 Запуск с различными профилями

### Базовая конфигурация

```bash
# Только основные сервисы
echo "COMPOSE_PROFILES=default" >> .env
docker-compose --profile default up -d
```

### Полная конфигурация

```bash
# Все сервисы
echo "COMPOSE_PROFILES=default,monitoring,logging,analytics,developer" >> .env
docker-compose --profile default,monitoring,logging,analytics,developer up -d
```

### Проверка конфигурации

```bash
# Валидация .env файла
docker-compose config

# Проверка запущенных сервисов
docker-compose ps

# Просмотр логов
docker-compose logs -f n8n
```

## 🔧 Расширенная настройка

### Кастомные домены

```env
# Пример кастомных доменов
N8N_DOMAIN=my-n8n.example.com
GRAFANA_DOMAIN=monitoring.example.com
KIBANA_DOMAIN=logs.example.com
```

### Настройки производительности

```env
# Увеличение ресурсов для AI
OLLAMA_GPU_LAYERS=35
DOCUMENT_PROCESSOR_MAX_WORKERS=4

# Оптимизация PostgreSQL
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
```

### Безопасность

```env
# Дополнительные заголовки безопасности
TRAEFIK_HEADERS_STS_SECONDS=31536000
N8N_SECURE_COOKIE=true

# Ограничения доступа
TRAEFIK_MIDDLEWARE_RATE_LIMIT=100
```

## 📋 Контрольный список настройки

- [ ] `DOMAIN_NAME` указан корректно
- [ ] `N8N_ENCRYPTION_KEY` сгенерирован (32+ символов)
- [ ] `POSTGRES_PASSWORD` установлен
- [ ] `ACME_EMAIL` указан для SSL
- [ ] `N8N_ADMIN_TOKEN` создан в n8n UI
- [ ] Профили `COMPOSE_PROFILES` выбраны
- [ ] Домены для всех сервисов настроены
- [ ] Секретные ключи сгенерированы
- [ ] `.env` файл добавлен в `.gitignore`

## 🆘 Устранение проблем

### Распространенные ошибки

**"Encryption key is too short"**
```bash
# Сгенерируйте новый ключ
openssl rand -base64 32
```

**"SSL certificate failed"**
```bash
# Проверьте email в ACME_EMAIL
# Убедитесь что домен доступен
```

**"Database connection failed"**
```bash
# Проверьте POSTGRES_PASSWORD
# Проверьте доступность порта 5432
```

### Диагностика

```bash
# Проверка конфигурации
docker-compose config --quiet

# Тестирование подключений
docker-compose exec n8n n8n healthcheck

# Просмотр переменных окружения
docker-compose exec n8n env | grep N8N_
```

## 📚 Следующие шаги

После настройки конфигурации:

1. [🚀 Запустите систему](./01-getting-started.md#шаг-3-первый-запуск)
2. [🏗️ Изучите архитектуру](./03-architecture.md)
3. [🤖 Настройте AI-функции](./04-guides/ai-features.md)
4. [📊 Настройте мониторинг](./05-monitoring-and-logging.md)
