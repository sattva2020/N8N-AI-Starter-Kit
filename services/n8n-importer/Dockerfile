# Dockerfile для N8N Workflows Auto-Importer v1.2.0
FROM python:3-alpine3.22

# Используем зеркало, так как основной репозиторий недоступен
# Замените dl-2.alpinelinux.org на другое зеркало (например, dl-3.alpinelinux.org), если это зеркало тоже недоступно
RUN sed -i 's/dl-cdn.alpinelinux.org/dl-2.alpinelinux.org/g' /etc/apk/repositories

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
