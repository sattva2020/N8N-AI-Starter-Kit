@echo off
REM N8N AI Starter Kit - Monitoring Stack Deployment Script (Windows)
REM Развертывает Prometheus, Grafana, AlertManager и связанные сервисы

setlocal enabledelayedexpansion

REM Конфигурация
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "COMPOSE_FILE=%PROJECT_ROOT%\compose\monitoring-compose.yml"
set "ENV_FILE=%PROJECT_ROOT%\.env"

REM Функции для вывода
:log_info
echo [INFO] %~1
exit /b 0

:log_success
echo [SUCCESS] %~1
exit /b 0

:log_warning
echo [WARNING] %~1
exit /b 0

:log_error
echo [ERROR] %~1
exit /b 0

REM Проверка зависимостей
:check_dependencies
call :log_info "Checking dependencies..."

REM Проверяем Docker
docker --version >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker is not installed"
    exit /b 1
)

REM Проверяем Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker Compose is not installed"
    exit /b 1
)

REM Проверяем файлы конфигурации
if not exist "%COMPOSE_FILE%" (
    call :log_error "Monitoring compose file not found: %COMPOSE_FILE%"
    exit /b 1
)

if not exist "%ENV_FILE%" (
    call :log_warning "Environment file not found: %ENV_FILE%"
    call :log_info "Creating basic .env file..."
    call :create_basic_env
)

call :log_success "Dependencies check passed"
goto :eof

REM Создание базового .env файла
:create_basic_env
(
echo # N8N AI Starter Kit Environment Configuration
echo.
echo # Domain configuration
echo DOMAIN_NAME=localhost
echo.
echo # Grafana configuration
echo GRAFANA_ADMIN_USER=admin
echo GRAFANA_ADMIN_PASSWORD=admin123
echo.
echo # N8N configuration
echo N8N_API_KEY=your-api-key-here
echo.
echo # PostgreSQL configuration
echo POSTGRES_USER=n8n
echo POSTGRES_PASSWORD=n8n
echo POSTGRES_DB=n8n
echo POSTGRES_PORT=5432
echo.
echo # Environment
echo ENVIRONMENT=development
) > "%ENV_FILE%"
call :log_success "Created basic .env file"
goto :eof

REM Проверка сети Docker
:check_network
call :log_info "Checking Docker networks..."

docker network ls | findstr "n8n_network" >nul
if errorlevel 1 (
    call :log_warning "n8n_network not found, creating..."
    docker network create n8n_network
    call :log_success "Created n8n_network"
)
goto :eof

REM Создание необходимых директорий
:create_directories
call :log_info "Creating necessary directories..."

if not exist "%PROJECT_ROOT%\data\prometheus" mkdir "%PROJECT_ROOT%\data\prometheus"
if not exist "%PROJECT_ROOT%\data\grafana" mkdir "%PROJECT_ROOT%\data\grafana"
if not exist "%PROJECT_ROOT%\data\alertmanager" mkdir "%PROJECT_ROOT%\data\alertmanager"

call :log_success "Directories created"
goto :eof

REM Сборка кастомных образов
:build_images
call :log_info "Building custom images..."

cd /d "%PROJECT_ROOT%"

call :log_info "Building N8N exporter..."
docker-compose -f "%COMPOSE_FILE%" build n8n-exporter

call :log_info "Building PostgreSQL exporter..."
docker-compose -f "%COMPOSE_FILE%" build postgres-exporter

call :log_success "Custom images built"
goto :eof

REM Запуск мониторинга
:start_monitoring
call :log_info "Starting monitoring stack..."

cd /d "%PROJECT_ROOT%"
docker-compose -f "%COMPOSE_FILE%" up -d

call :log_success "Monitoring stack started"
goto :eof

REM Проверка статуса сервисов
:check_services
call :log_info "Checking service status..."

set "failed_services="

REM Проверяем каждый сервис
for %%s in (prometheus grafana alertmanager node-exporter cadvisor) do (
    docker ps --filter "name=n8n-ai-%%s" --filter "status=running" | findstr "n8n-ai-%%s" >nul
    if errorlevel 1 (
        call :log_error "✗ %%s is not running"
        set "failed_services=!failed_services! %%s"
    ) else (
        call :log_success "✓ %%s is running"
    )
)

if "%failed_services%"=="" (
    call :log_success "All monitoring services are running"
    call :show_access_urls
) else (
    call :log_error "Some services failed to start:%failed_services%"
    exit /b 1
)
goto :eof

REM Отображение URL для доступа
:show_access_urls
call :log_info "Monitoring services are available at:"
echo.
echo Prometheus:   http://localhost:9090
echo Grafana:      http://localhost:3000 ^(admin/admin123^)
echo AlertManager: http://localhost:9093
echo Node Exporter: http://localhost:9100
echo cAdvisor:     http://localhost:8080
echo.
goto :eof

REM Остановка мониторинга
:stop_monitoring
call :log_info "Stopping monitoring stack..."
cd /d "%PROJECT_ROOT%"
docker-compose -f "%COMPOSE_FILE%" down
call :log_success "Monitoring stack stopped"
goto :eof

REM Перезапуск мониторинга
:restart_monitoring
call :log_info "Restarting monitoring stack..."
call :stop_monitoring
call :start_monitoring
timeout /t 10 /nobreak >nul
call :check_services
goto :eof

REM Показать логи
:show_logs
cd /d "%PROJECT_ROOT%"
docker-compose -f "%COMPOSE_FILE%" logs -f --tail=50
goto :eof

REM Очистка
:clean_monitoring
call :log_warning "This will remove all monitoring containers and volumes!"
set /p "choice=Are you sure? [y/N]: "
if /i "%choice%"=="y" (
    call :log_info "Cleaning monitoring stack..."
    cd /d "%PROJECT_ROOT%"
    docker-compose -f "%COMPOSE_FILE%" down -v --remove-orphans
    docker-compose -f "%COMPOSE_FILE%" rm -f
    call :log_success "Monitoring stack cleaned"
) else (
    call :log_info "Operation cancelled"
)
goto :eof

REM Отображение помощи
:show_help
echo N8N AI Starter Kit - Monitoring Deployment Script
echo.
echo Usage: %~nx0 [COMMAND]
echo.
echo Commands:
echo   start     Start the monitoring stack
echo   stop      Stop the monitoring stack
echo   restart   Restart the monitoring stack
echo   status    Check status of monitoring services
echo   logs      Show logs from monitoring services
echo   clean     Stop and remove monitoring containers and volumes
echo   help      Show this help message
echo.
goto :eof

REM Основная функция
:main
set "command=%~1"
if "%command%"=="" set "command=start"

call :log_info "Starting with command: %command%"

if /i "%command%"=="start" (
    call :check_dependencies
    if errorlevel 1 exit /b 1
    call :check_network
    call :create_directories
    call :build_images
    call :start_monitoring
    timeout /t 10 /nobreak >nul
    call :check_services
) else if /i "%command%"=="stop" (
    call :stop_monitoring
) else if /i "%command%"=="restart" (
    call :restart_monitoring
) else if /i "%command%"=="status" (
    call :check_services
) else if /i "%command%"=="logs" (
    call :show_logs
) else if /i "%command%"=="clean" (
    call :clean_monitoring
) else if /i "%command%"=="help" (
    call :show_help
) else if /i "%command%"=="-h" (
    call :show_help
) else if /i "%command%"=="--help" (
    call :show_help
) else (
    call :log_error "Unknown command: %command%"
    call :show_help
    exit /b 1
)

goto :eof

REM Запуск скрипта
call :main %*
