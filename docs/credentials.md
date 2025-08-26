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
- Шаблоны для HashiCorp Vault / Azure KeyVault интеграции. 
- Примеры использования Docker secrets и Kubernetes secrets с `helm` манифестами.
- Скрипты для автоматической ротации ключей и обновления `.env`.

---

Если нужно, добавлю примеры изменённого `docker-compose.yml` для стабильной сетевой конфигурации и пример `README` по интеграции с Vault.
