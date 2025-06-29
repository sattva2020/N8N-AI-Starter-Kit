@echo off
setlocal enabledelayedexpansion

:: Health Check Script for N8N AI Starter Kit Logging Stack (Windows)
:: This script checks the health of all logging components

:: Get script directory and project root
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%\..\..") do set "PROJECT_ROOT=%%~fi"

echo 🔍 N8N AI Starter Kit - Logging Stack Health Check
echo ==================================================
echo Timestamp: %date% %time%
echo.

:: Function to check service health
:check_service_health
set "service_name=%~1"
set "health_url=%~2"
set "expected_status=%~3"
if "%expected_status%"=="" set "expected_status=200"

echo | set /p="🔍 Checking %service_name%... "

curl -s -w "%%{http_code}" -o nul "%health_url%" >temp_response.txt 2>nul
if errorlevel 1 (
    echo ❌ Not responding
    del temp_response.txt >nul 2>&1
    exit /b 1
)

set /p response=<temp_response.txt
del temp_response.txt >nul 2>&1

if "%response%"=="%expected_status%" (
    echo ✅ Healthy (HTTP %response%)
    exit /b 0
) else (
    echo ❌ Unhealthy (HTTP %response%)
    exit /b 1
)

:: Function to check disk usage
:check_disk_usage
echo 💾 Disk Usage Analysis
echo ======================

if exist "%PROJECT_ROOT%\logs" (
    for /f "tokens=3" %%a in ('dir "%PROJECT_ROOT%\logs" /-c ^| find "File(s)"') do set "logs_size=%%a"
    echo 📁 Logs directory exists
)

if exist "%PROJECT_ROOT%\data" (
    echo 📁 Data directory exists
)

for /f "tokens=4" %%a in ('dir /-c "%PROJECT_ROOT%" ^| find "bytes free"') do set "free_space=%%a"
echo 💿 Free disk space available

echo.
goto :eof

:: Function to check Docker containers
:check_containers
echo 🐳 Container Status
echo ==================

set "containers=n8n_elasticsearch n8n_logstash n8n_kibana n8n_filebeat n8n_log_rotator"

for %%c in (%containers%) do (
    docker ps --format "table {{.Names}}" | findstr "%%c" >nul
    if errorlevel 1 (
        echo ❌ %%c: Not found
    ) else (
        docker inspect --format="{{.State.Status}}" "%%c" >temp_status.txt 2>nul
        if errorlevel 1 (
            echo ❌ %%c: Error getting status
        ) else (
            set /p status=<temp_status.txt
            if "!status!"=="running" (
                echo ✅ %%c: Running
            ) else (
                echo ❌ %%c: !status!
            )
        )
        del temp_status.txt >nul 2>&1
    )
)

echo.
goto :eof

:: Function to check service APIs
:check_apis
echo 🌐 API Health Checks
echo ===================

set /a services_healthy=0
set /a total_services=0

:: Elasticsearch
set /a total_services+=1
call :check_service_health "Elasticsearch" "http://localhost:9200/_cluster/health"
if not errorlevel 1 (
    set /a services_healthy+=1
    
    :: Get cluster status
    curl -s "http://localhost:9200/_cluster/health" | findstr "green" >nul
    if not errorlevel 1 (
        echo    📊 Cluster status: Green ✅
    ) else (
        curl -s "http://localhost:9200/_cluster/health" | findstr "yellow" >nul
        if not errorlevel 1 (
            echo    📊 Cluster status: Yellow ⚠️
        ) else (
            echo    📊 Cluster status: Red ❌
        )
    )
)

:: Logstash
set /a total_services+=1
call :check_service_health "Logstash" "http://localhost:9600/_node/stats"
if not errorlevel 1 (
    set /a services_healthy+=1
    echo    📈 Logstash is responding
)

:: Kibana
set /a total_services+=1
call :check_service_health "Kibana" "http://localhost:5601/api/status"
if not errorlevel 1 (
    set /a services_healthy+=1
    echo    📊 Kibana is responding
)

echo.
echo 📊 Overall API Health: !services_healthy!/!total_services! services healthy

if !services_healthy! equ !total_services! (
    echo ✅ All services are healthy
) else if !services_healthy! gtr 0 (
    echo ⚠️ Some services are unhealthy
) else (
    echo ❌ All services are unhealthy
)

echo.
goto :eof

:: Function to check log ingestion
:check_log_ingestion
echo 📊 Log Ingestion Status
echo ======================

curl -s "http://localhost:9200/_cluster/health" >nul 2>&1
if errorlevel 1 (
    echo ❌ Cannot check log ingestion - Elasticsearch not available
) else (
    echo ✅ Elasticsearch available for log checking
    
    :: Check if indices exist
    curl -s "http://localhost:9200/_cat/indices" | findstr "logstash" >nul
    if not errorlevel 1 (
        echo ✅ Logstash indices found
    ) else (
        echo ⚠️ No logstash indices found
    )
    
    curl -s "http://localhost:9200/_cat/indices" | findstr "n8n-logs" >nul
    if not errorlevel 1 (
        echo ✅ N8N log indices found
    ) else (
        echo ⚠️ No N8N log indices found
    )
)

echo.
goto :eof

:: Function to check network connectivity
:check_network
echo 🌐 Network Connectivity
echo ======================

docker network ls | findstr "n8n_logging" >nul
if errorlevel 1 (
    echo ❌ n8n_logging network missing
) else (
    echo ✅ n8n_logging network exists
)

docker network ls | findstr "n8n_network" >nul
if errorlevel 1 (
    echo ❌ n8n_network network missing
) else (
    echo ✅ n8n_network network exists
)

echo.
goto :eof

:: Function to generate summary report
:generate_summary
echo 📋 Health Check Summary
echo ======================

set "overall_status=HEALTHY"

curl -s "http://localhost:9200/_cluster/health" >nul 2>&1
if errorlevel 1 (
    set "overall_status=CRITICAL"
) else (
    curl -s "http://localhost:5601/api/status" >nul 2>&1
    if errorlevel 1 (
        set "overall_status=DEGRADED"
    ) else (
        curl -s "http://localhost:9600/_node/stats" >nul 2>&1
        if errorlevel 1 (
            set "overall_status=DEGRADED"
        )
    )
)

echo 🕐 Timestamp: %date% %time%
echo 📊 Overall Status: !overall_status!
echo 🔧 Project: N8N AI Starter Kit v1.2.0
echo 📍 Component: Logging Stack (Stage 3.2)

if "!overall_status!"=="HEALTHY" (
    echo ✅ All systems operational
) else if "!overall_status!"=="DEGRADED" (
    echo ⚠️ Some components need attention
) else (
    echo ❌ Critical issues detected
)

echo.
echo 🔗 Quick Links:
echo   📊 Kibana Dashboard: http://localhost:5601
echo   🔍 Elasticsearch: http://localhost:9200
echo   📈 Logstash API: http://localhost:9600
echo.
echo 📚 Documentation:
echo   📖 Logging Guide: docs\LOGGING_SETUP_GUIDE.md
echo   🚨 Troubleshooting: TROUBLESHOOTING.md
goto :eof

:: Main execution
call :check_containers
call :check_apis
call :check_disk_usage
call :check_log_ingestion
call :check_network
call :generate_summary

echo ==============================================
echo Health check completed at %date% %time%

pause
