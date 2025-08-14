FROM python:3.11-alpine

# Установка зависимостей
RUN apk add --no-cache \
  git \
  curl \
  && rm -rf /var/cache/apk/*

# Создание рабочей директории
WORKDIR /app

# Копирование requirements
COPY services/workflows-importer/requirements.txt .

# Установка Python зависимостей
RUN pip install --no-cache-dir -r requirements.txt

# Копирование исходного кода
COPY services/workflows-importer/ .

# Создание директорий для workflows
RUN mkdir -p /workflows /credentials

# Установка прав на выполнение
RUN chmod +x /app/import-workflows.py

# Переменные окружения по умолчанию
ENV PYTHONUNBUFFERED=1
ENV N8N_URL=http://n8n:5678
ENV DEBUG_IMPORTER=false

# Точка входа
CMD ["python", "/app/import-workflows.py"]
