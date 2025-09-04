# Протокол тестирования в среде Production

Дата: 2025-09-01
Проект: N8N AI Starter Kit
Версия/ветка: test/v1.0-2025-09-01
Ответст## 12. Security checks (non-intrusive)

- Проверить открытые порты на хосте `ss -tuln` или `docker port`.
- Убедиться, что Traefik защищён (admin-auth/basic auth для дашборда) и что реальные секреты не закоммичены.

## 13. Load / performance sanity (опционально)

- Небольшая нагрузка на n8n (10 concurrent requests × 1 minute) для sanity.

## 14. Фикс проблем с Traefik dynamic YAML (CRLF и нормализация)

### Проблема

- Traefik file-provider может не регистрировать middlewares из-за CRLF (Windows-style line endings) в dynamic YAML файлах.
- Симптомы: роутеры Docker создаются, но остаются disabled с ошибками "middleware 'X@file' does not exist".

### Диагностика

- Проверить hex-дамп файлов: `od -An -t x1 -c /opt/N8N-AI-Starter-Kit/config/traefik/dynamic/*.yml`
- Искать CRLF (0x0d 0x0a) — они выглядят как "\r \n" в выводе.

### Решение

- Нормализовать line endings: `sed -i 's/\r$//' /opt/N8N-AI-Starter-Kit/config/traefik/dynamic/*.yml`
- Пересоздать Traefik: `docker compose up -d --no-deps --force-recreate traefik`
- Проверить API: `curl -sS http://127.0.0.1:8080/api/http/middlewares` — должны появиться file-provided middlewares.
- Проверить роутеры: `curl -sS http://127.0.0.1:8080/api/http/routers` — n8n роутеры должны стать enabled.

### Безопасное хранение htpasswd

- Не хранить plain пароль в .env или репо.
- Лучше: сгенерировать bcrypt-строку (например, `htpasswd -nbB admin 'password'`) и поместить в middlewares.yml.
- Идеально: хранить в файле на сервере (например, /run/secrets/traefik-admin-auth), монтировать в контейнер и ссылаться как `file: /run/secrets/traefik-admin-auth`.
- Не коммитить реальные секреты; использовать placeholders в репо.

## 15. Проверки TLS и сертификатов

### Внешняя проверка

- `curl -I -v https://n8n.${DOMAIN_NAME}` — должен вернуть 200 OK с заголовками безопасности.
- `curl -v https://n8n.${DOMAIN_NAME}/` — проверить тело ответа (n8n UI).
- `openssl s_client -connect n8n.${DOMAIN_NAME}:443 -servername n8n.${DOMAIN_NAME} -showcerts` — проверить цепочку Let's Encrypt.

### Критерии успеха

- HTTP 200, валидный TLS (Let's Encrypt), заголовки HSTS/X-Frame-Options и т.д.
- Сертификат не истёк, CN=n8n.${DOMAIN_NAME}.

## 16. Удаление debug-флагов (production cleanup)

- Убрать `--api.insecure=true` из docker-compose.override.yml (если добавлен для диагностики).
- Пересоздать Traefik: `docker compose up -d --no-deps --force-recreate traefik`.
- Проверить, что API не доступен извне без аутентификации.оператор/DevOps, QA, разработчик

Для выполнения теста: подключитесь к удалённому VDS, склонируйте ветку `test/v1.0-2025-09-01` и дайте права на скрипты. Для тестирования используйте основной домен `sattva-ai.top`.

Примечание: `ACME_EMAIL` — адрес, используемый Traefik/ACME (Let's Encrypt) для управления сертификатами: `ruslan.griban@gmail.com`. Контактный email для уведомлений и ответственных операций задаётся отдельно через переменную в `.env` — `TEST_CONTACT` (например `TEST_CONTACT=ruslan.griban@gmail.com`).

Пример однострочной команды (Windows PowerShell) — выполнит SSH-подключение к ноде, перейдёт в каталог и склонирует репозиторий, установит права на скрипты. Команда запускается без запроса подтверждений (StrictHostKeyChecking отключён):

```powershell
ssh -i "C:\Users\Admin\.ssh\id_rsa_n8n" -o StrictHostKeyChecking=no root@37.53.91.144 "cd /opt && mkdir -p N8N-AI-Starter-Kit && cd N8N-AI-Starter-Kit && git clone -b test/v1.0-2025-09-01 https://github.com/sattva2020/N8N-AI-Starter-Kit.git . && chmod +x scripts/*.sh && chmod +x *.sh"
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

В репозитории используются профили: `default`, `cpu`, `gpu`. Есть отдельный профиль `developer` для dev-only сервисов (`compose/optional-services.yml`).

Рекомендуемый порядок тестирования (production-facing): `default` → `cpu` → `gpu`.
Запуск `developer` — отдельно, только для локальной разработки или интеграционных проверок.

## Чеклист тестирования

### 1. Предварительные условия (проверить перед запуском)

- [ ] Доступы, резервные копии, доступ к monitoring/traefik консоли, подготовленный `template.env`.

### 2. Бэкап и подготовка

- [ ] Сделать snapshot/backup docker volumes и важнейших БД (Postgres, Grafana DB, Qdrant snapshots).
- [ ] Проверить доступность backup-файлов и зафиксировать их хеши.

### 3. Генерация `.env` и валидация переменных

Команды (локально на операторе):

```bash
./scripts/setup.sh --generate-only
./scripts/setup.sh --generate-only --force-regenerate
```

Проверить, что `.env` создан и содержит:

- `POSTGRES_PASSWORD`, `N8N_ENCRYPTION_KEY`, `N8N_API_KEY`, `TRAEFIK_PASSWORD_HASHED`
- `LIGHTRAG_API_KEY` и `TOKEN_SECRET` — обязательны

Ожидаемый результат: все перечисленные переменные непустые.

### 4. Развёртывание стека (минимальный профиль)

```bash
docker compose --profile default up -d
```

Проверки:

- `docker ps` — все контейнеры запущены (статусы `healthy` по возможности)
- Просмотреть логи Traefik, Postgres, n8n: `docker logs -f <container>`

### 5. Проверка Traefik и HTTPS

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

### 6. Проверка n8n (UI и Public API)

- Открыть UI: <https://n8n.${DOMAIN_NAME}>
- Проверить аутентификацию администратора (если включена) и Admin PAT.
- Тест REST API: создать workflow через API и выполнить его.
- Импорт credentials (bulk и single) — примеры зависят от вашей реализации (см. `scripts/create_n8n_credential.sh`).

### 7. Тест RAG-пайплайна (LightRAG → Qdrant → Ollama)

Простейшая проверка: запрос к LightRAG с коротким вопросом и проверка ответа через Qdrant.

```bash
curl -s -X POST "http://lightrag.${DOMAIN_NAME}:9621/query" \
  -H "Authorization: Bearer ${LIGHTRAG_API_KEY}" \
  -d '''{"query":"What is n8n?","top_k":3}'''
```

### 8. Проверка хранения и сетевых соединений

```bash
docker exec -it $(docker ps -qf "name=postgres") psql -U n8n -d n8n -c "SELECT 1;"
```

### 9. Мониторинг и метрики

- Убедиться, что Prometheus собирает метрики и Grafana дашборды доступны.
- Проверить Prometheus targets: `http://prometheus:9090/targets`

### 10. Логирование и трассировка

- Проверить логи ошибок в последние 5–10 минут для ключевых компонентов (Traefik, n8n, Postgres, LightRAG).

### 11. Отказоустойчивость и откат (rollback)

- Проверить сценарий восстановления из бэкапа в staging: останов, восстановление томов, поднятие стека, smoke tests.

### 12. Security checks (non-intrusive)

- Проверить открытые порты на хосте `ss -tuln` или `docker port`.
- Убедиться, что Traefik защищён (admin-auth/basic auth для дашборда) и что реальные секреты не закоммичены.

### 14. Load / performance sanity (опционально)

- Небольшая нагрузка на n8n (10 concurrent requests × 1 minute) для sanity.

## Примеры команд для быстрой проверки

```bash
./scripts/setup.sh --generate-only --force-regenerate
docker compose up -d
docker ps --format '''{{.Names}}: {{.Status}}'''
curl -s -o /dev/null -w "%{http_code}\n" https://n8n.${DOMAIN_NAME}/
```

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

## Runbook (план отката)

1. Переключить трафик на страницу maintenance через Traefik.
2. Собрать логи: `docker logs --tail 200 <container>`.
3. Остановить стек, восстановить тома из backup, поднять стек, выполнить smoke tests.
4. Уведомить SRE/DBA/Dev и начать postmortem.

## Артефакты тестирования

- Логи ключевых контейнеров.
- Редактируемый архив с redacted `.env` (шаблон `template.env` + сгенерированная `.env` с redaction).
- Результаты smoke tests (pass/fail) и время выполнения.

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

## Как вносить правки и деплоить в тестовую ветку

Краткая инструкция для разработчиков/операторов: как безопасно внести правки локально в VS Code, отправить их в тестовую ветку и применить на VDS.

### 1) Локально (в Windows PowerShell / VS Code)

```powershell
# Надёжный порядок действий (работает если у вас уже есть локальный репозиторий):
git fetch origin
git switch test/v1.0-2025-09-01 || git switch -c test/v1.0-2025-09-01 origin/test/v1.0-2025-09-01

# Или, если ветка создаётся впервые локально:
# git switch -c test/v1.0-2025-09-01

# Внести изменения в файлы (VS Code)
git add <изменённые_файлы>
git commit -m "fix(test): короткое описание изменений"
git push -u origin test/v1.0-2025-09-01
```

Примечания:

- Перед коммитом запускайте локальные pre-commit hooks (они выполняются автоматически при commit).
- Запускайте проектные линтеры/проверки по необходимости (например, `ruff check`, `mypy` или тесты) — это ускорит приёмку изменений.
- Никогда не коммитьте реальные секреты или `.env`; используйте `template.env` и создавайте redacted‑артефакты для отчётов.

Дополнительные рекомендации по безопасному workflow:

- Перед изменениями на VDS проверьте состояние рабочей копии: `git status --porcelain`. Если есть незакоммиченные изменения — сохраните их (`git stash`) или создайте патч.
- Избегайте автоматического `git reset --hard` на прод‑подобной ноде без проверки — этот шаг удаляет локальные незакоммиченные изменения. В документе ниже показан контролируемый пример использования `reset`.

Важно: после внесения изменений в `config/traefik/dynamic/` всегда проверить синтаксис YAML (например, `yamllint` или `python -c "import yaml,sys;yaml.safe_load(sys.stdin)" < file.yml`) и затем перезапустить Traefik. После перезапуска убедитесь, что runtime API Traefik возвращает routers:

```bash
curl -sS -w "HTTP_CODE:%{http_code}\n" http://127.0.0.1:8080/api/http/routers
```

Если API возвращает HTTP 404 — проверьте логи Traefik (`docker logs --tail 200 traefik`) и корректность файлов в `config/traefik/dynamic/`.

### 2) На удалённой машине (VDS)

Подключитесь к VDS и выполните обновление репозитория и развёртывание из ветки `test/v1.0-2025-09-01`.

`Пример (локально, PowerShell, используя plink/ssh):`

```powershell
# Windows-only: `plink.exe` пример. `echo y | plink.exe` автоматически подтверждает hostkey — это удобно для автоматизации
# но менее безопасно; предпочтительнее заранее добавить хост в known_hosts.
echo y | plink.exe -i "C:\Users\Admin\Documents\ssh_private.ppk" root@37.53.91.144 "cd /opt/N8N-AI-Starter-Kit && git fetch origin && git switch test/v1.0-2025-09-01 || git switch -c test/v1.0-2025-09-01 origin/test/v1.0-2025-09-01; git status --porcelain; # проверьте состояние перед reset && git reset --hard origin/test/v1.0-2025-09-01 && docker compose --profile default up -d --remove-orphans && docker compose --profile default restart traefik"
```

На VDS можно выполнить эквивалентные команды вручную (bash). Рекомендуется перед `reset --hard` проверить отсутствие незакоммиченных изменений и при необходимости сделать `git stash`:

```bash
cd /opt/N8N-AI-Starter-Kit
git fetch origin
# Попробовать переключиться на ветку; если её нет — создать из origin
git switch test/v1.0-2025-09-01 || git switch -c test/v1.0-2025-09-01 origin/test/v1.0-2025-09-01

# Проверить незакоммиченные изменения
git status --porcelain
# При необходимости: git stash save "work-before-deploy"

# Контролируемый reset (только если вы уверены):
git reset --hard origin/test/v1.0-2025-09-01

# Преддеплой‑чеки на ноде: свободное место и состояние Docker
df -h
docker info --format '''{{.ServerVersion}} ({{.NCPU}} CPU, {{.MemTotal}} bytes)'''

# Поднять/обновить сервисы (Traefik и остальные)
docker compose --profile default up -d --remove-orphans
docker compose --profile default restart traefik

# Проверка, что Traefik зарегистрировал routers (ожидается HTTP/200 с JSON):
# Ожидаемый результат: HTTP 200 и список маршрутов; HTTP 404 означает, что провайдер не зарегистрировал routers
curl -sS -w "HTTP_CODE:%{http_code}\n" http://127.0.0.1:8080/api/http/routers | sed -n '''1,200p''' || true
```

### 3) Проверки после deploy

- Убедиться, что Traefik runtime API возвращает список routers и services.
  - Команда: `curl -sS -w "HTTP_CODE:%{http_code}\n" http://127.0.0.1:8080/api/http/routers`
  - Ожидаемый результат: HTTP 200 и JSON‑список routers. Если возвращается HTTP 404 — провайдер (docker/file) не зарегистрировал маршруты; см. логи Traefik (`docker logs --tail 200 traefik`).
- Проверить HTTPS/ACME и доступность сервисов: `curl -vk https://n8n.${DOMAIN_NAME}`.
- Выполнить локальные smoke-checks (см. разделы выше).

Если что-то пошло не так — соберите логи (`docker logs --tail 200 <container>`) и откатитесь к предыдущему рабочему коммиту или восстановите тома из бэкапа.
