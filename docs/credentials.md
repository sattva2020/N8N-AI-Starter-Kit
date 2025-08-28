# Управление учетными данными (credentials) в N8N

Этот документ описывает использование `scripts/create_n8n_credential.sh` для создания учетных данных (credential) в n8n через REST API, включая массовое создание из CSV/JSON (`--bulk-file`) и пример шаблона CSV.

## Быстрый обзор

- Скрипт: `scripts/create_n8n_credential.sh`
- Требуется: admin token n8n (через `N8N_ADMIN_TOKEN` в `.env` или флаг `--token`)
- Поддерживает: одиночное создание, массовое создание (`--bulk-file`), `--dry-run`, `--force`

## Создание токенов для API n8n

В n8n есть два способа авторизации для автоматизации:

- Personal Access Token (PAT) — используется как Bearer-токен для приватного REST API (`/rest/...`).
- Public API Key — используется в заголовке `X-N8N-API-KEY` для публичного API (`/api/v1/...`, требуется включить Public API).

### Как создать N8N_ADMIN_TOKEN (PAT, Bearer для /rest)

1) Войдите в n8n под администратором.
2) Откройте: Settings → Security → Personal access tokens.
3) Нажмите New token, задайте имя (например, `automation`), выберите Full access, создайте и скопируйте токен (показывается один раз).
4) Сохраните токен безопасно. Для удобства можно добавить в `.env`:

```
N8N_ADMIN_TOKEN=<ВАШ_PAT>
```

5) Проверка доступа:

```bash
curl -sS -H "Authorization: Bearer <ВАШ_PAT>" \
	https://n8n.<ваш-домен>/rest/credentials | jq '.[].name'
```

6) Использование со скриптом:

```bash
./scripts/create_n8n_credential.sh \
	--token "<ВАШ_PAT>" \
	--name "Qdrant API" \
	--type qdrantApi \
	--n8n-url https://n8n.<ваш-домен>
```

Примечания:
- PAT стабилен для автоматизаций. JWT из переменной `N8N_ADMIN_TOKEN`, выданный системой при первом запуске, может иметь срок действия — для CI лучше использовать PAT.

### Как создать N8N_API_KEY (Public API, X-N8N-API-KEY для /api/v1)

1) Включите Public API в конфигурации n8n (если ещё не включён):

```
N8N_PUBLIC_API_DISABLED=false
```

Перезапустите сервис n8n:

```bash
docker compose up -d n8n
```

2) В UI n8n: Settings → API keys → Create key → скопируйте значение (это и есть `N8N_API_KEY`).

3) Сохраните ключ безопасно. Можно добавить в `.env`:

```
N8N_API_KEY=<ВАШ_API_KEY>
```

4) Проверка доступа к Public API:

```bash
curl -sS -H "X-N8N-API-KEY: <ВАШ_API_KEY>" \
	https://n8n.<ваш-домен>/api/v1/credentials | jq '.[].name'
```

5) Использование со скриптом (поддерживается `--api-key` и `api_key` в bulk):

```bash
./scripts/create_n8n_credential.sh \
	--api-key "<ВАШ_API_KEY>" \
	--name "Qdrant API" \
	--type qdrantApi \
	--n8n-url https://n8n.<ваш-домен>
```

Примечания:
- Public API должен быть включён, иначе получите 401 Unauthorized.
- Public API использует эндпоинты `/api/v1/...`; приватный REST — `/rest/...`.

## Пример использования

1) Одиночное создание (пример Qdrant):

```bash
./scripts/create_n8n_credential.sh --token "$N8N_ADMIN_TOKEN" --name "Qdrant" --type qdrantApi --n8n-url http://localhost:5678
```

2) Dry-run (проверить payload, ничего не менять):

```bash
./scripts/create_n8n_credential.sh --dry-run --token "$N8N_ADMIN_TOKEN" --name "Qdrant" --type qdrantApi
```

3) Массовое создание из JSON (рекомендуется):

```bash
./scripts/create_n8n_credential.sh --bulk-file credentials.json --token "$N8N_ADMIN_TOKEN"
```

4) Массовое создание из CSV (fallback, использовать только если JSON неудобен):

```bash
./scripts/create_n8n_credential.sh --bulk-file credentials.csv --token "$N8N_ADMIN_TOKEN"
```

## CSV шаблон

Файл CSV должен содержать заголовки: `name,type,data,token,n8n_url`

Пример `credentials.csv`:

```csv
name,type,data,token,n8n_url
Qdrant,qdrantApi,"{\"url\": \"http://qdrant:6333\", \"apiKey\": \"\"}",,
MinIO,awsS3,"{\"accessKeyId\": \"miniouser\", \"secretAccessKey\": \"miniosecret\", \"endpoint\": \"http://minio:9000\", \"region\": \"us-east-1\"}",,
```

> Примечание: поле `data` ожидает JSON-строку. Если поле `token` пустое, будет использован токен из общего окружения.

CSV — ограничения и рекомендации
- По возможности используйте JSON для `--bulk-file`: JSON полностью избавляет от проблем с экранированием и вложенными структурами.
- Если вы всё же используете CSV, соблюдайте формат: поле `data` должно быть валидной JSON-строкой, корректно экранированной. Рекомендуется генерировать CSV через скрипт/программу (например, Python csv.DictWriter) а не править вручную.
- Скрипт содержит эвристики для распространённых проблем (удаляет внешние обёртки, разворачивает двойные кавычки, нормализует CRLF→LF и пытается извлечь JSON-подстроку). Но эти эвристики — не замена корректному формату.
- Всегда выполняйте `--dry-run` перед массовым применением: это покажет, какие payload будут отправлены и позволит найти записи, у которых `data` остался строкой вместо объекта.

Тестирование и локальная разработка
- Мы добавили `pytest.ini` (в корень репозитория) чтобы исключать большие/внешние каталоги из автоматического discovery тестов на локальной машине — это важно на Windows, где некоторые путь/volumes могут быть недоступны и вызывать ошибки при сборе тестов.

## Безопасность и рекомендации

- Никогда не храните реальные секреты или `N8N_ADMIN_TOKEN` в системе контроля версий.
- Тестируйте массовые операции в staging окружении перед production.
- Используйте `--dry-run` для проверки payload перед фактическим созданием.

### Поведение флага --force и edge-cases

- `--force` — при передаче этого флага скрипт будет игнорировать некоторые ошибки валидации схем (например, если n8n не вернул схему или обязательные поля пустые). Используйте с осторожностью: `--force` может привести к созданию некорректных credential, требующих ручной правки.
- Edge-cases:
	- Пустые поля в `data`: если `data` не содержит обязательных значений (например, пустой `apiKey`), скрипт по умолчанию остановится и попросит использовать `--force` для продолжения.
	- Отсутствующий endpoint схемы: если n8n не отвечает на `/rest/credentials/schema/<type>`, скрипт выведет предупреждение и, по умолчанию, пропустит строгую валидацию (можно контролировать через `--force`).
	- Некорректный JSON в CSV `data` поле: при парсинге CSV `data` поле, если JSON некорректен, оно будет оставлено как строка и при отправке в n8n может вызвать ошибку — проверяйте вывод `--dry-run`.

Рекомендуется всегда запускать сначала `--dry-run`, затем один тестовый POST в staging перед массовым выполнением с `--bulk-file`.

## Интеграция с `start.sh`

Если в `.env` установлена переменная `N8N_AUTO_CREATE_CREDENTIALS=true`, `start.sh` попытается выполнить `./scripts/create_n8n_credential.sh` при старте (если он исполняемый). См. `README.md` для деталей.
## Раздел: Credentials (учётные данные) — ручное создание и хранение

Кратко: в этом разделе собрано оперативное руководство по тому, как вручную создать, поместить и безопасно хранить секреты/ключи/токены (далее — credentials) для сервисов в этом проекте (n8n, Ollama, LightRAG, Traefik/ACME и т.п.). Материал даёт рабочие команды и практические примеры.

### Что покрываем
- Типы credentials в проекте: переменные окружения в `.env`, Docker secrets, консольные токены для n8n, API key для Ollama/LightRAG, `acme.json` для Traefik.
- Как сгенерировать безопасные ключи и токены (примеры команд).
- Где положить ключи (рекомендации: `.env.local`, Docker secrets, HashiCorp Vault/KeyVault) и как это привязать к compose.
- Практические шаги: пример настройки credential для Ollama и LightRAG и проверка в UI n8n.

---

### Основные принципы безопасности
- Никогда не коммитьте реальные секреты в репозиторий. Для локальной работы используйте `.env.local` или аналог, добавленный в `.gitignore`.
- Для production используйте провайдер секретов (Vault, Azure KeyVault, AWS Secrets Manager) или Docker Swarm/Kubernetes secrets.
- Минимизируйте права токенов: выдавайте минимальные полномочия и короткий TTL если возможно.
- Регулярно ротация секретов и ведите журнал изменений.

---

### Быстрая генерация секретов (примеры)

1) Генерация 32‑байтового секретного ключа (hex):

```bash
openssl rand -hex 32
```

2) Генерация 32‑символьного base64 токена:

```bash
openssl rand -base64 24
```

3) Пример для создания API key в `scripts/setup.sh` (уже используется в проекте):

```bash
# сгенерировать и записать в .env, только если переменная отсутствует
export LIGHTRAG_API_KEY="$(openssl rand -hex 32)"
export TOKEN_SECRET="$(openssl rand -hex 32)"
```

---

### Где хранить credentials (рекомендации)
- Локальная разработка: `.env.local` (добавить в `.gitignore`) или `.env` в корне при явной договорённости — лучше `.env.template` в репозитории, реальные значения в `.env.local`.
- Docker Compose (локально): использовать `environment` с ссылкой на `.env` или `env_file`. Для чувствительных данных — Docker secrets (в swarm) или bind‑mount из защищённого хранилища.
- Production: управлять через секретный менеджер (Vault/KeyVault) и передавать в рантайм через интеграцию.

Пример записи в `.env.local` (не коммитить):

```
# .env.local (пример, не коммитить)
OLLAMA_DOMAIN=ollama.sattva-ai.top
LIGHTRAG_API_KEY=9f2b... (сгенерированный ключ)
TOKEN_SECRET=2a7f... (сгенерированный токен)
```

---

### Пример: вручную создать credential для Ollama и подключить в n8n

1) Убедитесь, что n8n и Ollama находятся в одной Docker‑сети (обычно это `frontend` или `backend`).
2) Внутри сервера с Docker проверьте доступность:

```bash
docker run --rm --network n8n-ai-starter-kit_backend curlimages/curl:8.5.0 -v --max-time 5 http://ollama:11434/ || true
```

Ожидаемый ответ: HTTP/1.1 200 и тело "Ollama is running".

3) В n8n UI откройте создание аккаунта/credential для Ollama и укажите:
- Base URL: `http://ollama:11434` (имя сервиса внутри Docker);
- API Key: оставить пустым, если вы не настраивали токен/прокси; если настроен — вставьте токен (в поле просто токен, n8n добавит `Authorization: Bearer <token>`).

4) Нажмите Save → Test (в UI n8n). Если тест успешен — соединение установлено.

---

### Пример: LightRAG (локальная опция)

1) Сгенерируйте секреты (на хосте):

```bash
export LIGHTRAG_API_KEY=$(openssl rand -hex 32)
export TOKEN_SECRET=$(openssl rand -hex 32)
```

2) Запишите их в `.env.local` или в защищённое хранилище. В `compose/optional-services.yml` сервис lightrag читает их как `LIGHTRAG_API_KEY` и `TOKEN_SECRET`.

3) При подключении через Traefik используйте в `.env` `LIGHRAG_DOMAIN` и не оставляйте это поле пустым (иначе Traefik может отдавать default cert). Пример:

```
LIGHRAG_DOMAIN=lightrag.example.com
LIGHTRAG_API_KEY=<сгенерированный ключ>
TOKEN_SECRET=<сгенерированный секрет>
```

---
---

### Qdrant — подключение и проверка

Qdrant используется в стеке как векторная база данных (RAG). В нашем compose‑стеке сервис доступен по внутреннему имени `qdrant` и порту `6333`. Рекомендация — использовать внутренний URL внутри Docker‑сети (не проброшенный хост‑порт) при подключении из n8n.

1) Переменная окружения (пример для `.env.local`):

```
QDRANT_URL=http://qdrant:6333
QDRANT_API_KEY=
```

Если вы включили аутентификацию API в Qdrant — заполните `QDRANT_API_KEY`. По умолчанию в локальной dev‑копии ключ не обязателен.

2) Как создать credential в n8n (GUI):
- Откройте n8n → Credentials → New → выберите Qdrant (или Generic HTTP если нет нативного). 
- В поле `Qdrant URL` укажите `http://qdrant:6333` (или `http://localhost:6333` при обращении с хоста).
- Если нужен API key, вставьте его в поле `API Key` (n8n добавит заголовок `api-key: <value>` при запросах).
- Нажмите Save → Test. Должно появиться "Connection tested successfully" (см. пример на скриншоте).

3) Быстрая проверка из хоста / контейнера:

```bash
# из хоста (если порт проброшен)
curl -sS http://127.0.0.1:6333/collections | jq .

# из другого контейнера в той же сети (рекомендуется):
docker run --rm --network n8n-ai-starter-kit_backend curlimages/curl:8.5.0 -sS http://qdrant:6333/collections | jq .
```

Если Qdrant не защищён ключом, команды вернут список коллекций (обычно пустой массив `[]` при чистой инсталляции).

4) Управление ключами и безопасность
- В продакшене рекомендуем включать API ключи и ограничивать доступ по сети (firewall, приватные VPC). Qdrant поддерживает передачу ключа через HTTP заголовок `api-key`.
- Не коммитьте `QDRANT_API_KEY` в git — храните в `.env.local` или в секретном хранилище (Vault/KeyVault). Для Swarm/Kubernetes используйте соответствующие секреты.
- Если выставляете Qdrant наружу, используйте TLS/авторизацию и ограничьте IP‑доступ.

5) Траблшутинг
- При ошибке соединения проверьте, что контейнер `qdrant` запущен (docker ps) и что имя сети совпадает с `n8n-ai-starter-kit_backend` или `frontend`.
- Проверьте логи Qdrant: `docker logs qdrant`.

---

### Traefik и certs (acme.json)
- Traefik хранит полученные ACME сертификаты в `acme.json` (в нашем стеке — volume `n8n-ai-starter-kit_traefik_letsencrypt` → `/letsencrypt/acme.json`).
- Проверка наличия cert для хоста:

```bash
docker exec -it n8n-ai-starter-kit-traefik-1 sh -c 'cat /letsencrypt/acme.json' | jq .
```

- Если сертификат не выдан, проверьте, что Traefik видит правильный router (Host правило) и что порты 80/443 доступны для HTTP‑01 challenge.

---

### Docker secrets (если вы используете Swarm/Kubernetes)
- Для Swarm: создайте секрет и ссылку на него в compose как secret. Пример создания секретов:

```bash
echo -n "${LIGHTRAG_API_KEY}" | docker secret create lightRag_api_key -
```

И в `docker-compose` укажите `secrets:` и `secret` в сервисе.

---

### Ротация и минимальные рекомендации
- Ротируйте ключи каждые 90 дней (или чаще) и планируйте автоматизированную ротацию. Для экспериментальных сервисов — минимум 180 дней.
- Ограничьте доступ к ключам: только CI/CD и администраторы у которых это необходимо.
- Логируйте операции выдачи/ротации ключей (в контролируемом журнале).

---

### Troubleshooting (быстрые проверки)
- Если n8n не подключается к Ollama: проверьте, что в UI Base URL не `localhost`, а `ollama` (имя контейнера). Проверьте доступность из сети с `curl` (см. выше).
- Если Traefik отдаёт self‑signed cert: проверьте `acme.json` и роутер Host правило; вероятно, Traefik не видит SNI или ACME не прошёл.
- Если credential не применяются после изменения `.env`: перезапустите соответствующие контейнеры (`docker compose restart <service>`).

---

### Что добавить позже (TODO для раздела)


Если нужно, добавлю примеры изменённого `docker-compose.yml` для стабильной сетевой конфигурации и пример `README` по интеграции с Vault.

---

## Автоматическое создание credentials в n8n (API)

Для автоматического создания credential в n8n можно использовать REST API. Скрипт‑пример добавлен в `scripts/create_n8n_credential.sh`.

Пример ручного вызова (curl) для Qdrant credential (adapt для вашего n8n URL / token):

```bash
N8N_URL="http://localhost:5678"
AUTH_TOKEN="<YOUR_N8N_ADMIN_TOKEN>"

curl -sS -X POST "$N8N_URL/rest/credentials" \
	-H "Authorization: Bearer $AUTH_TOKEN" \
	-H "Content-Type: application/json" \
	-d '{
		"name": "QdrantApi account",
		"type": "qdrantApi",
		"nodesAccess": [],
		"data": {
			"apiKey": "",
			"url": "http://qdrant:6333"
		}
	}' | jq .
```

Использование скрипта:

```bash
./scripts/create_n8n_credential.sh --token "<YOUR_N8N_ADMIN_TOKEN>" \
	--name "QdrantApi account" --type qdrantApi \
	--data '{"apiKey":"","url":"http://qdrant:6333"}' --n8n-url http://localhost:5678
```

Примечание: формат поля `type` должен соответствовать internal type в вашей версии n8n; если сомневаетесь, создайте credential вручную в UI и посмотрите структуру через API.

---

### Как получить admin token (PASTE_ADMIN_TOKEN_HERE)

Для автоматического создания credentials через REST API скрипт использует заголовок
Authorization: Bearer <TOKEN>. Обычно удобнее всего создать Personal Access Token
в UI n8n и потом положить его в `.env` под понятным именем (в наших примерах мы
используем `PASTE_ADMIN_TOKEN_HERE` как плейсхолдер).

Шаги (UI):
1. Войдите в n8n под учётной записью администратора.
2. Нажмите на аватар/иконку пользователя в правом верхнем углу и выберите "Settings" (Настройки).
3. Перейдите в раздел "Security" → "Personal Access Tokens" (или аналогичное название в вашей версии).
4. Нажмите "Create token" / "New token", задайте имя (например "automation-script") и опционально срок действия.
5. Скопируйте сгенерированный токен — он показывается только один раз. Это и есть значение `{PASTE_ADMIN_TOKEN_HERE}`.

Пример: поместите токен в локальный `.env.local` (не коммитите файл):

```
# .env.local (не коммитить)
N8N_ADMIN_TOKEN=PASTE_ADMIN_TOKEN_HERE
N8N_URL=http://localhost:5678
```

После этого можно вызывать скрипт так:

```bash
./scripts/create_n8n_credential.sh --env-file .env.local --bulk-file data/credentials-bulk.json
```

Если у вашей версии n8n нет GUI для Personal Access Tokens, или вы управляете пользователями
через внешний провайдер, альтернативный путь — создать временного администратора в UI и
получить токен через функционал вашей инсталляции (в некоторых установках поддерживается
создание токена через API/CLI). Всегда храните токены в защищённом месте и не вставляйте их
в публичные репозитории.

## После установки: как получить admin token и применить bulk‑credentials

Если вы только что выполнили `scripts/setup.sh` и запустили стек (`docker compose up -d` или `./start.sh`), n8n может потребовать время до полной готовности UI.
Чтобы корректно выполнить массовое создание credential, выполните эти шаги после того, как n8n UI станет доступен:

1) Запустите n8n и дождитесь готовности UI. Примеры:

```bash
# из корня репозитория
docker compose up -d
# или
./start.sh
```

2) В n8n UI создайте Personal/Admin token (Settings → Security → Personal Access Tokens) и сохраните его безопасно.

3) Выполните dry-run для проверки payload'ов (не изменяет состояние n8n):

```bash
./scripts/create_n8n_credential.sh --dry-run --token "<YOUR_N8N_ADMIN_TOKEN>" \
	--bulk-file config/samples/credentials-bulk.json --n8n-url http://localhost:5678
```

4) Если dry-run прошёл успешно, примените создание credential (выполнит реальные POST‑запросы):

```bash
./scripts/create_n8n_credential.sh --token "<YOUR_N8N_ADMIN_TOKEN>" \
	--bulk-file config/samples/credentials-bulk.json --n8n-url http://localhost:5678
```

Альтернативно в CI или скриптах можно экспортировать токен и запускать без интерактивности, например:

```bash
export N8N_ADMIN_TOKEN="<YOUR_N8N_ADMIN_TOKEN>" \
	&& ./scripts/create_n8n_credential.sh --dry-run --bulk-file config/samples/credentials-bulk.json --n8n-url http://localhost:5678
```

Просмотрите вывод `--dry-run` и убедитесь, что payload'ы корректны, прежде чем выполнять реальный импорт.

Если n8n ещё не доступен из CI-пайплайна (например, запускается в compose на том же runner), добавьте wait/poll шаг перед выполнением dry-run.

Безопасность: никогда не логируйте или не коммитьте admin token; используйте защищённые переменные CI/CD или менеджер секретов.
