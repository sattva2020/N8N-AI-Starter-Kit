# Dockerfile для N8N Workflows Auto-Importer v1.2.0
FROM python:3.11-alpine

# Устанавливаем необходимые пакеты
RUN apk add --no-cache curl jq bash

# Устанавливаем Python зависимости
RUN pip install --no-cache-dir requests

# Создаем рабочую директорию
WORKDIR /app

# Копируем Python скрипт импорта
COPY services/n8n-importer/import-workflows.py /app/import-workflows.py

# Делаем скрипт исполняемым
RUN chmod +x /app/import-workflows.py

# Точка входа
ENTRYPOINT ["python3", "/app/import-workflows.py"]
