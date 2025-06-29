@echo off
setlocal enabledelayedexpansion

REM Analytics Stack Health Check Script for Windows

echo 🔍 Проверка состояния Analytics Stack
echo ====================================

:check_clickhouse
echo Проверка ClickHouse...
curl -s http://localhost:8123/ | findstr "Ok." >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ ClickHouse: Работает
    echo   - Проверка базы данных n8n_analytics...
    curl -s "http://localhost:8123/?query=SELECT%%201%%20FROM%%20system.databases%%20WHERE%%20name='n8n_analytics'" | findstr "1" >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        echo   ✅ База данных существует
    ) else (
        echo   ⚠️ База данных не найдена
    )
) else (
    echo ❌ ClickHouse: Недоступен
)

:check_superset
echo Проверка Superset...
curl -s http://localhost:8088/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ Superset: Работает ^(http://localhost:8088^)
) else (
    echo ❌ Superset: Недоступен
)

:check_analytics_api
echo Проверка Analytics API...
curl -s http://localhost:8089/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ Analytics API: Работает ^(http://localhost:8089^)
    echo   - Проверка Metrics endpoint...
    curl -s http://localhost:8089/metrics | findstr "^#" >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        echo   ✅ Metrics работают
    ) else (
        echo   ⚠️ Metrics недоступны
    )
) else (
    echo ❌ Analytics API: Недоступен
)

:check_etl_processor
echo Проверка ETL Processor...
curl -s http://localhost:8080/health >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ ETL Processor: Работает ^(http://localhost:8080^)
    echo   - Проверка ETL Status...
    curl -s http://localhost:8080/status | findstr "status" >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        echo   ✅ ETL Status работает
    ) else (
        echo   ⚠️ ETL Status недоступен
    )
) else (
    echo ❌ ETL Processor: Недоступен
)

echo.
echo 📊 Состояние контейнеров:
echo ========================
docker ps --format "table {{.Names}}\t{{.Status}}" | findstr "n8n_clickhouse\|n8n_superset\|n8n_analytics\|n8n_etl"

echo.
echo 🔗 Состояние сетей:
echo ==================
docker network ls | findstr "n8n"

echo.
echo 💾 Состояние хранилища:
echo ======================
if exist "data\clickhouse" (
    echo ✅ Директория ClickHouse существует
) else (
    echo ❌ Директория ClickHouse отсутствует
)

if exist "data\superset" (
    echo ✅ Директория Superset существует
) else (
    echo ❌ Директория Superset отсутствует
)

if exist "data\postgres-analytics" (
    echo ✅ Директория PostgreSQL существует
) else (
    echo ❌ Директория PostgreSQL отсутствует
)

if exist "data\redis-analytics" (
    echo ✅ Директория Redis существует
) else (
    echo ❌ Директория Redis отсутствует
)

echo.
echo 📈 Статистика использования:
echo ===========================
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" n8n_clickhouse n8n_superset n8n_analytics_postgres n8n_analytics_redis n8n_etl_processor n8n_analytics_api 2>nul

echo.
echo 🌐 Доступные интерфейсы:
echo =======================
echo   - Superset Dashboard: http://localhost:8088
echo   - Analytics API: http://localhost:8089
echo   - API Документация: http://localhost:8089/docs
echo   - ETL Processor: http://localhost:8080
echo   - ClickHouse HTTP: http://localhost:8123

echo.
echo 📋 Сводка завершена
echo.

pause
