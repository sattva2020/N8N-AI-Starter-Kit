@echo off
setlocal enabledelayedexpansion

:: Deploy Logging Stack for N8N AI Starter Kit (Windows)
:: This script deploys the ELK stack with Filebeat for centralized logging

echo 🚀 Deploying N8N AI Starter Kit Logging Stack
echo ==============================================

:: Get script directory and project root
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%\..\..") do set "PROJECT_ROOT=%%~fi"
set "COMPOSE_FILE=%PROJECT_ROOT%\compose\logging-compose.yml"

:: Function to check if required directories exist
:check_directories
echo 📁 Checking required directories...

set "dirs=data\elasticsearch data\kibana data\filebeat logs logs\elasticsearch logs\logstash logs\kibana"

for %%d in (%dirs%) do (
    if not exist "%PROJECT_ROOT%\%%d" (
        echo Creating directory: %%d
        mkdir "%PROJECT_ROOT%\%%d"
    )
)

echo ✅ Directories checked and created
goto :eof

:: Function to check system requirements
:check_system_requirements
echo 🔧 Checking system requirements...

:: Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not installed or not in PATH
    exit /b 1
)

:: Check Docker Compose
docker-compose --version >nul 2>&1 || docker compose version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose is not installed or not in PATH
    exit /b 1
)

echo ✅ System requirements checked
goto :eof

:: Function to create Docker network
:create_network
echo 🌐 Creating Docker network...

docker network ls | findstr "n8n_logging" >nul
if errorlevel 1 (
    docker network create n8n_logging
    echo ✅ Created n8n_logging network
) else (
    echo ✅ n8n_logging network already exists
)

docker network ls | findstr "n8n_network" >nul
if errorlevel 1 (
    docker network create n8n_network
    echo ✅ Created n8n_network network
) else (
    echo ✅ n8n_network network already exists
)
goto :eof

:: Function to deploy logging stack
:deploy_logging_stack
echo 📊 Deploying logging stack...

cd /d "%PROJECT_ROOT%"

echo Pulling latest images...
docker-compose -f "%COMPOSE_FILE%" pull

echo Starting logging services...
docker-compose -f "%COMPOSE_FILE%" up -d

echo ✅ Logging stack deployed
goto :eof

:: Function to wait for services to be ready
:wait_for_services
echo ⏳ Waiting for services to be ready...

:: Wait for Elasticsearch
echo Waiting for Elasticsearch...
set /a counter=0
:wait_elasticsearch
set /a counter+=1
curl -s http://localhost:9200/_cluster/health >nul 2>&1
if errorlevel 1 (
    if !counter! lss 30 (
        echo Waiting for Elasticsearch... (!counter!/30)
        timeout /t 10 /nobreak >nul
        goto wait_elasticsearch
    ) else (
        echo ❌ Elasticsearch failed to start within timeout
    )
) else (
    echo ✅ Elasticsearch is ready
)

:: Wait for Logstash
echo Waiting for Logstash...
set /a counter=0
:wait_logstash
set /a counter+=1
curl -s http://localhost:9600/_node/stats >nul 2>&1
if errorlevel 1 (
    if !counter! lss 20 (
        echo Waiting for Logstash... (!counter!/20)
        timeout /t 10 /nobreak >nul
        goto wait_logstash
    ) else (
        echo ❌ Logstash failed to start within timeout
    )
) else (
    echo ✅ Logstash is ready
)

:: Wait for Kibana
echo Waiting for Kibana...
set /a counter=0
:wait_kibana
set /a counter+=1
curl -s http://localhost:5601/api/status >nul 2>&1
if errorlevel 1 (
    if !counter! lss 30 (
        echo Waiting for Kibana... (!counter!/30)
        timeout /t 10 /nobreak >nul
        goto wait_kibana
    ) else (
        echo ❌ Kibana failed to start within timeout
    )
) else (
    echo ✅ Kibana is ready
)

echo ✅ All services are ready
goto :eof

:: Function to create index patterns
:create_index_patterns
echo 📋 Creating index patterns...

:: Wait a bit more for Kibana to fully initialize
timeout /t 30 /nobreak >nul

:: Create index patterns via Kibana API
set "patterns=logstash-general-* n8n-logs-* docker-logs-* system-logs-*"

for %%p in (%patterns%) do (
    echo Creating index pattern: %%p
    curl -X POST "localhost:5601/api/saved_objects/index-pattern" ^
        -H "Content-Type: application/json" ^
        -H "kbn-xsrf: true" ^
        -d "{\"attributes\":{\"title\":\"%%p\",\"timeFieldName\":\"@timestamp\"}}" >nul 2>&1
)

echo ✅ Index patterns created
goto :eof

:: Function to show service status
:show_service_status
echo 📊 Service Status
echo ==================

cd /d "%PROJECT_ROOT%"
docker-compose -f "%COMPOSE_FILE%" ps

echo.
echo 🌐 Service URLs:
echo   Elasticsearch: http://localhost:9200
echo   Kibana: http://localhost:5601
echo   Logstash API: http://localhost:9600
echo.
echo 🔍 Health Checks:

:: Elasticsearch health
curl -s http://localhost:9200/_cluster/health >nul 2>&1
if errorlevel 1 (
    echo   ❌ Elasticsearch: Not responding
) else (
    echo   ✅ Elasticsearch: Healthy
)

:: Logstash health
curl -s http://localhost:9600/_node/stats >nul 2>&1
if errorlevel 1 (
    echo   ❌ Logstash: Not responding
) else (
    echo   ✅ Logstash: Healthy
)

:: Kibana health
curl -s http://localhost:5601/api/status >nul 2>&1
if errorlevel 1 (
    echo   ❌ Kibana: Not responding
) else (
    echo   ✅ Kibana: Healthy
)
goto :eof

:: Main execution
echo Starting deployment at %date% %time%

call :check_directories
call :check_system_requirements
call :create_network
call :deploy_logging_stack
call :wait_for_services
call :create_index_patterns
call :show_service_status

echo.
echo 🎉 Logging stack deployment completed!
echo =========================================
echo Access Kibana at: http://localhost:5601
echo Access Elasticsearch at: http://localhost:9200
echo Logs will be automatically collected and indexed.
echo.
echo Next steps:
echo 1. Open Kibana and explore the dashboards
echo 2. Create custom visualizations for your needs
echo 3. Set up alerting rules in Elasticsearch
echo 4. Configure log retention policies
echo.
echo For troubleshooting, check service logs:
echo   docker-compose -f "%COMPOSE_FILE%" logs [service_name]

pause
