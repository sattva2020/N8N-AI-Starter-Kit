#!/bin/bash
# filepath: scripts/fix-env-vars.sh
# Script to fix missing environment variables for Supabase

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Исправление переменных окружения для Supabase...${NC}"

# Проверяем и исправляем переменные окружения в .env файле
if [ -f .env ]; then
  # Создаем симлинки между переменными в .env
  if grep -q "SUPABASE_ANON_KEY" .env && ! grep -q "^ANON_KEY=" .env; then
    # Добавляем экспорт для ANON_KEY из SUPABASE_ANON_KEY
    ANON_KEY_VALUE=$(grep -E "^SUPABASE_ANON_KEY=" .env | cut -d '=' -f2)
    echo "ANON_KEY=$ANON_KEY_VALUE" >> .env
    echo -e "${GREEN}✅ Добавлена переменная ANON_KEY на основе SUPABASE_ANON_KEY${NC}"
  fi

  if grep -q "SUPABASE_SERVICE_ROLE_KEY" .env && ! grep -q "^SERVICE_ROLE_KEY=" .env; then
    # Добавляем экспорт для SERVICE_ROLE_KEY из SUPABASE_SERVICE_ROLE_KEY
    SERVICE_KEY_VALUE=$(grep -E "^SUPABASE_SERVICE_ROLE_KEY=" .env | cut -d '=' -f2)
    echo "SERVICE_ROLE_KEY=$SERVICE_KEY_VALUE" >> .env
    echo -e "${GREEN}✅ Добавлена переменная SERVICE_ROLE_KEY на основе SUPABASE_SERVICE_ROLE_KEY${NC}"
  fi
  
  # Дополнительно проверяем JWT_SECRET
  if grep -q "SUPABASE_JWT_SECRET" .env && ! grep -q "^JWT_SECRET=" .env; then
    JWT_SECRET_VALUE=$(grep -E "^SUPABASE_JWT_SECRET=" .env | cut -d '=' -f2)
    echo "JWT_SECRET=$JWT_SECRET_VALUE" >> .env
    echo -e "${GREEN}✅ Добавлена переменная JWT_SECRET на основе SUPABASE_JWT_SECRET${NC}"
  fi
  
  echo -e "${GREEN}Переменные окружения успешно исправлены!${NC}"
else
  echo -e "\033[0;31m❌ Файл .env не найден. Сначала запустите скрипт setup.sh для создания файла .env.${NC}"
  exit 1
fi
