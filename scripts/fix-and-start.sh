#!/bin/bash

echo "Применение всех исправлений для n8n-ai-starter-kit..."

# Остановка всех контейнеров
echo "Остановка запущенных контейнеров..."
docker-compose down

# Очистка неиспользуемых сетей
echo "Очистка сетей Docker..."
docker network prune -f

# Генерация переменных окружения
echo "Генерация отсутствующих переменных окружения..."
if [ -f ./scripts/generate-env-vars.sh ]; then
  bash ./scripts/generate-env-vars.sh
else
  echo "Скрипт generate-env-vars.sh не найден. Пропускаем этот шаг."
fi

# Проверка и исправление переменных Supabase
echo "Проверка и исправление переменных Supabase..."
if [ -f ./scripts/fix-env-vars.sh ]; then
  bash ./scripts/fix-env-vars.sh
else
  echo "Скрипт fix-env-vars.sh не найден. Пропускаем этот шаг."
  
  # Ручное исправление переменных
  if [ -f .env ]; then
    if grep -q "SUPABASE_ANON_KEY" .env && ! grep -q "^ANON_KEY=" .env; then
      ANON_KEY_VALUE=$(grep -E "^SUPABASE_ANON_KEY=" .env | cut -d '=' -f2)
      echo "ANON_KEY=$ANON_KEY_VALUE" >> .env
      echo "✅ Добавлена переменная ANON_KEY"
    fi
    
    if grep -q "SUPABASE_SERVICE_ROLE_KEY" .env && ! grep -q "^SERVICE_ROLE_KEY=" .env; then
      SERVICE_KEY_VALUE=$(grep -E "^SUPABASE_SERVICE_ROLE_KEY=" .env | cut -d '=' -f2)
      echo "SERVICE_ROLE_KEY=$SERVICE_KEY_VALUE" >> .env
      echo "✅ Добавлена переменная SERVICE_ROLE_KEY"
    fi
  fi
fi

# Установка ограничения параллелизма
echo "Ограничение параллелизма Docker Compose..."
export COMPOSE_PARALLEL_LIMIT=1

# Запуск системы
echo "Запуск системы с профилем CPU..."
docker-compose --profile cpu up -d

# Проверка статуса
echo "Проверка статуса контейнеров..."
sleep 5
docker-compose ps

echo ""
echo "Готово! Система должна быть запущена без ошибок."
echo "Если вы все еще видите предупреждения о переменных окружения, "
echo "проверьте файл .env и убедитесь, что в нем определены все необходимые переменные."
echo "Полный список переменных вы найдете в документации: docs/ENV_VARIABLES_FIX.md"
