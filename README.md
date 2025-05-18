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

📂 N8N-AI-Starter-Kit
 ┣ 📂 compose
 ┃ ┣ 📄 zep-compose.yaml    # Переместить сюда
 ┃ ┣ 📄 supabase-compose.yml # Переместить сюда
 ┃ ┗ 📄 optional-services.yml # Создать для опциональных сервисов
 ┣ 📂 config
 ┃ ┣ 📄 zep.yaml           # Перемеcтить сюда
 ┃ ┣ 📄 traefik.yml        # Конфигурация для Traefik
 ┃ ┗ 📄 ollama-models.txt  # Список моделей для автозагрузки
 ┣ 📂 scripts
 ┃ ┣ 📄 setup.sh           # Скрипт для автоматической настройки
 ┃ ┣ 📄 backup.sh          # Скрипт для резервного копирования данных
 ┃ ┗ 📄 update.sh          # Скрипт для обновления компонентов


# Установка

## Установка необходимых пакетов
```bash
sudo apt update
sudo apt install -y ca-certificates curl git gnupg
```
## Добавление официального GPG-ключа Docker
```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

## Настройка репозитория Docker
```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list
```

## Установка Docker
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Добавление текущего пользователя в группу 'docker', чтобы избежать использования 'sudo' с командами docker
```bash
newgrp docker
sudo usermod -aG docker $USER
```

** Активация изменений членства в группе 'docker' для текущей сессии терминала.
** Это позволяет сразу выполнять команды docker без sudo в этой сессии.
** Для применения изменений во всех новых сессиях может потребоваться перезапуск терминала или полный выход/вход в систему.


## Проверка установки
```bash
docker --version
docker compose version
```

### Клонирование репозитория

```bash
git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git
cd N8N-AI-Starter-Kit
```

### Настройка файла `.env`

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

##### Для пользователей Mac, запускающих OLLAMA локально (НЕ в Docker)

Если вы запускаете OLLAMA локально на вашем Mac (не в Docker-контейнере этого проекта), вам необходимо изменить переменную окружения `OLLAMA_HOST`
в конфигурации сервиса n8n. Обновите секцию `x-n8n` в вашем файле Docker Compose следующим образом:

```yaml
x-n8n: &service-n8n
  # ... другие конфигурации ...
  environment:
    # ... другие переменные окружения ...
    - OLLAMA_HOST=host.docker.internal:11434 # Позволяет контейнеру n8n обращаться к Ollama на хосте Mac
```

Кроме того, после того как вы увидите "Editor is now accessible via: <http://localhost:5678/>":

1.  Перейдите по адресу <http://localhost:5678/credentials> (или `https://n8n.ваш-домен.com/credentials`, если настроен Traefik)
2.  Нажмите на "Local Ollama service"
3.  Измените базовый URL на `http://host.docker.internal:11434/`

##### Для стандартной конфигурации (OLLAMA в Docker, включая профили CPU, GPU Nvidia, GPU AMD)

В стандартной конфигурации, когда Ollama запускается как Docker-контейнер в рамках этого проекта, сервис n8n уже настроен для подключения к Ollama по адресу `http://ollama:11434`.
Переменная окружения `OLLAMA_HOST` в `docker-compose.yml` для `x-n8n` должна выглядеть так (это значение по умолчанию в `.env.example` и используется, если не переопределено для сценария с Mac):

```yaml
# Пример из docker-compose.yml (через .env файл)
# OLLAMA_HOST=ollama:11434
```

Убедитесь, что в ваших учетных данных "Local Ollama service" в n8n (доступных по адресу <http://localhost:5678/credentials> или `https://n8n.ваш-домен.com/credentials`) базовый URL установлен на:

`http://ollama:11434`

Если вы импортировали демонстрационные данные, эти учетные данные уже должны быть настроены правильно для этого сценария.

#### Для всех остальных (CPU)

```bash
docker compose --profile cpu up -d --build
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


# Добавление возможности автоматического резервного копирования по расписанию

Решение 1: Использование cron на хост-системе
Это самый простой способ, если у вас есть доступ к настройке cron-задач на хост-машине
# Откройте редактор crontab
crontab -e

# Добавьте строку для ежедневного резервного копирования в 2:00 ночи
0 2 * * * cd /путь/к/n8n-ai-starter-kit && ./scripts/backup.sh >> /путь/к/n8n-ai-starter-kit/logs/backup.log 2>&1

# Для еженедельного резервного копирования по воскресеньям в 3:00 ночи
0 3 * * 0 cd /путь/к/n8n-ai-starter-kit && ./scripts/backup.sh >> /путь/к/n8n-ai-starter-kit/logs/backup.log 2>&1

Решение 2: Создание workflow в n8n для автоматического резервного копирования
Это элегантное решение, использующее возможности уже имеющегося в вашей системе n8n:

В n8n создайте новый workflow "System Backup"
Добавьте узел "Schedule" (расписание) и настройте желаемую периодичность выполнения
Добавьте узел "Execute Command" со следующей конфигурацией:
Command: bash
Arguments: -c, cd /data && ../scripts/backup.sh >> /data/logs/backup.log 2>&1
Не забудьте активировать workflow после создания