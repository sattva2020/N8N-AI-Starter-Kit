#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\scripts\check-ollama-models.sh

set -e
echo "🔍 Диагностика Ollama и загрузки моделей..."

# Проверка доступности API Ollama
echo "📡 Проверка доступности Ollama API..."
if ! curl -s -f "${LLM_BINDING_HOST:-http://ollama:11434}/api/version" > /dev/null; then
  echo "❌ Ошибка: Ollama API недоступен. Сервер не запущен или не отвечает."
  exit 1
else
  echo "✅ Ollama API доступен."
  VERSION=$(curl -s "${LLM_BINDING_HOST:-http://ollama:11434}/api/version" | grep -o '"version":"[^"]*' | cut -d'"' -f4)
  echo "   📋 Версия Ollama: $VERSION"
fi

# Получение списка загруженных моделей
echo -e "\n📋 Получение списка загруженных моделей..."
LOADED_MODELS=$(curl -s "${LLM_BINDING_HOST:-http://ollama:11434}/api/tags" | grep -o '"name":"[^"]*' | cut -d'"' -f4 || echo "")

if [ -z "$LOADED_MODELS" ]; then
  echo "⚠️  Предупреждение: Нет загруженных моделей в Ollama."
else
  echo "✅ Загружены следующие модели:"
  echo "$LOADED_MODELS" | while read -r MODEL; do
    echo "   - $MODEL"
  done
fi

# Чтение требуемых моделей из файла
echo -e "\n🔍 Проверка соответствия с файлом конфигурации..."
if [ -f "/app/config/ollama-models.txt" ]; then
  REQUIRED_MODELS=$(cat /app/config/ollama-models.txt | grep -v "^#" | sed '/^\s*$/d')

  echo "📋 Список требуемых моделей:"

  # Проверка каждой модели из списка
  echo "$REQUIRED_MODELS" | while read -r MODEL; do
    if echo "$LOADED_MODELS" | grep -q "$MODEL"; then
      echo "   ✅ $MODEL - загружена"
    else
      echo "   ❌ $MODEL - НЕ загружена"
      MISSING_MODELS="$MISSING_MODELS $MODEL"
    fi
  done

  # Предложение загрузить отсутствующие модели
  if [ ! -z "$MISSING_MODELS" ]; then
    echo -e "\n⚠️  Обнаружены отсутствующие модели. Хотите загрузить их? (y/n)"
    read -r ANSWER
    if [ "$ANSWER" = "y" ]; then
      echo "$MISSING_MODELS" | tr ' ' '\n' | while read -r MODEL; do
        if [ ! -z "$MODEL" ]; then
          echo "🔄 Загрузка модели $MODEL..."
          curl -X POST "${LLM_BINDING_HOST:-http://ollama:11434}/api/pull" -d "{\"model\":\"$MODEL\"}"
          echo "✅ Модель $MODEL загружена."
        fi
      done
    fi
  fi
else
  echo "❌ Ошибка: Файл конфигурации моделей не найден по пути /app/config/ollama-models.txt"
fi

echo -e "\n📊 Диагностика завершена."
