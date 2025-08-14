FROM python:3.11-alpine

# Установка зависимостей
RUN apk add --no-cache \
  curl \
  && rm -rf /var/cache/apk/*

# Создание рабочей директории
WORKDIR /app

# Копирование requirements
COPY services/workflows-manager/requirements.txt .

# Установка Python зависимостей
RUN pip install --no-cache-dir -r requirements.txt

# Копирование исходного кода
COPY services/workflows-manager/ .

# Создание директории для workflows
RUN mkdir -p /workflows

# Переменные окружения по умолчанию
ENV PYTHONUNBUFFERED=1
ENV WORKFLOWS_DOC_URL=http://workflows-doc:8000
ENV N8N_URL=http://n8n:5678

# Точка входа
CMD ["python", "/app/app.py"]
