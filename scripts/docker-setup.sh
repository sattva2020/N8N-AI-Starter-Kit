# Сначала только базовые сервисы
COMPOSE_PARALLEL_LIMIT=1 docker compose --profile minimal up -d
# Затем остальные
COMPOSE_PARALLEL_LIMIT=1 docker compose --profile cpu up -d