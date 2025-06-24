# 🌐 Web Interface Service Dockerfile
# ====================================

FROM python:3.11-slim

# Установка рабочей директории
WORKDIR /app

# Установка переменных окружения
ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONPATH=/app

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
  gcc \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Копирование requirements для лучшего кэширования
COPY requirements.txt .

# Установка Python зависимостей
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY . .

# Создание пользователя без root привилегий для безопасности
RUN useradd -m -u 1000 webuser && \
  chown -R webuser:webuser /app

USER webuser

# Открытие порта
EXPOSE 8002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8002/health || exit 1

# Команда запуска приложения
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8002", "--reload"]
