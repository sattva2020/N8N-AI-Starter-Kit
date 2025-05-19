# N8N Self-hosted AI starter kit (N8N Стартовый набор для self-hosted ИИ)

**N8N Self-hosted AI Starter Kit** — это шаблон Docker Compose с открытым исходным кодом, предназначенный для быстрого развертывания комплексной локальной среды для разработки ИИ и low-code.

Созданный <https://github.com/n8n-io>, он объединяет self-hosted платформу n8n
с тщательно подобранным списком совместимых ИИ-продуктов и компонентов,
чтобы быстро начать создавать self-hosted ИИ-воркфлоу.

> [!TIP]
> [Прочитайте анонс](https://blog.n8n.io/self-hosted-ai/) (на английском)

### Что включено

✅ [**Self-hosted n8n**](https://n8n.io/) - Low-code платформа с более чем 400
интеграциями и продвинутыми ИИ-компонентами.

✅ [**Ollama**](https://ollama.com/) - Кроссплатформенная LLM-платформа для установки
и запуска последних локальных LLM.

✅ [**Qdrant**](https://qdrant.tech/) - Высокопроизводительное векторное хранилище
с открытым исходным кодом и комплексным API.

✅ [**PostgreSQL**](https://www.postgresql.org/) - Рабочая лошадка в мире инженерии
данных, безопасно обрабатывающая большие объемы данных.

✅ [**MinIO**](https://min.io/) - Высокопроизводительное, S3-совместимое объектное хранилище.

✅ [**pgAdmin**](https://www.pgadmin.org/) - Платформа для администрирования и разработки PostgreSQL с открытым исходным кодом.

✅ [**Traefik**](https://traefik.io/traefik/) - Современный обратный прокси и балансировщик нагрузки, упрощающий развертывание микросервисов.

✅ [**JupyterLab**](https://jupyter.org/) - Веб-интерактивная среда разработки для ноутбуков, кода и данных.

✅ [**Zep**](https://getzep.com/) - Долговременное хранилище памяти для ИИ-приложений.

### Что вы можете создать

⭐️ **ИИ-агенты** для планирования встреч

⭐️ **Суммаризация PDF-документов компании** безопасно, без утечек данных

⭐️ **Более умные Slack-боты** для улучшения корпоративных коммуникаций и ИТ-операций

⭐️ **Анализ частных финансовых документов** с минимальными затратами

# Структура и организация

<pre>
📂 N8N-AI-Starter-Kit
 ┣ 📂 backups                               # Директория для автоматических резервных копий
 ┃ ┗ 📄 n8n_db_20250518_232543.sql          # Пример файла резервной копии базы данных n8n
 ┣ 📂 compose                               # Конфигурации Docker Compose для различных компонентов
 ┃ ┣ 📄 zep-compose.yaml                    # Конфигурация для хранилища памяти и обработки контекста в ИИ-приложениях
 ┃ ┣ 📄 supabase-compose.yml                # Конфигурация для бэкенда с базой данных, аутентификацией и хранилищем
 ┃ ┗ 📄 optional-services.yml               # Дополнительные сервисы для расширения функциональности (мониторинг, аналитика)
 ┣ 📂 config                                # Конфигурационные файлы для сервисов
 ┃ ┣ 📄 middlewares.yml                     # Конфигурация промежуточного ПО для Traefik (безопасность, заголовки)
 ┃ ┣ 📄 ollama-models.txt                   # Перечень LLM-моделей для автоматической загрузки в Ollama
 ┃ ┣ 📄 traefik.yml                         # Правила маршрутизации, SSL-сертификаты и безопасность для обратного прокси
 ┃ ┣ 📄 zep.yaml                            # Настройки для хранилища памяти Zep (индексация, векторизация, поиск)
 ┃ ┣ 📂 loki                                # Конфигурация для системы сбора логов
 ┃ ┃ ┗ 📄 loki-config.yml                   # Настройки сервера Loki для агрегации и хранения логов
 ┃ ┣ 📂 prometheus                          # Конфигурация для системы мониторинга
 ┃ ┃ ┗ 📄 prometheus.yml                    # Настройки сбора метрик и алертов
 ┃ ┗ 📂 promtail                            # Конфигурация для агента сбора логов
 ┃   ┗ 📄 promtail-config.yml               # Настройки отправки логов в Loki
 ┣ 📂 logs                                  # Директория для хранения логов
 ┃ ┣ 📄 backup.log                          # Логи успешных операций резервного копирования
 ┃ ┗ 📄 backup_error.log                    # Логи ошибок резервного копирования
 ┣ 📂 n8n                                   # Данные и конфигурация для n8n
 ┃ ┗ 📂 demo-data                           # Демонстрационные данные для n8n
 ┃   ┣ 📂 credentials                       # Предустановленные учетные данные для демонстрационных воркфлоу
 ┃   ┃ ┗ 📄 sFfERYppMeBnFNeA.json           # Пример учетных данных для интеграции
 ┃   ┗ 📂 workflows                         # Предустановленные демонстрационные воркфлоу
 ┣ 📂 scripts                               # Утилиты для управления проектом
 ┃ ┣ 📄 backup.sh                           # Создание резервных копий данных, БД и конфигураций
 ┃ ┣ 📄 setup.sh                            # Автоматизация начальной настройки окружения и переменных
 ┃ ┗ 📄 update.sh                           # Обновление компонентов системы и контейнеров
 ┣ 📄 .env                                  # Переменные окружения для настройки сервисов
 ┣ 📄 .env.example                          # Пример файла с переменными окружения
 ┣ 📄 .gitignore                            # Список игнорируемых Git файлов и директорий
 ┣ 📄 docker-compose.yml                    # Основной файл конфигурации для развертывания всех сервисов
 ┣ 📄 LICENSE                               # Лицензионное соглашение Apache 2.0
 ┣ 📄 README.md                             # Документация по проекту и инструкции
 ┗ 📄 TROUBLESHOOTING.md                    # Руководство по устранению распространенных проблем
</pre>


# Установка

## Быстрая установка (рекомендуется)

Самый простой способ установить и настроить N8N AI Starter Kit — использовать автоматический скрипт установки. Этот метод автоматизирует весь процесс настройки, включая создание `.env` файла со случайными безопасными паролями.

```bash
# Клонирование репозитория
git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git
cd N8N-AI-Starter-Kit

# Установка прав на выполнение для скриптов
chmod +x scripts/*.sh

# Запуск скрипта автоматической установки
./scripts/setup.sh
```

#### После успешного выполнения скрипта установки вы можете запустить проект с нужным профилем:

```bash
# Для стандартной конфигурации на CPU (по умолчанию)
docker compose --profile cpu up -d

# Для конфигурации с NVIDIA GPU
docker compose --profile gpu-nvidia up -d

# Для конфигурации с AMD GPU
docker compose --profile gpu-amd up -d

# Для минимальной конфигурации (только основные сервисы)
docker compose --profile minimal up -d

# Для расширенной конфигурации разработчика (с JupyterLab, pgAdmin и др.)
docker compose --profile developer up -d
```

#### Ручная установка (для опытных пользователей)

Если вы предпочитаете настроить каждый компонент вручную, следуйте инструкциям ниже.

* Установка необходимых пакетов

```bash
sudo apt update
sudo apt install -y ca-certificates curl git gnupg
```
#### Добавление официального GPG-ключа Docker
```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

#### Настройка репозитория Docker
```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list
```

#### Установка Docker
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Добавление текущего пользователя в группу 'docker', чтобы избежать использования 'sudo' с командами docker
```bash
sudo usermod -aG docker $USER
newgrp docker
```


#### Проверка установки
```bash
docker --version
docker compose version
```

#### Клонирование репозитория

```bash
git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git
cd N8N-AI-Starter-Kit
```

#### Настройка файла `.env`

Перед запуском убедитесь, что вы скопировали `.env.example` в `.env` и заполнили все необходимые переменные, такие как пароли, ключи API и ваш email для Let's Encrypt.

```bash
cp .env.example .env
# Отредактируйте .env и установите ваши значения
```

### Запуск с использованием Docker Compose

#### Для пользователей с GPU Nvidia

```bash
docker compose --profile gpu-nvidia up -d --build
```

> [!NOTE]
> Если вы ранее не использовали ваш GPU Nvidia с Docker, пожалуйста, следуйте
> [инструкциям Ollama для Docker](https://github.com/ollama/ollama/blob/main/docs/docker.md).

#### Для пользователей с GPU AMD (Linux)

```bash
docker compose --profile gpu-amd up -d --build
```

#### Для пользователей Mac / Apple Silicon

Если вы используете Mac с процессором M1 или новее, вы, к сожалению, не можете предоставить Docker-инстансу доступ к вашему GPU. В этом случае есть два варианта:

1.  Запустить стартовый набор полностью на CPU, как описано в разделе "Для всех остальных" ниже.
2.  Запустить Ollama на вашем Mac для более быстрого вывода (inference) и подключиться к нему из инстанса n8n.

Если вы хотите запустить Ollama на вашем Mac, ознакомьтесь с
[инструкциями по установке на домашней странице Ollama](https://ollama.com/)
и запустите стартовый набор следующим образом:

```bash
docker compose up -d --build
```

#### Для всех остальных (CPU)

```bash
docker compose --profile cpu up -d --build
```

### Запуск только необходимых сервисов (минимальная конфигурация)
Если вам нужны только основные сервисы без дополнительных инструментов:
```bash
docker compose --profile minimal up -d
```
### Запуск с инструментами для разработчика (максимальная конфигурация)
Для запуска с полным набором инструментов, включая JupyterLab, pgAdmin и систему мониторинга:
```bash
docker compose --profile developer up -d
```


## ⚡️ Быстрый старт и использование

Ядром N8N AI Starter Kit является файл Docker Compose, предварительно настроенный с сетевыми параметрами и хранилищами, что минимизирует необходимость в дополнительных установках.
После выполнения шагов по установке, просто следуйте приведенным ниже шагам, чтобы начать.

1.  Откройте `http://localhost:5678/` (или `https://n8n.ваш-домен.com/`, если настроен Traefik с вашим доменом) в вашем браузере, чтобы настроить n8n. Это нужно будет сделать только один раз.
2.  Откройте включенный воркфлоу:
    `http://localhost:5678/workflow/srOnR8PAY3u4RSwb` (или `https://n8n.ваш-домен.com/workflow/srOnR8PAY3u4RSwb`)
3.  Нажмите кнопку **Chat** в нижней части холста, чтобы запустить воркфлоу.
4.  Если вы запускаете воркфлоу впервые, возможно, потребуется подождать,
    пока Ollama завершит загрузку Llama3.2. Вы можете проверить логи Docker
    консоли, чтобы отследить прогресс.

Чтобы открыть n8n в любое время, посетите `http://localhost:5678/` (или ваш настроенный домен) в вашем браузере.

С вашим инстансом n8n у вас будет доступ к более чем 400 интеграциям и
набору базовых и продвинутых ИИ-узлов, таких как
[AI Agent](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/),
[Text classifier](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.text-classifier/)
и [Information Extractor](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.information-extractor/).
Чтобы все оставалось локальным, просто не забывайте использовать узел Ollama для вашей
языковой модели и Qdrant в качестве вашего векторного хранилища. Zep будет использоваться для долговременной памяти в воркфлоу.

> [!NOTE]
> Этот стартовый набор предназначен для того, чтобы помочь вам начать работу с self-hosted ИИ-воркфлоу.
> Хотя он не полностью оптимизирован для производственных сред, он
> объединяет надежные компоненты, которые хорошо работают вместе для проектов
> проверки концепции (proof-of-concept). Вы можете настроить его под свои конкретные нужды.

## Обновление

* ### Для обновления системы вы можете использовать встроенный скрипт:
```
./scripts/update.sh [профиль]
```
Где [профиль] может быть: cpu (по умолчанию), gpu-nvidia, gpu-amd, minimal или developer.

* ### Или использовать ручное обновление через Docker Compose:

*   ### Для конфигураций с GPU Nvidia:

```bash
docker compose --profile gpu-nvidia pull
docker compose --profile gpu-nvidia up -d --force-recreate
```

*   ### Для пользователей Mac / Apple Silicon (использующих конфигурацию без профиля GPU):

```bash
docker compose pull
docker compose up -d --force-recreate
```

*   ### Для конфигураций без GPU (CPU):

```bash
docker compose --profile cpu pull
docker compose --profile cpu up -d --force-recreate
```
## Система мониторинга и аналитики в профиле developer

Профиль "developer" включает в себя полноценную систему мониторинга, аналитики данных и мониторинга LLM/AI сервисов на основе современного стека инструментов:

### 1. Мониторинг системы

* **Prometheus** (`https://prometheus.ваш-домен.com` или `http://localhost:9090`) — система мониторинга и сбора метрик для отслеживания производительности всех сервисов
* **Grafana** (`https://grafana.ваш-домен.com` или `http://localhost:3000`) — платформа для визуализации данных мониторинга с предустановленными дашбордами для Docker, n8n и Ollama
* **cAdvisor** (`https://cadvisor.ваш-домен.com` или `http://localhost:8080`) — мониторинг использования ресурсов контейнерами
* **Loki** (`https://loki.ваш-домен.com`) — система сбора и анализа логов, интегрированная с Grafana

#### Доступ к Grafana:

Используйте логин `admin` и пароль из переменной `GRAFANA_ADMIN_PASSWORD` в файле `.env` (установлен скриптом `setup.sh`).

#### Предустановленные дашборды:

* Docker Container & Host Metrics
* n8n Performance Dashboard
* Ollama Resource Usage
* Container Logs (через Loki)

#### Использование Prometheus для мониторинга API

Для мониторинга ваших API и сервисов вы можете добавить конфигурацию сбора метрик в файл `config/prometheus/prometheus.yml`. Пример добавления нового целевого сервиса:

```yaml
scrape_configs:
  - job_name: 'my-custom-service'
    scrape_interval: 15s
    static_configs:
      - targets: ['my-service:8000']
```


## 👓 Рекомендуемая литература (на английском)

n8n полон полезного контента для быстрого старта с его ИИ-концепциями
и узлами. Если у вас возникла проблема, перейдите в раздел [Поддержка](#поддержка).

- [AI agents for developers: from theory to practice with n8n](https://blog.n8n.io/ai-agents/)
- [Tutorial: Build an AI workflow in n8n](https://docs.n8n.io/advanced-ai/intro-tutorial/)
- [Langchain Concepts in n8n](https://docs.n8n.io/advanced-ai/langchain/langchain-n8n/)
- [Demonstration of key differences between agents and chains](https://docs.n8n.io/advanced-ai/examples/agent-chain-comparison/)
- [What are vector databases?](https://docs.n8n.io/advanced-ai/examples/understand-vector-databases/)

## 🎥 Видео-инструкция (на английском)

- [Installing and using Local AI for n8n](https://www.youtube.com/watch?v=xz_X2N-hPg0)

## 🛍️ Больше ИИ-шаблонов (на английском)

Для получения дополнительных идей ИИ-воркфлоу посетите [**официальную галерею ИИ-шаблонов n8n**](https://n8n.io/workflows/?categories=AI).
Из каждого воркфлоу выберите кнопку **Use workflow**, чтобы автоматически импортировать воркфлоу в ваш локальный инстанс n8n.

### Изучите ключевые концепции ИИ

- [AI Agent Chat](https://n8n.io/workflows/1954-ai-agent-chat/)
- [AI chat with any data source (using the n8n workflow too)](https://n8n.io/workflows/2026-ai-chat-with-any-data-source-using-the-n8n-workflow-tool/)
- [Chat with OpenAI Assistant (by adding a memory)](https://n8n.io/workflows/2098-chat-with-openai-assistant-by-adding-a-memory/)
- [Use an open-source LLM (via Hugging Face)](https://n8n.io/workflows/1980-use-an-open-source-llm-via-huggingface/)
- [Chat with PDF docs using AI (quoting sources)](https://n8n.io/workflows/2165-chat-with-pdf-docs-using-ai-quoting-sources/)
- [AI agent that can scrape webpages](https://n8n.io/workflows/2006-ai-agent-that-can-scrape-webpages/)

### Шаблоны для локального ИИ

- [Tax Code Assistant](https://n8n.io/workflows/2341-build-a-tax-code-assistant-with-qdrant-mistralai-and-openai/)
- [Breakdown Documents into Study Notes with MistralAI and Qdrant](https://n8n.io/workflows/2339-breakdown-documents-into-study-notes-using-templating-mistralai-and-qdrant/)
- [Financial Documents Assistant using Qdrant and](https://n8n.io/workflows/2335-build-a-financial-documents-assistant-using-qdrant-and-mistralai/) [Mistral.ai](http://mistral.ai/)
- [Recipe Recommendations with Qdrant and Mistral](https://n8n.io/workflows/2333-recipe-recommendations-with-qdrant-and-mistral/)

## Советы и хитрости

### Доступ к локальным файлам

Self-hosted AI starter kit создаст общую папку (по умолчанию,
расположенную в том же каталоге), которая монтируется в контейнер n8n и
позволяет n8n получать доступ к файлам на диске. Эта папка внутри контейнера n8n
находится по адресу `/data/shared` -- это путь, который вам нужно будет использовать в узлах,
взаимодействующих с локальной файловой системой.

**Узлы, взаимодействующие с локальной файловой системой**

- [Read/Write Files from Disk](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.filesreadwrite/)
- [Local File Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.localfiletrigger/)
- [Execute Command](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand/)

## 📜 Лицензия

Этот проект лицензирован под лицензией Apache License 2.0 - см. файл
[LICENSE](LICENSE) для получения подробной информации.

## 💬 Поддержка

Присоединяйтесь к обсуждению на [форуме n8n](https://community.n8n.io/), где вы
можете:

- **Делиться своей работой**: Покажите, что вы создали с помощью n8n, и вдохновите других
  в сообществе.
- **Задавать вопросы**: Независимо от того, начинаете ли вы или являетесь опытным
  профессионалом, сообщество и наша команда готовы помочь с любыми проблемами.
- **Предлагать идеи**: Есть идея для функции или улучшения? Дайте нам знать!
  Мы всегда рады услышать, что бы вы хотели видеть дальше.

### Настройка Учетных Данных для Других Сервисов

Для взаимодействия с некоторыми встроенными сервисами из ваших воркфлоу n8n, вам может потребоваться настроить соответствующие учетные данные в n8n. Перейдите в ваш n8n (`http://localhost:5678/credentials` или `https://n8n.ваш-домен.com/credentials`) и создайте новые учетные данные, используя указанные ниже параметры.

#### MinIO (S3-совместимое хранилище)

Если ваши воркфлоу n8n должны взаимодействовать с MinIO для чтения или записи файлов:

1.  **Тип учетных данных в n8n:** `AWS S3`
2.  **Параметры подключения:**
    *   **Access Key ID:** Используйте значение переменной `MINIO_ROOT_USER` из вашего файла `.env`.
    *   **Secret Access Key:** Используйте значение переменной `MINIO_ROOT_PASSWORD` из вашего файла `.env`.
    *   **Endpoint:** `http://minio:9000`
    *   **Use Path Style:** `true` (обычно рекомендуется для MinIO)
    *   **Region:** Можно указать любое значение, например, `us-east-1` (MinIO не строго привязан к регионам AWS).
    *   **Bucket Name:** Укажите имя бакета, с которым вы хотите работать (его нужно предварительно создать в MinIO через консоль `https://minio-console.ваш-домен.com` или `http://localhost:9001`, если доступно напрямую).

#### Qdrant (Векторное хранилище)

Для подключения к Qdrant из n8n (например, при использовании узлов Langchain для работы с векторными базами данных):

1.  **Тип учетных данных в n8n:** `Qdrant`
2.  **Параметры подключения:**
    *   **URL:** `http://qdrant:6333` (это адрес для REST API Qdrant внутри Docker-сети)
    *   **API Key:** (Опционально) Если вы настроили API-ключ для Qdrant, укажите его здесь. По умолчанию API-ключ может не требоваться.

#### PostgreSQL (для доступа из воркфлоу)

Если вы хотите взаимодействовать с базой данных PostgreSQL (той, что используется n8n, или другой, созданной на этом же инстансе) из ваших воркфлоу:

1.  **Тип учетных данных в n8n:** `Postgres`
2.  **Параметры подключения:**
    *   **Host:** `postgres` (имя сервиса PostgreSQL в Docker-сети)
    *   **Port:** `5432`
    *   **Database:** Используйте значение переменной `POSTGRES_DB` из вашего файла `.env` (это база данных n8n по умолчанию) или имя другой базы данных, к которой вы хотите подключиться.
    *   **User:** Используйте значение переменной `POSTGRES_USER` из вашего файла `.env` или другого пользователя БД.
    *   **Password:** Используйте значение переменной `POSTGRES_PASSWORD` из вашего файла `.env` или пароль другого пользователя БД.
    *   **SSL Mode:** `disable` (для внутреннего подключения в Docker-сети без SSL).

#### Zep (Долговременная память для ИИ)

Для интеграции Zep в ваши ИИ-воркфлоу для управления памятью:

1.  **Тип учетных данных в n8n:** `Zep` (или `HTTP Request` / `Generic API Credential`, если специального узла Zep нет, а используется его API)
2.  **Параметры подключения:**
    *   **Base URL:** `http://zep:8000` (предполагается, что сервис Zep называется `zep` и слушает порт `8000` внутри Docker-сети. Проверьте актуальное имя сервиса и порт в вашем `docker-compose.yml` для Zep).
    *   **API Key:** (Опционально) Если Zep требует API-ключ, укажите его.

#### Supabase (Альтернатива Firebase с открытым исходным кодом)

Для взаимодействия с вашим экземпляром Supabase из n8n (например, для работы с базой данных, аутентификацией, хранилищем):

1.  **Тип учетных данных в n8n:** `Supabase`
2.  **Параметры подключения:**
    *   **Project URL:** `http://supabase-kong:8000` (внутренний адрес API-шлюза Supabase (Kong) в Docker-сети).
    *   **Anon Key:** Используйте значение переменной `SUPABASE_ANON_KEY` из вашего файла `.env`.
    *   **Service Role Key:** Используйте значение переменной `SUPABASE_SERVICE_ROLE_KEY` из вашего файла `.env`.

    **Примечание:** Внешний доступ к API Supabase настроен через Traefik по адресу, указанному в переменной `SUPABASE_API_DOMAIN` вашего `.env` файла (например, `https://api.supabase.sattva-ai.top`). Для подключения из n8n к API Supabase используется внутренний адрес `http://supabase-kong:8000`. Доступ к Supabase Studio (веб-интерфейсу) осуществляется по адресу, указанному в переменной `SUPABASE_STUDIO_DOMAIN` (например, `https://supabase.sattva-ai.top`).

Эти инструкции помогут пользователям правильно настроить n8n для работы со всеми основными компонентами вашего стартового набора. Убедитесь, что имена сервисов (`minio`, `qdrant`, `postgres`, `zep`, `supabase`) и порты соответствуют тем, что указаны в вашем актуальном файле `docker-compose.yml`.


## Добавление возможности автоматического резервного копирования по расписанию

#### Решение 1:  
Использование cron на хост-системе
Это самый простой способ, если у вас есть доступ к настройке cron-задач на хост-машине
#### Откройте редактор crontab
```bash
crontab -e
```

#### Добавьте строку для ежедневного резервного копирования в 2:00 ночи
```bash
0 2 * * * cd /путь/к/n8n-ai-starter-kit && ./scripts/backup.sh >> /путь/к/n8n-ai-starter-kit/logs/backup.log 2>&1
```

#### Для еженедельного резервного копирования по воскресеньям в 3:00 ночи
```bash
0 3 * * 0 cd /путь/к/n8n-ai-starter-kit && ./scripts/backup.sh >> /путь/к/n8n-ai-starter-kit/logs/backup.log 2>&1
```

#### Решение 2:
Создание workflow в n8n для автоматического резервного копирования
Это элегантное решение, использующее возможности уже имеющегося в вашей системе n8n:

В n8n создайте новый workflow "System Backup"
Добавьте узел "Schedule" (расписание) и настройте желаемую периодичность выполнения
Добавьте узел "Execute Command" со следующей конфигурацией:
```
Command: bash
Arguments: -c, cd /data && ../scripts/backup.sh >> /data/logs/backup.log 2>&1
```
Не забудьте активировать workflow после создания