# Протокол тестирования в среде Production

Дата: 2025-09-01
Проект: N8N AI Starter Kit
Версия/ветка: test2
Ответственные: оператор/DevOps, QA, разработчик

Для выполнения теста: подключитесь к удалённому VDS, склонируйте ветку `test2` и дайте права на скрипты. Для тестирования используйте основной домен `sattva-ai.top`, контактный email: `ruslan.griban@gmail.com`.

Пример однострочной команды (Windows PowerShell) — выполнит SSH-подключение к ноде, перейдёт в каталог и склонирует репозиторий, установит права на скрипты. Команда запускается без запроса подтверждений (StrictHostKeyChecking отключён):

```powershell
ssh -i "C:\Users\Admin\.ssh\id_rsa_n8n" -o StrictHostKeyChecking=no root@37.53.91.144 "cd /opt && mkdir -p N8N-AI-Starter-Kit && cd N8N-AI-Starter-Kit && git clone -b test2 https://github.com/sattva2020/N8N-AI-Starter-Kit.git . && chmod +x scripts/*.sh && chmod +x *.sh"
```

Примечания:

- Используется ключ `C:\Users\Admin\.ssh\id_rsa_n8n` (поменяйте путь при необходимости).
- Домены/почта для теста: `DOMAIN_NAME=sattva-ai.top`, `TEST_CONTACT=ruslan.griban@gmail.com`.
- Команда предназначена для автоматического выполнения и не запрашивает подтверждения; при необходимости адаптируйте опции SSH для вашей среды.

## Краткая цель

Верифицировать корректность развёртывания production-подобного стека: доступность, TLS, интеграции (n8n, Qdrant, LightRAG/OLLAMA), автогенерация секретов, импорт n8n, мониторинг и план отката.

## Область покрытия

- Traefik, Postgres, n8n, Qdrant, LightRAG/OLLAMA, Grafana, Prometheus и сопутствующие компоненты.
- Генерация и валидация `.env` (см. `scripts/setup.sh`).
- Проверки TLS/ACME, middlewares Traefik и базовые интеграционные проверки n8n + RAG.

## Профили Docker Compose

В репозитории используются профили: `default`, `cpu`, `gpu-nvidia`. Есть отдельный профиль `developer` для dev-only сервисов (`compose/optional-services.yml`).

Рекомендуемый порядок тестирования (production-facing): `default` → `cpu` → `gpu-nvidia`.
Запуск `developer` — отдельно, только для локальной разработки или интеграционных проверок.

## Быстрый чеклист

1) Бэкап и подготовка

- Snapshot/backup docker volumes и ключевых БД.
- Проверка целостности backup-архивов.

2) Генерация `.env`

```powershell
./scripts/setup.sh --generate-only
./scripts/setup.sh --generate-only --force-regenerate
```

Проверить наличие: `POSTGRES_PASSWORD`, `N8N_ENCRYPTION_KEY`, `N8N_API_KEY`, `TRAEFIK_PASSWORD_HASHED`, `LIGHTRAG_API_KEY`, `TOKEN_SECRET`.

3) Поднятие стека (пример)

```bash
docker compose --profile default up -d
```

4) Smoke-checks

- Проверить статусы контейнеров (`docker ps`, health where available).
- Traefik: dynamic middlewares и ACME.
- n8n: UI/API доступ, импорт credentials, запуск workflow.
- LightRAG: отвечает на запросы и взаимодействует с Qdrant.

5) Мониторинг и логи

- Проверить Prometheus targets и Grafana.
- Собрать логи: `docker logs --tail 200 <container>`.

6) Developer profile (dev-only)

- Файл: `compose/optional-services.yml`.
- Сервисы: `lightrag`, `n8n-importer`.
- Локальный запуск импорта:

```bash
docker compose -f docker-compose.yml -f compose/optional-services.yml run --rm n8n-importer
```

Убедитесь, что `.env` содержит `LIGHTRAG_API_KEY` и `TOKEN_SECRET`, и что `QDRANT_URL` доступен.

## Критерии приёмки

- Все ключевые сервисы запущены и, по возможности, в состоянии `healthy`/`running`.
- TLS валиден и HTTPS отвечает корректно.
- `.env` содержит непустые `LIGHTRAG_API_KEY` и `TOKEN_SECRET`.
- n8n UI/API и базовый RAG-пайплайн функционируют.

## Runbook (кратко)

1. Переключить трафик на maintenance.
2. Собрать логи и метрики.
3. Остановить стек, восстановить тома из backup, поднять стек, выполнить smoke tests.
4. Уведомить ответственных и начать постмортем.

## Артефакты тестирования

- Логи ключевых контейнеров.
- Редактируемый архив с redacted `.env` (template + redacted).
- Результаты smoke tests (pass/fail) и время выполнения.

---

Сохраните этот документ как `docs/PROD_TEST_PROTOCOL.md` и используйте как источник правды.

Дата: 2025-09-01
Проект: N8N AI Starter Kit
Версия/ветка: тестовая ветка — `test2`
Ответственные: оператор/DevOps, QA-инженер, разработчик сервиса

Для выполнения теста подключитесь к тестовой ноде по SSH и подготовьте рабочую директорию как показано выше (см. команду SSH в разделе верхнего уровня). Используйте основной домен `sattva-ai.top` и контактный email `ruslan.griban@gmail.com` для настроек и уведомлений.

Если нужно повторить команду локально в PowerShell, пример однострочника приведён выше.

## Цель

Предоставить воспроизводимый, минимально рискованный протокол проверки корректности развертывания в production-подобной среде: доступность сервисов, TLS/Traefik, интеграции (n8n, Qdrant, LightRAG/OLLAMA), автогенерация секретов, импорт/аутентификация n8n, мониторинг и план отката.

## Область покрытия

- Развёртывание через Docker Compose (Traefik, Postgres, n8n, Qdrant, LightRAG, Grafana, Prometheus и т.д.).
- Проверка HTTPS/ACME и Traefik middlewares.
- Генерация `.env` (`scripts/setup.sh --generate-only`) и валидация ключевых переменных.
- Проверка импорта и работы n8n (UI/API, Admin PAT, credentials).
- Мониторинг, логирование, бэкапы и откат.

## Предварительные условия

- SSH-доступ и права запуска Docker Compose на целевой машине.
- `template.env` доступен; возможность создать `.env` через `scripts/setup.sh`.
- Наличие резервных копий томов и БД (Postgres, Grafana, Qdrant).

## Общая стратегия

1. Non-destructive smoke-test на staging или fresh node.
2. Генерация `.env` и проверка обязательных переменных.
3. Поднятие production-facing профилей по очереди и выполнение smoke-check.
4. Функциональные тесты RAG и n8n.
5. Мониторинг/приёмка; при проблемах — откат по runbook.

## Профили Docker Compose

В репозитории используются профили: `default`, `cpu`, `gpu-nvidia`. Есть отдельный профиль `developer` для dev-only сервисов (файл: `compose/optional-services.yml`).

Рекомендуемый порядок тестирования (production-facing): `default` → `cpu` → `gpu-nvidia`.
Профиль `developer` запускать отдельно и только для локальной разработки или интеграционных проверок.

## Чеклист (пошагово)

1) Бэкап и подготовка

- Сделать snapshot/backup docker volumes и ключевых БД.
- Проверить целостность backup-архивов и зафиксировать хеши.

2) Генерация `.env` и валидация

```powershell
./scripts/setup.sh --generate-only
./scripts/setup.sh --generate-only --force-regenerate
```

Проверить, что `.env` содержит: `POSTGRES_PASSWORD`, `N8N_ENCRYPTION_KEY`, `N8N_API_KEY`, `TRAEFIK_PASSWORD_HASHED`. Обязательные для RAG: `LIGHTRAG_API_KEY`, `TOKEN_SECRET`.

3) Развёртывание (пример для production-facing)

```bash
docker compose --profile default up -d
```

4) Smoke-checks (выборочно)

- Проверить, что ключевые контейнеры запущены и (по возможности) в состоянии `healthy`.
- Traefik: dynamic middlewares заданы и ACME работает (если включено).
- n8n: UI доступен, API создаёт/запускает workflow; импорт credentials работает.
- LightRAG: отвечает на простой запрос и взаимодействует с Qdrant.

Пример запроса к LightRAG:

```bash
curl -s -X POST "http://lightrag.${DOMAIN_NAME}:9621/query" \
  -H "Authorization: Bearer ${LIGHTRAG_API_KEY}" \
  -d '{"query":"What is n8n?","top_k":3}'
```

5) Мониторинг и логи

- Проверить Prometheus targets и доступность Grafana дашбордов.
- Собрать логи проблемных контейнеров: `docker logs --tail 200 <container>`.

6) Developer profile (dev-only)

- Файл: `compose/optional-services.yml`.
- Сервисы: `lightrag`, `n8n-importer`.
- Локальный запуск импорта:

```bash
docker compose -f docker-compose.yml -f compose/optional-services.yml run --rm n8n-importer
```

Убедитесь, что `.env` содержит `LIGHTRAG_API_KEY` и `TOKEN_SECRET`, и что указываемый `QDRANT_URL` доступен.

## Критерии приёмки

- Все ключевые сервисы запущены и находятся в состоянии `healthy`/`running`.
- TLS сертификаты валидны; HTTPS отвечает корректно.
- `.env` содержит непустые `LIGHTRAG_API_KEY` и `TOKEN_SECRET`.
- n8n UI/API и базовый RAG-пайплайн функционируют.

## Runbook (кратко)

1. Переключить трафик на maintenance.
2. Собрать логи и метрики.
3. Остановить стек, восстановить тома из backup, поднять стек, выполнить smoke tests.
4. Уведомить ответственных и начать постмортем.

## Артефакты тестирования

- Логи ключевых контейнеров.
- Редактируемый архив с redacted `.env` (шаблон `template.env` + сгенерированная `.env` с redaction).
- Результаты smoke tests (pass/fail) и время выполнения.

---

Сохраните этот документ как `docs/PROD_TEST_PROTOCOL.md` и используйте как источник правды.

## Предварительные условия (проверить перед запуском)

- Доступ к production-хосту (SSH) и правам запуска Docker Compose.
- Наличие `template.env` и возможность создать `.env` (скрипт `scripts/setup.sh`).
- Создана резервная копия существующих конфигураций и томов (docker volumes). Скрипт резервного копирования должен быть доступен.
- Доступ к Grafana/Prometheus/Logs/Traefik админ-модулю.
- Контактный список для экстренных ролей (SRE, DBA, разработчик).

## Общая стратегия

1. Неприсваивающий (non-destructive) smoke-test на новую ноде или staging-клоне prod данных.
2. Полная генерация `.env` в режиме `--generate-only` и верификация всех ключей (включая LightRAG).
3. Поднятие стека с минимальным профилем, здравые проверки сервисов.
4. Функциональные тесты: n8n UI/API, импорт credential, RAG pipeline test (LightRAG → Qdrant → Ollama), чтение и запись в Postgres.
5. Мониторинг/логирование проверяются; при успехе — приёмочные тесты, затем включение всех профилей.
6. При сбое — следовать runbook: откат к backup, уведомление, postmortem.

## Чеклист тестов (пошагово)

### Тестирование профилей

В репозитории используются несколько Docker Compose профилей: `default`, `cpu`, `gpu-nvidia`, а также отдельный профиль `developer` для сервисов разработки и интеграционного тестирования.
При подготовке к продакшн‑развёртыванию важно протестировать релевантные (production-facing) профили отдельно и поочерёдно, а профиль `developer` — отдельно для dev-only сервисов.

Рекомендации:

- Рекомендуемый порядок тестирования (production-facing): `default` → `cpu` → `gpu-nvidia` (по возрастанию требований к ресурсам). Профиль `developer` содержит dev-only сервисы и должен запускаться отдельно, только для разработки/интеграционных проверок.

- Для каждого профиля выполнить: генерацию `.env`, поднятие стека, базовый smoke‑check (Traefik TLS, n8n UI/API, LightRAG health / query) и сбор логов.

- Использовать таймауты ожидания (например, 120s на старт и готовность ключевых сервисов).

- Если профиль включает дополнительные сервисы (например heavy analytics), запускать их отдельно после валидации базового профиля.

Примерная последовательность для профиля `cpu`:

```bash
# 1) сгенерировать .env
./scripts/setup.sh --generate-only --force-regenerate

# 2) поднять сервисы для профиля
docker compose --profile cpu up -d

# 3) подождать готовности (проверять liveness/health и ответы HTTP)
# 4) выполнить smoke tests (n8n, LightRAG) и собрать логи при ошибках
```

Ниже находится вспомогательный скрипт `tests/smoke/run_profiles_test.sh`, который упрощает выполнение этих шагов локально или в CI.

### 1. Бэкап и подготовка

- [ ] Сделать snapshot/backup docker volumes и важнейших БД (Postgres, Grafana DB, Qdrant snapshots).
- [ ] Проверить доступность backup-файлов и зафиксировать их хеши.

### 2. Генерация `.env` и валидация переменных

- Команда: (локально на операторе)

```bash
# Генерируем .env non-interactively
./scripts/setup.sh --generate-only
# Для принудительной регенерации всех автоген-переменных
./scripts/setup.sh --generate-only --force-regenerate
```

- Проверить, что `.env` создан и содержит:
  - `POSTGRES_PASSWORD`, `N8N_ENCRYPTION_KEY`, `N8N_API_KEY`, `TRAEFIK_PASSWORD_HASHED`
  - `LIGHTRAG_API_KEY` и `TOKEN_SECRET` — обязательны
- Ожидаемый результат: все перечисленные переменные непустые.

### 3. Развёртывание стека (минимальный профиль)

- Команды (пример):

```bash
# Запуск с профилями, как в репозитории
docker compose --profile default up -d
# Либо ./start.sh если есть обёртка
./start.sh
```

- Проверки:
  - `docker ps` — все контейнеры запущены (статусы `healthy` по возможности)
  - Просмотреть логи Traefik, Postgres, n8n: `docker logs -f <container>`

### 4. Проверка Traefik и HTTPS

- Проверить, что Traefik получил и применил dynamic middlewares из `config/traefik/dynamic/`.
- Проверить получение сертификата ACME (если включено):

```bash
# Проверяем том letsencrypt и файлы
docker volume inspect traefik_letsencrypt || true
# Проверяем логи Traefik на ошибки ACME
docker logs traefik | tail -n 200
```

- Проверка HTTPS с хоста и извне:

```bash
curl -vk https://n8n.${DOMAIN_NAME}
# ожидание HTTP 200 и корректного TLS сертификата (CN/SAN соответствует)
```

- Проверка middlewares (редирект http→https, security headers)

### 5. Проверка n8n (UI и Public API)

- Открыть UI: <https://n8n.${DOMAIN_NAME}>
- Проверить аутентификацию администратора (если включена) и Admin PAT.
- Тест REST API: создать workflow через API и выполнить его.
- Импорт credentials (bulk и single):

  # Протокол тестирования в среде Production

  Дата: 2025-09-01
  Проект: N8N AI Starter Kit
  Версия/ветка: тестовая ветка, пример — `test2`
  Ответственные: оператор/DevOps, QA-инженер, разработчик сервиса

  ## Цель

  Сформировать воспроизводимый, минимально рискованный протокол проверки корректности развертывания в production-подобной среде. Протокол охватывает проверку доступности, TLS/Traefik, интеграции сервисов (n8n, Qdrant, LightRAG/OLLAMA), автогенерацию секретов, импорт/аутентификацию n8n, мониторинг и план отката.

  ## Область покрытия

  - Развёртывание стека через Docker Compose / аналог (Traefik, Postgres, n8n, Qdrant, LightRAG, Grafana, Prometheus и т.д.).
  - Проверка HTTPS/ACME, middlewares Traefik.
  - Проверка автоматической генерации .env (`scripts/setup.sh --generate-only`) и наличия LightRAG ключей.
  - Проверка импорта и работы n8n credentials & Public API / Admin PAT.
  - Мониторинг, логи, откат и резервные копии (Backups & Restore).
  - Безопасность: открытые порты, TLS, пароли, секреты.

  ## Предварительные условия (проверить перед запуском)

  - Доступ к production-хосту (SSH) и правам запуска Docker Compose.
  - Наличие `template.env` и возможность создать `.env` (скрипт `scripts/setup.sh`).
  - Создана резервная копия существующих конфигураций и томов (docker volumes). Скрипт резервного копирования должен быть доступен.
  - Доступ к Grafana/Prometheus/Logs/Traefik админ-модулю.
  - Контактный список для экстренных ролей (SRE, DBA, разработчик).

  ## Общая стратегия

  1. Неприсваивающий (non-destructive) smoke-test на новой ноде или staging-клоне prod данных.
  2. Полная генерация `.env` в режиме `--generate-only` и верификация всех ключей (включая LightRAG).
  3. Поднятие стека с минимальным профилем, базовые проверки сервисов.
  4. Функциональные тесты: n8n UI/API, импорт credential, RAG pipeline test (LightRAG → Qdrant → Ollama), чтение и запись в Postgres.
  5. Мониторинг/логирование проверяются; при успехе — приёмочные тесты, затем включение всех профилей.
  6. При сбое — следовать runbook: откат к backup, уведомление, postmortem.

  ## Чеклист тестов (пошагово)

  ### Тестирование профилей

  В репозитории используются несколько Docker Compose профилей: `default`, `cpu`, `gpu-nvidia`, а также отдельный профиль `developer` для сервисов разработки и интеграционного тестирования.
  При подготовке к продакшн‑развёртыванию важно тестировать production-facing профили отдельно и поочерёдно; профиль `developer` запускается отдельно для dev-only сервисов.

  Рекомендации:

  - Рекомендуемый порядок тестирования (production-facing): `default` → `cpu` → `gpu-nvidia` (по возрастанию требований к ресурсам). Профиль `developer` содержит dev-only сервисы и должен запускаться отдельно, только для разработки/интеграционных проверок.

  - Для каждого профиля выполнить: генерацию `.env`, поднятие стека, базовый smoke‑check (Traefik TLS, n8n UI/API, LightRAG health / query) и сбор логов.

  - Использовать таймауты ожидания (например, 120s на старт и готовность ключевых сервисов).

  - Если профиль включает дополнительные сервисы (например heavy analytics), запускать их отдельно после валидации базового профиля.

  Примерная последовательность для профиля `cpu`:

  ```bash
  ./scripts/setup.sh --generate-only --force-regenerate
  docker compose --profile cpu up -d
  # подождать готовности и выполнить smoke tests
  ```

  Ниже находится вспомогательный скрипт `tests/smoke/run_profiles_test.sh`, который упрощает выполнение этих шагов локально или в CI.

  ### 1. Бэкап и подготовка

  - [ ] Сделать snapshot/backup docker volumes и важнейших БД (Postgres, Grafana DB, Qdrant snapshots).
  - [ ] Проверить доступность backup-файлов и зафиксировать их хеши.

  ### 2. Генерация `.env` и валидация переменных

  Команды (локально на операторе):

  ```bash
  ./scripts/setup.sh --generate-only
  ./scripts/setup.sh --generate-only --force-regenerate
  ```

  Проверить, что `.env` создан и содержит:

  - `POSTGRES_PASSWORD`, `N8N_ENCRYPTION_KEY`, `N8N_API_KEY`, `TRAEFIK_PASSWORD_HASHED`
  - `LIGHTRAG_API_KEY` и `TOKEN_SECRET` — обязательны

  Ожидаемый результат: все перечисленные переменные непустые.

  ### 3. Развёртывание стека (минимальный профиль)

  ```bash
  docker compose --profile default up -d
  ```

  Проверки:

  - `docker ps` — все контейнеры запущены (статусы `healthy` по возможности)
  - Просмотреть логи Traefik, Postgres, n8n: `docker logs -f <container>`

  ### 4. Проверка Traefik и HTTPS

  - Проверить, что Traefik получил и применил dynamic middlewares из `config/traefik/dynamic/`.
  - Проверить получение сертификата ACME (если включено):

  ```bash
  docker volume inspect traefik_letsencrypt || true
  docker logs traefik | tail -n 200
  ```

  - Проверка HTTPS с хоста/извне:

  ```bash
  curl -vk https://n8n.${DOMAIN_NAME}
  ```

  ### 5. Проверка n8n (UI и Public API)

  - Открыть UI: <https://n8n.${DOMAIN_NAME}>
  - Проверить аутентификацию администратора (если включена) и Admin PAT.
  - Тест REST API: создать workflow через API и выполнить его.
  - Импорт credentials (bulk и single) — примеры зависят от вашей реализации (см. `scripts/create_n8n_credential.sh`).

  ### 6. Тест RAG-пайплайна (LightRAG → Qdrant → Ollama)

  Простейшая проверка: запрос к LightRAG с коротким вопросом и проверка ответа через Qdrant.

  ```bash
  curl -s -X POST "http://lightrag.${DOMAIN_NAME}:9621/query" \
    -H "Authorization: Bearer ${LIGHTRAG_API_KEY}" \
    -d '{"query":"What is n8n?","top_k":3}'
  ```

  ### 7. Проверка хранения и сетевых соединений

  ```bash
  docker exec -it $(docker ps -qf "name=postgres") psql -U n8n -d n8n -c "SELECT 1;"
  ```

  ### 8. Мониторинг и метрики

  - Убедиться, что Prometheus собирает метрики и Grafana дашборды доступны.
  - Проверить Prometheus targets: `http://prometheus:9090/targets`

  ### 9. Логирование и трассировка

  - Проверить логи ошибок в последние 5–10 минут для ключевых компонентов (Traefik, n8n, Postgres, LightRAG).

  ### 10. Отказоустойчивость и откат (rollback)

  - Проверить сценарий восстановления из бэкапа в staging: останов, восстановление томов, поднятие стека, smoke tests.

  ### 11. Security checks (non-intrusive)

  - Проверить открытые порты на хосте `ss -tuln` или `docker port`.
  - Убедиться, что Traefik защищён (admin-auth/basic auth для дашборда) и что реальные секреты не закоммичены.

  ### 12. Load / performance sanity (опционально)

  - Небольшая нагрузка на n8n (10 concurrent requests × 1 minute) для sanity.

  ## Критерии приёмки

  Критично (must):

  - Все сервисы стартуют и находятся в состоянии `healthy` или `running`.
  - TLS сертификаты валидны, HTTPS отвечает корректно.
  - `.env` содержит непустые `LIGHTRAG_API_KEY` и `TOKEN_SECRET`.
  - n8n UI доступен и API выполняет создание/запуск workflow.
  - Basic monitoring (Prometheus/Grafana) собирает данные.

  Желательно (should):

  - Дашборды Grafana provisioned.
  - Traefik middlewares применены (security headers, rate-limit, admin-auth).
  - Импорт credentials в n8n проходит успешно.

  Триггеры для отката: критические сервисы не запускаются >15 минут или потеря данных в Postgres.

  ## Runbook (кратко)

  1. Переключить трафик на страницу maintenance через Traefik.
  2. Собрать логи: `docker logs --tail 200 <container>`.
  3. Остановить стек, восстановить тома из backup, поднять стек, выполнить smoke tests.
  4. Уведомить SRE/DBA/Dev и начать postmortem.

  ## Предварительные условия (проверить перед запуском)

  - Доступы, резервные копии, доступ к monitoring/traefik консоли, подготовленный `template.env`.

  ## Артефакты тестирования

  - Логи ключевых контейнеров.
  - Редактируемый архив с redacted `.env` (шаблон `template.env` + сгенерированная `.env` с redaction).
  - Результаты smoke tests (pass/fail) и время выполнения.

  ## Примеры команд для быстрого запуска проверки

  ```bash
  ./scripts/setup.sh --generate-only --force-regenerate
  docker compose up -d
  docker ps --format '{{.Names}}: {{.Status}}'
  curl -s -o /dev/null -w "%{http_code}\n" https://n8n.${DOMAIN_NAME}/
  ```

  ## Developer profile (специфика и рекомендации)

  В репозитории есть дополнительный compose-фрагмент `compose/optional-services.yml`, который содержит сервисы, помеченные профилем `developer`.

  Сервисы (на момент обзора):

  - `lightrag` — сервис RAG (LightRAG). Требует: `LIGHRAG_DOMAIN`, `LIGHTRAG_API_KEY`, `TOKEN_SECRET`, и доступного `QDRANT_URL`.
  - `n8n-importer` — утилита для пакетного импорта workflow/credentials в n8n (запускается вручную, `restart: "no"`).

  Рекомендации при тестировании профиля `developer`:

  1. Убедитесь, что `.env` содержит `LIGHTRAG_API_KEY` и `TOKEN_SECRET`. При отсутствии — `./scripts/setup.sh --generate-only --force-regenerate`.
  2. LightRAG ожидает доступный Qdrant — убедитесь, что `qdrant` доступен или укажите `QDRANT_URL`.
  3. Для локального запуска `n8n-importer`:

  ```bash
  docker compose -f docker-compose.yml -f compose/optional-services.yml run --rm n8n-importer
  ```

  4. Для проброса LightRAG через Traefik заполните `LIGHRAG_DOMAIN` и проверьте `config/traefik/dynamic/`.
  5. Не коммитьте реальные секреты — используйте `template.env` и redact `.env` в артефактах.

  Использование профиля `developer` рекомендуется отдельно от production-профилей.

  ## Время выполнения и примерное расписание

  - Подготовка/backup: 15–30 минут
  - Генерация .env и развертывание: 5–15 минут
  - Smoke + функциональная проверка: 30–60 минут
  - Мониторинг и финальная приёмка: 15–30 минут
  - Итого: ~1.5–2.0 часа

  ## Ответственные и эскалации

  - Оператор/DevOps — генерация .env, развёртывание, бэкап/восстановление.
  - QA — функциональные тесты n8n, RAG и проверка UI/API.
  - SRE/DBA — восстановление данных и откат.

  ---

  Сохраните этот документ как `docs/PROD_TEST_PROTOCOL.md` и используйте как источник правды для планирования релиза.
