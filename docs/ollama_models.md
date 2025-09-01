# Ollama — управление моделями (pull / list / remove)

Этот документ описывает, как вручную добавлять модели в Ollama, как просмотреть список уже загруженных моделей, как удалять модели, и даёт безопасные примеры команд для использования в Docker Compose окружении проекта.

Файлы и пути в стеке:
- Конфиг моделей: `config/ollama-models.txt` — список, который использует сервис `ollama-pull`.
- Директория данных Ollama в контейнере: `/root/.ollama` (см. том `ollama_data` в `docker-compose`).

Рекомендуемый быстрый поток (safe):
1. Отредактировать `config/ollama-models.txt` — оставить нужные модели (по одной на строке).
2. Запустить helper‑задачу, которая аккуратно загрузит все модели из файла:

```bash
docker compose -f docker-compose.yml -f compose/ollama-compose.yml run --rm ollama-pull
```

Этот контейнер дождётся готовности сервиса Ollama и пошлёт POST запросы к `http://ollama:11434/api/pull` для каждой модели из `config/ollama-models.txt`.

Если вы предпочитаете команды вручную — ниже три способа: HTTP API, CLI внутри контейнера и helper через docker compose.

---

1) HTTP API (удобно из скриптов CI / удалённо)

- Pull (загрузить модель):

```bash
curl -sS -X POST http://localhost:11434/api/pull \
  -H 'Content-Type: application/json' \
  -d '{"name":"phi4:14b"}'
```

Примечание: если вы вызываете изнутри Docker-сети (например, с другого контейнера в том же стеке), используйте `http://ollama:11434` вместо `localhost`.

- Список загруженных моделей (JSON):

```bash
curl -sS http://localhost:11434/v1/models | jq .
```

Ответ обычно содержит массив с моделями и их идентификаторами/статусом.

- Проверка конкретной модели (поиск по id):

```bash
curl -sS http://localhost:11434/v1/models | jq -r '.data[]?.id'
```

2) CLI внутри контейнера (интерактивно, надёжно)

Команды ниже предполагают, что контейнер называется `ollama` (см. `compose/ollama-compose.yml`).

- Pull (загрузить модель):

```bash
docker exec -it ollama ollama pull phi4:14b
```

- Список локальных моделей (CLI):

```bash
docker exec -it ollama ollama ls
# или (если версия CLI использует другое имя)
docker exec -it ollama ollama list
```

- Удаление модели (CLI):

```bash
docker exec -it ollama ollama rm phi4:14b
```

Если у вашей версии CLI команды отличаются (`list` vs `ls`) — используйте автокомплит/`--help`: `docker exec -it ollama ollama --help`.

3) Helper via docker-compose (batch from file)

```bash
docker compose -f docker-compose.yml -f compose/ollama-compose.yml run --rm ollama-pull
```

Этот способ — предпочтительный для CI/повторяемых развёртываний: он читает `config/ollama-models.txt`, ожидает готовности Ollama и пост‑запросами инициирует загрузку.

---

Просмотр файлов модели на диске

Чтобы убедиться, что модель физически загружена, можно посмотреть содержимое тома:

```bash
docker exec -it ollama ls -lah /root/.ollama
docker exec -it ollama ls -lah /root/.ollama/models || true
```

Удобно также смотреть логи загрузки (ollama-pull выводит логи в `logs/ollama` при монтировании):

```bash
docker compose -f docker-compose.yml -f compose/ollama-compose.yml run --rm ollama-pull
# или смотреть логи сервиса ollama
docker logs -f ollama
```

Удаление модели вручную (если CLI/HTTP не подходят)

Если что-то пошло не так и нужно удалить данные модели с диска, можно удалить каталоги в томе (ОСТОРОЖНО — это необратимо):

```bash
docker exec -it ollama bash -c 'rm -rf /root/.ollama/models/phi4:14b || true'
# затем при необходимости перезапустить контейнер
docker restart ollama
```

Используйте этот способ только если вы понимаете последствия и у вас есть резервная копия тома.

---

Практические советы

- Держите в `config/ollama-models.txt` только те модели, которые реально используете; хранение большого числа моделей быстро занимает дисковое пространство.
- Для тестирования и сравнения моделей используйте небольшой набор тест‑промптов и измеряйте latency с помощью `curl` или простых скриптов.
- Если у вас ограниченная VRAM, сначала пробуйте более лёгкие модели (phi4:14b), затем переходите к тяжёлым (bge-m3) если ресурсы позволяют.
- Всегда проверяйте логи `docker logs ollama` и выход `curl http://localhost:11434/v1/models` после запроса pull — сервис подтверждает регистрацию модели в API.

---

Примеры на основе вашего `config/ollama-models.txt`

- Оставить только `phi4:14b` (быстрый, экономный):

```bash
sed -i 's/^bge-m3:latest/# &/' config/ollama-models.txt
docker compose -f docker-compose.yml -f compose/ollama-compose.yml run --rm ollama-pull
```

- Восстановить обе модели (убрать #):

```bash
sed -i 's/^# \(phi4:14b\|bge-m3:latest\)/\1/' config/ollama-models.txt
docker compose -f docker-compose.yml -f compose/ollama-compose.yml run --rm ollama-pull
```

---

Если хотите, могу: 1) добавить ссылку на этот документ в `README.md` (или уже добавить — скажите), 2) выполнить `docker compose run --rm ollama-pull` здесь для вас (требуется разрешение на выполнение команд), или 3) автоматически запустить проверку `curl http://localhost:11434/v1/models` и показать текущее состояние моделей.
