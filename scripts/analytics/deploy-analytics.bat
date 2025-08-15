@echo off
setlocal enabledelayedexpansion

REM Deploy Analytics Stack Script for Windows
REM Развертывание аналитического стека N8N

echo 🚀 Развертывание Analytics Stack для N8N AI Starter Kit
echo ==============================================

REM Функции для логирования
:log
echo [%date% %time%] %~1
goto :eof

:error
echo [ОШИБКА] %~1
goto :eof

:success
echo [УСПЕХ] %~1
goto :eof

:warning
echo [ПРЕДУПРЕЖДЕНИЕ] %~1
goto :eof

REM Проверка зависимостей
call :log "Проверка зависимостей..."

where docker >nul 2>nul
if %ERRORLEVEL% neq 0 (
    call :error "Docker не установлен"
    exit /b 1
)

where docker-compose >nul 2>nul
if %ERRORLEVEL% neq 0 (
    call :error "Docker Compose не установлен"
    exit /b 1
)

call :success "Все зависимости установлены"

REM Создание необходимых директорий
call :log "Создание директорий для данных..."

if not exist "data\clickhouse" mkdir "data\clickhouse"
if not exist "data\superset" mkdir "data\superset"
if not exist "data\postgres-analytics" mkdir "data\postgres-analytics"
if not exist "data\redis-analytics" mkdir "data\redis-analytics"
if not exist "logs\clickhouse" mkdir "logs\clickhouse"
if not exist "logs\superset" mkdir "logs\superset"
if not exist "logs\postgres" mkdir "logs\postgres"
if not exist "logs\redis" mkdir "logs\redis"
if not exist "logs\etl" mkdir "logs\etl"
if not exist "logs\analytics-api" mkdir "logs\analytics-api"

call :success "Директории созданы"

REM Создание Docker networks
call :log "Создание Docker networks..."

docker network ls | findstr "n8n_analytics_network" >nul
if %ERRORLEVEL% neq 0 (
    docker network create n8n_analytics_network
    call :success "Создана сеть: n8n_analytics_network"
) else (
    call :warning "Сеть n8n_analytics_network уже существует"
)

REM Проверка существования основных сетей
docker network ls | findstr "n8n_network" >nul
if %ERRORLEVEL% neq 0 (
    call :warning "Сеть n8n_network не найдена. Убедитесь, что основные сервисы N8N запущены"
)

docker network ls | findstr "n8n_monitoring_network" >nul
if %ERRORLEVEL% neq 0 (
    call :warning "Сеть n8n_monitoring_network не найдена. Мониторинг может быть недоступен"
)

REM Генерация секретов
call :log "Генерация секретов..."

if not exist ".env.analytics" (
    echo # Analytics Stack Environment Variables > .env.analytics
    echo CLICKHOUSE_PASSWORD=clickhouse_pass_%RANDOM% >> .env.analytics
    echo SUPERSET_SECRET_KEY=superset_secret_%RANDOM% >> .env.analytics
    echo POSTGRES_PASSWORD=postgres_analytics_%RANDOM% >> .env.analytics
    echo REDIS_PASSWORD=redis_analytics_%RANDOM% >> .env.analytics
    call :success "Файл .env.analytics создан"
) else (
    call :warning "Файл .env.analytics уже существует"
)

REM Запуск ClickHouse
call :log "Развертывание ClickHouse..."
docker-compose -f compose/analytics-compose.yml up -d clickhouse

REM Ожидание готовности ClickHouse
call :log "Ожидание готовности ClickHouse..."
set /a count=0
:wait_clickhouse
curl -s http://localhost:8123/ >nul 2>nul
if %ERRORLEVEL% equ 0 (
    call :success "ClickHouse готов"
    goto :clickhouse_ready
)
set /a count+=1
if %count% geq 30 (
    call :error "ClickHouse не запустился в течение 150 секунд"
    exit /b 1
)
timeout /t 5 /nobreak >nul
goto :wait_clickhouse
:clickhouse_ready

REM Запуск PostgreSQL для Superset
call :log "Развертывание PostgreSQL для Superset..."
docker-compose -f compose/analytics-compose.yml up -d postgres

REM Ожидание готовности PostgreSQL
call :log "Ожидание готовности PostgreSQL..."
timeout /t 10 /nobreak >nul
call :success "PostgreSQL запущен"

REM Запуск Redis
call :log "Развертывание Redis..."
docker-compose -f compose/analytics-compose.yml up -d redis

REM Ожидание готовности Redis
call :log "Ожидание готовности Redis..."
timeout /t 5 /nobreak >nul
call :success "Redis запущен"

REM Инициализация и запуск Superset
call :log "Инициализация Superset..."
docker-compose -f compose/analytics-compose.yml up --no-deps superset-init

call :log "Запуск Superset..."
docker-compose -f compose/analytics-compose.yml up -d superset

REM Ожидание готовности Superset
call :log "Ожидание готовности Superset..."
set /a count=0
:wait_superset
curl -s http://localhost:8088/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    call :success "Superset готов"
    goto :superset_ready
)
set /a count+=1
if %count% geq 60 (
    call :warning "Superset может быть недоступен"
    goto :superset_ready
)
timeout /t 5 /nobreak >nul
goto :wait_superset
:superset_ready

REM Запуск ETL сервисов
call :log "Развертывание ETL сервисов..."
docker-compose -f compose/analytics-compose.yml up -d etl-processor
docker-compose -f compose/analytics-compose.yml up -d analytics-api

REM Ожидание готовности сервисов
call :log "Ожидание готовности ETL сервисов..."
timeout /t 10 /nobreak >nul

REM Проверка состояния всех сервисов
call :log "Проверка состояния сервисов..."

echo.
echo 🔍 Статус Analytics Stack:
echo ========================

REM ClickHouse
curl -s http://localhost:8123/ >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ ClickHouse: Работает ^(http://localhost:8123^)
) else (
    echo ❌ ClickHouse: Недоступен
)

REM Superset
curl -s http://localhost:8088/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ Superset: Работает ^(http://localhost:8088^)
    echo    👤 Логин: admin / admin123
) else (
    echo ❌ Superset: Недоступен
)

REM Analytics API
curl -s http://localhost:8089/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ Analytics API: Работает ^(http://localhost:8089^)
) else (
    echo ❌ Analytics API: Недоступен
)

REM ETL Processor
curl -s http://localhost:8080/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ ETL Processor: Работает ^(http://localhost:8080^)
) else (
    echo ❌ ETL Processor: Недоступен
)

echo.
echo 📊 Analytics Dashboard доступен по адресу: http://localhost:8088
echo 🔑 API документация: http://localhost:8089/docs
echo.

call :success "🎉 Analytics Stack успешно развернут!"
echo.
echo 🚀 Следующие шаги:
echo 1. Откройте Superset: http://localhost:8088
echo 2. Войдите как admin/admin123
echo 3. Создайте дашборды и графики
echo 4. Настройте источники данных из ClickHouse
echo.
echo 📖 Документация: docs\ANALYTICS_SETUP_GUIDE.md

pause
