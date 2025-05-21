#!/bin/bash
# filepath: e:\AI\n8n-ai-starter-kit\scripts\init-ollama-models.sh

# Ждем запуска Ollama
echo "⏳ Ожидание запуска Ollama API..."
until curl -s -f "http://ollama:11434/api/version" > /dev/null; do
  echo "Ollama еще не готов, повторная проверка через 5 секунд..."
  sleep 5
done
echo "✅ Ollama API доступен, начинаю загрузку моделей..."

# Чтение и загрузка моделей из файла
cat /app/config/ollama-models.txt | grep -v "^#" | sed '/^\s*$/d' | while read -r MODEL; do
  echo "🔄 Проверка/загрузка модели $MODEL..."
  if ! curl -s "http://ollama:11434/api/tags" | grep -q "\"name\":\"$MODEL\""; then
    echo "📥 Загрузка модели $MODEL..."
    curl -s -X POST "http://ollama:11434/api/pull" -d "{\"model\":\"$MODEL\"}"
    echo "✅ Загрузка модели $MODEL завершена"
  else
    echo "✅ Модель $MODEL уже загружена"
  fi
done

echo "🎉 Инициализация моделей Ollama завершена!"