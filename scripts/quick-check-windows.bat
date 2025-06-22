@echo off
chcp 65001 >nul
echo.
echo ========================================
echo FAST CONTAINER CHECK FOR N8N AI STARTER KIT
echo ========================================
echo.

echo [INFO] Checking Docker status...
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running or not accessible!
    echo [INFO] Please start Docker and try again.
    pause
    exit /b 1
)
echo [OK] Docker is running

echo.
echo [INFO] Checking running containers...
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo [INFO] Testing main service endpoints...

echo [TEST] N8N Web UI (port 5678)...
curl -s --max-time 5 http://localhost:5678 >nul 2>&1
if errorlevel 1 (
    echo [FAIL] N8N not accessible on port 5678
) else (
    echo [OK] N8N is accessible
)

echo [TEST] Ollama API (port 11434)...
curl -s --max-time 5 http://localhost:11434 >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Ollama not accessible on port 11434
) else (
    echo [OK] Ollama is accessible
)

echo [TEST] Qdrant API (port 6333)...
curl -s --max-time 5 http://localhost:6333 >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Qdrant not accessible on port 6333
) else (
    echo [OK] Qdrant is accessible
)

echo.
echo [INFO] Checking container health status...
for /f "tokens=*" %%i in ('docker ps --format "{{.Names}}"') do (
    for /f "tokens=*" %%j in ('docker inspect --format="{{.State.Health.Status}}" %%i 2^>nul') do (
        if "%%j"=="healthy" (
            echo [HEALTHY] %%i
        ) else if "%%j"=="unhealthy" (
            echo [UNHEALTHY] %%i
        ) else if "%%j"=="starting" (
            echo [STARTING] %%i
        ) else (
            echo [NO-HEALTHCHECK] %%i
        )
    )
)

echo.
echo [INFO] Checking for recent errors in logs...
for /f "tokens=*" %%i in ('docker ps --format "{{.Names}}"') do (
    echo [LOG-CHECK] %%i...
    docker logs --tail 20 %%i 2>&1 | findstr /i "error fatal exception" >nul
    if errorlevel 1 (
        echo [OK] No critical errors found
    ) else (
        echo [WARNING] Errors found in logs - check manually
    )
)

echo.
echo ========================================
echo CONTAINER CHECK COMPLETED
echo ========================================
echo.
echo [INFO] For detailed analysis, use:
echo   - scripts/comprehensive-container-check.sh (Linux)
echo   - scripts/analyze-logs.sh [container] (Linux)
echo   - docker compose logs [service] (manual check)
echo.
pause
