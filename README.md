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

## Установка

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

##### Для пользователей Mac, запускающих OLLAMA локально

Если вы запускаете OLLAMA локально на вашем Mac (не в Docker), вам необходимо изменить переменную окружения `OLLAMA_HOST`
в конфигурации сервиса n8n. Обновите секцию `x-n8n` в вашем файле Docker Compose следующим образом:

```yaml
x-n8n: &service-n8n
  # ... другие конфигурации ...
  environment:
    # ... другие переменные окружения ...
    - OLLAMA_HOST=host.docker.internal:11434
```

Кроме того, после того как вы увидите "Editor is now accessible via: <http://localhost:5678/>":

1.  Перейдите по адресу <http://localhost:5678/credentials> (или `https://n8n.ваш-домен.com/credentials`, если настроен Traefik)
2.  Нажмите на "Local Ollama service"
3.  Измените базовый URL на "http://host.docker.internal:11434/"

#### Для всех остальных (CPU)

```bash
docker compose --profile cpu up -d --build
```

## ⚡️ Быстрый старт и использование

Ядром Self-hosted AI Starter Kit является файл Docker Compose, предварительно настроенный с сетевыми параметрами и хранилищами, что минимизирует необходимость в дополнительных установках.
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
