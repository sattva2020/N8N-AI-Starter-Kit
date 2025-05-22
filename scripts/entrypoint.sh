#!/bin/bash
# filepath: scripts/entrypoint.sh

# Определяем функцию для корректного завершения процесса
cleanup() {
  echo "Завершение процесса Ollama..."
  kill $OLLAMA_PID
  wait $OLLAMA_PID
  exit 0
}

# Настройка перехвата сигналов
trap cleanup SIGINT SIGTERM

echo "🚀 Запуск контейнера Ollama..."

# Запускаем Ollama в фоновом режиме
ollama serve &
OLLAMA_PID=$!

# Ждем запуска Ollama API
echo "⏳ Ожидание запуска Ollama API..."
MAX_RETRIES=30
RETRY=0

while ! curl -s -f "http://localhost:11434/api/health" > /dev/null && [ $RETRY -lt $MAX_RETRIES ]; do
  echo "Ollama еще не готов, повторная проверка через 3 секунды... ($RETRY/$MAX_RETRIES)"
  sleep 3
  RETRY=$((RETRY+1))
done

if [ $RETRY -eq $MAX_RETRIES ]; then
  echo "❌ Превышено максимальное время ожидания. Ollama API не запустился."
  exit 1
fi

VERSION=$(curl -s "http://localhost:11434/api/version" | grep -o '"version":"[^"]*' | cut -d'"' -f4)
echo "✅ Ollama API доступен. Версия: $VERSION"

# Читаем и загружаем модели из файла
if [ -f /config/ollama-models.txt ]; then
  echo "📋 Загрузка моделей из файла..."
  cat /config/ollama-models.txt | grep -v "^#" | sed '/^\s*$/d' | while read -r MODEL; do
    echo "🔄 Проверка/загрузка модели $MODEL..."
    if ! curl -s "http://localhost:11434/api/tags" | grep -q "\"name\":\"$MODEL\""; then
      echo "📥 Загрузка модели $MODEL..."
      ollama pull "$MODEL" &
      PULL_PID=$!
      
      # Отображаем индикатор прогресса
      echo -n "⏳ Ожидание загрузки модели: "
      while kill -0 $PULL_PID 2>/dev/null; do
        echo -n "."
        sleep 2
      done
      echo " ✓"
      
      wait $PULL_PID
      echo "✅ Загрузка модели $MODEL завершена"
    else
      echo "✅ Модель $MODEL уже загружена"
    fi
  done
  echo "🎉 Все модели успешно загружены!"
else
  echo "⚠️ Файл ollama-models.txt не найден! Загружаем модель по умолчанию (llama3)..."
  ollama pull llama3
fi

echo "✨ Ollama готов к использованию! Сервер остаётся активным..."

# Ожидание завершения фонового процесса Ollama
wait $OLLAMA_PID