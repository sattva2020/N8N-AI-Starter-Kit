@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: N8N AI Starter Kit - Server Management Script (Batch)
:: =============================================================================
:: Скрипт для управления N8N AI Starter Kit на удаленном сервере через SSH
:: =============================================================================

set "GREEN=[32m"
set "RED=[31m"
set "YELLOW=[33m"
set "BLUE=[34m"
set "RESET=[0m"

if "%~1"=="" (
    call :show_help
    exit /b 1
)

set "SERVER_IP=%~1"
set "USERNAME=%~2"
set "ACTION=%~3"

if "%USERNAME%"=="" set "USERNAME=root"
if "%ACTION%"=="" set "ACTION=deploy"

echo.
echo %BLUE%============================================%RESET%
echo %BLUE%  N8N AI Starter Kit - Server Management   %RESET%
echo %BLUE%============================================%RESET%
echo.

call :check_ssh
if errorlevel 1 exit /b 1

call :test_connection "%SERVER_IP%" "%USERNAME%"
if errorlevel 1 exit /b 1

call :execute_action "%ACTION%" "%SERVER_IP%" "%USERNAME%"
exit /b %errorlevel%

:show_help
echo.
echo %BLUE%N8N AI Starter Kit - Remote Server Management%RESET%
echo.
echo Usage: manage-server.bat ^<ServerIP^> [Username] [Action]
echo.
echo Parameters:
echo   ServerIP    : IP address of the remote server (required)
echo   Username    : SSH username (default: root)
echo   Action      : Action to perform (default: deploy)
echo.
echo Available Actions:
echo   deploy      : Deploy N8N AI Starter Kit to server
echo   status      : Check server and services status
echo   update      : Update server to latest version
echo   start       : Start N8N services
echo   stop        : Stop N8N services
echo   restart     : Restart N8N services
echo   logs        : Show service logs
echo   backup      : Create backup of data
echo   help        : Show this help message
echo.
echo Examples:
echo   manage-server.bat 192.168.1.100
echo   manage-server.bat 192.168.1.100 ubuntu status
echo   manage-server.bat 192.168.1.100 root update
echo.
exit /b 0

:check_ssh
ssh -V >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% SSH client not found. Please install OpenSSH.
    echo.
    echo To install OpenSSH on Windows:
    echo 1. Open Settings ^> Apps ^> Optional Features
    echo 2. Click "Add a feature"
    echo 3. Find and install "OpenSSH Client"
    echo.
    echo Or use Windows Subsystem for Linux (WSL)
    exit /b 1
)
echo %GREEN%[INFO]%RESET% SSH client found
exit /b 0

:test_connection
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Testing SSH connection to %user%@%server%...

ssh -o ConnectTimeout=10 -o BatchMode=yes %user%@%server% exit >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% SSH connection failed. Please check:
    echo   1. Server IP is correct: %server%
    echo   2. SSH service is running on server
    echo   3. SSH key is properly configured
    echo   4. Username is correct: %user%
    exit /b 1
)
echo %GREEN%[INFO]%RESET% SSH connection successful
exit /b 0

:execute_action
set "action=%~1"
set "server=%~2"
set "user=%~3"

if /i "%action%"=="deploy" call :deploy_server "%server%" "%user%"
if /i "%action%"=="status" call :check_status "%server%" "%user%"
if /i "%action%"=="update" call :update_server "%server%" "%user%"
if /i "%action%"=="start" call :start_server "%server%" "%user%"
if /i "%action%"=="stop" call :stop_server "%server%" "%user%"
if /i "%action%"=="restart" call :restart_server "%server%" "%user%"
if /i "%action%"=="logs" call :get_logs "%server%" "%user%"
if /i "%action%"=="backup" call :backup_server "%server%" "%user%"
if /i "%action%"=="help" call :show_help

exit /b 0

:deploy_server
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Deploying N8N AI Starter Kit to %server%...

ssh %user%@%server% "curl -fsSL https://raw.githubusercontent.com/sattva2020/N8N-AI-Starter-Kit/main/scripts/deploy-server.sh | bash"
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% Deployment failed
    exit /b 1
)
echo %GREEN%[INFO]%RESET% Deployment completed successfully!
call :show_urls "%server%"
exit /b 0

:check_status
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Checking server status...

ssh %user%@%server% "cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit; if [ -f 'scripts/check-server-status.sh' ]; then chmod +x scripts/check-server-status.sh && ./scripts/check-server-status.sh; else echo 'Status script not found. Checking manually...' && echo 'Docker containers:' && docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' && echo '' && echo 'System resources:' && free -h && df -h; fi"
exit /b 0

:update_server
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Updating server...

ssh %user%@%server% "cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit; if [ -f 'scripts/update-server.sh' ]; then chmod +x scripts/update-server.sh && ./scripts/update-server.sh; else echo 'Update script not found. Performing manual update...' && git pull origin main && docker-compose pull && docker-compose down && docker-compose --profile cpu up -d; fi"
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% Update failed
    exit /b 1
)
echo %GREEN%[INFO]%RESET% Update completed successfully!
exit /b 0

:start_server
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Starting N8N services...

ssh %user%@%server% "cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit; docker-compose --profile cpu up -d"
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% Failed to start services
    exit /b 1
)
echo %GREEN%[INFO]%RESET% Services started successfully!
call :show_urls "%server%"
exit /b 0

:stop_server
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Stopping N8N services...

ssh %user%@%server% "cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit; docker-compose down"
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% Failed to stop services
    exit /b 1
)
echo %GREEN%[INFO]%RESET% Services stopped successfully!
exit /b 0

:restart_server
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Restarting N8N services...

call :stop_server "%server%" "%user%"
timeout /t 5 /nobreak >nul
call :start_server "%server%" "%user%"
exit /b 0

:get_logs
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Retrieving server logs...

ssh %user%@%server% "cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit; echo '=== Docker Compose Services ===' && docker-compose ps && echo '' && echo '=== Recent Logs (last 50 lines) ===' && docker-compose logs --tail=50"
exit /b 0

:backup_server
set "server=%~1"
set "user=%~2"
echo %GREEN%[INFO]%RESET% Creating server backup...

ssh %user%@%server% "cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit; BACKUP_DIR=\"/tmp/n8n-backup-$(date +%%Y%%m%%d-%%H%%M%%S)\"; mkdir -p \"$BACKUP_DIR\"; cp -r .env* \"$BACKUP_DIR/\" 2>/dev/null || true; echo 'Backing up Docker volumes...'; docker run --rm -v n8n_storage:/data -v \"$BACKUP_DIR\":/backup alpine tar czf /backup/n8n_storage.tar.gz -C /data .; echo \"Backup created at: $BACKUP_DIR\"; ls -la \"$BACKUP_DIR\""
if errorlevel 1 (
    echo %RED%[ERROR]%RESET% Backup failed
    exit /b 1
)
echo %GREEN%[INFO]%RESET% Backup completed successfully!
exit /b 0

:show_urls
set "server_ip=%~1"
echo.
echo %BLUE%Access URLs:%RESET%
echo N8N Interface: http://%server_ip%:5678
echo Web Interface: http://%server_ip%:8002
echo Document Processor: http://%server_ip%:8001
echo Qdrant Dashboard: http://%server_ip%:6333/dashboard
echo.
exit /b 0
