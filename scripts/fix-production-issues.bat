@echo off
REM =============================================
REM Исправление production проблем N8N AI Starter Kit
REM =============================================

echo 🔧 Исправление критических проблем production окружения...

REM Проверяем наличие .env файла
if not exist .env (
    echo ❌ Файл .env не найден. Создайте его из template.env
    exit /b 1
)

REM 1. Исправляем N8N encryption key mismatch
echo 🔑 Исправление N8N encryption key...
docker volume ls | findstr "n8n-ai-starter-kit_n8n_storage" >nul 2>&1
if %errorlevel% equ 0 (
    echo 🗑️ Удаление старого n8n volume для сброса encryption key...
    docker compose down -v --remove-orphans >nul 2>&1
    docker volume rm n8n-ai-starter-kit_n8n_storage >nul 2>&1
)

REM 2. Проверяем переменные окружения
echo 🔍 Проверка переменных окружения...

REM Проверяем OpenAI API key
findstr /B "OPENAI_API_KEY=" .env | findstr "your_openai_api_key_here" >nul 2>&1
if %errorlevel% equ 0 (
    echo ⚠️  ВНИМАНИЕ: OPENAI_API_KEY не настроен.
    echo    Установите его для работы Graphiti и других AI сервисов
)

REM 3. Останавливаем все сервисы
echo ⏹️  Остановка всех сервисов...
docker compose down --remove-orphans >nul 2>&1
docker compose -f compose/zep-compose.yaml down --remove-orphans >nul 2>&1
docker compose -f compose/supabase-compose.yml down --remove-orphans >nul 2>&1

REM 4. Очистка проблемных volume'ов
echo 🧹 Очистка проблемных volumes...
docker volume rm n8n-ai-starter-kit_postgres_storage >nul 2>&1
docker volume rm n8n-ai-starter-kit_n8n_storage >nul 2>&1

REM 5. Запуск основных сервисов
echo 🚀 Запуск основных сервисов...
docker compose up -d postgres traefik n8n qdrant ollama

REM Ждем запуска PostgreSQL
echo ⏳ Ожидание запуска PostgreSQL...
for /l %%i in (1,1,30) do (
    docker compose exec postgres pg_isready -U root -d n8n >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ PostgreSQL готов
        goto :postgres_ready
    )
    echo    Попытка %%i/30...
    timeout /t 2 >nul
)
:postgres_ready

REM Ждем запуска N8N
echo ⏳ Ожидание запуска N8N...
for /l %%i in (1,1,60) do (
    curl -s http://localhost:5678 >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ N8N готов
        goto :n8n_ready
    )
    echo    Попытка %%i/60...
    timeout /t 2 >nul
)
:n8n_ready

echo.
echo 🎉 Исправление завершено!
echo.
echo 📋 Статус сервисов:
echo    N8N: http://localhost:5678
echo    Qdrant: http://localhost:6333
echo    Ollama: http://localhost:11434
echo.
echo 🔧 Для запуска дополнительных сервисов (Zep, Graphiti):
echo    1. Установите OPENAI_API_KEY в .env
echo    2. Запустите: docker compose -f compose/zep-compose.yaml up -d
echo.
echo 📊 Проверка состояния: scripts\comprehensive-container-check.sh

pause
